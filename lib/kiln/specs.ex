defmodule Kiln.Specs do
  @moduledoc """
  Intent layer — versioned markdown specs and scenario manifests (Phase 5).

  CRUD here is limited to what Plans 05-02+ need before LiveView ships in 05-06.
  """

  alias Kiln.Repo
  alias Kiln.Specs.{ScenarioCompiler, ScenarioParser, Spec, SpecRevision}

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
