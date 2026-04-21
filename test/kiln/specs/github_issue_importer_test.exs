defmodule Kiln.Specs.GitHubIssueImporterTest do
  use Kiln.DataCase, async: false

  alias Kiln.Specs
  alias Kiln.Specs.GitHubIssueImporter

  @stub __MODULE__.ReqStubName

  setup {Req.Test, :verify_on_exit!}

  setup do
    Req.Test.stub(@stub, fn conn ->
      case Plug.Conn.get_req_header(conn, "if-none-match") do
        [] ->
          body = %{
            "title" => "GH title",
            "body" => "GH body",
            "node_id" => "MDU6SXNzdWUx",
            "number" => 1,
            "labels" => [%{"name" => "bug"}]
          }

          conn
          |> Plug.Conn.put_resp_header("etag", "\"issue-etag-1\"")
          |> Req.Test.json(body)

        _ ->
          Plug.Conn.send_resp(conn, 304, "")
      end
    end)

    :ok
  end

  defp req_opts, do: [req_options: [plug: {Req.Test, @stub}]]

  describe "import_from_slug/2 and import_from_url/2" do
    test "parses slug and url forms" do
      assert {:ok, d1} =
               GitHubIssueImporter.import_from_slug("octocat/Hello-World#1", req_opts())

      assert d1.source == :github_issue
      assert d1.github_owner == "octocat"
      assert d1.github_repo == "Hello-World"
      assert d1.github_issue_number == 1
      assert d1.github_node_id == "MDU6SXNzdWUx"
      assert d1.title == "GH title"
      assert d1.body =~ "GH body"
      assert d1.body =~ "Labels"
      assert d1.body =~ "bug"

      assert {:ok, d2} =
               GitHubIssueImporter.import_from_url(
                 "https://github.com/octocat/Hello-World/issues/1",
                 req_opts()
               )

      assert d1.id == d2.id
    end

    test "rejects malformed references" do
      assert {:error, :invalid_reference} =
               GitHubIssueImporter.import_from_slug("bad", req_opts())

      assert {:error, :invalid_reference} =
               GitHubIssueImporter.import_from_url("https://example.com/x", req_opts())
    end
  end

  describe "refresh/2 and If-None-Match" do
    test "304 updates last_synced_at only" do
      assert {:ok, draft} =
               Specs.import_github_issue_from_slug("octocat/Hello-World#1", req_opts())

      t0 = draft.last_synced_at
      assert is_struct(t0, DateTime)

      assert {:ok, refreshed} = Specs.refresh_github_issue_draft(draft, req_opts())
      assert refreshed.id == draft.id
      assert DateTime.compare(refreshed.last_synced_at, t0) == :gt
    end
  end
end
