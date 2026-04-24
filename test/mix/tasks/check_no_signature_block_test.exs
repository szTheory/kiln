defmodule Mix.Tasks.CheckNoSignatureBlockTest do
  @moduledoc """
  Smoke test for the Phase 2 / D-65 CI gate. Exercises both the
  passing path (no `priv/workflows/*.yaml` populates `signature:`) and
  the failing path (a transient fixture with a populated `signature:`
  triggers `exit({:shutdown, 1})`).

  `async: false` because the test writes to `priv/workflows/` — a repo
  directory shared by every runner in the OS process.
  """
  use ExUnit.Case, async: false

  alias Mix.Tasks.CheckNoSignatureBlock

  @workflows_dir "priv/workflows"
  @bogus_file Path.join(@workflows_dir, "_test_bogus_signature.yaml")

  setup do
    File.mkdir_p!(@workflows_dir)

    # Defensive cleanup on start + end — a crashed prior run must not
    # leave the bogus fixture in place and poison later CI runs.
    File.rm(@bogus_file)
    on_exit(fn -> File.rm(@bogus_file) end)

    :ok
  end

  test "passes when no priv/workflows/*.yaml has a populated signature" do
    # Ensure the bogus fixture doesn't exist; task should report OK and
    # return :ok (NOT call `exit({:shutdown, 1})`).
    File.rm(@bogus_file)

    result =
      try do
        CheckNoSignatureBlock.run([])
      catch
        :exit, reason -> {:exited, reason}
      end

    assert result == :ok
  end

  test "fails with shutdown-1 when a priv/workflows/*.yaml has a non-null signature" do
    try do
      # Ship a minimally-valid shaped workflow whose only defect is the
      # non-null `signature:` block. Plan 02-00 ships the analogous
      # rejection fixture under test/support/fixtures/workflows/, but THAT
      # path is out of scope for the gate's priv/workflows/*.yaml glob —
      # we need a fresh file under priv/workflows/ for this test.
      File.write!(@bogus_file, """
      apiVersion: kiln.dev/v1
      id: bogus
      version: 1
      metadata:
        description: "test"
      signature:
        alg: sigstore
        bundle: AAAA
      spec:
        caps:
          max_retries: 3
          max_tokens_usd: 1
          max_elapsed_seconds: 60
          max_stage_duration_seconds: 30
        model_profile: elixir_lib
        stages: []
      """)

      result =
        try do
          CheckNoSignatureBlock.run([])
        catch
          :exit, reason -> {:exited, reason}
        end

      assert {:exited, {:shutdown, 1}} = result
    after
      File.rm(@bogus_file)
    end
  end
end
