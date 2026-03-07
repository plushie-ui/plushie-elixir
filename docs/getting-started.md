# Getting Started with Julep

Build native desktop GUIs from Elixir. Julep handles rendering via iced (Rust)
while you own state, logic, and UI trees in pure Elixir.

## Prerequisites

- **Elixir** 1.15+ and **Erlang/OTP** 26+
- **Rust** 1.75+ (install via [rustup.rs](https://rustup.rs))
- **System libraries** for your platform:
  - Linux: a C compiler, `pkg-config`, and display server headers
    (e.g. `libxkbcommon-dev`, `libwayland-dev` on Debian/Ubuntu)
  - macOS: Xcode command-line tools (`xcode-select --install`)
  - Windows: Visual Studio C++ build tools

Verify your toolchain:

```sh
elixir --version   # Elixir 1.15+, Erlang/OTP 26+
rustc --version    # 1.75.0+
```

## Setup

### 1. Create a new Mix project

```sh
mix new my_app
cd my_app
```

### 2. Add Julep as a dependency

In `mix.exs`:

```elixir
defp deps do
  [
    {:julep, "~> 0.1"}
  ]
end
```

### 3. Fetch dependencies and build the renderer

```sh
mix deps.get
mix julep.build --release
```

The build step compiles the Rust renderer binary. This takes a few minutes
the first time; subsequent builds are fast thanks to Cargo's incremental
compilation.

## Your first app: a counter

Create `lib/my_app/counter.ex`:

```elixir
defmodule MyApp.Counter do
  use Julep.App

  # Initial state
  def init(_opts), do: %{count: 0}

  # Handle events
  def update(model, {:click, "increment"}), do: %{model | count: model.count + 1}
  def update(model, {:click, "decrement"}), do: %{model | count: model.count - 1}
  def update(model, _event), do: model

  # Describe the UI
  def view(model) do
    import Julep.UI

    window "main", title: "Counter" do
      column padding: 16, spacing: 8 do
        text("Count: #{model.count}")

        row spacing: 8 do
          button("increment", "+")
          button("decrement", "-")
        end
      end
    end
  end
end
```

Run it:

```sh
mix julep.gui MyApp.Counter
```

A native window appears with the count and two buttons. Click them and
the count updates.

## How it works: the Elm architecture

Julep follows the Elm architecture. Your app module implements four callbacks
via the `Julep.App` behaviour:

### `init/1` -- initial state

Returns the starting model (any Elixir term). Called once when the app boots.

```elixir
def init(_opts), do: %{count: 0}
```

### `update/2` -- handle events

Takes the current model and an event, returns the new model. Pure function,
no side effects. Pattern match on events to decide what changes.

```elixir
def update(model, {:click, "increment"}), do: %{model | count: model.count + 1}
def update(model, _event), do: model
```

To run side effects (async work, file dialogs, clipboard), return a
`{model, command}` tuple instead. See `docs/commands.md`.

### `view/1` -- describe the UI

Takes the model and returns a UI tree. Julep diffs consecutive trees and
sends only patches to the renderer. The tree is plain Elixir data -- maps
with `:id`, `:type`, `:props`, and `:children` keys.

### `subscribe/1` -- reactive subscriptions (optional)

Returns a list of subscriptions for timer or keyboard events.

```elixir
def subscribe(_model) do
  [Julep.Subscription.every(1000, :tick)]
end
```

## Event types

Events are tuples. The first element is the event kind, followed by the
widget ID and any payload:

| Event | Meaning |
|---|---|
| `{:click, id}` | Button click |
| `{:input, id, value}` | Text input change |
| `{:submit, id, value}` | Text input submitted (Enter) |
| `{:toggle, id, checked}` | Checkbox or toggler toggled |
| `{:slide, id, value}` | Slider moved |
| `{:select, id, value}` | Pick list, combo box, or radio selected |
| `{:tick, timestamp}` | Timer subscription fired |
| `{:key_press, key_event}` | Keyboard subscription fired |

See `docs/events.md` for the full taxonomy.

## State helpers

Julep includes pure-data modules for common UI state patterns:
`Julep.State` (change tracking), `Julep.Undo` (undo/redo),
`Julep.Selection` (single/multi select), `Julep.Route` (navigation),
and `Julep.Data` (in-memory queries). Plain structs, no processes.

## Debugging

Use JSONL wire format to inspect messages between Elixir and the renderer:

```sh
mix julep.gui --json MyApp.Counter
```

Enable verbose renderer logging:

```sh
RUST_LOG=julep_gui=debug mix julep.gui MyApp.Counter
```

## Next steps

- Browse the [examples](../lib/julep/examples/) for patterns beyond the counter
- Read [app-behaviour.md](app-behaviour.md) for the full callback API
- Read [ui-trees.md](ui-trees.md) for every widget and its props
- Read [commands.md](commands.md) for async work, file dialogs, and effects
- Read [events.md](events.md) for the complete event taxonomy
- Read [theming.md](theming.md) for custom themes and palettes
- Read [testing.md](testing.md) for writing tests against your UI
- Read [architecture.md](architecture.md) for the full system design
