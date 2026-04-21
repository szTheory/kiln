defmodule Kiln.GitTest do
  use ExUnit.Case, async: true

  alias Kiln.Git

  describe "ls_remote_tip/3 + push_intent_payload/2" do
    test "parses first sha and builds CAS payload" do
      sha = String.duplicate("b", 40)

      runner = fn
        ["ls-remote", "origin", "refs/heads/main"], _opts ->
          {:ok, "#{sha}\trefs/heads/main\n"}

        _, _ ->
          flunk("unexpected argv")
      end

      assert {:ok, ^sha} = Git.ls_remote_tip("origin", "refs/heads/main", runner)

      assert Git.push_intent_payload("a" |> String.duplicate(40), %{
               "local_commit_sha" => sha,
               "refspec" => "refs/heads/main"
             }) == %{
               "expected_remote_sha" => String.duplicate("a", 40),
               "local_commit_sha" => sha,
               "refspec" => "refs/heads/main"
             }
    end
  end

  describe "classify_push_failure/2" do
    test "success" do
      assert Git.classify_push_failure(0, "anything") == :ok
    end

    test "non-fast-forward stderr" do
      stderr =
        "error: failed to push some refs\nhint: Updates were rejected because the tip of your current branch is behind\nhint: its remote counterpart. Integrate the remote changes (e.g.\nhint: 'git pull ...') before pushing again.\nhint: See the 'Note about fast-forwards' in 'git push --help' for details.\n"

      assert Git.classify_push_failure(1, stderr) == :git_non_fast_forward
    end

    test "remote advanced pattern" do
      stderr =
        "error: failed to push some refs\nhint: Updates were rejected because the remote contains work that you do not have locally."

      assert Git.classify_push_failure(1, stderr) == :git_remote_advanced
    end

    test "stale info maps to remote advanced" do
      stderr = "error: stale info\n"
      assert Git.classify_push_failure(1, stderr) == :git_remote_advanced
    end

    test "unknown maps to push rejected" do
      assert Git.classify_push_failure(1, "some unknown transport failure") == :git_push_rejected
    end
  end
end
