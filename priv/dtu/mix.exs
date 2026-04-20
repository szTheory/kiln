defmodule KilnDtu.MixProject do
  use Mix.Project

  def project do
    [
      app: :kiln_dtu,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [kiln_dtu: [steps: [:assemble], strip_beams: true]]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {KilnDtu.Application, []}
    ]
  end

  defp deps do
    [
      {:bandit, "~> 1.10"},
      {:plug, "~> 1.18"},
      {:jason, "~> 1.4"},
      {:jsv, "~> 0.18"},
      {:yaml_elixir, "~> 2.12"}
    ]
  end
end
