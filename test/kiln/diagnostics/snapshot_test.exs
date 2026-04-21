defmodule Kiln.Diagnostics.SnapshotTest do
  use Kiln.DataCase, async: true

  alias Kiln.Diagnostics.Snapshot
  alias Kiln.Factory.Run, as: RunFactory

  test "build_zip/1 writes manifest and redacts secret patterns" do
    run = RunFactory.insert(:run, workflow_id: "wf_snap")

    sample = """
    line ok
    token sk-ant-api03-abc
    pat ghp_aaaaaaaaaaaaaaaaaaaa
    slack xoxb-1234567890-abcdefghij
    short sk-ok
    """

    assert {:ok, path} = Snapshot.build_zip(run_id: run.id, sample_log: sample)

    assert {:ok, bin} = File.read(path)
    File.rm!(path)

    assert {:ok, files} = :zip.unzip(bin, [:memory])

    log_bin =
      files
      |> Enum.find_value(fn {n, body} ->
        if List.to_string(n) == "redacted-sample.log", do: body
      end)

    assert is_binary(log_bin)
    assert log_bin =~ "[REDACTED]"
    refute log_bin =~ "sk-ant-api03"
    refute log_bin =~ "ghp_aaaaaaaa"
    refute log_bin =~ "xoxb-1234567890"
  end
end
