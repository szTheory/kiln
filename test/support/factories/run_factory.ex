defmodule Kiln.Factory.Run do
  @moduledoc """
  ex_machina factory for `Kiln.Runs.Run` rows (Plan 02-02).

  Replaces the SHELL factory shipped in Plan 02-00. The Ecto-backed
  variant supports `build(:run)` (in-memory struct) and
  `insert(:run)` (persisted via `Kiln.Repo`).

  Default attrs:
    * `workflow_id` — auto-sequenced (`wf_0`, `wf_1`, ...) for test
      isolation
    * `workflow_version` — 1
    * `workflow_checksum` — canonical 64-char lowercase hex placeholder
      (matches the DB CHECK format)
    * `state` — `:queued` (the only state `Kiln.Runs.create/1` should
      produce)
    * `model_profile_snapshot` / `caps_snapshot` — non-empty maps
      matching the D-56/D-57 shapes so downstream consumers can pattern
      match on them
    * `correlation_id` — fresh UUID per built row
    * `tokens_used_usd` — `Decimal.new("0.0")`
    * `elapsed_seconds` — 0

  Tests that need a specific field override pass it as the second arg
  to `build/2` or `insert/2`:

      build(:run, state: :planning, workflow_id: "my_wf")
      insert(:run, correlation_id: "fixed-cid-for-assertion")
  """

  use ExMachina.Ecto, repo: Kiln.Repo

  @doc """
  Build a `Kiln.Runs.Run` struct with sensible defaults. Use `build/1`
  for in-memory assertions and `insert/1` for persisted fixtures.
  """
  @spec run_factory() :: Kiln.Runs.Run.t()
  def run_factory do
    %Kiln.Runs.Run{
      workflow_id: sequence(:workflow_id, &"wf_#{&1}"),
      workflow_version: 1,
      # 64-char lowercase hex satisfies the DB CHECK + changeset regex
      workflow_checksum: String.duplicate("a", 64),
      state: :queued,
      model_profile_snapshot: %{
        "profile" => "elixir_lib",
        "roles" => %{"planner" => "sonnet-class", "coder" => "sonnet-class"}
      },
      caps_snapshot: %{
        "max_retries" => 3,
        "max_tokens_usd" => 1.0,
        "max_elapsed_seconds" => 600,
        "max_stage_duration_seconds" => 300
      },
      correlation_id: Ecto.UUID.generate(),
      tokens_used_usd: Decimal.new("0.0"),
      elapsed_seconds: 0
    }
  end
end
