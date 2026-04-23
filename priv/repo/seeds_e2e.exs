# E2E fixture seed — idempotent.
#
# Populates the dev database with a canonical set of fixtures so every
# Playwright spec can reference a stable run, workflow, spec, and
# template ID by a literal path:
#
#   * 2 runs with deterministic `workflow_id` so we can look them up
#     on a second run and reuse their uuidv7 IDs.
#   * 1 stage_run per run (satisfies the /runs/:id chrome).
#   * 1 workflow snapshot (from `priv/workflows/elixir_phoenix_feature.yaml`).
#   * 1 spec + revision.
#   * 1 draft (so /inbox isn't always in the empty state).
#
# Writes `test/e2e/.fixture-ids.json` so TypeScript fixtures can read
# the exact IDs without re-querying.
#
# Run with:
#
#     KILN_DB_ROLE=kiln_owner MIX_ENV=dev mix run priv/repo/seeds_e2e.exs
#
# Re-running is safe: upserts by stable `workflow_id` / `title` markers.

import Ecto.Query

if Mix.env() == :test do
  raise """
  priv/repo/seeds_e2e.exs must not run under MIX_ENV=test.

  This seed populates long-lived Playwright fixtures and will contaminate
  sandbox assumptions for unit and LiveView tests. Run it under the dev
  environment instead, for example:

      KILN_DB_ROLE=kiln_owner MIX_ENV=dev mix run priv/repo/seeds_e2e.exs
  """
end

alias Kiln.Repo
alias Kiln.Runs.Run
alias Kiln.Stages.StageRun
alias Kiln.Specs
alias Kiln.Specs.Spec
alias Kiln.Specs.SpecDraft
alias Kiln.Workflows
alias Kiln.Workflows.Loader
alias Kiln.Workflows.WorkflowDefinitionSnapshot

workflow_id_a = "e2e_fixture_run_a"
workflow_id_b = "e2e_fixture_run_b"
spec_title = "e2e fixture spec"
draft_title = "e2e fixture draft"
template_id = "hello-kiln"
checksum = String.duplicate("a", 64)

upsert_run = fn wf_id ->
  case Repo.get_by(Run, workflow_id: wf_id) do
    %Run{} = existing ->
      existing

    nil ->
      {:ok, run} =
        %Run{}
        |> Run.changeset(%{
          workflow_id: wf_id,
          workflow_version: 1,
          workflow_checksum: checksum,
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
          elapsed_seconds: 0,
          governed_attempt_count: 0,
          stuck_signal_window: []
        })
        |> Repo.insert()

      run
  end
end

run_a = upsert_run.(workflow_id_a)
run_b = upsert_run.(workflow_id_b)

ensure_stage = fn %Run{id: run_id} ->
  existing =
    StageRun
    |> where([s], s.run_id == ^run_id and s.workflow_stage_id == "e2e_stage")
    |> Repo.one()

  case existing do
    %StageRun{} ->
      :ok

    nil ->
      {:ok, _} =
        %StageRun{}
        |> StageRun.changeset(%{
          run_id: run_id,
          workflow_stage_id: "e2e_stage",
          kind: :planning,
          agent_role: :planner,
          attempt: 1,
          state: :pending,
          timeout_seconds: 300,
          sandbox: :readonly,
          tokens_used: 0,
          cost_usd: Decimal.new("0.0")
        })
        |> Repo.insert()

      :ok
  end
end

ensure_stage.(run_a)
ensure_stage.(run_b)

wf_path = Application.app_dir(:kiln, "priv/workflows/elixir_phoenix_feature.yaml")
{:ok, cg} = Loader.load(wf_path)
wf_yaml = File.read!(wf_path)

workflow_id =
  case Workflows.list_snapshots_for(cg.id, limit: 1) do
    [%WorkflowDefinitionSnapshot{workflow_id: wid} | _] ->
      wid

    [] ->
      {:ok, snap} =
        Workflows.record_snapshot(%{
          workflow_id: cg.id,
          version: cg.version,
          compiled_checksum: cg.checksum,
          yaml: wf_yaml
        })

      snap.workflow_id
  end

spec =
  case Repo.get_by(Spec, title: spec_title) do
    %Spec{} = existing ->
      existing

    nil ->
      {:ok, created} = Specs.create_spec(%{title: spec_title})

      {:ok, _rev} =
        Specs.create_revision(created, %{
          body: "# e2e spec\n\nSeeded by priv/repo/seeds_e2e.exs for Playwright.\n"
        })

      created
  end

case Repo.get_by(SpecDraft, title: draft_title) do
  %SpecDraft{} ->
    :ok

  nil ->
    {:ok, _draft} =
      Specs.create_draft(%{
        title: draft_title,
        body: "Draft body seeded by Playwright e2e fixtures.",
        source: :freeform
      })
end

ids = %{
  run_a_id: run_a.id,
  run_b_id: run_b.id,
  workflow_id: workflow_id,
  spec_id: spec.id,
  template_id: template_id
}

out_path = Path.join([File.cwd!(), "test", "e2e", ".fixture-ids.json"])
File.mkdir_p!(Path.dirname(out_path))
File.write!(out_path, Jason.encode!(ids, pretty: true) <> "\n")

IO.puts("[seeds_e2e] wrote #{out_path}")
IO.puts("[seeds_e2e] #{inspect(ids, pretty: true)}")
