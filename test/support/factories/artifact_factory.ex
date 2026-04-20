defmodule Kiln.Factory.Artifact do
  @moduledoc """
  ex_machina factory for `Kiln.Artifacts.Artifact` rows (Plan 02-03).

  Replaces the SHELL factory shipped in Plan 02-00. The Ecto-backed
  variant supports `build(:artifact)` (in-memory struct) and
  `insert(:artifact)` (persisted via `Kiln.Repo`).

  Default attrs:

    * `stage_run_id` — `nil`; CALLER MUST SUPPLY. Every artifact has a
      non-nullable FK to `stage_runs` with `on_delete: :restrict`. Build
      a parent stage_run (and its parent run) first and pass both ids:

          run = insert(:run)
          stage_run = insert(:stage_run, run_id: run.id)
          insert(:artifact, stage_run_id: stage_run.id, run_id: run.id)

      A default auto-insert of parent rows would hide the FK
      dependency and produce surprise orphans when tests use
      `build/1` without persisting.
    * `run_id` — `nil`; CALLER MUST SUPPLY (see above).
    * `name` — auto-sequenced (`artifact_0.md`, `artifact_1.md`, ...)
      to satisfy the per-stage-attempt unique `(stage_run_id, name)`
      index.
    * `sha256` — 64-char lowercase hex placeholder (satisfies the DB
      CHECK format). Tests that need a *real* hash should either
      round-trip through `Kiln.Artifacts.put/4` or supply an override.
    * `size_bytes` — 128 (well under the 50 MB D-75 cap).
    * `content_type` — `:"text/markdown"` (one of the five Ecto.Enum
      values in `Kiln.Artifacts.Artifact.content_types/0`).
    * `schema_version` — 1.
    * `producer_kind` — `"planning"`.

  Tests that need a specific field override pass it as the second arg
  to `build/2` or `insert/2`:

      insert(:artifact, stage_run_id: sr.id, run_id: r.id,
                        name: "plan.md", content_type: :"text/x-elixir")
  """

  use ExMachina.Ecto, repo: Kiln.Repo

  @doc """
  Build a `Kiln.Artifacts.Artifact` struct with sensible defaults. The
  `stage_run_id` and `run_id` fields are intentionally `nil` —
  callers MUST supply valid parent ids (see moduledoc).
  """
  @spec artifact_factory() :: Kiln.Artifacts.Artifact.t()
  def artifact_factory do
    %Kiln.Artifacts.Artifact{
      # Caller MUST supply stage_run_id + run_id (FK on_delete: :restrict).
      stage_run_id: nil,
      run_id: nil,
      name: sequence(:artifact_name, &"artifact_#{&1}.md"),
      # 64-char lowercase hex satisfies the DB CHECK + changeset regex
      sha256: String.duplicate("a", 64),
      size_bytes: 128,
      content_type: :"text/markdown",
      schema_version: 1,
      producer_kind: "planning"
    }
  end
end
