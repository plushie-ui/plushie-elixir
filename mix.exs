defmodule Julep.MixProject do
  use Mix.Project

  def project do
    [
      app: :julep,
      version: "0.1.0-dev",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Julep",
      description: "Native desktop GUIs from Elixir, powered by iced"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:jason, "~> 1.4"}
    ]
  end
end
