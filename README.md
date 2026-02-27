# julep

Native desktop GUIs from Elixir, powered by [iced](https://github.com/iced-rs/iced).

Julep is an Elixir library for building native cross-platform desktop applications.
You write your app logic, state management, and UI trees entirely in Elixir. A thin
Rust binary handles rendering via the iced GUI toolkit and sends user events back
over a simple JSONL-over-stdio transport.

## Goals

- **Elixir-first.** App teams write Elixir, not Rust. The Rust renderer is a
  dependency, not a framework.
- **Simple.** Elm architecture: model, update, view. No ceremony.
- **Pragmatic.** Start a GUI from `mix julep.gui`, from IEx, or embed it as a
  library in a larger OTP application.
- **Powerful.** Full access to iced's widget catalog, theming, multi-window,
  and native platform features -- without writing Rust.

## Status

All five roadmap phases complete. Approaching first Hex release.

## Quick taste

```elixir
defmodule MyApp do
  @behaviour Julep.App

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
3. `mix test`
4. `mix dialyzer`
5. `cargo build` (renderer)
6. `cargo test` (renderer)
7. `cargo fmt --check` (renderer)
8. `cargo clippy -D warnings` (renderer)

## Testing

The Elm architecture makes julep apps unusually testable. `update/2` is a
pure function. `view/1` returns plain data. No mocks needed for the core
loop. But pure-function unit tests can't catch everything -- a misspelled
prop name, an iced version bump that shifts widget rendering, a platform
effect that silently changed behaviour. You need tests that cross the
Elixir-Rust boundary too.

Julep ships a test framework with progressive fidelity: millisecond tests
for logic, headless Rust rendering for protocol verification, and real GPU
windows for full-stack confidence. Same test code, same assertions -- you
choose the depth.

```elixir
defmodule MyAppTest do
  use Julep.Test.Case, app: MyApp

  test "clicking increment updates counter" do
    click("#increment")
    assert find!("#count") |> text() == "1"
  end
end
```

No setup, no Rust binary, no display server. Tests run in milliseconds by
default. When you need deeper verification, swap backends with a single tag
and the same test exercises the real renderer or captures GPU pixels.

See the [Testing guide](docs/testing.md) for the full API, backend
comparison, pixel regression workflow, and CI configuration.

## Documentation

Core:

- [Charter](docs/charter.md) -- what and why
- [Architecture](docs/architecture.md) -- the three pieces
- [App behaviour](docs/app-behaviour.md) -- the Elixir API contract
- [Iced parity guide](docs/iced-parity.md) -- Rust-to-Elixir mapping for iced users
- [UI trees](docs/ui-trees.md) -- node format and widget catalog
- [Layout](docs/layout.md) -- length, padding, alignment, spacing
- [Events](docs/events.md) -- full event taxonomy
- [Commands and subscriptions](docs/commands.md) -- async work, timers, widget ops
- [Transport](docs/transport.md) -- JSONL protocol between Elixir and Rust
- [Renderer](docs/renderer.md) -- what the Rust binary does
- [Multi-window](docs/multi-window.md) -- declarative multi-window model
- [Effects](docs/effects.md) -- native platform features
- [Theming](docs/theming.md) -- themes, custom palettes, styling
- [Stateful widgets](docs/stateful-widgets.md) -- text_editor, combo_box, pane_grid
- [State helpers](docs/state-helpers.md) -- optional state management modules
- [Testing](docs/testing.md) -- three-backend test framework and pixel regression
- [Accessibility](docs/accessibility.md) -- planned approach and roadmap
- [Developer experience](docs/developer-experience.md) -- mix tasks, IEx, project structure
- [Roadmap](docs/roadmap.md) -- phased build plan
- [Iced parity audit](docs/audit-iced-parity.md) -- detailed coverage matrix against iced 0.14

Decisions:

- [0001: Clean break from icing](docs/decisions/0001-clean-break-from-icing.md)
- [0002: Elixir-first process model](docs/decisions/0002-elixir-first-process-model.md)
- [0003: JSONL over stdio transport](docs/decisions/0003-jsonl-over-stdio-transport.md)
- [0004: Interactive canvas via Program trait](docs/decisions/0004-interactive-canvas.md)
- [0005: PaneGrid as a stateful widget](docs/decisions/0005-pane-grid-stateful-widget.md)
- [0006: Responsive layout via sensor](docs/decisions/0006-responsive-via-sensor.md)
- [0007: Two-tier custom widget strategy](docs/decisions/0007-custom-widget-extension.md)
- [0008: Test framework architecture](docs/decisions/0008-test-framework-architecture.md)

## License

MIT
