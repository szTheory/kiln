defmodule Kiln.Specs do
  @moduledoc """
  Intent layer — versioned markdown specs and scenario manifests (Phase 5).

  CRUD here is limited to what Plans 05-02+ need before LiveView ships in 05-06.

  Phase 8 adds **inbox drafts** (`spec_drafts`) with promote/archive flows (D-813..D-820).
  """

  import Ecto.Query

  alias Kiln.Artifacts
  alias Kiln.Audit
  alias Kiln.ExternalOperations.Operation
  alias Kiln.Repo
  alias Kiln.Runs.Run

  alias Kiln.Specs.{
    GitHubIssueImporter,
    ScenarioCompiler,
    ScenarioParser,
    Spec,
    SpecDraft,
    SpecRevision
  }

  @doc """
  Latest revision for a spec by `inserted_at` (append-only bodies; newest wins).
  """
  @spec latest_revision_for_spec(Ecto.UUID.t()) :: SpecRevision.t() | nil
  def latest_revision_for_spec(spec_id) do
    from(r in SpecRevision,
      where: r.spec_id == ^spec_id,
      order_by: [desc: r.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  @spec get_open_attached_draft(Ecto.UUID.t(), Ecto.UUID.t()) :: SpecDraft.t() | nil
  def get_open_attached_draft(attached_repo_id, draft_id)
      when is_binary(attached_repo_id) and is_binary(draft_id) do
    from(d in SpecDraft,
      where:
        d.id == ^draft_id and d.attached_repo_id == ^attached_repo_id and
          d.source == :attached_repo_intake and d.inbox_state == :open
    )
    |> Repo.one()
  end

  @spec latest_open_attached_draft(Ecto.UUID.t()) :: SpecDraft.t() | nil
  def latest_open_attached_draft(attached_repo_id) when is_binary(attached_repo_id) do
    from(d in SpecDraft,
      where:
        d.attached_repo_id == ^attached_repo_id and d.source == :attached_repo_intake and
          d.inbox_state == :open,
      order_by: [desc: d.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  @spec list_open_attached_drafts(Ecto.UUID.t(), keyword()) :: [SpecDraft.t()]
  def list_open_attached_drafts(attached_repo_id, opts \\ []) when is_binary(attached_repo_id) do
    limit = Keyword.get(opts, :limit, 5)

    from(d in SpecDraft,
      where:
        d.attached_repo_id == ^attached_repo_id and d.source == :attached_repo_intake and
          d.inbox_state == :open,
      order_by: [desc: d.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @spec latest_promoted_attached_request(Ecto.UUID.t()) ::
          %{spec: Spec.t(), revision: SpecRevision.t()} | nil
  def latest_promoted_attached_request(attached_repo_id) when is_binary(attached_repo_id) do
    from(r in SpecRevision,
      join: s in Spec,
      on: s.id == r.spec_id,
      where: r.attached_repo_id == ^attached_repo_id,
      order_by: [desc: r.inserted_at],
      preload: [spec: s],
      limit: 1
    )
    |> Repo.one()
    |> case do
      %SpecRevision{spec: %Spec{} = spec} = revision -> %{spec: spec, revision: revision}
      nil -> nil
    end
  end

  @spec list_recent_promoted_attached_requests(Ecto.UUID.t(), keyword()) ::
          [%{spec: Spec.t(), revision: SpecRevision.t()}]
  def list_recent_promoted_attached_requests(attached_repo_id, opts \\ [])
      when is_binary(attached_repo_id) do
    limit = Keyword.get(opts, :limit, 5)

    from(r in SpecRevision,
      join: s in Spec,
      on: s.id == r.spec_id,
      where: r.attached_repo_id == ^attached_repo_id,
      order_by: [desc: r.inserted_at],
      preload: [spec: s],
      limit: ^limit
    )
    |> Repo.all()
    |> Enum.map(fn %SpecRevision{spec: %Spec{} = spec} = revision ->
      %{spec: spec, revision: revision}
    end)
  end

  @spec create_spec(map()) :: {:ok, Spec.t()} | {:error, Ecto.Changeset.t()}
  def create_spec(attrs) do
    %Spec{}
    |> Spec.changeset(attrs)
    |> Repo.insert()
  end

  @spec create_revision(Spec.t(), map()) :: {:ok, SpecRevision.t()} | {:error, Ecto.Changeset.t()}
  def create_revision(%Spec{} = spec, attrs) do
    %SpecRevision{}
    |> SpecRevision.changeset(Map.put(attrs, :spec_id, spec.id))
    |> Repo.insert()
  end

  @spec get_revision!(Ecto.UUID.t()) :: SpecRevision.t()
  def get_revision!(id), do: Repo.get!(SpecRevision, id)

  @doc """
  Parse `revision.body`, compile ExUnit modules under `test/generated/…`, and
  persist `scenario_manifest_sha256` on success.
  """
  @spec compile_revision!(SpecRevision.t()) :: SpecRevision.t()
  def compile_revision!(%SpecRevision{} = rev) do
    case ScenarioParser.parse_document(rev.body) do
      {:error, reason} ->
        raise ArgumentError,
              "compile_revision!: parse failed: #{inspect(reason)}"

      {:ok, ir} ->
        manifest = ScenarioCompiler.manifest_sha256(ir)
        {:ok, _rel} = ScenarioCompiler.compile(rev, ir)

        rev
        |> SpecRevision.changeset(%{scenario_manifest_sha256: manifest})
        |> Repo.update!()

        Repo.get!(SpecRevision, rev.id)
    end
  end

  @doc """
  Inserts an **open** inbox draft (`inbox_state` defaults to `:open`).
  """
  @spec create_draft(map()) :: {:ok, SpecDraft.t()} | {:error, Ecto.Changeset.t()}
  def create_draft(attrs) when is_map(attrs) do
    attrs = Map.put_new(attrs, :inbox_state, :open)

    %SpecDraft{}
    |> SpecDraft.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists drafts in **`inbox_state: :open`**, newest first.
  """
  @spec list_open_drafts() :: [SpecDraft.t()]
  def list_open_drafts do
    from(d in SpecDraft,
      where: d.inbox_state == :open,
      order_by: [desc: d.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Archives an **open** draft (`:archived` + `archived_at`).
  """
  @spec archive_draft(Ecto.UUID.t()) ::
          {:ok, SpecDraft.t()}
          | {:error, :not_found | :invalid_state | Ecto.Changeset.t()}
  def archive_draft(draft_id) when is_binary(draft_id) do
    Repo.transaction(fn ->
      case Repo.get(SpecDraft, draft_id) do
        nil ->
          Repo.rollback(:not_found)

        %SpecDraft{inbox_state: :open} = draft ->
          draft
          |> SpecDraft.changeset(%{
            inbox_state: :archived,
            archived_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
          })
          |> Repo.update()
          |> case do
            {:ok, d} -> d
            {:error, cs} -> Repo.rollback(cs)
          end

        %SpecDraft{} ->
          Repo.rollback(:invalid_state)
      end
    end)
    |> case do
      {:ok, draft} -> {:ok, draft}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Promotes an **open** draft into `specs` + `spec_revisions`, marks the draft
  **`:promoted`**, and appends `:spec_draft_promoted` in the **same** transaction.

  Pass **`template_id:`** to record built-in template provenance on the audit
  payload (optional JSON-Schema field).
  """
  @spec promote_draft(Ecto.UUID.t(), keyword()) ::
          {:ok, %{draft: SpecDraft.t(), spec: Spec.t(), revision: SpecRevision.t()}}
          | {:error, :not_found | :invalid_state | Ecto.Changeset.t() | term()}
  def promote_draft(draft_id, opts \\ []) when is_binary(draft_id) and is_list(opts) do
    Repo.transaction(fn ->
      draft =
        from(d in SpecDraft,
          where: d.id == ^draft_id,
          lock: "FOR UPDATE"
        )
        |> Repo.one()

      case draft do
        nil ->
          Repo.rollback(:not_found)

        %SpecDraft{inbox_state: s} when s != :open ->
          Repo.rollback(:invalid_state)

        %SpecDraft{} = draft ->
          case promote_locked_open_draft(draft, opts) do
            {:ok, result} ->
              result

            {:error, %Ecto.Changeset{} = cs} ->
              Repo.rollback(cs)

            {:error, other} ->
              Repo.rollback(other)
          end
      end
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a **`spec_drafts`** row from a built-in template and **promotes** it in
  one Postgres transaction (D-1706 / D-1707).
  """
  @spec instantiate_template_promoted(String.t()) ::
          {:ok, %{spec: Spec.t(), revision: SpecRevision.t()}}
          | {:error, :unknown_template | File.posix() | Ecto.Changeset.t() | term()}
  def instantiate_template_promoted(template_id) when is_binary(template_id) do
    case Kiln.Templates.fetch(template_id) do
      {:error, :unknown_template} = not_found ->
        not_found

      {:ok, entry} ->
        case Kiln.Templates.read_spec(template_id) do
          {:error, reason} ->
            {:error, reason}

          {:ok, body} ->
            Repo.transaction(fn ->
              cs =
                SpecDraft.changeset(%SpecDraft{}, %{
                  title: entry.title,
                  body: body,
                  source: :template,
                  inbox_state: :open
                })

              case Repo.insert(cs) do
                {:error, changeset} ->
                  Repo.rollback(changeset)

                {:ok, draft} ->
                  case promote_locked_open_draft(draft, template_id: template_id) do
                    {:ok, %{spec: spec, revision: rev}} ->
                      %{spec: spec, revision: rev}

                    {:error, other} ->
                      Repo.rollback(other)
                  end
              end
            end)
            |> case do
              {:ok, %{spec: spec, revision: rev}} ->
                {:ok, %{spec: spec, revision: rev}}

              {:error, reason} ->
                {:error, reason}
            end
        end
    end
  end

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

  defp audit_payload_spec_draft_promoted(draft, spec, rev, template_id) do
    base = %{
      "draft_id" => uuid_string!(draft.id),
      "spec_id" => uuid_string!(spec.id),
      "spec_revision_id" => uuid_string!(rev.id)
    }

    case template_id do
      nil -> base
      id when is_binary(id) -> Map.put(base, "template_id", id)
    end
  end

  defp insert_spec_from_draft(%SpecDraft{title: title}) do
    %Spec{}
    |> Spec.changeset(%{title: title})
    |> Repo.insert()
  end

  defp insert_revision_from_draft(%Spec{id: spec_id}, %SpecDraft{} = draft) do
    %SpecRevision{}
    |> SpecRevision.changeset(%{
      spec_id: spec_id,
      body: draft.body,
      attached_repo_id: draft.attached_repo_id,
      request_kind: draft.request_kind,
      change_summary: draft.change_summary,
      acceptance_criteria: draft.acceptance_criteria,
      out_of_scope: draft.out_of_scope
    })
    |> Repo.insert()
  end

  defp mark_draft_promoted(%SpecDraft{} = draft, spec_id) do
    draft
    |> SpecDraft.changeset(%{inbox_state: :promoted, promoted_spec_id: spec_id})
    |> Repo.update()
  end

  @doc """
  Import a GitHub issue reference **`owner/repo#N`** into the inbox as a draft.
  """
  @spec import_github_issue_from_slug(String.t(), keyword()) ::
          {:ok, SpecDraft.t()} | {:error, term()}
  def import_github_issue_from_slug(slug, opts \\ []),
    do: GitHubIssueImporter.import_from_slug(slug, opts)

  @doc """
  Import a canonical GitHub issue **`https://github.com/.../issues/N`** URL.
  """
  @spec import_github_issue_from_url(String.t(), keyword()) ::
          {:ok, SpecDraft.t()} | {:error, term()}
  def import_github_issue_from_url(url, opts \\ []),
    do: GitHubIssueImporter.import_from_url(url, opts)

  @doc """
  Re-fetch a GitHub-backed draft using the stored **etag** (`If-None-Match`).
  """
  @spec refresh_github_issue_draft(SpecDraft.t(), keyword()) ::
          {:ok, SpecDraft.t()} | {:error, term()}
  def refresh_github_issue_draft(%SpecDraft{} = draft, opts \\ []),
    do: GitHubIssueImporter.refresh(draft, opts)

  @doc """
  Updates an **open** draft's title/body (operator edit from inbox).
  """
  @spec update_open_draft(Ecto.UUID.t(), map()) ::
          {:ok, SpecDraft.t()} | {:error, :not_found | :invalid_state | Ecto.Changeset.t()}
  def update_open_draft(draft_id, attrs) when is_binary(draft_id) and is_map(attrs) do
    case Repo.get(SpecDraft, draft_id) do
      nil ->
        {:error, :not_found}

      %SpecDraft{inbox_state: :open} = draft ->
        draft
        |> SpecDraft.changeset(attrs)
        |> Repo.update()

      %SpecDraft{} ->
        {:error, :invalid_state}
    end
  end

  @doc """
  Creates an inbox **follow-up** draft from a **merged** terminal run (INTAKE-03).

  Idempotency: `external_operations` row keyed
  `follow_up_draft:<run_id>:<correlation_id>`. The LiveView should reuse one
  `correlation_id` per mount so double-clicks dedupe.

  Same Postgres transaction: intent row (when new), draft insert,
  `:follow_up_drafted` audit, op completion + `:external_op_completed` audit.
  """
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
          case draft_id_from_op_result(op.result_payload) do
            nil ->
              Repo.rollback({:missing_result_payload, op.id})

            draft_id ->
              case Repo.get(SpecDraft, draft_id) do
                %SpecDraft{} = d -> d
                nil -> Repo.rollback({:draft_not_found, draft_id})
              end
          end

        :intent_recorded ->
          artifact_refs = Artifacts.list_refs_for_run(run.id)
          summary = follow_up_operator_summary(run)

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
               {:ok, _} <-
                 Audit.append(%{
                   event_kind: :follow_up_drafted,
                   run_id: run.id,
                   correlation_id: audit_cid,
                   payload: %{
                     "draft_id" => uuid_string!(draft.id),
                     "source_run_id" => uuid_string!(run.id),
                     "idempotency_key" => idempotency_key
                   }
                 }),
               {:ok, op_done} <-
                 Repo.update(
                   Operation.changeset(op, %{
                     state: :completed,
                     result_payload: %{"draft_id" => uuid_string!(draft.id)},
                     completed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
                   })
                 ),
               {:ok, _} <-
                 Audit.append(%{
                   event_kind: :external_op_completed,
                   run_id: op_done.run_id,
                   correlation_id: audit_cid,
                   payload: %{
                     "op_kind" => op_done.op_kind,
                     "idempotency_key" => op_done.idempotency_key,
                     "result_summary" => summarize_follow_up_result(op_done.result_payload)
                   }
                 }) do
            draft
          else
            {:error, reason} -> Repo.rollback(reason)
          end

        _other ->
          Repo.rollback({:unexpected_op_state, op.state})
      end
    end)
    |> case do
      {:ok, draft} -> {:ok, draft}
      {:error, reason} -> {:error, reason}
    end
  end

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
            payload: %{
              "op_kind" => op.op_kind,
              "idempotency_key" => op.idempotency_key
            }
          })

        op

      {:error, changeset} ->
        Repo.rollback(changeset)
    end
  end

  defp insert_follow_up_draft(attrs) do
    %SpecDraft{}
    |> SpecDraft.changeset(attrs)
    |> Repo.insert()
  end

  defp draft_id_from_op_result(nil), do: nil

  defp draft_id_from_op_result(payload) when is_map(payload) do
    Map.get(payload, "draft_id") || Map.get(payload, :draft_id)
  end

  defp follow_up_operator_summary(%Run{} = run) do
    short = run.id |> uuid_string!() |> String.slice(0, 8)
    "Follow-up filed from merged run #{short} (#{run.workflow_id})"
  end

  defp follow_up_lazy_body do
    "[lazy-resolve]\nOpen the inbox to edit the full follow-up spec. Body loads from artifacts on demand."
  end

  defp summarize_follow_up_result(result) when is_map(result) do
    result
    |> inspect(limit: 120)
    |> String.slice(0, 400)
  end

  defp uuid_string!(id) when is_binary(id) do
    cond do
      byte_size(id) == 16 ->
        case Ecto.UUID.load(id) do
          {:ok, s} -> s
          :error -> raise ArgumentError, "expected uuid binary, got: #{inspect(id)}"
        end

      true ->
        case Ecto.UUID.cast(id) do
          {:ok, s} -> s
          :error -> raise ArgumentError, "expected uuid string, got: #{inspect(id)}"
        end
    end
  end
end
