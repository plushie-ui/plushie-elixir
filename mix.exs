defmodule Julep.MixProject do
  use Mix.Project

  def project do
    [
      app: :julep,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers() ++ [:julep_gui],
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Julep",
      description: "Native desktop GUIs from Elixir, powered by iced",
      package: package(),
      # TODO: verify source_url before Hex publish -- github.com/julep-ui/julep
      # is an unrelated project; update to the correct repo URL first.
      source_url: "https://github.com/julep-ui/julep",
      docs: [main: "Julep", extras: ["README.md"]],
      aliases: aliases(),
      dialyzer: [plt_add_apps: [:mix, :ex_unit, :inets, :ssl]]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/julep-ui/julep"
      },
      files: ~w(lib native/julep_gui/src native/julep_gui/Cargo.toml mix.exs README.md LICENSE),
      exclude_patterns: [~r/julep\.preflight\.ex$/]
    ]
  end

  defp aliases do
    [
      preflight: "julep.preflight"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:msgpax, "~> 2.3"},
      {:file_system, "~> 1.0", optional: true},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
