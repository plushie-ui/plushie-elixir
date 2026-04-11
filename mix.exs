defmodule Plushie.MixProject do
  use Mix.Project

  @version "0.6.0"
  @source_url "https://github.com/plushie-ui/plushie-elixir"

  def project do
    [
      app: :plushie,
      version: @version,
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
      main: "01-introduction",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        {"docs/README.md", [title: "Documentation", filename: "documentation"]},
        # Guides (ordered, read sequentially)
        "docs/guides/01-introduction.md",
        "docs/guides/02-getting-started.md",
        "docs/guides/03-your-first-app.md",
        "docs/guides/04-the-development-loop.md",
        "docs/guides/05-events.md",
        "docs/guides/06-lists-and-inputs.md",
        "docs/guides/07-layout.md",
        "docs/guides/08-styling.md",
        "docs/guides/09-animation.md",
        "docs/guides/10-subscriptions.md",
        "docs/guides/11-async-and-effects.md",
        "docs/guides/12-canvas.md",
        "docs/guides/13-custom-widgets.md",
        "docs/guides/14-state-management.md",
        "docs/guides/15-testing.md",
        "docs/guides/16-shared-state.md",
        "docs/guides/17-wasm-deployment.md",
        # Reference (alphabetical, lookup by topic)
        "docs/reference/accessibility.md",
        "docs/reference/animation.md",
        "docs/reference/app-lifecycle.md",
        "docs/reference/built-in-widgets.md",
        "docs/reference/canvas.md",
        "docs/reference/commands.md",
        "docs/reference/configuration.md",
        "docs/reference/custom-canvas-elements.md",
        "docs/reference/custom-types.md",
        "docs/reference/custom-widgets.md",
        "docs/reference/dsl.md",
        "docs/reference/events.md",
        "docs/reference/windows-and-layout.md",
        "docs/reference/mix-tasks.md",
        "docs/reference/composition-patterns.md",
        "docs/reference/scoped-ids.md",
        "docs/reference/themes-and-styling.md",
        "docs/reference/subscriptions.md",
        "docs/reference/testing.md",
        "docs/reference/wire-protocol.md",
        # About
        "examples/README.md",
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        Guides: ~r/docs\/guides\/.*/,
        Reference: ~r/docs\/reference\/.*/,
        About: ["examples/README.md", "CHANGELOG.md"]
      ],
      groups_for_modules: [
        "App Framework": [
          Plushie,
          Plushie.App,
          Plushie.Runtime,
          Plushie.Bridge,
          Plushie.Binary,
          Plushie.Dev.DevServer,
          Plushie.Dev.RebuildingOverlay
        ],
        "UI Builder": [
          Plushie.UI,
          Plushie.Widget,
          Plushie.Tree
        ],
        Widgets: ~r/Plushie\.Widget\..*/,
        Types: [
          Plushie.Type,
          ~r/Plushie\.Type\..*/
        ],
        Events: ~r/Plushie\.Event.*/,
        Commands: [
          Plushie.Command,
          Plushie.Subscription,
          Plushie.Effect
        ],
        Animation: [
          Plushie.Animation,
          ~r/Plushie\.Animation\..*/
        ],
        "State Helpers": [
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
        DSL: [],
        Widgets: [
          Plushie.Widget,
          Plushie.Widget.WidgetProtocol
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
          not String.starts_with?(mod_str, "Elixir.ModalApp") and
          not String.starts_with?(mod_str, "Elixir.Gallery")
      end
    ]
  end

  defp package do
    [
      maintainers: ["Daniel Hedlund"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Rust binary" => "https://github.com/plushie-ui/plushie-renderer",
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: ~w(
        lib
        docs
        examples
        mix.exs
        BINARY_VERSION
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
      {:stream_data, "~> 1.0", only: [:test, :dev]},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end
end
