defmodule Kiln.Factory.Run do
  @moduledoc """
  SHELL module — placeholder for the Wave 1+ live `Kiln.Runs.Run` factory.

  Plan 02 (runs schema + `Kiln.Runs.Run` Ecto module) REPLACES this file
  wholesale with a live factory that pairs `ExMachina`'s Ecto integration
  with a `Kiln.Runs.Run` factory function. Shape of the eventual body
  (placeholder keys; real schema fields are decided in Plan 02):

    * top-level: ex_machina + Kiln.Repo
    * `run_factory/0` returns `%Kiln.Runs.Run{state: :queued, ...}`

  Until Plan 02 lands, this shell ships with a lone `placeholder_run_attrs/0`
  marker so the file can be imported without raising and its SHELL status
  is grep-verifiable. The shell deliberately does NOT declare the
  ex_machina Ecto integration at compile time — that would fail because
  `Kiln.Runs.Run` does not yet exist.

  Grep markers (used by Plan 02's acceptance-criteria automation):

    * `SHELL` / `Plan 02` — shell-vs-live discriminator
    * `placeholder_run_attrs` — function name

  Part of Plan 02-00 Wave 0 infrastructure (see PLAN.md Task 2a).
  """

  @doc """
  Placeholder — returns an empty map.

  This function exists SOLELY as a compile-time marker for the SHELL
  status of this module. Plan 02 replaces this module wholesale with a
  live ex_machina / Ecto-backed factory; at that point
  `placeholder_run_attrs/0` disappears.
  """
  @spec placeholder_run_attrs() :: map()
  def placeholder_run_attrs, do: %{}
end
