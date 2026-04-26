defmodule Kiln.OperatorRuntime do
  @moduledoc """
  Operator-facing **demo vs live** runtime mode (Phase 999.2 / OPS-01).

  The mode is a **label for UI chrome** only: it does **not** authorize or
  bypass security. **Live** means the stack expects real provider credentials
  and may call external APIs (see SEC-01 — secrets are references, never
  values). **Demo** means fixtures/stubs and no paid provider calls in the
  intended local-first story.

  Source of truth is `Application.get_env(:kiln, :operator_runtime_mode)`.
  Host env `KILN_OPERATOR_RUNTIME_MODE` is bound in `config/runtime.exs` only.
  """

  @type mode :: :demo | :live | :unknown

  @doc """
  Normalizes string or atom inputs to a supported runtime mode.
  """
  @spec normalize(term()) :: mode()
  def normalize(mode)

  def normalize(:demo), do: :demo
  def normalize(:live), do: :live
  def normalize("demo"), do: :demo
  def normalize("live"), do: :live
  def normalize(_), do: :unknown

  @doc """
  Returns `:demo`, `:live`, or `:unknown` from application env.

  Unknown values and `nil` normalize to `:unknown` — this function never raises.
  """
  @spec mode() :: mode()
  def mode do
    Application.get_env(:kiln, :operator_runtime_mode)
    |> normalize()
  end
end
