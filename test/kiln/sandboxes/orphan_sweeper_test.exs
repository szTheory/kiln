defmodule Kiln.Sandboxes.OrphanSweeperTest do
  use ExUnit.Case, async: false

  alias Kiln.Notifications.DedupCache
  alias Kiln.Sandboxes.OrphanSweeper

  setup do
    Application.put_env(:kiln, OrphanSweeper,
      list_orphans_fun: fn _boot_epoch -> [] end,
      system_cmd_fun: fn _cmd, _args, _opts -> {"", 0} end,
      audit_append_fun: fn _event -> {:ok, :stubbed} end,
      periodic_scan_ms: 0,
      boot_epoch_fun: fn -> 12_345 end
    )

    on_exit(fn ->
      Application.delete_env(:kiln, OrphanSweeper)
    end)

    :ok
  end

  test "start_link/1 starts successfully and survives unexpected messages" do
    pid =
      case start_supervised(OrphanSweeper) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    send(pid, :unexpected)
    assert %{boot_epoch: boot_epoch} = :sys.get_state(pid)
    assert is_integer(boot_epoch)
  end

  test "init/1 defers work by sending itself :boot_scan" do
    assert {:ok, %{boot_epoch: 12_345}} = OrphanSweeper.init([])
    assert_received :boot_scan
  end

  test "boot scan sweeps each orphan via docker rm and audit append" do
    parent = self()

    Application.put_env(:kiln, OrphanSweeper,
      list_orphans_fun: fn 12_345 -> ["dead-1", "dead-2"] end,
      system_cmd_fun: fn "docker", ["rm", "-f", container_id], _opts ->
        send(parent, {:docker_rm, container_id})
        {"", 0}
      end,
      audit_append_fun: fn event ->
        send(parent, {:audit_append, event})
        {:ok, :stubbed}
      end,
      periodic_scan_ms: 0,
      boot_epoch_fun: fn -> 12_345 end
    )

    assert {:noreply, %{boot_epoch: 12_345}} =
             OrphanSweeper.handle_info(:boot_scan, %{boot_epoch: 12_345})

    assert_received {:audit_append,
                     %{
                       event_kind: :orphan_container_swept,
                       payload: %{"container_id" => "dead-1"}
                     }}

    assert_received {:audit_append,
                     %{
                       event_kind: :orphan_container_swept,
                       payload: %{"container_id" => "dead-2"}
                     }}

    assert_received {:docker_rm, "dead-1"}
    assert_received {:docker_rm, "dead-2"}
    assert_received :periodic_scan
  end

  test "periodic scan re-arms its timer" do
    assert {:noreply, %{boot_epoch: 12_345}} =
             OrphanSweeper.handle_info(:periodic_scan, %{boot_epoch: 12_345})

    assert_received :periodic_scan
  end

  test "catch-all handle_info/2 ignores stray messages" do
    state = %{boot_epoch: 12_345}
    assert {:noreply, ^state} = OrphanSweeper.handle_info(:something_else, state)
  end

  test "boot_epoch_now/0 returns a monotonic integer" do
    first = OrphanSweeper.boot_epoch_now()
    second = OrphanSweeper.boot_epoch_now()

    assert is_integer(first)
    assert second >= first
  end

  test "Sandboxes.Supervisor starts OrphanSweeper first and DedupCache second" do
    assert {:ok, {%{strategy: :one_for_one}, children}} = Kiln.Sandboxes.Supervisor.init([])

    child_ids = Enum.map(children, & &1.id)

    assert child_ids == [Kiln.Sandboxes.OrphanSweeper, DedupCache]
  end

  test "Kiln.Sandboxes moduledoc is rewritten for Phase 3" do
    assert {:docs_v1, _, _, _, %{"en" => doc}, _, _} = Code.fetch_docs(Kiln.Sandboxes)
    assert doc =~ "cap-drop=ALL"
    assert doc =~ "no-new-privileges"
    refute doc =~ "Phase 4"
  end
end
