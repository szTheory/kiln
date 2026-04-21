defmodule Kiln.Specs.HoldoutManifestTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Kiln.Stages.NextStageDispatcher

  test "artifact_allowlist/2 drops holdout-tagged digests when holdout_excluded" do
    good = %{"sha256" => String.duplicate("a", 64), "size_bytes" => 1}
    bad = %{"sha256" => "holdout_" <> String.duplicate("b", 57), "size_bytes" => 1}

    assert [^good] =
             NextStageDispatcher.artifact_allowlist([good, bad], %{holdout_excluded: true})
  end

  test "artifact_allowlist/2 leaves refs unchanged without holdout_excluded" do
    good = %{"sha256" => String.duplicate("c", 64), "size_bytes" => 1}
    bad = %{"sha256" => "holdout_" <> String.duplicate("d", 57), "size_bytes" => 1}

    assert [^good, ^bad] = NextStageDispatcher.artifact_allowlist([good, bad], %{})
  end
end
