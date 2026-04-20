defmodule Kiln.ModelRegistry.Preset do
  @moduledoc """
  Decoded D-105 preset: `role atom => role_spec`.

  A role spec carries:
    * `:model` — the primary model id (String.t())
    * `:fallback` — ordered fallback chain (list of model ids)
    * `:tier_crossing_alerts_on` — optional list of model ids that trip
      a tier-crossing desktop notification (D-106)
    * `:fallback_policy` — `:same_provider` (P3 only; D-107) or
      `:cross_provider` (shipped as data, never exercised in P3)
    * `:deprecated_on` — optional `~D[YYYY-MM-DD]` date marker (D-108).
      Resolution still succeeds; consumers emit
      `model_deprecated_resolved` audit warnings.

  The struct is thin — data lives in `priv/model_registry/<preset>.exs`
  and is loaded at compile time by `Kiln.ModelRegistry`.
  """

  @type role ::
          :planner
          | :coder
          | :tester
          | :reviewer
          | :ui_ux
          | :qa_verifier
          | :mayor

  @type role_spec :: %{
          required(:model) => String.t(),
          required(:fallback) => [String.t()],
          optional(:tier_crossing_alerts_on) => [String.t()],
          required(:fallback_policy) => :same_provider | :cross_provider,
          optional(:deprecated_on) => Date.t()
        }

  @type t :: %__MODULE__{
          name: atom(),
          roles: %{role() => role_spec()}
        }

  @enforce_keys [:name, :roles]
  defstruct [:name, :roles]
end
