# plushie

Build native desktop apps in Elixir. **[Pre-1.0](#status)**

Plushie is a native desktop GUI platform with SDKs for Elixir, Gleam,
Python, Ruby, and TypeScript. This is the Elixir SDK.

Write your entire application in Elixir -- state, events, UI -- and get
native windows on Linux, macOS, and Windows. Rendering is powered by
[Iced](https://github.com/iced-rs/iced), a cross-platform GUI toolkit
for Rust, which Plushie drives as a precompiled binary behind the scenes.

<!-- test: readme_counter_init_test, readme_counter_increment_test, readme_counter_decrement_test, readme_counter_unknown_event_test, readme_counter_view_structure_test, readme_counter_view_after_increment_test -- keep this code block in sync with the test -->
```elixir
defmodule Counter do
  use Plushie.App
  alias Plushie.Event.WidgetEvent
  import Plushie.UI

  def init(_opts), do: %{count: 0}

  def update(model, %WidgetEvent{type: :click, id: "inc"}),
    do: %{model | count: model.count + 1}

  def update(model, %WidgetEvent{type: :click, id: "dec"}),
    do: %{model | count: model.count - 1}

  def update(model, _event), do: model

  def view(model) do
    window "main", title: "Counter" do
      column padding: 16, spacing: 8 do
        text("count", "Count: #{model.count}")
        row spacing: 8 do
          button("inc", "+")
          button("dec", "-")
        end
      end
    end
  end
end
```

```bash
mix plushie.gui Counter
```

Or from IEx:

```elixir
iex> Plushie.start_link(Counter)
```

This is one of [8 examples](examples/) included in the repo, from a
minimal counter to a full widget catalog. Edit them while the GUI is
running and see changes instantly. For multi-file projects (custom widgets,
collaborative transports, real project scaffolding), see the
[plushie-demos](https://github.com/plushie-ui/plushie-demos/tree/main/elixir)
repo.

## Getting started

Add plushie to your dependencies:

```elixir
# mix.exs
{:plushie, "== 0.5.0"}
```

Then:

```bash
mix deps.get
mix plushie.download                    # download precompiled binary
mix plushie.gui Counter                 # run the counter example
```

Pin to an exact version (`==`, not `~>`) and read the
[CHANGELOG](CHANGELOG.md) carefully when upgrading.

The precompiled binary requires no Rust toolchain. To build from
source instead, install [rustup](https://rustup.rs/) and run
`mix plushie.build`. See the
[getting started guide](docs/guides/02-getting-started.md) for the
full walkthrough.

## Features

- **Built-in widgets** -- buttons, text inputs, sliders, tables,
  markdown, canvas, and more. Easy to build your own.
  [Layout guide](docs/guides/07-layout.md)
- **Themes** -- dark, light, nord, catppuccin, tokyo night, and
  more. Custom palettes and per-widget style overrides.
  [Styling guide](docs/guides/08-styling.md)
- **Multi-window** -- declare window nodes in your widget tree;
  the framework opens, closes, and manages them automatically.
  [Async and Effects guide](docs/guides/10-async-and-effects.md)
- **Platform effects** -- native file dialogs, clipboard, OS
  notifications. [Async and Effects guide](docs/guides/10-async-and-effects.md)
- **Accessibility** -- keyboard navigation, screen reader support
  via [AccessKit](https://accesskit.dev) on all platforms.
  [Accessibility reference](docs/reference/accessibility.md)
- **Hot reload** -- edit code, see changes instantly when enabled
  via `config :plushie, code_reloader: true` or `--watch`.
- **Custom Widgets** -- multiple paths to custom widgets:
  - **Compose** existing widgets into higher-level components with
    pure Elixir. No Rust, no binary rebuild.
  - **Draw** on the canvas with shape primitives for charts, gauges,
    diagrams, and other custom 2D rendering.
  - **Native** -- implement `WidgetExtension` in Rust for full
    control over rendering, state, and event handling.
  - [Custom Widgets guide](docs/guides/12-custom-widgets.md)
- **Remote rendering** -- native desktop UI for apps running on
  servers or embedded devices. Dashboards, admin tools, IoT
  diagnostics -- over SSH with configurable event throttling.
  [Tooling and Deployment guide](docs/guides/15-tooling-and-deployment.md)
- **Scriptable automation** -- drive real running apps with `.plushie`
  scripts for demos, smoke flows, and screenshots.
  [Testing guide](docs/guides/14-testing.md)

## Testing

Plushie ships a test framework with three interchangeable backends.
Write your tests once, run them at whatever fidelity you need:

- **Mocked** -- millisecond tests, no display server. Uses a shared
  mock process for fast logic and interaction testing.
- **Headless** -- real rendering via
  [tiny-skia](https://github.com/linebender/tiny-skia), no display
  server needed. Supports screenshots for pixel regression in CI.
- **Windowed** -- real windows with GPU rendering. Platform effects,
  real input, the works.

```elixir
defmodule TodoTest do
  use Plushie.Test.Case, app: Todo

  test "add and complete a todo" do
    type_text("#new_todo", "Buy milk")
    submit("#new_todo")

    assert_text "#todo_count", "1 item"
    assert_exists "#todo:1"

    toggle("#todo:1")
    click("#filter_completed")

    assert_text "#todo_count", "0 items"
    assert_not_exists "#todo:1"
  end
end
```

See the [testing guide](docs/guides/14-testing.md) for the full API,
backend details, and CI configuration.

## How it works

Under the hood, a renderer built on
[Iced](https://github.com/iced-rs/iced) handles window drawing and
platform integration. Your Elixir code sends widget trees to the
renderer over stdin; the renderer draws native windows and sends
user events back over stdout.

You don't need Rust to use plushie. The renderer is a precompiled
binary, similar to how your app talks to a database without you
writing C. If you ever need custom native rendering, the
[widget system](docs/guides/12-custom-widgets.md) lets you write
Rust for just those parts.

The same protocol works over a local pipe, an SSH connection, or
any bidirectional byte stream -- your code doesn't need to change.
See the [dev workflow guide](docs/guides/15-tooling-and-deployment.md) for
deployment options.

## Status

Pre-1.0. The core works -- built-in widgets, event system, themes,
multi-window, testing framework, accessibility -- but the API is
still evolving:

- Pin to an exact version and read the
  [CHANGELOG](CHANGELOG.md) when upgrading.
- Mix releases are not yet supported.
- The widget macro DSL (`Plushie.Widget`) is the least stable
  part of the API.

## Documentation

Guides and references are in [`docs/`](docs/) and will be on
[hexdocs](https://hexdocs.pm/plushie) once published:

**Guides** -- sequential chapters building a live widget editor:

- [Introduction](docs/guides/01-introduction.md)
- [Getting Started](docs/guides/02-getting-started.md)
- [Your First App](docs/guides/03-your-first-app.md)
- [The Development Loop](docs/guides/04-the-development-loop.md)
- [Events](docs/guides/05-events.md)
- [Lists and Inputs](docs/guides/06-lists-and-inputs.md)
- [Layout](docs/guides/07-layout.md)
- [Styling](docs/guides/08-styling.md)
- [Subscriptions](docs/guides/09-subscriptions.md)
- [Async and Effects](docs/guides/10-async-and-effects.md)
- [Canvas](docs/guides/11-canvas.md)
- [Custom Widgets](docs/guides/12-custom-widgets.md)
- [State Management](docs/guides/13-state-management.md)
- [Testing](docs/guides/14-testing.md)
- [Tooling and Deployment](docs/guides/15-tooling-and-deployment.md)

**References** -- lookup material by topic:

- [App Lifecycle](docs/reference/app-lifecycle.md),
  [Events](docs/reference/events.md),
  [Commands](docs/reference/commands.md),
  [Subscriptions](docs/reference/subscriptions.md),
  [Built-in Widgets](docs/reference/built-in-widgets.md),
  [Patterns](docs/reference/patterns.md),
  [Canvas](docs/reference/canvas.md),
  [Types](docs/reference/types.md),
  [Custom Widgets](docs/reference/custom-widgets.md),
  [Accessibility](docs/reference/accessibility.md),
  [Testing](docs/reference/testing.md),
  [Scoped IDs](docs/reference/scoped-ids.md),
  [DSL](docs/reference/dsl.md),
  [Mix Tasks](docs/reference/mix-tasks.md),
  [Configuration](docs/reference/configuration.md),
  [Wire Protocol](docs/reference/wire-protocol.md)

## Development

```bash
mix preflight                         # run all CI checks locally
```

Mirrors CI and stops on first failure: format, compile (warnings as
errors), credo, test, dialyzer.

## System requirements

The precompiled binary (`mix plushie.download`) has no additional
dependencies. To build from source, install a Rust toolchain via
[rustup](https://rustup.rs/) and the platform-specific libraries:

- **Linux (Debian/Ubuntu):**
  `sudo apt-get install libxkbcommon-dev libwayland-dev libx11-dev cmake fontconfig pkg-config`
- **Linux (Arch):**
  `sudo pacman -S libxkbcommon wayland libx11 cmake fontconfig pkgconf`
- **macOS:** `xcode-select --install`
- **Windows:**
  [Visual Studio Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
  with "Desktop development with C++"

## Links

| | |
|---|---|
| Elixir SDK | [github.com/plushie-ui/plushie-elixir](https://github.com/plushie-ui/plushie-elixir) |
| Demos | [github.com/plushie-ui/plushie-demos](https://github.com/plushie-ui/plushie-demos/tree/main/elixir) |
| Renderer | [github.com/plushie-ui/plushie](https://github.com/plushie-ui/plushie) |
| Rust crate | [crates.io/crates/plushie](https://crates.io/crates/plushie) |

## License

MIT
