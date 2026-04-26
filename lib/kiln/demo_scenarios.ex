defmodule Kiln.DemoScenarios do
  @moduledoc """
  Curated demo-mode scenarios for first-use onboarding.

  These are fixed presets for now: each one changes the narrative, the seeded
  context framing, and the recommended template without exposing arbitrary
  runtime mutation.
  """

  @type scenario :: %{
          id: String.t(),
          title: String.t(),
          persona: String.t(),
          jtbd: String.t(),
          narrative: String.t(),
          seeded_context: String.t(),
          expected_outcome: String.t(),
          recommended_template_id: String.t()
        }

  @scenarios [
    %{
      id: "solo-founder-fast-proof",
      title: "Solo founder fast proof",
      persona: "Solo builder evaluating whether Kiln is worth a real project slot.",
      jtbd:
        "Understand the product quickly and see one believable run path without paying for APIs yet.",
      narrative:
        "You want the shortest possible proof that the factory story is real before committing real credentials and project time.",
      seeded_context:
        "Show a calm low-friction story: setup, template choice, and one believable run path with demo-safe framing.",
      expected_outcome:
        "You should leave this scenario knowing where to start, what the run board does, and how to graduate to live mode.",
      recommended_template_id: "hello-kiln"
    },
    %{
      id: "operator-triage-readiness",
      title: "Operator readiness triage",
      persona: "Operator bringing a fresh machine online.",
      jtbd: "Find every missing configuration step quickly and recover without guessing.",
      narrative:
        "You care less about the run itself and more about whether the app explains blockers cleanly and self-serves the path to live mode.",
      seeded_context:
        "Surface settings, provider health, and the places where missing configuration would interrupt real work.",
      expected_outcome:
        "You should know exactly what to fix next and where each missing dependency matters.",
      recommended_template_id: "markdown-spec-stub"
    },
    %{
      id: "gameboy-first-project",
      title: "Game Boy first project",
      persona: "Dogfooding operator preparing the first real external project.",
      jtbd:
        "See how Kiln will take you from demo familiarity into a real external Game Boy workflow.",
      narrative:
        "You want the app to make the Game Boy path feel intentional rather than buried in a generic template list.",
      seeded_context:
        "Bias the copy toward external repo expectations, dogfood constraints, and the bridge from demo confidence to live execution.",
      expected_outcome:
        "You should know that the Game Boy vertical slice is the first real project path once live credentials and local tooling are in place.",
      recommended_template_id: "gameboy-vertical-slice"
    }
  ]

  @spec list() :: [scenario()]
  def list, do: @scenarios

  @spec default() :: scenario()
  def default, do: hd(@scenarios)

  @spec fetch(String.t() | nil) :: {:ok, scenario()} | {:error, :unknown_scenario}
  def fetch(nil), do: {:ok, default()}
  def fetch(""), do: {:ok, default()}

  def fetch(id) when is_binary(id) do
    case Enum.find(@scenarios, &(&1.id == id)) do
      nil -> {:error, :unknown_scenario}
      scenario -> {:ok, scenario}
    end
  end
end
