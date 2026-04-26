# Phase 31: Draft PR trust ramp and attach proof - Pattern Map

**Mapped:** 2026-04-24
**Files analyzed:** 7 implied target files
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/kiln/attach/branch_name.ex` | utility | transform | `lib/kiln/attach/workspace_manager.ex` | data-flow match |
| `lib/kiln/attach/delivery.ex` | service | request-response | `lib/kiln/attach.ex` | role-match |
| `lib/kiln/github/push_worker.ex` | worker/service | event-driven | `lib/kiln/github/push_worker.ex` | exact |
| `lib/kiln/github/open_pr_worker.ex` | worker/service | event-driven | `lib/kiln/github/open_pr_worker.ex` | exact |
| `lib/kiln/github/pr_formatter.ex` | utility | transform | `lib/kiln/github/cli.ex` | partial |
| `lib/mix/tasks/kiln.attach.prove.ex` | config/task | batch | `lib/mix/tasks/kiln.first_run.prove.ex` | exact |
| `test/integration/attach_delivery_test.exs` and `test/kiln_web/live/attach_entry_live_test.exs` | test | request-response | `test/integration/github_delivery_test.exs`, `test/kiln/github/push_worker_test.exs`, `test/kiln/github/open_pr_worker_test.exs`, `test/kiln_web/live/attach_entry_live_test.exs` | exact |

## Pattern Assignments

### `lib/kiln/attach/branch_name.ex` (utility, transform)

**Primary analog:** `lib/kiln/attach/workspace_manager.ex`

Use the existing “human slug + durable hash suffix” shape instead of inventing opaque UUID-only names or slug-only names.

**Durable identifier pattern** from [lib/kiln/attach/workspace_manager.ex](/Users/jon/projects/kiln/lib/kiln/attach/workspace_manager.ex:53):
```elixir
def workspace_key(%Source{} = source) do
  fingerprint =
    case source.kind do
      :local_path -> "#{source.kind}:#{source.canonical_root}"
      :github_url -> "#{source.kind}:#{source.canonical_input}"
    end

  hash =
    :sha256
    |> :crypto.hash(fingerprint)
    |> Base.encode16(case: :lower)
    |> binary_part(0, 12)
```

**Readable slug sanitization** from [lib/kiln/attach/workspace_manager.ex](/Users/jon/projects/kiln/lib/kiln/attach/workspace_manager.ex:67):
```elixir
slug =
  source.repo_identity.slug
  |> String.replace("/", "-")
  |> String.replace(~r/[^a-zA-Z0-9_-]+/, "-")
  |> String.trim("-")
  |> String.slice(0, 48)
```

**Persisted attached-repo identity** from [lib/kiln/attach.ex](/Users/jon/projects/kiln/lib/kiln/attach.ex:70):
```elixir
%{
  repo_slug: source.repo_identity.slug,
  source_fingerprint: source_fingerprint(source),
  workspace_key: hydrated.workspace_key,
  workspace_path: hydrated.workspace_path,
  remote_url: hydrated.remote_url,
  base_branch: hydrated.base_branch
}
```

**What to copy for Phase 31**
- Derive the durable branch suffix from immutable run identity, matching the existing “descriptive slug + stable discriminator” posture.
- Keep the human-readable slug descriptive only.
- Freeze the chosen branch name once per run, the same way attach freezes `workspace_key` and persistence facts once.

**Anti-patterns to avoid**
- Do not make the slug the durable key.
- Do not recompute a new branch name on every retry.
- Do not trust arbitrary operator input as branch text without sanitization and validation.

### `lib/kiln/attach/delivery.ex` (service, request-response)

**Primary analog:** `lib/kiln/attach.ex`

Phase 31 should extend the existing narrow attach boundary instead of reaching into schema internals or re-discovering repo facts ad hoc.

**Thin boundary pattern** from [lib/kiln/attach.ex](/Users/jon/projects/kiln/lib/kiln/attach.ex:29):
```elixir
@spec hydrate_workspace(Source.t(), keyword()) :: hydrate_result()
def hydrate_workspace(%Source{} = source, opts \\ []) do
  WorkspaceManager.hydrate(source, opts)
end
```

**Preflight delegation pattern** from [lib/kiln/attach.ex](/Users/jon/projects/kiln/lib/kiln/attach.ex:47):
```elixir
@spec preflight_workspace(Source.t(), WorkspaceManager.result(), keyword()) ::
        preflight_result()
def preflight_workspace(%Source{} = source, %WorkspaceManager{} = hydrated, opts \\ []) do
  SafetyGate.evaluate(source, hydrated, opts)
end
```

**Stable persistence/update pattern** from [lib/kiln/attach.ex](/Users/jon/projects/kiln/lib/kiln/attach.ex:34):
```elixir
%AttachedRepo{}
|> AttachedRepo.changeset(attrs)
|> Repo.insert(
  on_conflict: {:replace_all_except, [:id, :inserted_at]},
  conflict_target: :source_fingerprint,
  returning: true
)
```

**What to copy for Phase 31**
- Accept attached-repo facts from `Kiln.Attach`, not from reparsing form input.
- Keep orchestration entrypoints narrow and typed.
- Persist frozen delivery facts once, then pass those facts into workers.

**Anti-patterns to avoid**
- Do not fetch raw repo state in LiveView and bypass `Kiln.Attach`.
- Do not build a second attach-only git/GitHub execution path.

### `lib/kiln/github/push_worker.ex` (worker, event-driven)

**Primary analog:** `lib/kiln/github/push_worker.ex`

This is already the exact durable external-op pattern for git side effects.

**Worker defaults + external-op helpers** from [lib/kiln/oban/base_worker.ex](/Users/jon/projects/kiln/lib/kiln/oban/base_worker.ex:50):
```elixir
opts =
  opts
  |> Keyword.put_new(:max_attempts, 3)
  |> Keyword.put_new(:unique,
    keys: [:idempotency_key],
    period: :infinity,
    states: [:available, :scheduled, :executing]
  )
```

**Intent-before-side-effect pattern** from [lib/kiln/github/push_worker.ex](/Users/jon/projects/kiln/lib/kiln/github/push_worker.ex:46):
```elixir
case fetch_or_record_intent(parsed.idempotency_key, %{
       op_kind: "git_push",
       intent_payload: Map.take(parsed.raw_args, cas_fields()),
       run_id: parsed.run_id,
       stage_id: parsed.stage_id
     }) do
  {:found_existing, %{state: :completed}} ->
    {:ok, :already_done}
```

**CAS-before-push pattern** from [lib/kiln/github/push_worker.ex](/Users/jon/projects/kiln/lib/kiln/github/push_worker.ex:59):
```elixir
case Git.ls_remote_tip(parsed.remote, parsed.ref, runner) do
  {:ok, tip} ->
    cond do
      tip == parsed.local_sha ->
        complete_ok(op, %{"result" => "noop_already_on_remote", "remote_sha" => tip})

      tip != parsed.expected_sha ->
        _ = fail_op(op, %{"reason" => Atom.to_string(reason), "tip" => tip, "expected" => parsed.expected_sha})
        {:cancel, reason}
```

**Typed retry/cancel split** from [lib/kiln/github/push_worker.ex](/Users/jon/projects/kiln/lib/kiln/github/push_worker.ex:106):
```elixir
class = Git.classify_push_failure(code, err)

case class do
  :git_push_rejected ->
    _ = fail_op(op, %{"reason" => "git_push", "class" => "git_push_rejected", "stderr" => err})
    {:error, :git_push_rejected}

  other ->
    _ = fail_op(op, %{"reason" => Atom.to_string(other), "stderr" => err})
    {:cancel, other}
end
```

**Idempotency key assertion** from [lib/kiln/github/push_worker.ex](/Users/jon/projects/kiln/lib/kiln/github/push_worker.ex:165):
```elixir
want = "run:#{run_id}:stage:#{stage_id}:git_push"

if key == want do
  :ok
else
  {:error, {:bad_idempotency_key, want, key}}
end
```

**What to copy for Phase 31**
- Freeze push args before enqueue.
- Reuse the existing `git_push` worker and CAS payload shape when attach delivery pushes a branch.
- Treat semantic failures as `{:cancel, atom}` and transport ambiguity as retryable `{:error, atom}`.

**Anti-patterns to avoid**
- Do not run `git push` directly from a LiveView or synchronous controller-style path.
- Do not skip `fetch_or_record_intent/2`.
- Do not make retry semantics depend on string matching outside `Kiln.Git.classify_push_failure/2`.

### `lib/kiln/github/open_pr_worker.ex` (worker, event-driven)

**Primary analog:** `lib/kiln/github/open_pr_worker.ex`

This is the exact pattern for draft PR creation boundaries: parse/freeze attrs, record intent, delegate to `gh`, classify typed terminal failures.

**Frozen PR attrs pattern** from [lib/kiln/github/open_pr_worker.ex](/Users/jon/projects/kiln/lib/kiln/github/open_pr_worker.ex:73):
```elixir
pr_attrs = %{
  "title" => title,
  "body" => body,
  "base" => base,
  "head" => head,
  "draft" => draft,
  "reviewers" => reviewers
}

intent_payload: Map.merge(pr_attrs, %{"frozen" => true})
```

**Duplicate suppression pattern** from [lib/kiln/github/open_pr_worker.ex](/Users/jon/projects/kiln/lib/kiln/github/open_pr_worker.ex:24):
```elixir
case fetch_or_record_intent(key, %{
       op_kind: "gh_pr_create",
       intent_payload: parsed.intent_payload,
       run_id: parsed.run_id,
       stage_id: parsed.stage_id
     }) do
  {:found_existing, %{state: :completed}} ->
    {:ok, :duplicate_suppressed}
```

**Typed cancel for auth/permissions** from [lib/kiln/github/open_pr_worker.ex](/Users/jon/projects/kiln/lib/kiln/github/open_pr_worker.ex:50):
```elixir
{:error, reason} when is_atom(reason) ->
  case reason do
    :gh_auth_expired -> {:cancel, reason}
    :gh_permissions_insufficient -> {:cancel, reason}
    _ ->
      _ = fail_op(op, %{"reason" => Atom.to_string(reason)})
      {:error, reason}
  end
```

**Key shape assertion** from [lib/kiln/github/open_pr_worker.ex](/Users/jon/projects/kiln/lib/kiln/github/open_pr_worker.ex:131):
```elixir
want = "run:#{run_id}:stage:#{stage_id}:gh_pr_create"
if key == want, do: :ok, else: {:error, {:bad_idempotency_key, want, key}}
```

**What to copy for Phase 31**
- Freeze title/body/base/head/draft once.
- Keep PR creation worker-focused and boundary-driven.
- Return durable result facts such as `pr_number`, `pr_url`, and `is_draft`.

**Anti-patterns to avoid**
- Do not regenerate title/body on retries.
- Do not pass mutable runtime context into the worker and derive user-facing copy there.

### `lib/kiln/github/pr_formatter.ex` (utility, transform)

**Primary analog:** `lib/kiln/github/cli.ex`

There is no existing PR formatter module, but `Kiln.GitHub.Cli` shows the right boundary: format attrs before the CLI call, keep transport generic, keep secrets off argv.

**CLI boundary pattern** from [lib/kiln/github/cli.ex](/Users/jon/projects/kiln/lib/kiln/github/cli.ex:42):
```elixir
@spec create_pr(map(), keyword()) :: {:ok, map()} | {:error, term()}
def create_pr(attrs, opts \\ []) when is_map(attrs) do
  runner = normalize_runner(Keyword.get(opts, :runner, default_runner()))
  cd = Keyword.get(opts, :cd)
```

**Long-body fallback pattern** from [lib/kiln/github/cli.ex](/Users/jon/projects/kiln/lib/kiln/github/cli.ex:63):
```elixir
{body_args, cleanup} =
  if String.length(body) < 12_000 do
    {["--body", body], :none}
  else
    path = body_temp_file!(body)
    {["--body-file", path], {:file, path}}
  end
```

**Transport argv assembly** from [lib/kiln/github/cli.ex](/Users/jon/projects/kiln/lib/kiln/github/cli.ex:71):
```elixir
argv =
  [
    "pr",
    "create",
    "--title",
    title,
    "--base",
    base,
    "--head",
    head
  ] ++ draft_flag(draft?) ++ body_args
```

**Typed error classification boundary** from [lib/kiln/github/cli.ex](/Users/jon/projects/kiln/lib/kiln/github/cli.ex:163):
```elixir
@spec classify_gh_error(String.t(), integer()) ::
        :gh_auth_expired | :gh_permissions_insufficient | :gh_cli_failed
```

**What to copy for Phase 31**
- Build PR title/body in a pure formatter before worker enqueue.
- Keep `Kiln.GitHub.Cli` transport-agnostic.
- Use simple string-key maps for frozen attrs.

**Anti-patterns to avoid**
- Do not couple body formatting to `gh` argv creation.
- Do not put raw machine blobs into the PR body when the internal intent payload already preserves machine facts.

### `lib/mix/tasks/kiln.attach.prove.ex` (mix task, batch)

**Primary analog:** `lib/mix/tasks/kiln.first_run.prove.ex`

Phase 31 should copy the “thin owning proof command over fixed delegated layers” pattern exactly.

**Locked delegated layer pattern** from [lib/mix/tasks/kiln.first_run.prove.ex](/Users/jon/projects/kiln/lib/mix/tasks/kiln.first_run.prove.ex:11):
```elixir
@shortdoc "Run the local first-run proof layers in locked order"

@focused_liveview_files [
  "test/kiln_web/live/templates_live_test.exs",
  "test/kiln_web/live/run_detail_live_test.exs"
]
```

**Thin task body** from [lib/mix/tasks/kiln.first_run.prove.ex](/Users/jon/projects/kiln/lib/mix/tasks/kiln.first_run.prove.ex:18):
```elixir
@impl Mix.Task
def run(_args) do
  run_task("integration.first_run", [])
  run_cmd(["env", "MIX_ENV=test", "mix", "test" | @focused_liveview_files])
end
```

**Injectable task runners for testability** from [lib/mix/tasks/kiln.first_run.prove.ex](/Users/jon/projects/kiln/lib/mix/tasks/kiln.first_run.prove.ex:24):
```elixir
defp runner do
  Application.get_env(:kiln, :kiln_first_run_prove_runner, &Mix.Task.run/2)
end

defp reenabler do
  Application.get_env(:kiln, :kiln_first_run_prove_reenabler, &Mix.Task.reenable/1)
end
```

**What to copy for Phase 31**
- One top-level `mix kiln.attach.prove` task.
- Fixed delegated proof layers: hermetic integration/domain first, focused LiveView tests second.
- Injectable runner hooks so the task itself has a fast unit test.

**Anti-patterns to avoid**
- Do not bake a custom test framework into the Mix task.
- Do not scatter proof responsibility into README snippets or manual command lists.

### `test/integration/attach_delivery_test.exs` and `test/kiln_web/live/attach_entry_live_test.exs` (tests)

**Primary analogs:** `test/kiln/github/push_worker_test.exs`, `test/kiln/github/open_pr_worker_test.exs`, `test/integration/github_delivery_test.exs`, `test/mix/tasks/kiln.first_run.prove_test.exs`, `test/kiln_web/live/attach_entry_live_test.exs`

**Hermetic worker injection pattern** from [test/kiln/github/push_worker_test.exs](/Users/jon/projects/kiln/test/kiln/github/push_worker_test.exs:29):
```elixir
{:ok, counter} = Agent.start_link(fn -> 0 end)

runner = fn
  ["ls-remote", _, _], _opts -> ...
  ["push", _, _], _opts -> {:ok, ""}
end

:ok = Application.put_env(:kiln, Kiln.GitHub.PushWorker, git_runner: runner)
```

**PR worker argv assertion pattern** from [test/kiln/github/open_pr_worker_test.exs](/Users/jon/projects/kiln/test/kiln/github/open_pr_worker_test.exs:23):
```elixir
:ok =
  Application.put_env(:kiln, Kiln.GitHub.OpenPRWorker,
    cli_runner: fn argv, _opts ->
      assert argv == [
               "pr",
               "create",
               "--title",
               "t",
               "--base",
               "main",
               "--head",
               "f",
               "--draft",
               "--body",
               "b",
               "--json",
               "number,url,headRefName,baseRefName,isDraft"
             ]
```

**Replay/no-duplicate-audit pattern** from [test/integration/github_delivery_test.exs](/Users/jon/projects/kiln/test/integration/github_delivery_test.exs:86):
```elixir
assert {:ok, :already_done} = perform_job(PushWorker, args)
assert {:ok, :already_done} = perform_job(PushWorker, args)
assert after_count == before
```

**Thin proof-task test pattern** from [test/mix/tasks/kiln.first_run.prove_test.exs](/Users/jon/projects/kiln/test/mix/tasks/kiln.first_run.prove_test.exs:6):
```elixir
test "delegates exactly the two locked proof layers in order" do
  parent = self()
  Application.put_env(:kiln, :kiln_first_run_prove_runner, fn task, args -> ... end, persistent: false)
  Application.put_env(:kiln, :kiln_first_run_prove_cmd_runner, fn args -> ... end, persistent: false)
```

**LiveView honest-state assertions** from [test/kiln_web/live/attach_entry_live_test.exs](/Users/jon/projects/kiln/test/kiln_web/live/attach_entry_live_test.exs:33):
```elixir
assert has_element?(view, "#attach-ready")
assert has_element?(view, "#attach-ready-summary")
refute has_element?(view, "#attach-blocked")
```

**Blocked-vs-ready contract** from [test/kiln_web/live/attach_entry_live_test.exs](/Users/jon/projects/kiln/test/kiln_web/live/attach_entry_live_test.exs:72):
```elixir
assert has_element?(view, "#attach-blocked")
assert has_element?(view, "#attach-remediation-summary")
refute has_element?(view, "#attach-ready")
```

**What to copy for Phase 31**
- Inject fake `git_runner` and `cli_runner` through application env.
- Assert exact argv and exact idempotency outcomes.
- Verify no duplicate completion artifacts on replay.
- In LiveView tests, assert mutually exclusive DOM ids for ready vs blocked states.

**Anti-patterns to avoid**
- Do not assert raw full HTML when stable element ids already exist.
- Do not use live browser tests as the primary safety proof for git/PR semantics.
- Do not rely on sleeps; keep tests deterministic and injected.

## Shared Patterns

### Stable durable identifiers
**Sources:** [lib/kiln/attach/workspace_manager.ex](/Users/jon/projects/kiln/lib/kiln/attach/workspace_manager.ex:53), [lib/kiln/attach.ex](/Users/jon/projects/kiln/lib/kiln/attach.ex:80)

Copy this shape:
- derive from immutable facts
- hash for compact durable suffix
- keep a human-readable sanitized prefix
- persist once and reuse

### Two-phase side-effect idempotency
**Sources:** [lib/kiln/oban/base_worker.ex](/Users/jon/projects/kiln/lib/kiln/oban/base_worker.ex:28), [lib/kiln/external_operations.ex](/Users/jon/projects/kiln/lib/kiln/external_operations.ex:34)

Copy this sequence:
1. Assert deterministic `idempotency_key`.
2. `fetch_or_record_intent/2`.
3. Run the external effect outside the DB transaction.
4. `complete_op/2` or `fail_op/2`.
5. Return `{:ok, ...}`, `{:error, ...}`, or `{:cancel, ...}` by failure class.

### Git boundary and classification
**Sources:** [lib/kiln/git.ex](/Users/jon/projects/kiln/lib/kiln/git.ex:37), [lib/kiln/git.ex](/Users/jon/projects/kiln/lib/kiln/git.ex:78)

Copy this shape:
- one thin git boundary module
- explicit CAS payload builder
- centralized stderr classification
- injectable runner for hermetic tests

### GitHub PR boundary
**Sources:** [lib/kiln/github/cli.ex](/Users/jon/projects/kiln/lib/kiln/github/cli.ex:42), [lib/kiln/github/open_pr_worker.ex](/Users/jon/projects/kiln/lib/kiln/github/open_pr_worker.ex:73)

Copy this shape:
- pure/frozen PR attrs first
- transport second
- typed auth/permission failures
- persist only the stable PR facts returned by GitHub

### Honest attach operator-state tests
**Source:** [test/kiln_web/live/attach_entry_live_test.exs](/Users/jon/projects/kiln/test/kiln_web/live/attach_entry_live_test.exs:16)

Copy this shape:
- stable DOM ids
- assert presence of the intended state container
- refute the opposite state container
- assert remediation or ready copy only after state transition

## No Exact Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/kiln/attach/branch_name.ex` | utility | transform | No existing run-scoped branch-name helper yet; closest analog is `workspace_key/1` for durable slug-plus-hash generation. |
| `lib/kiln/github/pr_formatter.ex` | utility | transform | No existing dedicated PR title/body formatter yet; closest analog is the frozen-attrs boundary in `Kiln.GitHub.Cli` and `OpenPRWorker`. |

## Metadata

**Analog search scope:** `lib/kiln/attach*`, `lib/kiln/git*`, `lib/kiln/github*`, `lib/kiln/oban*`, `lib/mix/tasks`, `test/kiln/github*`, `test/integration`, `test/kiln_web/live`
**Files scanned:** 13
**Pattern extraction date:** 2026-04-24
