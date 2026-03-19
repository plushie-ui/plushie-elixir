# toddy

Build native desktop apps in Elixir. **[Pre-1.0](#status)**

Toddy is a desktop GUI framework that allows you to write your entire
application in Elixir -- state, events, UI -- and get native windows
on Linux, macOS, and Windows. Rendering is powered by
[iced](https://github.com/iced-rs/iced), a cross-platform GUI library
for Rust, which toddy drives as a precompiled binary behind the scenes.

```elixir
defmodule Counter do
  use Toddy.App
  alias Toddy.Event.Widget
  import Toddy.UI

  def init(_opts), do: %{count: 0}

  def update(model, %Widget{type: :click, id: "inc"}),
    do: %{model | count: model.count + 1}

  def update(model, %Widget{type: :click, id: "dec"}),
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
mix toddy.gui Counter
```

Or from IEx:

```elixir
iex> Toddy.start_link(Counter)
```

## Getting started

Add toddy to your dependencies:

```elixir
# mix.exs
{:toddy, "== 0.3.0"}
```

Then:

```bash
mix deps.get
mix toddy.download                    # download precompiled binary
mix toddy.gui Counter                 # run the counter example
```

Pin to an exact version (`==`, not `~>`) and read the
[CHANGELOG](CHANGELOG.md) carefully when upgrading.

The precompiled binary requires no Rust toolchain. To build from
source instead, install [rustup](https://rustup.rs/) and run
`mix toddy.build`. See the
[getting started guide](docs/getting-started.md) for the full
walkthrough.

## Features

- **37 built-in widget types** -- buttons, text inputs, sliders,
  tables, markdown, canvas, and more. Easy to build your own.
  [Layout guide](docs/layout.md)
- **22 built-in themes** -- light, dark, dracula, nord, solarized,
  gruvbox, catppuccin, tokyo night, kanagawa, and more. Custom
  palettes and per-widget style overrides.
  [Theming guide](docs/theming.md)
- **Multi-window** -- declare window nodes in your widget tree;
  the framework opens, closes, and manages them automatically.
  [App behaviour guide](docs/app-behaviour.md)
- **Platform effects** -- native file dialogs, clipboard, OS
  notifications. [Effects guide](docs/effects.md)
- **Accessibility** -- screen reader support via
  [accesskit](https://accesskit.dev) on all platforms.
  [Accessibility guide](docs/accessibility.md)
- **Live reload** -- edit code, see changes instantly. Enabled by
  default in dev mode.
- **Extensions** -- multiple paths to custom widgets:
  - **Compose** existing widgets into higher-level components with
    pure Elixir. No Rust, no binary rebuild.
  - **Draw** on the canvas with shape primitives for charts, gauges,
    diagrams, and other custom 2D rendering.
  - **Native** -- implement `WidgetExtension` in Rust for full
    control over rendering, state, and event handling.
  - [Extensions guide](docs/extensions.md)

## Testing

Toddy ships a test framework with three interchangeable backends.
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
  use Toddy.Test.Case, app: Todo

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

See the [testing guide](docs/testing.md) for the full API, backend
details, and CI configuration.

## How it works

Under the hood, a Rust binary built on
[iced](https://github.com/iced-rs/iced) handles rendering and
platform integration. Your Elixir app sends widget trees to the
binary over stdin; the binary renders native windows and sends user
events back over stdout.

You don't need Rust to use toddy. The binary is a precompiled
dependency, similar to how your app talks to a database without you
writing C. If you ever need custom native rendering, the
[extension system](docs/extensions.md) lets you write Rust for just
those parts.

## Status

Pre-1.0. The core works -- 37 widget types, event system, 22 themes,
multi-window, testing framework, accessibility -- but the API is
still evolving:

- Pin to an exact version and read the
  [CHANGELOG](CHANGELOG.md) when upgrading.
- Mix releases are not yet supported.
- The extension macro DSL (`Toddy.Extension`) is the least stable
  part of the API.

## Documentation

Guides are in [`docs/`](docs/) and will be on
[hexdocs](https://hexdocs.pm/toddy) once published:

- [Getting started](docs/getting-started.md) -- setup, first app, mix tasks, dev mode
- [Tutorial](docs/tutorial.md) -- build a todo app step by step
- [App behaviour](docs/app-behaviour.md) -- the Elixir API contract, multi-window
- [Layout](docs/layout.md) -- length, padding, alignment, spacing
- [Events](docs/events.md) -- full event taxonomy
- [Commands and subscriptions](docs/commands.md) -- async work, timers, widget ops
- [Effects](docs/effects.md) -- native platform features
- [Theming](docs/theming.md) -- themes, custom palettes, styling
- [Composition patterns](docs/composition-patterns.md) -- tabs, sidebars, modals, cards, state helpers
- [Scoped IDs](docs/scoped-ids.md) -- hierarchical ID namespacing
- [Testing](docs/testing.md) -- three-backend test framework and pixel regression
- [Accessibility](docs/accessibility.md) -- accesskit integration, a11y props
- [Extensions](docs/extensions.md) -- custom widgets, publishing packages

## Development

```bash
mix preflight                         # run all CI checks locally
```

Mirrors CI and stops on first failure: format, compile (warnings as
errors), credo, test, dialyzer.

## System requirements

The precompiled binary (`mix toddy.download`) has no additional
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
| Elixir SDK | [github.com/toddy-ui/toddy-elixir](https://github.com/toddy-ui/toddy-elixir) |
| Rust binary | [github.com/toddy-ui/toddy](https://github.com/toddy-ui/toddy) |
| Rust crate | [crates.io/crates/toddy](https://crates.io/crates/toddy) |

## License

MIT
