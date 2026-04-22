defmodule Kiln.ModelRegistry do
  @moduledoc """
  Preset → role → model resolution + fallback chain (D-105..D-108 /
  OPS-03).

  Loads `priv/model_registry/<preset>.exs` files at compile time. P3
  ships `:same_provider` on every role's `fallback_policy`; Phase 5+
  flips OpenAI live and the operator may switch individual roles to
  `:cross_provider` without a schema migration.

  Public API:

    * `resolve/2` — preset name + per-stage overrides → role → spec map
    * `next/3` — given a current model, a fault class, and a preset,
      return the next model in the fallback chain or `{:exhausted, _}`
      if no more hops remain
    * `adapter_for/1` — model id → adapter module (provider routing)
    * `all_presets/0` — the 6 D-57 preset atoms

  Each preset file is marked `@external_resource` so mix recompiles
  when any preset changes.
  """

  alias Kiln.ModelRegistry.Preset

  @presets ~w(elixir_lib phoenix_saas_feature typescript_web_feature python_cli bugfix_critical docs_update)a

  @presets_dir Path.expand("../../priv/model_registry", __DIR__)

  @presets_data (for preset <- @presets, into: %{} do
                   path = Path.join(@presets_dir, "#{preset}.exs")
                   @external_resource path

                   case File.read(path) do
                     {:ok, _} ->
                       roles = path |> Code.eval_file() |> elem(0)
                       {preset, %Preset{name: preset, roles: roles}}

                     {:error, :enoent} ->
                       raise CompileError,
                         description:
                           "Missing preset file priv/model_registry/#{preset}.exs — every D-57 preset MUST have a definition file"
                   end
                 end)

  @doc """
  Returns the list of 6 D-57 preset atoms.
  """
  @spec all_presets() :: [atom(), ...]
  def all_presets, do: @presets

  @doc """
  Resolve a preset to a `role => role_spec` map, with optional
  per-stage overrides that win over the preset's defaults.

  Overrides are merged shallowly: a role entry in `stage_overrides`
  replaces the preset's entry for that role entirely.
  """
  @spec resolve(atom(), map()) :: %{atom() => map()}
  def resolve(preset_name, stage_overrides \\ %{})
      when is_atom(preset_name) and is_map(stage_overrides) do
    preset = Map.fetch!(@presets_data, preset_name)
    Map.merge(preset.roles, stage_overrides)
  end

  @doc """
  Walk the fallback chain for `preset_name`. Given a `current_model` and
  a `fault_class` (recorded for telemetry; not used to filter here —
  downstream adapter logic decides whether the fault is retryable), return
  the next model id to try.

  Returns `{:ok, model_id}` when the chain has another hop, or
  `{:exhausted, current_model}` when the chain is exhausted.

  The chain is the concatenation of `model :: fallback` across every
  role, deduplicated in declaration order.
  """
  # Stable role iteration order for `next/3` so chain traversal is
  # deterministic regardless of underlying map ordering.
  @role_order ~w(planner coder tester reviewer ui_ux qa_verifier mayor)a

  @spec next(String.t(), atom(), atom()) :: {:ok, String.t()} | {:exhausted, String.t()}
  def next(current_model, _fault_class, preset_name)
      when is_binary(current_model) and is_atom(preset_name) do
    preset = Map.fetch!(@presets_data, preset_name)

    chain =
      @role_order
      |> Enum.flat_map(fn role ->
        case Map.get(preset.roles, role) do
          %{model: m, fallback: f} -> [m | f]
          _ -> []
        end
      end)
      |> Enum.uniq()

    case Enum.drop_while(chain, &(&1 != current_model)) do
      [_current, next | _] -> {:ok, next}
      _ -> {:exhausted, current_model}
    end
  end

  @doc """
  Provider routing by model-id prefix. Used by `Kiln.Agents.BudgetGuard`
  and the telemetry handler to dispatch through the right adapter
  module.

  The `Adapter.*` modules are shipped by Plan 03-05; routing here works
  at runtime regardless of whether the target module is compiled yet
  — the atom lookup is inert until an adapter call actually dispatches.
  """
  @spec adapter_for(String.t()) :: module()
  def adapter_for("claude-" <> _), do: Kiln.Agents.Adapter.Anthropic
  def adapter_for("gpt-" <> _), do: Kiln.Agents.Adapter.OpenAI
  def adapter_for("gemini-" <> _), do: Kiln.Agents.Adapter.Google
  def adapter_for(_), do: Kiln.Agents.Adapter.Ollama

  @typedoc """
  Operator-facing provider card row for `ProviderHealthLive` (OPS-01).

  Raw API keys never appear — only booleans and aggregates.
  """
  @type provider_health_snapshot :: %{
          id: :anthropic | :openai | :google | :ollama,
          key_configured?: boolean(),
          last_ok_at: DateTime.t() | nil,
          recent_error_rate: float(),
          rate_limit_remaining: integer() | nil,
          token_budget_remaining_today: Decimal.t() | nil,
          spend_usd_today: Decimal.t()
        }

  @provider_ids ~w(anthropic openai google ollama)a
  @health_ets :kiln_provider_health_counters

  @doc """
  Returns one snapshot map per configured LLM provider for health cards.

  Spend is derived from today's `CostRollups.by_provider/1` rows bucketed
  by model-id prefix. Error counters and `last_ok_at` are backed by a public
  named ETS table so tests (and future adapter telemetry) can move cards
  between polls without exposing secrets.
  """
  @spec provider_health_snapshots() :: [provider_health_snapshot()]
  def provider_health_snapshots do
    ensure_health_ets!()
    spend = today_spend_usd_by_provider_id()

    for id <- @provider_ids do
      ctr = health_counters(id)
      calls = ctr.oks + ctr.errors
      err_rate = if(calls > 0, do: ctr.errors / calls, else: 0.0)

      %{
        id: id,
        key_configured?: provider_key_configured?(id),
        last_ok_at: ctr.last_ok_at,
        recent_error_rate: err_rate,
        rate_limit_remaining: ctr.rate_limit_remaining,
        token_budget_remaining_today: nil,
        spend_usd_today: Map.get(spend, id, Decimal.new(0))
      }
    end
  end

  @doc false
  @spec provider_health_record_ok(atom()) :: :ok
  def provider_health_record_ok(id) when id in @provider_ids do
    ensure_health_ets!()
    c = health_counters(id)
    now = DateTime.utc_now(:microsecond)

    :ets.insert(@health_ets, {
      id,
      %{c | oks: c.oks + 1, last_ok_at: now}
    })

    :ok
  end

  @doc false
  @spec provider_health_record_error(atom()) :: :ok
  def provider_health_record_error(id) when id in @provider_ids do
    ensure_health_ets!()
    c = health_counters(id)
    :ets.insert(@health_ets, {id, %{c | errors: c.errors + 1}})
    :ok
  end

  defp ensure_health_ets! do
    case :ets.whereis(@health_ets) do
      :undefined ->
        :ets.new(@health_ets, [:named_table, :public, :set])

      _tid ->
        :ok
    end

    for id <- @provider_ids do
      case :ets.lookup(@health_ets, id) do
        [] ->
          :ets.insert(
            @health_ets,
            {id, %{oks: 0, errors: 0, last_ok_at: nil, rate_limit_remaining: nil}}
          )

        _ ->
          :ok
      end
    end

    :ok
  end

  defp health_counters(id) do
    case :ets.lookup(@health_ets, id) do
      [{^id, m}] when is_map(m) -> m
      _ -> %{oks: 0, errors: 0, last_ok_at: nil, rate_limit_remaining: nil}
    end
  end

  defp provider_key_configured?(:ollama), do: true

  defp provider_key_configured?(:anthropic), do: Kiln.Secrets.present?(:anthropic_api_key)
  defp provider_key_configured?(:openai), do: Kiln.Secrets.present?(:openai_api_key)
  defp provider_key_configured?(:google), do: Kiln.Secrets.present?(:google_api_key)

  defp today_spend_usd_by_provider_id do
    Kiln.CostRollups.by_provider(%{})
    |> Enum.reduce(%{}, fn %{key: model_key, usd: usd}, acc ->
      case provider_id_for_model_key(model_key) do
        nil -> acc
        id -> Map.update(acc, id, usd, &Decimal.add(&1, usd))
      end
    end)
  end

  defp provider_id_for_model_key(key) when is_binary(key) do
    cond do
      String.starts_with?(key, "claude-") -> :anthropic
      String.starts_with?(key, "gpt-") -> :openai
      String.starts_with?(key, "gemini-") -> :google
      key in ["unpriced", nil] -> nil
      true -> :ollama
    end
  end

  defp provider_id_for_model_key(_), do: nil
end
