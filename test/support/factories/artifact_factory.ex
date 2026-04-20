defmodule Kiln.Factory.Artifact do
  @moduledoc """
  SHELL module — placeholder for the Wave 1+ live `Kiln.Artifacts.Artifact`
  factory.

  Plan 03 (artifacts schema + `Kiln.Artifacts.Artifact` Ecto module +
  `Kiln.Artifacts` CAS context) REPLACES this file wholesale with a live
  factory that pairs `ExMachina`'s Ecto integration with a
  `Kiln.Artifacts.Artifact` factory function. Shape of the eventual body
  (placeholder keys; real schema fields are decided in Plan 03):

    * top-level: ex_machina + Kiln.Repo
    * `artifact_factory/0` returns `%Kiln.Artifacts.Artifact{name: "plan.md", sha256: ..., content_type: "text/markdown", ...}`

  Until Plan 03 lands, this shell ships with a lone
  `placeholder_artifact_attrs/0` marker so the file can be imported
  without raising and its SHELL status is grep-verifiable. The shell
  deliberately does NOT declare the ex_machina Ecto integration at
  compile time — that would fail because `Kiln.Artifacts.Artifact` does
  not yet exist.

  Grep markers (used by Plan 03's acceptance-criteria automation):

    * `SHELL` / `Plan 03` — shell-vs-live discriminator
    * `placeholder_artifact_attrs` — function name

  Part of Plan 02-00 Wave 0 infrastructure (see PLAN.md Task 2a).
  """

  @doc """
  Placeholder — returns an empty map.

  This function exists SOLELY as a compile-time marker for the SHELL
  status of this module. Plan 03 replaces this module wholesale with a
  live ex_machina / Ecto-backed factory; at that point
  `placeholder_artifact_attrs/0` disappears.
  """
  @spec placeholder_artifact_attrs() :: map()
  def placeholder_artifact_attrs, do: %{}
end
