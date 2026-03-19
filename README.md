# julep

Native desktop GUIs from Elixir, powered by [iced](https://github.com/iced-rs/iced).

Julep is an Elixir library for building native cross-platform desktop applications.
You write your app logic, state management, and UI trees entirely in Elixir. A thin
Rust binary handles rendering via the iced GUI toolkit and sends user events back
over a MessagePack-over-stdio transport (JSONL available for debugging).

## Goals

- **Elixir-first.** App teams write Elixir, not Rust. The Rust renderer is a
  dependency, not a framework.
- **Simple.** Elm architecture: model, update, view. No ceremony.
- **Pragmatic.** Start a GUI from `mix julep.gui`, from IEx, or embed it as a
  library in a larger OTP application.
- **Powerful.** Full access to iced's widget catalog, theming, multi-window,
  and native platform features -- without writing Rust.
- **Accessible.** Optional accesskit integration for screen reader support
  on macOS, Linux, and Windows. See [docs/accessibility.md](docs/accessibility.md).

## Status

All five roadmap phases complete. Approaching first Hex release.

## Quick taste

```elixir
defmodule MyApp do
  use Julep.App

  def init(_opts), do: %{count: 0}

  def update(model, {:click, "increment"}), do: %{model | count: model.count + 1}
  def update(model, {:click, "decrement"}), do: %{model | count: model.count - 1}
  def update(model, _event), do: model

  def view(model) do
    import Julep.UI

    window "main", title: "Counter" do
      column do
        text("Count: #{model.count}")
        row do
          button("increment", "+" )
          button("decrement", "-")
        end
      end
    end
  end
end
```

```bash
mix julep.gui MyApp
```

### Dev mode

```bash
mix julep.dev MyApp
```

Edit your source files and watch the GUI update in place. See [dev mode docs](docs/dev-mode.md).

## System Requirements

Building the Rust renderer requires a working Rust toolchain (`cargo`). Install
via [rustup](https://rustup.rs/). Platform-specific dependencies:

**Linux**

```bash
# Debian/Ubuntu
sudo apt-get install libxkbcommon-dev libwayland-dev libx11-dev cmake fontconfig pkg-config

# Arch Linux
sudo pacman -S libxkbcommon wayland libx11 cmake fontconfig pkgconf
```

**macOS**

```bash
xcode-select --install
```

**Windows**

Install [Visual Studio Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
with the "Desktop development with C++" workload.

## Getting started

```bash
mix deps.get                          # fetch Elixir deps
mix julep.build                       # build the Rust renderer (requires cargo)
mix julep.gui Counter                 # run an example app
mix julep.gui Catalog                 # run the full widget catalog
```

## Development

```bash
mix preflight                         # run all CI checks locally
```

This is the single command to verify everything before pushing. It runs
the full CI pipeline locally and stops on first failure:

1. `mix format --check-formatted`
2. `mix compile --warnings-as-errors`
3. `mix credo --strict`
4. `mix test`
5. `mix dialyzer`
6. `cargo build` (renderer)
7. `cargo test` (renderer)
8. `cargo fmt --check` (renderer)
9. `cargo clippy -D warnings` (renderer)

## Testing

Write your tests once, then run them at whatever fidelity you need. Julep
ships a test framework with three interchangeable backends:

- **Simulated** -- millisecond tests with zero setup. No Rust binary, no
  display server. Click buttons, type text, assert on results.
- **Headless** -- real Rust rendering powered by iced's
  [iced_test](https://docs.rs/iced_test) and
  [tiny-skia](https://github.com/linebender/tiny-skia), no display server
  needed. Catches protocol bugs and structural regressions across upgrades.
- **Full** -- real iced windows with GPU rendering. Pixel-accurate
  screenshot regression, platform effects, the works.

All three use the same API. Swap between them with a single line change --
or let CI run all three.

```elixir
defmodule TodoTest do
  use Julep.Test.Case, app: MyApp.Todo

  test "complete todo flow" do
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

Write test scenarios in Elixir with the full power of ExUnit, or use
declarative `.julep` scripts -- a superset of iced's
[`.ice` format](https://docs.rs/iced_test/latest/iced_test/ice/) --
for acceptance tests and visual demos. Capture golden-file screenshots for
pixel regression, or just test your logic fast and move on.

See the [Testing guide](docs/testing.md) for the full API, backend details,
and CI configuration.

## Documentation

- [Getting started](docs/getting-started.md) -- setup, first app, mix tasks, debugging
- [Architecture](docs/architecture.md) -- the three pieces
- [App behaviour](docs/app-behaviour.md) -- the Elixir API contract
- [UI trees](docs/ui-trees.md) -- node format and widget catalog
- [Layout](docs/layout.md) -- length, padding, alignment, spacing
- [Events](docs/events.md) -- full event taxonomy
- [Commands and subscriptions](docs/commands.md) -- async work, timers, widget ops
- [Effects](docs/effects.md) -- native platform features
- [Theming](docs/theming.md) -- themes, custom palettes, styling
- [Multi-window](docs/multi-window.md) -- declarative multi-window model
- [Stateful widgets](docs/stateful-widgets.md) -- text_editor, combo_box, pane_grid
- [State helpers](docs/state-helpers.md) -- optional state management modules
- [Composition patterns](docs/composition-patterns.md) -- tabs, sidebars, modals, cards
- [Testing](docs/testing.md) -- three-backend test framework and pixel regression
- [Accessibility](docs/accessibility.md) -- accesskit integration, a11y props
- [Iced parity guide](docs/iced-parity.md) -- Rust-to-Elixir mapping for iced users
- [Renderer](docs/renderer.md) -- what the Rust binary does
- [Transport](docs/transport.md) -- MessagePack wire protocol
- [Dev mode](docs/dev-mode.md) -- live code reloading
- [Extensions](docs/extensions.md) -- writing native widget extensions
- [Widget authoring](docs/widget-authoring.md) -- adding widgets to the typed layer
- [Widget packages](docs/widget-packages.md) -- publishing reusable packages
- [Testing internals](docs/testing-internals.md) -- contributing to the test framework

## License

MIT
