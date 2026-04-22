defmodule Kiln.Dogfood.Template do
  @moduledoc """
  Canonical dogfood markdown bytes shipped under `priv/dogfood/spec.md`
  (mirrors `dogfood/spec.md` in git — D-901).
  """

  @spec read() :: {:ok, String.t()} | {:error, File.posix()}
  def read do
    path = Application.app_dir(:kiln, "priv/dogfood/spec.md")
    File.read(path)
  end
end
