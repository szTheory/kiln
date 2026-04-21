defmodule Kiln.Specs.GitHubIssueImporter do
  @moduledoc """
  Imports GitHub Issues into **`spec_drafts`** via the REST API (D-815).

  URLs are built only from **validated** `{owner, repo, number}` tuples — never
  from raw paste interpolated into paths. HTTP is performed with **`Req`**;
  there is no shell-out fetch path (no `curl`, no `System.*` command helpers).

  ## Idempotency

  Open drafts are keyed by GitHub `node_id` (partial unique index). A second
  import for the same issue **updates** the existing open row (title/body/etag)
  and returns `{:ok, draft}` with the **same** `id`.
  """

  import Ecto.Query

  alias Kiln.Repo
  alias Kiln.Specs
  alias Kiln.Specs.SpecDraft

  @github_accept "application/vnd.github+json"

  @slug_re ~r/\A(?<owner>[\w.-]+)\/(?<repo>[\w.-]+)#(?<num>\d+)\z/u
  @url_re ~r{\Ahttps://github\.com/(?<owner>[\w.-]+)/(?<repo>[\w.-]+)/issues/(?<num>\d+)/?\z}u

  @spec import_from_slug(String.t(), keyword()) ::
          {:ok, SpecDraft.t()} | {:error, :invalid_reference | term()}
  def import_from_slug(input, opts \\ []) when is_binary(input) do
    case Regex.named_captures(@slug_re, String.trim(input)) do
      %{"owner" => owner, "repo" => repo, "num" => num_str} ->
        import_issue(owner, repo, String.to_integer(num_str), nil, opts)

      _ ->
        {:error, :invalid_reference}
    end
  end

  @spec import_from_url(String.t(), keyword()) ::
          {:ok, SpecDraft.t()} | {:error, :invalid_reference | term()}
  def import_from_url(input, opts \\ []) when is_binary(input) do
    case Regex.named_captures(@url_re, String.trim(input)) do
      %{"owner" => owner, "repo" => repo, "num" => num_str} ->
        import_issue(owner, repo, String.to_integer(num_str), nil, opts)

      _ ->
        {:error, :invalid_reference}
    end
  end

  @doc """
  Re-fetch using **`If-None-Match`** from the draft's stored **etag**.

  * **304** — returns `{:ok, draft}` without mutating title/body.
  * **200** — upserts body/title/etag like `import_from_slug/2`.
  """
  @spec refresh(SpecDraft.t(), keyword()) :: {:ok, SpecDraft.t()} | {:error, term()}
  def refresh(draft, opts \\ [])

  def refresh(%SpecDraft{inbox_state: :open} = draft, opts) do
    import_issue(
      draft.github_owner,
      draft.github_repo,
      draft.github_issue_number,
      draft.etag,
      Keyword.put(opts, :existing_draft, draft)
    )
  end

  def refresh(%SpecDraft{}, _opts), do: {:error, :invalid_state}

  defp import_issue(owner, repo, number, if_none_match, opts)
       when is_binary(owner) and is_binary(repo) and is_integer(number) do
    url = issue_api_url(owner, repo, number)
    headers = request_headers(if_none_match)
    req_options = Keyword.get(opts, :req_options, [])

    case Req.get(url, Keyword.merge([headers: headers, receive_timeout: 15_000], req_options)) do
      {:ok, %{status: 304} = resp} ->
        handle_not_modified(opts, resp)

      {:ok, %{status: 200, body: body} = resp} when is_map(body) ->
        upsert_from_response(owner, repo, number, body, etag_from_response(resp), opts)

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_status, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp request_headers(nil), do: [{"accept", @github_accept}, {"user-agent", "kiln/0.1"}]

  defp request_headers(etag) when is_binary(etag) do
    [{"if-none-match", etag}, {"accept", @github_accept}, {"user-agent", "kiln/0.1"}]
  end

  defp issue_api_url(owner, repo, number) do
    o = URI.encode(owner, &URI.char_unreserved?/1)
    r = URI.encode(repo, &URI.char_unreserved?/1)
    "https://api.github.com/repos/#{o}/#{r}/issues/#{number}"
  end

  defp etag_from_response(resp) do
    case Req.Response.get_header(resp, "etag") do
      [etag | _] -> etag
      _ -> nil
    end
  end

  defp handle_not_modified(opts, _resp) do
    case Keyword.get(opts, :existing_draft) do
      %SpecDraft{} = draft ->
        now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

        draft
        |> SpecDraft.changeset(%{last_synced_at: now})
        |> Repo.update()

      _ ->
        {:error, :not_modified}
    end
  end

  defp upsert_from_response(owner, repo, number, body, etag, opts) do
    node_id = Map.get(body, "node_id")
    title = Map.get(body, "title") || ""
    issue_body = Map.get(body, "body") || ""
    labels = label_lines(Map.get(body, "labels"))
    composed = compose_body(issue_body, labels)

    attrs = %{
      title: title,
      body: composed,
      source: :github_issue,
      github_owner: owner,
      github_repo: repo,
      github_issue_number: number,
      github_node_id: node_id,
      etag: etag,
      last_synced_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
    }

    existing =
      case Keyword.get(opts, :existing_draft) do
        %SpecDraft{} = d -> d
        _ -> find_open_by_node_id(node_id, owner, repo, number)
      end

    case existing do
      nil ->
        Specs.create_draft(attrs)

      %SpecDraft{} = draft ->
        draft
        |> SpecDraft.changeset(attrs)
        |> Repo.update()
    end
  end

  defp find_open_by_node_id(nil, owner, repo, number) do
    from(d in SpecDraft,
      where:
        d.inbox_state == :open and
          d.github_owner == ^owner and
          d.github_repo == ^repo and
          d.github_issue_number == ^number,
      limit: 1
    )
    |> Repo.one()
  end

  defp find_open_by_node_id(node_id, _owner, _repo, _number) when is_binary(node_id) do
    from(d in SpecDraft,
      where: d.inbox_state == :open and d.github_node_id == ^node_id,
      limit: 1
    )
    |> Repo.one()
  end

  defp label_lines(labels) when is_list(labels) do
    labels
    |> Enum.map(fn
      %{"name" => n} when is_binary(n) -> n
      %{name: n} when is_binary(n) -> n
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp label_lines(_), do: []

  defp compose_body(issue_body, []) do
    issue_body
  end

  defp compose_body(issue_body, labels) do
    header = "## Labels\n\n" <> Enum.join(Enum.map(labels, &("- " <> &1)), "\n")
    issue_body <> "\n\n" <> header
  end
end
