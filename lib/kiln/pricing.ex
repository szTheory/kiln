defmodule Kiln.Pricing do
  @moduledoc """
  Pricing-table lookup (D-146). Loads `priv/pricing/v1/<provider>.exs`
  files at compile time and exposes `estimate_usd/3` as the single
  pricing surface.

  On unknown model: returns `Decimal.new(0)` and emits a
  `Logger.warning/1` line. Pricing-table drift should not crash a run;
  `mix kiln.pricing.check` (Wave 5/6) surfaces drift in CI as a
  warning-only signal (D-146 — Phase 9 hardening may make fatal).

  The per-provider files are marked `@external_resource` so mix
  recompiles this module whenever any provider table changes — no stale
  cache.
  """

  require Logger

  @pricing_dir Path.expand("../../priv/pricing/v1", __DIR__)
  @providers [:anthropic, :openai, :google, :ollama]

  @pricing_by_provider (for provider <- @providers, into: %{} do
                          path = Path.join(@pricing_dir, "#{provider}.exs")
                          @external_resource path

                          data =
                            case File.read(path) do
                              {:ok, _} -> path |> Code.eval_file() |> elem(0)
                              {:error, _} -> %{}
                            end

                          {provider, data}
                        end)

  # Flat %{model_id => rates} map — the hot-path lookup structure.
  @flat @pricing_by_provider
        |> Map.values()
        |> Enum.reduce(%{}, &Map.merge(&2, &1))

  @doc """
  Estimate USD cost for a completion call: `input_tokens` + `output_tokens`
  against the per-million-token rates declared in
  `priv/pricing/v1/<provider>.exs`.

  Returns a `Decimal`. On unknown model, returns `Decimal.new(0)` and
  emits a `Logger.warning/1` — the pre-flight guard should never block
  a run on a pricing-table miss; let the drift-check task surface it.
  """
  @spec estimate_usd(String.t() | nil, non_neg_integer(), non_neg_integer()) :: Decimal.t()
  def estimate_usd(nil, _input_tokens, _output_tokens), do: Decimal.new(0)

  def estimate_usd(model, input_tokens, output_tokens)
      when is_binary(model) and is_integer(input_tokens) and is_integer(output_tokens) and
             input_tokens >= 0 and output_tokens >= 0 do
    case Map.get(@flat, model) do
      nil ->
        Logger.warning("Kiln.Pricing.estimate_usd: unknown model #{inspect(model)} — returning 0")

        Decimal.new(0)

      %{input_per_mtok_usd: in_rate, output_per_mtok_usd: out_rate} ->
        mtok = Decimal.new(1_000_000)

        in_cost =
          input_tokens
          |> Decimal.new()
          |> Decimal.div(mtok)
          |> Decimal.mult(in_rate)

        out_cost =
          output_tokens
          |> Decimal.new()
          |> Decimal.div(mtok)
          |> Decimal.mult(out_rate)

        Decimal.add(in_cost, out_cost)
    end
  end

  @doc """
  Returns `true` when `model` has a pricing row in any provider table.
  Consumed by `Kiln.ModelRegistry.PresetsTest` as a cross-validation
  guard — every preset's primary + fallback models must be known here.
  """
  @spec known_model?(String.t()) :: boolean()
  def known_model?(model) when is_binary(model), do: Map.has_key?(@flat, model)

  @doc """
  Returns the list of all pricing-table model ids across providers.
  Used by the `mix kiln.pricing.check` task and diagnostic tooling.
  """
  @spec all_known_models() :: [String.t()]
  def all_known_models, do: Map.keys(@flat)

  @doc """
  Returns the per-provider pricing map. Exposed for the pricing-drift
  check and CLI reporting; callers MUST treat the result as opaque.
  """
  @spec providers() :: %{atom() => %{String.t() => map()}}
  def providers, do: @pricing_by_provider
end
