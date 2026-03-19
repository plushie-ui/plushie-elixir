defmodule Toddy.MixProject do
  use Mix.Project

  # Load extension beam files so Code.ensure_loaded? guards evaluate correctly.
  # Each extension depends on :toddy (circular path dep), so we can't use Mix
  # deps. Instead, we add their compiled ebin dirs to the code path and
  # pre-load all their modules.
  if Mix.env() in [:dev, :test] do
    for ext <- ~w(toddy_sparkline toddy_hex_view toddy_code_view toddy_plot toddy_timeline) do
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
      app: :toddy,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers() ++ [:toddy_renderer],
      elixirc_options: [warnings_as_errors: true],
      consolidate_protocols: Mix.env() != :test,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Toddy",
      description: "Native desktop GUIs from Elixir, powered by iced",
      package: package(),
      source_url: "https://github.com/toddy/toddy-elixir",
      docs: docs(),
      aliases: aliases(),
      dialyzer: [plt_add_apps: [:mix, :ex_unit, :inets, :ssl]]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs do
    [
      main: "getting-started",
      source_url: "https://github.com/toddy/toddy-elixir",
      extras: [
        "docs/getting-started.md",
        "docs/tutorial.md",
        "docs/app-behaviour.md",
        "docs/layout.md",
        "docs/events.md",
        "docs/commands.md",
        "docs/effects.md",
        "docs/scoped-ids.md",
        "docs/theming.md",
        "docs/testing.md",
        "docs/composition-patterns.md",
        "docs/accessibility.md",
        "docs/extensions.md"
      ],
      groups_for_extras: [
        Guides: [
          "docs/getting-started.md",
          "docs/tutorial.md",
          "docs/app-behaviour.md",
          "docs/layout.md",
          "docs/events.md",
          "docs/commands.md",
          "docs/effects.md",
          "docs/scoped-ids.md",
          "docs/theming.md",
          "docs/testing.md"
        ],
        Advanced: [
          "docs/composition-patterns.md",
          "docs/accessibility.md",
          "docs/extensions.md"
        ]
      ],
      groups_for_modules: [
        "App Framework": [
          Toddy,
          Toddy.App,
          Toddy.Runtime,
          Toddy.Bridge,
          Toddy.Binary,
          Toddy.DevServer
        ],
        "UI Builder": [
          Toddy.UI,
          Toddy.Iced,
          Toddy.Iced.Widget,
          Toddy.Iced.Encode,
          Toddy.Tree
        ],
        Widgets: ~r/Toddy\.Iced\.Widget\..*/,
        "Widget Types": [
          Toddy.Iced.Alignment,
          Toddy.Iced.Anchor,
          Toddy.Iced.Border,
          Toddy.Iced.Color,
          Toddy.Iced.ContentFit,
          Toddy.Iced.Direction,
          Toddy.Iced.FilterMethod,
          Toddy.Iced.Font,
          Toddy.Iced.Gradient,
          Toddy.Iced.Length,
          Toddy.Iced.Padding,
          Toddy.Iced.Position,
          Toddy.Iced.Shadow,
          Toddy.Iced.Shaping,
          Toddy.Iced.StyleMap,
          Toddy.Iced.Theme,
          Toddy.Iced.Wrapping,
          Toddy.Iced.A11y
        ],
        Events: ~r/Toddy\.Event.*/,
        Commands: [
          Toddy.Command,
          Toddy.Subscription,
          Toddy.Effects
        ],
        "State Helpers": [
          Toddy.Animation,
          Toddy.Data,
          Toddy.KeyModifiers,
          Toddy.Route,
          Toddy.Selection,
          Toddy.State,
          Toddy.Undo
        ],
        Testing: ~r/Toddy\.Test.*/,
        Extensions: [
          Toddy.Extension,
          Toddy.Canvas.Shape
        ],
        Protocol: ~r/Toddy\.Protocol.*/
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/toddy/toddy-elixir"
      },
      files: ~w(
        lib
        mix.exs
        README.md
        LICENSE
        .formatter.exs
      ),
      exclude_patterns: [~r/toddy\.preflight\.ex$/]
    ]
  end

  defp aliases do
    [
      preflight: "toddy.preflight"
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
      # to avoid circular path deps (each extension depends on :toddy).
    ]
  end
end
