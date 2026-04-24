defmodule Kiln.Attach.SourceTest do
  use Kiln.DataCase, async: true

  alias Kiln.Attach
  describe "resolve_source/2" do
    test "resolves a local git repo path into the canonical source contract" do
      repo_root = make_git_repo!("kiln_attach_source_local")
      canonical_root = canonical_root!(repo_root)
      repo_name = Path.basename(canonical_root)

      assert {:ok,
              %{
                kind: :local_path,
                input: ^repo_root,
                canonical_input: ^repo_root,
                canonical_root: ^canonical_root,
                repo_identity: %{
                  provider: :local,
                  host: nil,
                  owner: nil,
                  name: ^repo_name,
                  slug: ^repo_name
                },
                remote_metadata: %{
                  url: nil,
                  clone_url: nil,
                  default_branch: nil,
                  head_sha: nil
                }
              }} = Attach.resolve_source(repo_root)
    end

    test "treats an existing clone path inside the repo as a local-path success path" do
      repo_root = make_git_repo!("kiln_attach_source_existing_clone")
      canonical_root = canonical_root!(repo_root)
      nested_path = Path.join([repo_root, "lib", "nested"])
      File.mkdir_p!(nested_path)

      assert {:ok, %{kind: :local_path, canonical_root: ^canonical_root} = source} =
               Attach.resolve_source(nested_path)

      assert source.canonical_input == Path.expand(nested_path)
      assert source.repo_identity.slug == Path.basename(canonical_root)
    end

    test "parses a github url into one owner/repo identity" do
      input = "https://github.com/elixir-lang/elixir.git"

      assert {:ok,
              %{
                kind: :github_url,
                input: ^input,
                canonical_input: "https://github.com/elixir-lang/elixir",
                canonical_root: nil,
                repo_identity: %{
                  provider: :github,
                  host: "github.com",
                  owner: "elixir-lang",
                  name: "elixir",
                  slug: "elixir-lang/elixir"
                },
                remote_metadata: %{
                  url: "https://github.com/elixir-lang/elixir",
                  clone_url: "https://github.com/elixir-lang/elixir.git",
                  default_branch: nil,
                  head_sha: nil
                }
              }} = Attach.resolve_source(input)
    end

    test "returns a typed validation error for an existing path that is not a git repo" do
      path = temp_path("kiln_attach_source_plain_dir")
      File.mkdir_p!(path)

      assert {:error,
              %{
                code: :not_a_git_repo,
                field: :source,
                input: ^path,
                message: "Path exists but is not inside a git repository.",
                remediation: "Choose a local git repo, an existing clone, or a GitHub URL."
              }} = Attach.resolve_source(path)
    end

    test "rejects unsupported urls deterministically" do
      input = "https://gitlab.com/example/kiln"

      assert {:error,
              %{
                code: :unsupported_source,
                field: :source,
                input: ^input,
                message: "Only local paths and GitHub URLs are supported right now.",
                remediation: "Use a local repo path, an existing clone, or a GitHub URL."
              }} = Attach.resolve_source(input)
    end
  end

  defp make_git_repo!(name) do
    repo_root = temp_path(name)
    File.mkdir_p!(repo_root)

    {_, 0} = System.cmd("git", ["init", "--quiet", repo_root])
    repo_root
  end

  defp temp_path(name) do
    Path.join(System.tmp_dir!(), "#{name}_#{System.unique_integer([:positive])}")
  end

  defp canonical_root!(path) do
    {output, 0} = System.cmd("pwd", ["-P"], cd: path)
    String.trim(output)
  end
end
