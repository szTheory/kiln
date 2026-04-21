defmodule Kiln.GitHub.CliTest do
  use ExUnit.Case, async: true

  alias Kiln.GitHub.Cli

  @attrs %{
    "title" => "t",
    "body" => "hello",
    "base" => "main",
    "head" => "feature",
    "draft" => true,
    "reviewers" => []
  }

  test "create_pr/2 parses gh json on success" do
    json =
      ~s({"number":42,"url":"https://github.com/o/r/pull/42","headRefName":"feature","baseRefName":"main","isDraft":true})

    runner = fn argv, _opts ->
      assert "pr" in argv
      assert "create" in argv
      assert "--json" in argv
      {:ok, json}
    end

    assert {:ok, %{"number" => 42, "url" => url}} = Cli.create_pr(@attrs, runner: runner)
    assert String.ends_with?(url, "/42")
  end

  test "classify_gh_error maps 401-ish stderr to :gh_auth_expired" do
    assert Cli.classify_gh_error("HTTP 401: Bad credentials\n", 1) == :gh_auth_expired
  end

  test "classify_gh_error maps permission stderr to :gh_permissions_insufficient" do
    assert Cli.classify_gh_error("HTTP 403: permission denied\n", 1) ==
             :gh_permissions_insufficient
  end

  test "create_pr maps classified auth errors to {:error, atom}" do
    runner = fn _, _opts ->
      {:error, %{exit_status: 1, stdout: "", stderr: "HTTP 401: Bad credentials\n"}}
    end

    assert {:error, :gh_auth_expired} = Cli.create_pr(@attrs, runner: runner)
  end
end
