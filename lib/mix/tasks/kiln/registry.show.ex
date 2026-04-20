defmodule Mix.Tasks.Kiln.Registry.Show do
  @moduledoc """
  Operator DX task — prints the resolved `role -> model` mapping for a
  D-57 preset (D-105 / OPS-03).

      mix kiln.registry.show elixir_lib
      mix kiln.registry.show bugfix_critical

  Output format is plain text, one line per role, with fallback chain
  and policy fields included so an operator can spot-check a preset
  without reading the `.exs` file.
  """

  use Mix.Task

  @shortdoc "Print resolved role->model mapping for a preset"

  @impl Mix.Task
  def run([preset_str]) when is_binary(preset_str) do
    Mix.Task.run("loadpaths")
    # Ensure the :kiln app is compiled and loaded so the preset atoms
    # declared by `Kiln.ModelRegistry.all_presets/0` are registered in
    # the atom table before `String.to_existing_atom/1`.
    Mix.Task.run("compile", ["--no-warnings-as-errors"])
    Code.ensure_loaded(Kiln.ModelRegistry)
    _ = Kiln.ModelRegistry.all_presets()

    preset =
      try do
        String.to_existing_atom(preset_str)
      rescue
        ArgumentError ->
          Mix.raise(
            "Unknown preset #{inspect(preset_str)}. Known presets: " <>
              (Kiln.ModelRegistry.all_presets() |> Enum.map(&Atom.to_string/1) |> Enum.join(", "))
          )
      end

    unless preset in Kiln.ModelRegistry.all_presets() do
      Mix.raise(
        "Unknown preset #{inspect(preset_str)}. Known presets: " <>
          (Kiln.ModelRegistry.all_presets() |> Enum.map(&Atom.to_string/1) |> Enum.join(", "))
      )
    end

    mapping = Kiln.ModelRegistry.resolve(preset)

    IO.puts("Preset: #{preset}")

    for {role, spec} <- Enum.sort_by(mapping, &elem(&1, 0)) do
      IO.puts("  #{role}:")
      IO.puts("    model:           #{spec.model}")
      IO.puts("    fallback:        #{inspect(spec.fallback)}")
      IO.puts("    fallback_policy: #{spec.fallback_policy}")

      if tca = Map.get(spec, :tier_crossing_alerts_on) do
        IO.puts("    tier_crossing_alerts_on: #{inspect(tca)}")
      end

      if dep = Map.get(spec, :deprecated_on) do
        IO.puts("    deprecated_on:   #{Date.to_iso8601(dep)}")
      end
    end
  end

  def run(_) do
    Mix.raise("Usage: mix kiln.registry.show <preset_name>")
  end
end
