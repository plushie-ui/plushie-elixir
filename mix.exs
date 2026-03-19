defmodule Toddy.MixProject do
  use Mix.Project

  @binary_version "0.3.0"

  def project do
    [
      app: :toddy,
      version: "0.1.0",
      binary_version: @binary_version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers() ++ [:toddy_binary],
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
      extra_applications: [:logger, :inets, :ssl]
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
        "GitHub" => "https://github.com/toddy/toddy-elixir",
        "Rust binary" => "https://github.com/toddy-ui/toddy",
        "Changelog" => "https://github.com/toddy/toddy-elixir/blob/main/CHANGELOG.md"
      },
      files: ~w(
        lib
        mix.exs
        README.md
        LICENSE
        .formatter.exs
      ),
      exclude_patterns: [~r/preflight\.ex$/]
    ]
  end

  defp aliases do
    []
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
    ]
  end
end
