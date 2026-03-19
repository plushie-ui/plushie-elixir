# Getting started

Build native desktop GUIs from Elixir. Toddy handles rendering via
iced (Rust) while you own state, logic, and UI trees in pure Elixir.

## Prerequisites

- **Elixir** 1.15+ and **Erlang/OTP** 26+
- **Rust** 1.75+ (install via [rustup.rs](https://rustup.rs))
- **System libraries** for your platform:
  - Linux: a C compiler, `pkg-config`, and display server headers
    (e.g. `libxkbcommon-dev`, `libwayland-dev` on Debian/Ubuntu)
  - macOS: Xcode command-line tools (`xcode-select --install`)
  - Windows: Visual Studio C++ build tools

## Setup

### 1. Create a new Mix project

```sh
mix new my_app
cd my_app
```

### 2. Add toddy as a dependency

```elixir
# mix.exs
defp deps do
  [
    {:toddy, "~> 0.3"}
  ]
end
```

### 3. Formatter config

Add `:toddy` to `import_deps` in your `.formatter.exs` so `mix format`
keeps layout blocks paren-free:

```elixir
# .formatter.exs
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:toddy]
]
```

### 4. Fetch dependencies and build the renderer

```sh
mix deps.get
mix toddy.build
```

The build step compiles the Rust renderer binary. First build takes a
few minutes; subsequent builds are fast.

## Your first app: a counter

Create `lib/my_app/counter.ex`:

```elixir
defmodule MyApp.Counter do
  use Toddy.App

  import Toddy.UI

  alias Toddy.Event.Widget

  def init(_opts), do: %{count: 0}

  def update(model, %Widget{type: :click, id: "increment"}),
    do: %{model | count: model.count + 1}

  def update(model, %Widget{type: :click, id: "decrement"}),
    do: %{model | count: model.count - 1}

  def update(model, _event), do: model

  def view(model) do
    window "main", title: "Counter" do
      column padding: 16, spacing: 8 do
        text("count", "Count: #{model.count}", size: 20)

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
mix toddy.gui MyApp.Counter
```

A native window appears with the count and two buttons.

## The Elm architecture

Toddy follows the Elm architecture. Your app module implements
callbacks via `Toddy.App`:

- **`init/1`** -- returns the initial model (any Elixir term).
- **`update/2`** -- takes the current model and an event, returns
  the new model. Pure function. To run side effects, return
  `{model, command}` instead. See [Commands](commands.md).
- **`view/1`** -- takes the model and returns a UI tree. Toddy diffs
  trees and sends only patches to the renderer.
- **`subscribe/1`** (optional) -- returns a list of active
  subscriptions (timers, keyboard events).

See [App behaviour](app-behaviour.md) for the full callback API.

## Event types

Events are structs under `Toddy.Event.*`. Pattern match in `update/2`:

| Event | Meaning |
|---|---|
| `%Widget{type: :click, id: id}` | Button click |
| `%Widget{type: :input, id: id, value: val}` | Text input change |
| `%Widget{type: :submit, id: id, value: val}` | Text input Enter |
| `%Widget{type: :toggle, id: id, value: val}` | Checkbox/toggler |
| `%Widget{type: :slide, id: id, value: val}` | Slider moved |
| `%Widget{type: :select, id: id, value: val}` | Pick list/radio |
| `%Timer{tag: tag, timestamp: ts}` | Timer fired |

See [Events](events.md) for the full taxonomy.

## Mix tasks

```bash
mix toddy.gui MyApp              # build and run
mix toddy.gui MyApp --build      # rebuild renderer first
mix toddy.gui MyApp --release    # use release build
mix toddy.build                  # build renderer only
mix toddy.build --release        # release build
mix toddy.gui MyApp --no-watch   # run without file watching
mix toddy.inspect MyApp          # print UI tree as JSON
```

## Debugging

Use JSON wire format to see messages between Elixir and the renderer:

```sh
mix toddy.gui MyApp --json
```

Enable verbose renderer logging:

```sh
RUST_LOG=toddy=debug mix toddy.gui MyApp
```

## Error handling

If `update/2` or `view/1` raises, the runtime catches the exception,
logs it, and continues with the previous state. The GUI does not
crash. Fix the code and the next event works normally.

## Dev mode

Live code reloading without losing application state. Add
`:file_system` to your deps:

```elixir
{:file_system, "~> 1.0"}
```

In dev mode, `mix toddy.gui` watches `lib/` by default. Edit any
`.ex` file, save, and the GUI updates in place. Pass `--no-watch`
to disable.
The model is preserved -- only `view/1` is re-evaluated with the new
code. See `Toddy.DevServer` for configuration options.

## Next steps

- [Tutorial: building a todo app](tutorial.md) -- step-by-step guide
- Browse the [examples](../examples/) for patterns
- [App behaviour](app-behaviour.md) -- full callback API
- [Layout](layout.md) -- sizing and positioning widgets
- [Commands](commands.md) -- async work, file dialogs, effects
- [Events](events.md) -- complete event taxonomy
- [Testing](testing.md) -- writing tests against your UI
- [Theming](theming.md) -- custom themes and palettes
