defmodule Kiln.Sandboxes.ImageResolverTest do
  use ExUnit.Case, async: true

  alias Kiln.Sandboxes.ImageResolver

  test "resolve/1 returns image ref and digest for elixir" do
    assert {:ok, {image_ref, digest}} = ImageResolver.resolve("elixir")
    assert String.starts_with?(image_ref, "kiln/sandbox-elixir:")
    assert String.starts_with?(digest, "sha256:")
  end

  test "resolve/1 accepts atom input" do
    assert {:ok, {_, _}} = ImageResolver.resolve(:elixir)
  end

  test "resolve/1 rejects unsupported languages" do
    assert {:error, :unsupported_language} = ImageResolver.resolve("unknown_lang")
  end

  test "all_supported_languages/0 includes elixir" do
    assert "elixir" in ImageResolver.all_supported_languages()
  end
end
