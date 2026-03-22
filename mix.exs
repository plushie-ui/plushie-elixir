defmodule Plushie.MixProject do
  use Mix.Project

  @version "0.4.0"
  @source_url "https://github.com/plushie-ui/plushie-elixir"
  @binary_version "0.4.0"

  def project do
    [
      app: :plushie,
      version: @version,
      binary_version: @binary_version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers() ++ [:plushie_binary],
      test_paths: ["test", "examples/tests"],
      elixirc_options: [warnings_as_errors: true],
      consolidate_protocols: Mix.env() != :test,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Plushie",
      description: "Native desktop GUI framework for Elixir, powered by Iced",
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
          Plushie,
          Plushie.App,
          Plushie.Runtime,
          Plushie.Bridge,
          Plushie.Binary,
          Plushie.DevServer
        ],
        "UI Builder": [
          Plushie.UI,
          Plushie.Widget,
          Plushie.Encode,
          Plushie.Tree
        ],
        Widgets: ~r/Plushie\.Widget\..*/,
        "Widget Types": [
          Plushie.Type.Alignment,
          Plushie.Type.Anchor,
          Plushie.Type.Border,
          Plushie.Type.Color,
          Plushie.Type.ContentFit,
          Plushie.Type.Direction,
          Plushie.Type.FilterMethod,
          Plushie.Type.Font,
          Plushie.Type.Gradient,
          Plushie.Type.Length,
          Plushie.Type.Padding,
          Plushie.Type.Position,
          Plushie.Type.Shadow,
          Plushie.Type.Shaping,
          Plushie.Type.StyleMap,
          Plushie.Type.Theme,
          Plushie.Type.Wrapping,
          Plushie.Type.A11y
        ],
        Events: ~r/Plushie\.Event.*/,
        Commands: [
          Plushie.Command,
          Plushie.Subscription,
          Plushie.Effects
        ],
        "State Helpers": [
          Plushie.Animation,
          Plushie.Data,
          Plushie.KeyModifiers,
          Plushie.Route,
          Plushie.Selection,
          Plushie.State,
          Plushie.Undo
        ],
        Testing: ~r/Plushie\.Test.*/,
        Canvas: [
          Plushie.Canvas.Shape,
          ~r/Plushie\.Canvas\.Shape\..*/
        ],
        DSL: [
          Plushie.DSL.Buildable
        ],
        Extensions: [
          Plushie.Extension
        ],
        Protocol: ~r/Plushie\.Protocol.*/
      ],
      filter_modules: fn mod, _meta ->
        # Exclude example app modules from docs
        mod_str = Atom.to_string(mod)

        not String.starts_with?(mod_str, "Elixir.Counter") and
          not String.starts_with?(mod_str, "Elixir.Clock") and
          not String.starts_with?(mod_str, "Elixir.Todo") and
          not String.starts_with?(mod_str, "Elixir.Notes") and
          not String.starts_with?(mod_str, "Elixir.Shortcuts") and
          not String.starts_with?(mod_str, "Elixir.AsyncFetch") and
          not String.starts_with?(mod_str, "Elixir.ColorPicker") and
          not String.starts_with?(mod_str, "Elixir.Catalog") and
          not String.starts_with?(mod_str, "Elixir.RatePlushie") and
          not String.starts_with?(mod_str, "Elixir.StarRating") and
          not String.starts_with?(mod_str, "Elixir.ThemeToggle") and
          not String.starts_with?(mod_str, "Elixir.TabApp") and
          not String.starts_with?(mod_str, "Elixir.ModalApp")
      end
    ]
  end

  defp package do
    [
      maintainers: ["Daniel Hedlund"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Rust binary" => "https://github.com/plushie-ui/plushie",
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
