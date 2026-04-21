defmodule Kiln.Specs do
  @moduledoc """
  Intent layer — versioned markdown specs and scenario manifests (Phase 5).

  CRUD here is limited to what Plans 05-02+ need before LiveView ships in 05-06.
  """

  import Ecto.Query

  alias Kiln.Repo
  alias Kiln.Specs.{ScenarioCompiler, ScenarioParser, Spec, SpecRevision}

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
end
