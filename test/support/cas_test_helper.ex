defmodule Kiln.CasTestHelper do
  @moduledoc """
  Per-test setup/teardown helper for `Kiln.Artifacts` content-addressed
  storage (D-77). Each test that touches the CAS path MUST get its own
  `cas_root` + `tmp_root` directory so concurrent tests don't corrupt
  each other's blobs (ex4/APFS rename(2) atomicity still holds, but two
  tests writing identical bytes to the same `<sha>` path can race).

  Pattern:

      defmodule Kiln.Artifacts.CasTest do
        use ExUnit.Case, async: false

        setup :with_tmp_cas

        test "round-trips a blob", %{cas_root: cas_root, tmp_root: tmp_root} do
          # ... code that reads Application.get_env(:kiln, :artifacts)
          # will see {cas_root: ..., tmp_root: ...} pointing at the
          # per-test tmpdirs.
        end

        defp with_tmp_cas(_ctx) do
          {cas_root, tmp_root} = Kiln.CasTestHelper.setup_tmp_cas()
          on_exit(fn -> Kiln.CasTestHelper.cleanup_tmp_cas({cas_root, tmp_root}) end)
          {:ok, cas_root: cas_root, tmp_root: tmp_root}
        end
      end

  The helper captures the existing `:artifacts` env entry before
  overriding so cleanup restores the pre-test value — threat T3 in the
  plan threat model (Application env bleed).

  Plan 03 activates this helper fully once `Kiln.Artifacts` ships; until
  then the helper is a fully-functional fs-only primitive (no Artifacts
  context calls).
  """

  @app :kiln
  @env_key :artifacts

  @doc """
  Creates `<tmp>/kiln_cas_<uuid>/cas` and `<tmp>/kiln_cas_<uuid>/tmp`
  directories and points `Application.put_env(:kiln, :artifacts, ...)` at
  them for the test duration. Returns `{cas_root, tmp_root}`.

  The caller is responsible for invoking `cleanup_tmp_cas/1` in
  `on_exit/1` — the helper can't do it automatically because `on_exit/1`
  must be registered from inside an ExUnit `setup` block.
  """
  @spec setup_tmp_cas() :: {String.t(), String.t()}
  def setup_tmp_cas do
    uuid = Ecto.UUID.generate()
    base = Path.join(System.tmp_dir!(), "kiln_cas_#{uuid}")
    cas_root = Path.join(base, "cas")
    tmp_root = Path.join(base, "tmp")

    File.mkdir_p!(cas_root)
    File.mkdir_p!(tmp_root)

    prior = Application.get_env(@app, @env_key)

    # Store the prior value in process-dict so `cleanup_tmp_cas/1` can
    # restore it. Keyed by the base directory so parallel tests don't
    # clobber each other's saved values.
    # credo:disable-for-next-line Kiln.Credo.NoProcessPut
    Process.put({__MODULE__, :prior, base}, prior)

    Application.put_env(@app, @env_key,
      cas_root: cas_root,
      tmp_root: tmp_root
    )

    {cas_root, tmp_root}
  end

  @doc """
  Removes the tmp directories created by `setup_tmp_cas/0` and restores
  the `:artifacts` env entry to whatever it was before the setup call.

  Pass the 2-tuple returned from `setup_tmp_cas/0`. Safe to call
  multiple times (each call is idempotent; missing dirs are ignored).
  """
  @spec cleanup_tmp_cas({String.t(), String.t()}) :: :ok
  def cleanup_tmp_cas({cas_root, tmp_root}) do
    base = cas_root |> Path.dirname()

    File.rm_rf!(base)

    case Process.delete({__MODULE__, :prior, base}) do
      nil ->
        Application.delete_env(@app, @env_key)

      prior ->
        Application.put_env(@app, @env_key, prior)
    end

    _ = tmp_root
    :ok
  end

  @doc """
  Convenience helper that wires `setup_tmp_cas/0` + `on_exit/1` cleanup
  into a single call from an ExUnit `setup` block.

  Returns `{:ok, cas_root: ..., tmp_root: ...}` so ExUnit merges the
  paths into the test context automatically.
  """
  @spec with_tmp_cas(((-> any()) -> any())) :: {:ok, keyword()}
  def with_tmp_cas(on_exit) when is_function(on_exit, 1) do
    pair = setup_tmp_cas()
    on_exit.(fn -> cleanup_tmp_cas(pair) end)
    {cas_root, tmp_root} = pair
    {:ok, cas_root: cas_root, tmp_root: tmp_root}
  end
end
