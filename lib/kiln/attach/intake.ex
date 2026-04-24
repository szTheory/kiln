defmodule Kiln.Attach.Intake do
  @moduledoc """
  Attach-owned boundary for bounded attached-repo request intake.
  """

  alias Kiln.Attach
  alias Kiln.Attach.IntakeRequest
  alias Kiln.Specs
  alias Kiln.Specs.SpecDraft

  @type result :: {:ok, SpecDraft.t()} | {:error, :not_found | Ecto.Changeset.t()}

  @spec create_draft(Ecto.UUID.t(), map()) :: result()
  def create_draft(attached_repo_id, attrs) when is_binary(attached_repo_id) and is_map(attrs) do
    with {:ok, _attached_repo} <- Attach.get_attached_repo(attached_repo_id),
         {:ok, request_attrs} <- validate_request(attrs) do
      request_attrs
      |> draft_attrs(attached_repo_id)
      |> Specs.create_draft()
    end
  end

  defp validate_request(attrs) do
    changeset = IntakeRequest.changeset(%IntakeRequest{}, attrs)

    if changeset.valid? do
      {:ok, IntakeRequest.to_attrs(changeset)}
    else
      {:error, changeset}
    end
  end

  defp draft_attrs(request_attrs, attached_repo_id) do
    %{
      title: request_attrs.title,
      body: render_body(request_attrs),
      source: :freeform,
      attached_repo_id: attached_repo_id,
      request_kind: request_attrs.request_kind,
      change_summary: request_attrs.change_summary,
      acceptance_criteria: request_attrs.acceptance_criteria,
      out_of_scope: request_attrs.out_of_scope
    }
  end

  defp render_body(request_attrs) do
    [
      "# #{request_attrs.title}",
      "",
      "## Request Kind",
      "",
      request_kind_label(request_attrs.request_kind),
      "",
      "## Change Summary",
      "",
      request_attrs.change_summary,
      "",
      "## Acceptance Criteria",
      "",
      render_bullets(request_attrs.acceptance_criteria),
      render_out_of_scope_section(request_attrs.out_of_scope)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp render_out_of_scope_section([]), do: nil

  defp render_out_of_scope_section(items) do
    [
      "",
      "## Out of Scope",
      "",
      render_bullets(items)
    ]
    |> Enum.join("\n")
  end

  defp render_bullets(items) do
    Enum.map_join(items, "\n", &"- #{&1}")
  end

  defp request_kind_label(:feature), do: "Feature"
  defp request_kind_label(:bugfix), do: "Bugfix"
end
