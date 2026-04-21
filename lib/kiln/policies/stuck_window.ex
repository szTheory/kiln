defmodule Kiln.Policies.StuckWindow do
  @moduledoc """
  Pure sliding-window policy for stuck-run detection (OBS-04).

  Window keeps the last **K** `{stage, failure_class}` pairs (insertion order).
  If any single pair appears **≥ N** times inside the window, the run should
  halt as stuck.

  Defaults: **K = 15**, **N = 3** (three identical failures inside the window).
  """

  alias Kiln.Policies.FailureClass

  @window_k 15
  @halt_n 3

  @type pair :: {atom(), atom()}
  @type window :: [pair()]

  @doc """
  Append one signal. Returns `{new_window, :ok}` or
  `{new_window, {:halt, %{reason: :stuck, ...}}}`.
  """
  @spec push_event(window() | list(), atom(), atom()) :: {window(), :ok | {:halt, map()}}
  def push_event(window, stage, failure_class)
      when is_list(window) and is_atom(stage) do
    {:ok, fc} = FailureClass.cast(failure_class)
    pair = {stage, fc}
    normalized = normalize_window(window)
    trimmed = (normalized ++ [pair]) |> Enum.take(-@window_k)

    occurrences =
      Enum.count(trimmed, fn
        {^stage, ^fc} -> true
        _ -> false
      end)

    if occurrences >= @halt_n do
      {trimmed,
       {:halt,
        %{
          reason: :stuck,
          stage: stage,
          failure_class: fc,
          occurrences: occurrences,
          stuck_signal_window: tuples_to_maps(trimmed)
        }}}
    else
      {trimmed, :ok}
    end
  end

  @doc "Clear window after a successful stage advance (stub hook for future policy)."
  @spec decay_on_progress(window(), map()) :: []
  def decay_on_progress(_window, _meta), do: []

  defp normalize_window(list) do
    Enum.map(list, fn
      {s, f} ->
        {s, normalize_fc(f)}

      %{"stage" => s, "failure_class" => f} ->
        {parse_stage(s), normalize_fc(f)}

      %{stage: s, failure_class: f} ->
        {s, normalize_fc(f)}
    end)
  end

  defp parse_stage(s) when is_atom(s), do: s

  defp parse_stage(s) when is_binary(s) do
    String.to_atom(s)
  end

  defp normalize_fc(f) when is_atom(f), do: elem(FailureClass.cast(f), 1)
  defp normalize_fc(f), do: elem(FailureClass.cast(f), 1)

  defp tuples_to_maps(tuples) do
    Enum.map(tuples, fn {s, f} ->
      %{"stage" => Atom.to_string(s), "failure_class" => Atom.to_string(f)}
    end)
  end
end
