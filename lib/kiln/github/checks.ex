defmodule Kiln.GitHub.Checks do
  @moduledoc """
  Pure summariser for GitHub **check runs** JSON (GIT-03, D-G01..D-G04).

  The GitHub REST list endpoint does not mark which runs are *required* by
  branch protection; callers pass `required_check_names` (exact `name` match)
  via the second-argument opts map.

  ## Legacy commit statuses (D-G20)

  Inputs without a `check_runs` list return `{:error, :checks_transport_unsupported}` —
  never silently pass.
  """

  @typedoc "One check row used by merge predicates and diagnostics."
  @type check_row :: %{
          id: integer(),
          name: String.t(),
          conclusion: String.t() | nil,
          status: String.t()
        }

  @doc """
  Summarises a decoded `check-runs` list response.

  `opts` must include `:required_check_names` — a list of check **names**
  that must be `success` for `predicate_pass` to be true.

  Optional checks are any `check_runs` entries whose `name` is not in
  `required_check_names`; their `failure` / `timed_out` conclusions do not
  block the predicate. `skipped`, `neutral`, and `cancelled` are treated as
  non-blocking for both required and optional rows (D-G03).

  **Draft rule (D-G04):** when `is_draft: true`, `predicate_pass` is always
  `false` regardless of check conclusions.
  """
  @spec summarize(map(), map()) ::
          {:ok,
           %{
             head_sha: String.t(),
             required: [check_row()],
             optional: [check_row()],
             predicate_pass: boolean()
           }}
          | {:error, :checks_transport_unsupported}
  def summarize(input, opts \\ %{})

  def summarize(%{"check_runs" => runs} = root, opts)
      when is_list(runs) and runs != [] do
    required_names =
      Map.get(opts, :required_check_names) || Map.get(opts, "required_check_names", [])

    unless is_list(required_names) and required_names != [] do
      raise ArgumentError,
            "required_check_names must be a non-empty list of check names (branch protection truth lives outside this pure function)"
    end

    is_draft = Map.get(opts, :is_draft) || Map.get(opts, "is_draft", false)

    head_sha = Map.get(root, "head_sha") || ""

    rows = Enum.map(runs, &normalize_row/1)

    {req, opt} =
      Enum.split_with(rows, fn %{name: name} -> name in required_names end)

    predicate =
      if is_draft do
        false
      else
        required_all_success?(req)
      end

    {:ok,
     %{
       head_sha: head_sha,
       required: req,
       optional: opt,
       predicate_pass: predicate
     }}
  end

  def summarize(map, _opts) when is_map(map), do: {:error, :checks_transport_unsupported}
  def summarize(_, _opts), do: {:error, :checks_transport_unsupported}

  defp normalize_row(%{"id" => id, "name" => name} = r) do
    %{
      id: id,
      name: name,
      conclusion: Map.get(r, "conclusion"),
      status: Map.get(r, "status") || ""
    }
  end

  defp required_all_success?(rows) do
    Enum.all?(rows, fn %{conclusion: c, status: st} ->
      st == "completed" and c == "success"
    end)
  end
end
