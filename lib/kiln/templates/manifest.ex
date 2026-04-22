defmodule Kiln.Templates.Manifest do
  @moduledoc false

  defmodule Entry do
    @moduledoc false
    @enforce_keys [
      :id,
      :title,
      :workflow_id,
      :spec_file,
      :workflow_file,
      :purpose,
      :time_hint,
      :cost_hint,
      :assumptions,
      :last_verified_at,
      :last_verified_kiln_version
    ]

    defstruct @enforce_keys ++ [tags: []]

    @type t :: %__MODULE__{
            id: String.t(),
            title: String.t(),
            workflow_id: String.t(),
            spec_file: String.t(),
            workflow_file: String.t(),
            purpose: String.t(),
            time_hint: String.t(),
            cost_hint: String.t(),
            assumptions: [String.t()],
            last_verified_at: String.t(),
            last_verified_kiln_version: String.t(),
            tags: [String.t()]
          }

    @spec from_map!(map()) :: t()
    def from_map!(%{} = row) do
      id = fetch_string!(row, "id")

      %__MODULE__{
        id: id,
        title: fetch_string!(row, "title"),
        workflow_id: fetch_string!(row, "workflow_id"),
        spec_file: fetch_string!(row, "spec_file"),
        workflow_file: fetch_string!(row, "workflow_file"),
        purpose: fetch_string!(row, "purpose"),
        time_hint: fetch_string!(row, "time_hint"),
        cost_hint: fetch_string!(row, "cost_hint"),
        assumptions: fetch_string_list!(row, "assumptions"),
        last_verified_at: fetch_string!(row, "last_verified_at"),
        last_verified_kiln_version: fetch_string!(row, "last_verified_kiln_version"),
        tags: fetch_optional_string_list(row, "tags")
      }
    end

    defp fetch_string!(row, key) do
      case Map.get(row, key) do
        bin when is_binary(bin) and bin != "" ->
          bin

        other ->
          raise ArgumentError,
                "template manifest entry #{inspect(key)} invalid for id #{inspect(Map.get(row, "id"))}: #{inspect(other)}"
      end
    end

    defp fetch_string_list!(row, key) do
      case Map.get(row, key) do
        list when is_list(list) ->
          Enum.map(list, fn
            s when is_binary(s) -> s
            other -> raise ArgumentError, "expected string list for #{key}, got #{inspect(other)}"
          end)

        other ->
          raise ArgumentError, "expected list for #{key}, got #{inspect(other)}"
      end
    end

    defp fetch_optional_string_list(row, key) do
      case Map.get(row, key) do
        nil -> []
        list when is_list(list) -> Enum.map(list, &to_string/1)
        other -> raise ArgumentError, "expected list or nil for #{key}, got #{inspect(other)}"
      end
    end
  end

  defmodule Root do
    @moduledoc false
    defstruct templates: []

    @type t :: %__MODULE__{templates: [Entry.t()]}
  end

  @spec read!() :: Root.t()
  def read! do
    path = Application.app_dir(:kiln, "priv/templates/manifest.json")

    case File.read(path) do
      {:ok, body} ->
        decode!(body)

      {:error, reason} ->
        raise "failed to read template manifest #{path}: #{inspect(reason)}"
    end
  end

  defp decode!(body) do
    case Jason.decode(body) do
      {:ok, %{"templates" => rows}} when is_list(rows) ->
        entries = Enum.map(rows, &Entry.from_map!/1)
        %Root{templates: entries}

      {:ok, other} ->
        raise "template manifest must contain a templates array, got: #{inspect(other)}"

      {:error, err} ->
        raise "invalid template manifest JSON: #{inspect(err)}"
    end
  end
end
