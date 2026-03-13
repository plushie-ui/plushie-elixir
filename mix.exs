defmodule Julep.MixProject do
  use Mix.Project

  # Load extension beam files so Code.ensure_loaded? guards evaluate correctly.
  # Each extension depends on :julep (circular path dep), so we can't use Mix
  # deps. Instead, we add their compiled ebin dirs to the code path and
  # pre-load all their modules.
  if Mix.env() in [:dev, :test] do
    for ext <- ~w(julep_sparkline julep_hex_view julep_code_view julep_plot julep_timeline) do
      ebin = Path.expand("../#{ext}/_build/dev/lib/#{ext}/ebin")

      if File.dir?(ebin) do
        Code.append_path(ebin)

        ebin
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".beam"))
        |> Enum.each(fn beam ->
          mod = beam |> String.trim_trailing(".beam") |> String.to_atom()
          Code.ensure_loaded(mod)
        end)
      end
    end
  end

  def project do
    [
      app: :julep,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers() ++ [:julep_renderer],
      elixirc_options: [warnings_as_errors: true],
      consolidate_protocols: Mix.env() != :test,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Julep",
      description: "Native desktop GUIs from Elixir, powered by iced",
      package: package(),
      source_url: "https://github.com/lincracy/julep",
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
        "GitHub" => "https://github.com/lincracy/julep"
      },
      files: ~w(
        lib
        mix.exs
        README.md
        LICENSE
        .formatter.exs
      ),
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
      {:telemetry, "~> 1.0"},
      {:file_system, "~> 1.0", optional: true},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
      # Extension packages are loaded via Code.append_path in mix.exs (above)
      # to avoid circular path deps (each extension depends on :julep).
    ]
  end
end
