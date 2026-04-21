defmodule Kiln.Artifacts do
  @moduledoc """
  Kiln's 13th bounded context (D-79, D-97). Content-addressed artifact
  storage for per-stage outputs (plans, diffs, logs, test outputs).

  Every stage output flows through this context. Per D-82's threshold
  rule, any binary or any payload >4 KB is an artifact, not an
  `audit_events.payload` inlining. This keeps the audit ledger a thin
  fact record and lets CAS handle the storage, dedup, and integrity
  invariants separately.

  Contracts:

    * `put/4` — stream body through SHA-256 + atomic rename into
      `<cas_root>/<aa>/<bb>/<sha>`, insert `Artifact` row + append
      `:artifact_written` audit event in a single `Repo.transact/2`
      (D-80). If either the row INSERT or the audit append fails,
      the whole transaction rolls back (the blob remains in CAS —
      orphan cleanup is Phase 5's `ScrubWorker` job, per T5 residual
      risk).
    * `get/2` — look up `(stage_run_id, name) → Artifact.t()`.
    * `read!/1` — re-hash on every open; raise
      `Kiln.Artifacts.CorruptionError` on mismatch AFTER appending an
      `:integrity_violation` audit event (D-84). Loud-on-violation per
      the durability-floor contract.
    * `stream!/1` — `File.stream!/2` over a blob; skips the
      integrity-on-every-open cost. Use `read!/1` when integrity
      matters; `ScrubWorker` covers periodic verification.
    * `ref_for/1` — returns the exact shape (`sha256`, `size_bytes`,
      `content_type`) that stage-contract `$defs.artifact_ref` expects
      for cross-stage handoff (D-75).
    * `by_sha/1` — refcount / dedup-visibility helper.
  """

  import Ecto.Query

  require Logger

  alias Kiln.{Audit, Repo}
  alias Kiln.Artifacts.{Artifact, CAS, CorruptionError}

  @type body :: Enumerable.t()
  @type put_opts :: [
          content_type: atom() | String.t(),
          run_id: Ecto.UUID.t(),
          producer_kind: String.t() | nil
        ]

  @doc """
  Write `body` to the CAS, insert an `Artifact` row, and append an
  `:artifact_written` audit event — all inside a single
  `Repo.transact/2`.

  Required `opts`:

    * `:content_type` — one of the five `Artifact.content_types/0`
      atoms (or a matching string that resolves to one).
    * `:run_id` — the parent run UUID. Must be consistent with the
      `stage_run_id`'s parent; we don't re-derive it here because
      callers already hold both ids and passing explicitly keeps this
      function a pure writer.

  Optional:

    * `:producer_kind` — the stage kind that wrote this artifact
      (e.g. `"planning"`). Persisted on the row; informational.

  On success, returns `{:ok, %Artifact{}}`. On failure (CAS write
  error, changeset validation error, audit schema rejection, FK
  violation, unique-index collision on `(stage_run_id, name)`),
  returns `{:error, term()}`.
  """
  @spec put(Ecto.UUID.t(), String.t(), body(), put_opts()) ::
          {:ok, Artifact.t()} | {:error, term()}
  def put(stage_run_id, name, body, opts) do
    content_type = Keyword.fetch!(opts, :content_type)
    run_id = Keyword.fetch!(opts, :run_id)
    producer_kind = Keyword.get(opts, :producer_kind)

    with {:ok, sha, size} <- CAS.put_stream(body) do
      Repo.transact(fn ->
        cs =
          Artifact.changeset(%Artifact{}, %{
            stage_run_id: stage_run_id,
            run_id: run_id,
            name: name,
            sha256: sha,
            size_bytes: size,
            content_type: normalize_content_type(content_type),
            schema_version: 1,
            producer_kind: producer_kind
          })

        with {:ok, artifact} <- Repo.insert(cs),
             {:ok, _ev} <-
               Audit.append(%{
                 event_kind: :artifact_written,
                 run_id: artifact.run_id,
                 stage_id: artifact.stage_run_id,
                 correlation_id: Logger.metadata()[:correlation_id] || Ecto.UUID.generate(),
                 payload: %{
                   "name" => name,
                   "sha256" => sha,
                   "size_bytes" => size,
                   "content_type" => to_string(content_type)
                 }
               }) do
          {:ok, artifact}
        end
      end)
    end
  end

  @doc """
  List artifact names for a stage run (read-only metadata for UI pickers).
  """
  @spec list_for_stage_run(Ecto.UUID.t()) :: [%{name: String.t(), content_type: atom()}]
  def list_for_stage_run(stage_run_id) do
    from(a in Artifact,
      where: a.stage_run_id == ^stage_run_id,
      order_by: [asc: a.name],
      select: %{name: a.name, content_type: a.content_type}
    )
    |> Repo.all()
  end

  @doc """
  Look up an artifact by `(stage_run_id, name)`. Returns
  `{:ok, %Artifact{}}` when found, `{:error, :not_found}` otherwise.
  """
  @spec get(Ecto.UUID.t(), String.t()) :: {:ok, Artifact.t()} | {:error, :not_found}
  def get(stage_run_id, name) do
    case Repo.one(
           from(a in Artifact,
             where: a.stage_run_id == ^stage_run_id and a.name == ^name
           )
         ) do
      nil -> {:error, :not_found}
      a -> {:ok, a}
    end
  end

  @doc """
  Read the blob for `artifact` into memory and verify the re-hashed
  SHA-256 matches `artifact.sha256` (D-84).

  On mismatch:

    1. An `:integrity_violation` audit event is appended (so the
       ledger has a forensic record even if the caller's rescue
       handler swallows the raise).
    2. `Kiln.Artifacts.CorruptionError` is raised with `artifact_id`,
       `expected`, `actual`, and `path` set.

  On match, the binary contents are returned. For large blobs prefer
  `stream!/1` (skips integrity-on-every-open); the periodic
  `ScrubWorker` (Phase 5) covers bulk verification.
  """
  @spec read!(Artifact.t()) :: binary()
  def read!(%Artifact{sha256: expected} = artifact) do
    path = CAS.cas_path(expected)
    bytes = File.read!(path)
    actual = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

    if actual != expected do
      # Append the integrity-violation audit event BEFORE raising so
      # the forensic record lands even if the caller catches the
      # exception. If the audit append itself fails, we still raise —
      # never silently return corrupted bytes.
      _ =
        Audit.append(%{
          event_kind: :integrity_violation,
          correlation_id: Logger.metadata()[:correlation_id] || Ecto.UUID.generate(),
          payload: %{
            "artifact_id" => artifact.id,
            "expected_sha" => expected,
            "actual_sha" => actual,
            "path" => path
          }
        })

      raise CorruptionError,
        artifact_id: artifact.id,
        expected: expected,
        actual: actual,
        path: path
    end

    bytes
  end

  @doc """
  Stream a blob's bytes in 64 KB chunks. Skips the integrity-on-every-
  open re-hash — use `read!/1` when integrity matters, or rely on the
  Phase 5 `ScrubWorker` for periodic bulk verification.
  """
  @spec stream!(Artifact.t()) :: Enumerable.t()
  def stream!(%Artifact{sha256: sha}) do
    File.stream!(CAS.cas_path(sha), [], 64 * 1024)
  end

  @doc """
  Return the artifact-reference shape consumed by stage-contract
  `$defs.artifact_ref` (`sha256` + `size_bytes` + `content_type` as
  strings — matching the JSON-Schema enum). Drives cross-stage handoff:
  no raw bytes cross stage boundaries, only refs (D-75, P4 token-bloat
  mitigation).
  """
  @spec ref_for(Artifact.t()) :: %{
          sha256: String.t(),
          size_bytes: non_neg_integer(),
          content_type: String.t()
        }
  def ref_for(%Artifact{sha256: sha, size_bytes: size, content_type: ct}) do
    %{sha256: sha, size_bytes: size, content_type: to_string(ct)}
  end

  @doc """
  Return every artifact whose `sha256` matches — i.e. every row that
  references the same underlying CAS blob. Used by D-83 refcount GC
  (refcount of zero = safe to delete from CAS) and by tests asserting
  dedup visibility.
  """
  @spec by_sha(String.t()) :: [Artifact.t()]
  def by_sha(sha) when is_binary(sha) do
    Repo.all(from(a in Artifact, where: a.sha256 == ^sha))
  end

  # Coerce string content-types to the Ecto.Enum atoms. Uses
  # `String.to_existing_atom/1` (never `to_atom`) so malicious input
  # can't exhaust the atom table — D-63 atom-exhaustion defence.
  defp normalize_content_type(ct) when is_atom(ct), do: ct

  defp normalize_content_type(ct) when is_binary(ct),
    do: String.to_existing_atom(ct)
end
