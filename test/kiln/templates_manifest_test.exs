defmodule Kiln.TemplatesManifestTest do
  use ExUnit.Case, async: true

  alias Kiln.Templates
  alias Kiln.Templates.Manifest

  test "list/0 returns sorted ids and unique manifest ids" do
    ids = Templates.list() |> Enum.map(& &1.id)
    assert ids == Enum.sort(ids)
    assert length(ids) == length(Enum.uniq(ids))
    assert length(ids) >= 3
  end

  test "fetch/1 rejects unknown template ids" do
    assert Templates.fetch("../../../etc/passwd") == {:error, :unknown_template}
    assert Templates.fetch("nope-not-a-template") == {:error, :unknown_template}
  end

  test "read_spec/1 returns non-empty body for a known template" do
    assert {:ok, body} = Templates.read_spec("hello-kiln")
    assert is_binary(body)
    assert String.trim(body) != ""
  end

  test "Manifest.read!/0 loads via Application.app_dir" do
    %Manifest.Root{templates: rows} = Manifest.read!()
    assert length(rows) >= 3
    assert Enum.all?(rows, fn e -> is_binary(e.workflow_id) end)
  end
end
