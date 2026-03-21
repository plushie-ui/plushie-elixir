defmodule Toddy.MixProject do
  use Mix.Project

  @version "0.3.0"
  @source_url "https://github.com/toddy-ui/toddy-elixir"
  @binary_version "0.3.2"

  def project do
    [
      app: :toddy,
      version: @version,
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
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
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
      source_url: @source_url,
      source_ref: "v#{@version}",
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
        "docs/running.md",
        "docs/composition-patterns.md",
        "docs/accessibility.md",
        "docs/extensions.md",
        "docs/dsl-internals.md",
        "examples/README.md",
        "CHANGELOG.md"
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
          "docs/running.md",
          "docs/composition-patterns.md",
          "docs/accessibility.md",
          "docs/extensions.md",
          "docs/dsl-internals.md"
        ],
        About: [
          "examples/README.md",
          "CHANGELOG.md"
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
          Toddy.Widget,
          Toddy.Encode,
          Toddy.Tree
        ],
        Widgets: ~r/Toddy\.Widget\..*/,
        "Widget Types": [
          Toddy.Type.Alignment,
          Toddy.Type.Anchor,
          Toddy.Type.Border,
          Toddy.Type.Color,
          Toddy.Type.ContentFit,
          Toddy.Type.Direction,
          Toddy.Type.FilterMethod,
          Toddy.Type.Font,
          Toddy.Type.Gradient,
          Toddy.Type.Length,
          Toddy.Type.Padding,
          Toddy.Type.Position,
          Toddy.Type.Shadow,
          Toddy.Type.Shaping,
          Toddy.Type.StyleMap,
          Toddy.Type.Theme,
          Toddy.Type.Wrapping,
          Toddy.Type.A11y
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
      maintainers: ["Daniel Hedlund"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Rust binary" => "https://github.com/toddy-ui/toddy",
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: ~w(
        lib
        docs
        examples
        mix.exs
        README.md
        CHANGELOG.md
        LICENSE
        .formatter.exs
      ),
      exclude_patterns: [~r/preflight\.ex$/]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "examples", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "examples"]
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
