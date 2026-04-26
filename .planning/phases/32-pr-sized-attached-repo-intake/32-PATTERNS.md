# Phase 32: PR-sized attached-repo intake - Pattern Map

**Mapped:** 2026-04-24
**Files analyzed:** 8
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `priv/repo/migrations/*_spec_drafts_attached_repo_fields.exs` | migration | CRUD | `priv/repo/migrations/20260422000006_spec_drafts_follow_up_fields.exs` | exact |
| `lib/kiln/specs/spec_draft.ex` | model | CRUD | `lib/kiln/specs/spec_draft.ex` | exact |
| `lib/kiln/specs.ex` | service | CRUD | `lib/kiln/specs.ex` | exact |
| `lib/kiln/attach/intake.ex` | service | request-response | `lib/kiln/specs.ex` (`file_follow_up_from_run/2`) + `lib/kiln/attach.ex` | role-match |
| `lib/kiln/attach.ex` | service | request-response | `lib/kiln/attach.ex` | exact |
| `priv/repo/migrations/*_add_attached_request_run_links.exs` | migration | CRUD | `priv/repo/migrations/20260419000003_add_github_delivery_snapshot_to_runs.exs` | exact |
| `lib/kiln/runs/run.ex` | model | CRUD | `lib/kiln/runs/run.ex` | exact |
| `lib/kiln/runs.ex` | service | request-response | `lib/kiln/runs.ex` | exact |
| `lib/kiln_web/live/attach_entry_live.ex` | component | request-response | `lib/kiln_web/live/attach_entry_live.ex` | exact |
| `test/kiln/runs/attached_request_start_test.exs` | test | request-response | `test/kiln/specs/follow_up_draft_test.exs` + `test/kiln/runs_test.exs` | role-match |
| `test/integration/attached_repo_intake_test.exs` | test | integration | `test/integration/attach_workspace_hydration_test.exs` + `test/integration/github_delivery_test.exs` | role-match |
| `test/kiln/specs/attach_*_test.exs` | test | CRUD | `test/kiln/specs/follow_up_draft_test.exs` | exact |
| `test/kiln_web/live/attach_entry_live_test.exs` | test | request-response | `test/kiln_web/live/attach_entry_live_test.exs` | exact |

## Pattern Assignments

### `priv/repo/migrations/*_spec_drafts_attached_repo_fields.exs` (migration, CRUD)

**Analog:** `priv/repo/migrations/20260422000006_spec_drafts_follow_up_fields.exs`

**Alter-table pattern** (lines 9-24):
```elixir
def up do
  alter table(:spec_drafts) do
    add(:source_run_id, references(:runs, type: :binary_id, on_delete: :nilify_all))
    add(:artifact_refs, :map, null: false, default: fragment("'[]'::jsonb"))
    add(:operator_summary, :text)
  end

  create(index(:spec_drafts, [:source_run_id], name: :spec_drafts_source_run_id_idx))

  execute("ALTER TABLE spec_drafts DROP CONSTRAINT IF EXISTS spec_drafts_source_values")

  execute("""
  ALTER TABLE spec_drafts
    ADD CONSTRAINT spec_drafts_source_values
    CHECK (source IN ('freeform', 'markdown_import', 'github_issue', 'run_follow_up'))
  """)
end
```

**Down migration pattern** (lines 27-42):
```elixir
def down do
  execute("ALTER TABLE spec_drafts DROP CONSTRAINT IF EXISTS spec_drafts_source_values")

  execute("""
  ALTER TABLE spec_drafts
    ADD CONSTRAINT spec_drafts_source_values
    CHECK (source IN ('freeform', 'markdown_import', 'github_issue'))
  """)

  drop(index(:spec_drafts, [:source_run_id], name: :spec_drafts_source_run_id_idx))

  alter table(:spec_drafts) do
    remove(:operator_summary)
    remove(:artifact_refs)
    remove(:source_run_id)
  end
end
```

**Also copy grants/ownership style from** `priv/repo/migrations/20260422000005_create_spec_drafts.exs` lines 77-87 and `priv/repo/migrations/20260424120544_create_attached_repos.exs` lines 71-84 when creating a new table instead of altering an existing one.

---

### `lib/kiln/specs/spec_draft.ex` (model, CRUD)

**Analog:** `lib/kiln/specs/spec_draft.ex`

**Schema + enum pattern** (lines 20-45):
```elixir
schema "spec_drafts" do
  field(:title, :string)
  field(:body, :string)

  field(:source, Ecto.Enum,
    values: [:freeform, :markdown_import, :github_issue, :run_follow_up, :template]
  )

  field(:inbox_state, Ecto.Enum, values: [:open, :archived, :promoted])

  field(:archived_at, :utc_datetime_usec)
  belongs_to(:promoted_spec, Kiln.Specs.Spec, foreign_key: :promoted_spec_id)

  field(:github_node_id, :string)
  field(:github_owner, :string)
  field(:github_repo, :string)
  field(:github_issue_number, :integer)

  field(:etag, :string)
  field(:last_synced_at, :utc_datetime_usec)

  field(:source_run_id, :binary_id)
  field(:artifact_refs, {:array, :map}, default: [])
  field(:operator_summary, :string)

  timestamps(type: :utc_datetime_usec)
end
```

**Changeset pattern** (lines 48-71):
```elixir
def changeset(draft, attrs) do
  draft
  |> cast(attrs, [
    :title,
    :body,
    :source,
    :inbox_state,
    :archived_at,
    :promoted_spec_id,
    :github_node_id,
    :github_owner,
    :github_repo,
    :github_issue_number,
    :etag,
    :last_synced_at,
    :source_run_id,
    :artifact_refs,
    :operator_summary
  ])
  |> validate_required([:title, :body, :source])
  |> validate_number(:github_issue_number, greater_than: 0)
  |> foreign_key_constraint(:promoted_spec_id)
end
```

**Phase 32 implication:** if attach-scoped intake adds fields like `attached_repo_id`, `request_kind`, or structured acceptance data, extend this schema and cast list rather than creating a second draft model.

---

### `lib/kiln/specs.ex` (service, CRUD)

**Analog:** `lib/kiln/specs.ex`

**Simple draft creation boundary** (lines 80-90):
```elixir
@spec create_draft(map()) :: {:ok, SpecDraft.t()} | {:error, Ecto.Changeset.t()}
def create_draft(attrs) when is_map(attrs) do
  attrs = Map.put_new(attrs, :inbox_state, :open)

  %SpecDraft{}
  |> SpecDraft.changeset(attrs)
  |> Repo.insert()
end
```

**Promotion transaction pattern** (lines 145-180, 235-249):
```elixir
def promote_draft(draft_id, opts \\ []) when is_binary(draft_id) and is_list(opts) do
  Repo.transaction(fn ->
    draft =
      from(d in SpecDraft,
        where: d.id == ^draft_id,
        lock: "FOR UPDATE"
      )
      |> Repo.one()

    case draft do
      nil -> Repo.rollback(:not_found)
      %SpecDraft{inbox_state: s} when s != :open -> Repo.rollback(:invalid_state)
      %SpecDraft{} = draft ->
        case promote_locked_open_draft(draft, opts) do
          {:ok, result} -> result
          {:error, %Ecto.Changeset{} = cs} -> Repo.rollback(cs)
          {:error, other} -> Repo.rollback(other)
        end
    end
  end)
  |> case do
    {:ok, result} -> {:ok, result}
    {:error, reason} -> {:error, reason}
  end
end
```

```elixir
defp promote_locked_open_draft(%SpecDraft{} = draft, opts) when is_list(opts) do
  correlation_id = Keyword.get(opts, :correlation_id, Ecto.UUID.generate())
  template_id = Keyword.get(opts, :template_id)

  with {:ok, spec} <- insert_spec_from_draft(draft),
       {:ok, rev} <- insert_revision_from_draft(spec, draft),
       {:ok, promoted_draft} <- mark_draft_promoted(draft, spec.id),
       {:ok, _audit} <-
         Audit.append(%{
           event_kind: :spec_draft_promoted,
           correlation_id: correlation_id,
           payload: audit_payload_spec_draft_promoted(draft, spec, rev, template_id)
         }) do
    {:ok, %{draft: promoted_draft, spec: spec, revision: rev}}
  end
end
```

**Idempotent draft-from-context pattern** (lines 327-417, strongest Phase 32 analog):
```elixir
@spec file_follow_up_from_run(Run.t(), keyword()) ::
        {:ok, SpecDraft.t()} | {:error, term()}
def file_follow_up_from_run(%Run{} = run, opts \\ []) do
  correlation_id = Keyword.get(opts, :correlation_id, Ecto.UUID.generate())
  audit_cid = Keyword.get(opts, :audit_correlation_id, correlation_id)
  idempotency_key = "follow_up_draft:" <> run.id <> ":" <> correlation_id

  Repo.transaction(fn ->
    op = follow_up_fetch_or_insert_intent!(idempotency_key, run, audit_cid)

    case op.state do
      :completed ->
        ...

      :intent_recorded ->
        artifact_refs = Artifacts.list_refs_for_run(run.id)
        summary = follow_up_operator_summary(run)

### `priv/repo/migrations/*_add_attached_request_run_links.exs` (migration, CRUD)

**Analog:** `priv/repo/migrations/20260419000003_add_github_delivery_snapshot_to_runs.exs`

Use the existing runs-table alter pattern for additive fields and keep the migration scoped to durable execution identity rather than derived snapshots.

### `lib/kiln/runs/run.ex` (model, CRUD)

**Analog:** `lib/kiln/runs/run.ex`

Follow the current schema and changeset pattern by adding the new attach/spec linkage fields directly on the run schema and keeping them in the narrow cast lists where run creation/start needs them.

### `lib/kiln/runs.ex` (service, request-response)

**Analog:** `lib/kiln/runs.ex`

Follow the existing `create_for_promoted_template/2` and `start_for_promoted_template/3` split:

- one create function that persists a queued run with workflow metadata
- one start function that preserves the blocked-start contract and delegates to `RunDirector.start_run/1`
- keep workflow loading and checksum discipline inside `Kiln.Runs`, not in LiveView

### `test/kiln/runs/attached_request_start_test.exs` (test, request-response)

**Analogs:** `test/kiln/specs/follow_up_draft_test.exs`, `test/kiln/runs_test.exs`

Copy the repo style of focused context tests that verify one public API contract at a time:

- persistence assertions on explicit foreign-key fields
- typed blocked return coverage
- idempotency or duplicate-start assertions where the launcher contract depends on stable identity

### `test/integration/attached_repo_intake_test.exs` (test, integration)

**Analogs:** `test/integration/attach_workspace_hydration_test.exs`, `test/integration/github_delivery_test.exs`

Keep the integration test hermetic and narrow:

- construct one realistic attached-repo fixture
- exercise the real sequence `Attach.Intake -> Specs.promote_draft -> Runs.start_for_attached_request`
- assert durable linkage and queued/started state, not downstream GitHub delivery

        draft_attrs = %{
          title: "Follow-up: #{run.workflow_id}",
          body: follow_up_lazy_body(),
          source: :run_follow_up,
          inbox_state: :open,
          source_run_id: run.id,
          artifact_refs: artifact_refs,
          operator_summary: summary
        }

        with {:ok, draft} <- insert_follow_up_draft(draft_attrs),
             {:ok, _} <- Audit.append(%{event_kind: :follow_up_drafted, ...}),
             {:ok, op_done} <- Repo.update(Operation.changeset(op, %{state: :completed, ...})),
             {:ok, _} <- Audit.append(%{event_kind: :external_op_completed, ...}) do
          draft
        else
          {:error, reason} -> Repo.rollback(reason)
        end
    end
  end)
  |> case do
    {:ok, draft} -> {:ok, draft}
    {:error, reason} -> {:error, reason}
  end
end
```

**Idempotency helper pattern** (lines 420-459):
```elixir
defp follow_up_fetch_or_insert_intent!(idempotency_key, %Run{} = run, audit_cid) do
  now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

  insert_attrs = %{
    op_kind: "follow_up_draft",
    idempotency_key: idempotency_key,
    state: :intent_recorded,
    intent_recorded_at: now,
    run_id: run.id,
    intent_payload: %{"correlation_id" => idempotency_key}
  }

  cs = Operation.changeset(%Operation{}, insert_attrs)

  case Repo.insert(cs, on_conflict: :nothing, conflict_target: :idempotency_key) do
    {:ok, %Operation{id: nil}} ->
      Repo.one!(
        from(o in Operation,
          where: o.idempotency_key == ^idempotency_key,
          lock: "FOR UPDATE"
        )
      )

    {:ok, %Operation{} = op} ->
      {:ok, _} =
        Audit.append(%{
          event_kind: :external_op_intent_recorded,
          run_id: run.id,
          correlation_id: audit_cid,
          payload: %{"op_kind" => op.op_kind, "idempotency_key" => op.idempotency_key}
        })

      op

    {:error, changeset} ->
      Repo.rollback(changeset)
  end
end
```

**Phase 32 implication:** attach-aware intake should look like this follow-up flow: stable upstream context, one transaction, draft creation inside the domain boundary, optional idempotency key, and audit append before returning control to LiveView.

---

### `lib/kiln/attach/intake.ex` (service, request-response)

**Analog:** `lib/kiln/specs.ex` (`file_follow_up_from_run/2`) and `lib/kiln/attach.ex`

**Public-boundary pattern from `lib/kiln/attach.ex`** (lines 21-33, 55-80):
```elixir
@spec resolve_source(String.t(), keyword()) :: resolve_result()
def resolve_source(raw_input, opts \\ []) when is_binary(raw_input) do
  Source.resolve(raw_input, opts)
end

@spec hydrate_workspace(Source.t(), keyword()) :: hydrate_result()
def hydrate_workspace(%Source{} = source, opts \\ []) do
  WorkspaceManager.hydrate(source, opts)
end
```

```elixir
@spec get_attached_repo(Ecto.UUID.t()) :: {:ok, AttachedRepo.t()} | {:error, :not_found}
def get_attached_repo(id) when is_binary(id) do
  case Repo.get(AttachedRepo, id) do
    %AttachedRepo{} = attached_repo -> {:ok, attached_repo}
    nil -> {:error, :not_found}
  end
end
```

**Creation-from-context pattern to copy from `lib/kiln/specs.ex`**:
- Use the `file_follow_up_from_run/2` transaction shape for “attached repo + bounded request -> draft”.
- Keep `attached_repo_id` lookup outside prose parsing; fetch the durable repo row first through `Kiln.Attach`.
- Return tagged tuples only; do not let LiveView own `Repo.transaction/1`.

**Recommended assignment:** if Phase 32 adds a new module, make it a thin orchestration boundary that validates/fetches attached repo context, assembles draft attrs, and delegates persistence to `Kiln.Specs`.

---

### `lib/kiln/attach.ex` (service, request-response)

**Analog:** `lib/kiln/attach.ex`

**Facade/alias/import pattern** (lines 6-19):
```elixir
import Ecto.Query

alias Kiln.Attach.AttachedRepo
alias Kiln.Attach.Delivery
alias Kiln.Attach.SafetyGate
alias Kiln.Attach.Source
alias Kiln.Attach.WorkspaceManager
alias Kiln.Repo

@type resolve_result :: {:ok, Source.t()} | {:error, Source.error()}
@type hydrate_result :: {:ok, WorkspaceManager.result()} | {:error, WorkspaceManager.error()}
```

**Upsert boundary pattern** (lines 36-47):
```elixir
def create_or_update_attached_repo(%Source{} = source, %WorkspaceManager{} = hydrated) do
  attrs = attached_repo_attrs(source, hydrated)

  %AttachedRepo{}
  |> AttachedRepo.changeset(attrs)
  |> Repo.insert(
    on_conflict: {:replace_all_except, [:id, :inserted_at]},
    conflict_target: :source_fingerprint,
    returning: true
  )
end
```

**Lookup pattern** (lines 63-69):
```elixir
def get_attached_repo_by_workspace_key(workspace_key) when is_binary(workspace_key) do
  case Repo.one(from(a in AttachedRepo, where: a.workspace_key == ^workspace_key)) do
    %AttachedRepo{} = attached_repo -> {:ok, attached_repo}
    nil -> {:error, :not_found}
  end
end
```

**Phase 32 implication:** if `Kiln.Attach` itself is modified instead of adding `Kiln.Attach.Intake`, keep the boundary style: narrow public functions, simple tuple returns, and no UI-specific concerns.

---

### `lib/kiln_web/live/attach_entry_live.ex` (component, request-response)

**Analog:** `lib/kiln_web/live/attach_entry_live.ex`

**Mount/form initialization pattern** (lines 12-22):
```elixir
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:page_title, "Attach existing repo")
   |> assign(:resolution_state, :untouched)
   |> assign(:attach_ready, nil)
   |> assign(:attach_blocked, nil)
   |> assign(:resolved_source, nil)
   |> assign(:source_error, nil)
   |> assign(:form, to_form(%{"source" => ""}, as: :attach_source))}
end
```

**Thin event-handler pattern** (lines 25-40):
```elixir
def handle_event("validate_source", %{"attach_source" => params}, socket) do
  source = Map.get(params, "source", "")

  {:noreply,
   if String.trim(source) == "" do
     reset_resolution(socket, params)
   else
     assign_resolution(socket, params, Attach.validate_source(source))
   end}
end

def handle_event("resolve_source", %{"attach_source" => params}, socket) do
  source = Map.get(params, "source", "")

  {:noreply, submit_attach(socket, params, source)}
end
```

**LiveView form + stable ids pattern** (lines 112-139):
```heex
<.form
  for={@form}
  id="attach-source-form"
  class="space-y-4"
  phx-change="validate_source"
  phx-submit="resolve_source"
>
  <.input
    field={@form[:source]}
    id="attach-source-input"
    type="text"
    label="Repo source"
    placeholder="/Users/operator/project or https://github.com/owner/repo"
  />

  <div class="flex flex-wrap items-center gap-3">
    <button
      id="attach-source-submit"
      type="submit"
      class="btn btn-primary transition-transform duration-150 hover:-translate-y-0.5"
    >
      Resolve source
    </button>
  </div>
</.form>
```

**Backend orchestration stays in helper, not template/event body** (lines 369-404):
```elixir
defp submit_attach(socket, params, source_input) do
  opts = attach_runtime_opts()

  case Attach.resolve_source(source_input) do
    {:ok, resolved_source} ->
      with {:ok, hydrated} <- Attach.hydrate_workspace(resolved_source, opts),
           {:ok, _attached_repo} <-
             Attach.create_or_update_attached_repo(resolved_source, hydrated),
           {:ok, ready} <- Attach.preflight_workspace(resolved_source, hydrated, opts) do
        ...
      else
        {:blocked, blocked} -> ...
        {:error, %Ecto.Changeset{} = changeset} -> ...
        {:error, error} when is_map(error) -> ...
      end

    {:error, source_error} ->
      assign_resolution(socket, params, {:error, source_error})
  end
end
```

**Phase 32 implication:** new bounded-request intake on `/attach` should reuse this style: one `to_form/2` assign, explicit DOM ids, honest ready/blocked states, and a thin `handle_event` that calls a backend boundary.

---

### `test/kiln/specs/attach_*_test.exs` (test, CRUD)

**Analog:** `test/kiln/specs/follow_up_draft_test.exs`

**Idempotency test structure** (lines 9-20):
```elixir
test "file_follow_up_from_run is idempotent for the same correlation id" do
  run = RunFactory.insert(:run, state: :merged, workflow_id: "wf_follow_up")
  cid = Ecto.UUID.generate()

  assert {:ok, %SpecDraft{id: id1}} =
           Specs.file_follow_up_from_run(run, correlation_id: cid)

  assert {:ok, %SpecDraft{id: id2}} =
           Specs.file_follow_up_from_run(run, correlation_id: cid)

  assert id1 == id2
  assert Repo.aggregate(from(d in SpecDraft, where: d.source_run_id == ^run.id), :count) == 1
end
```

**Distinct-input test structure** (lines 23-30):
```elixir
test "different correlation ids create distinct drafts" do
  run = RunFactory.insert(:run, state: :merged, workflow_id: "wf_follow_up_2")

  assert {:ok, d1} = Specs.file_follow_up_from_run(run, correlation_id: Ecto.UUID.generate())
  assert {:ok, d2} = Specs.file_follow_up_from_run(run, correlation_id: Ecto.UUID.generate())

  assert d1.id != d2.id
  assert Repo.aggregate(from(d in SpecDraft, where: d.source_run_id == ^run.id), :count) == 2
end
```

**Phase 32 implication:** domain tests should assert one durable draft per attach request when correlation/idempotency is reused, and should count persisted `spec_drafts` rows rather than testing internal helpers.

---

### `test/kiln_web/live/attach_entry_live_test.exs` (test, request-response)

**Analog:** `test/kiln_web/live/attach_entry_live_test.exs`

**Stable-id smoke test pattern** (lines 16-31):
```elixir
test "mounts the attach intake surface with stable ids and untouched guidance", %{conn: conn} do
  {:ok, view, html} = live(conn, ~p"/attach")

  assert has_element?(view, "#attach-entry-root")
  assert has_element?(view, "#attach-entry-hero")
  assert has_element?(view, "#attach-supported-sources")
  assert has_element?(view, "#attach-source-form")
  assert has_element?(view, "#attach-source-input")
  assert has_element?(view, "#attach-source-submit")
  assert has_element?(view, "#attach-source-untouched")
  assert has_element?(view, "#attach-next-step")
  assert has_element?(view, "#attach-back-to-templates")
  refute has_element?(view, "#attach-source-resolved")
  refute has_element?(view, "#attach-source-error")
  assert html =~ "Supports a local path, an existing clone, or a GitHub URL."
end
```

**Form-submit test pattern** (lines 42-52):
```elixir
html =
  view
  |> form("#attach-source-form", attach_source: %{source: repo_root})
  |> render_submit()

assert has_element?(view, "#attach-ready")
assert has_element?(view, "#attach-ready-summary")
refute has_element?(view, "#attach-blocked")
assert html =~ "Attach ready for the next branch and draft PR phase"
```

**Blocked-state truth-surface pattern** (lines 85-96):
```elixir
view
|> form("#attach-source-form", attach_source: %{source: repo_root})
|> render_submit()

html = render(view)

assert has_element?(view, "#attach-blocked")
assert has_element?(view, "#attach-remediation-summary")
refute has_element?(view, "#attach-ready")
assert html =~ "Kiln refuses to mark this attached repo ready"
```

**Phase 32 implication:** extend this same test file with assertions for the new post-ready bounded-request form and its stable ids; keep using `has_element?/2`, `form/3`, and rendered outcome checks rather than raw HTML snapshots.

## Shared Patterns

### LiveView Form Handling
**Sources:** `lib/kiln_web/live/attach_entry_live.ex` lines 12-40, 112-139; `lib/kiln_web/live/inbox_live.ex` lines 15-31, 148-171, 330-404
**Apply to:** Any new attach-request form or attach-specific edit surface
```elixir
|> assign(:form, to_form(%{"source" => ""}, as: :attach_source))
```

```heex
<.form for={@form} id="attach-source-form" phx-submit="resolve_source">
  <.input field={@form[:source]} id="attach-source-input" type="text" />
</.form>
```

Use `to_form/2`, `<.input>`, and explicit IDs. Keep form state in assigns and submit through `handle_event/3`.

### Streamed Draft Lists
**Source:** `lib/kiln_web/live/inbox_live.ex` lines 240-246, 289-328
**Apply to:** Any attach flow that reuses inbox-style draft listing
```elixir
socket
|> assign(:drafts_empty?, drafts == [])
|> stream(:drafts, drafts, reset: true, dom_id: &"draft-#{&1.id}")
```

```heex
<div id="inbox-drafts" phx-update="stream" class="space-y-3">
  <div :for={{dom_id, draft} <- @streams.drafts} id={dom_id}>
```

### Idempotent Intent Recording + Audit
**Source:** `lib/kiln/specs.ex` lines 337-459
**Apply to:** Attach-aware draft creation if retries or double-submit dedupe matters
```elixir
Repo.insert(cs, on_conflict: :nothing, conflict_target: :idempotency_key)
```

```elixir
Audit.append(%{
  event_kind: :external_op_intent_recorded,
  run_id: run.id,
  correlation_id: audit_cid,
  payload: %{"op_kind" => op.op_kind, "idempotency_key" => op.idempotency_key}
})
```

### Attach Boundary Ownership
**Source:** `lib/kiln/attach.ex` lines 55-80
**Apply to:** Any Phase 32 code that needs attached repo facts
```elixir
case Repo.get(AttachedRepo, id) do
  %AttachedRepo{} = attached_repo -> {:ok, attached_repo}
  nil -> {:error, :not_found}
end
```

Fetch attached repo state through `Kiln.Attach`; do not recover repo identity from operator prose in the LiveView.

### Schema Extension Pattern
**Sources:** `lib/kiln/specs/spec_draft.ex` lines 20-71; `priv/repo/migrations/20260422000006_spec_drafts_follow_up_fields.exs` lines 9-42; `priv/repo/migrations/20260422000007_spec_drafts_source_template.exs` lines 8-25
**Apply to:** New attach-request fields on `spec_drafts`
```elixir
field(:source, Ecto.Enum,
  values: [:freeform, :markdown_import, :github_issue, :run_follow_up, :template]
)
```

When adding a new enum value or fields, update both the schema and the DB constraint in the migration.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/kiln/attach/intake.ex` | service | request-response | No existing attach-specific intake orchestration module exists yet; closest pattern is split between `Kiln.Attach` facade functions and `Specs.file_follow_up_from_run/2`. |

## Metadata

**Analog search scope:** `lib/kiln/**`, `lib/kiln_web/live/**`, `test/kiln/**`, `test/kiln_web/live/**`, `priv/repo/migrations/**`
**Files scanned:** 15
**Pattern extraction date:** 2026-04-24
