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
  @spec next(String.t(), atom(), atom()) :: {:ok, String.t()} | {:exhausted, String.t()}
  def next(current_model, _fault_class, preset_name)
      when is_binary(current_model) and is_atom(preset_name) do
    preset = Map.fetch!(@presets_data, preset_name)

    chain =
      preset.roles
      |> Map.values()
      |> Enum.flat_map(fn %{model: m, fallback: f} -> [m | f] end)
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
end
