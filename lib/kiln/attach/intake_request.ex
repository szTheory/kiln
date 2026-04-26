defmodule Kiln.Attach.IntakeRequest do
  @moduledoc """
  Embedded request contract for bounded attached-repo intake.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type request_kind :: :feature | :bugfix
  @type t :: %__MODULE__{}

  embedded_schema do
    field(:request_kind, Ecto.Enum, values: [:feature, :bugfix])
    field(:title, :string)
    field(:change_summary, :string)
    field(:acceptance_criteria, {:array, :string}, default: [])
    field(:out_of_scope, {:array, :string}, default: [])
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(request, attrs) do
    request
    |> cast(attrs, [
      :request_kind,
      :title,
      :change_summary,
      :acceptance_criteria,
      :out_of_scope
    ])
    |> normalize_string_field(:title)
    |> normalize_string_field(:change_summary)
    |> normalize_list_field(:acceptance_criteria)
    |> normalize_list_field(:out_of_scope)
    |> validate_required([:request_kind, :title, :change_summary])
    |> validate_non_empty_list(:acceptance_criteria)
    |> validate_length(:title, max: 120)
    |> validate_length(:change_summary, max: 2_000)
    |> validate_list_item_lengths(:acceptance_criteria, 280)
    |> validate_list_item_lengths(:out_of_scope, 280)
  end

  @spec to_attrs(Ecto.Changeset.t()) :: map()
  def to_attrs(%Ecto.Changeset{} = changeset) do
    %{
      request_kind: get_field(changeset, :request_kind),
      title: get_field(changeset, :title),
      change_summary: get_field(changeset, :change_summary),
      acceptance_criteria: get_field(changeset, :acceptance_criteria) || [],
      out_of_scope: get_field(changeset, :out_of_scope) || []
    }
  end

  defp normalize_string_field(changeset, field) do
    update_change(changeset, field, fn value ->
      value
      |> String.trim()
      |> blank_to_nil()
    end)
  end

  defp normalize_list_field(changeset, field) do
    update_change(changeset, field, fn values ->
      values
      |> List.wrap()
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
    end)
  end

  defp validate_non_empty_list(changeset, field) do
    case get_field(changeset, field, []) do
      [] -> add_error(changeset, field, "must include at least one item")
      _items -> changeset
    end
  end

  defp validate_list_item_lengths(changeset, field, max_length) do
    values = get_field(changeset, field, [])

    if Enum.all?(values, &(String.length(&1) <= max_length)) do
      changeset
    else
      add_error(changeset, field, "items must be #{max_length} characters or fewer")
    end
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
