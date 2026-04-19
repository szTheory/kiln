defmodule Kiln.CredoTestCase do
  @moduledoc "Convenience wrapper around `Credo.Test.Case` for Kiln's custom-check tests."
  use ExUnit.CaseTemplate

  using do
    quote do
      use Credo.Test.Case
    end
  end
end
