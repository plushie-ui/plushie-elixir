# Getting started

Build native desktop GUIs from Elixir. Plushie handles rendering via
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

### 2. Add plushie as a dependency

```elixir
# mix.exs
defp deps do
  [
    {:plushie, "~> 0.4"}
  ]
end
```

### 3. Formatter config

Add `:plushie` to `import_deps` in your `.formatter.exs` so `mix format`
keeps layout blocks paren-free:

```elixir
# .formatter.exs
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:plushie]
]
```

### 4. Fetch dependencies and build the renderer

```sh
mix deps.get
mix plushie.build
```

The build step compiles the Rust renderer binary. First build takes a
few minutes; subsequent builds are fast.

## Your first app: a counter

Create `lib/my_app/counter.ex`:

<!-- test: getting_started_counter_init_test, getting_started_counter_increment_test, getting_started_counter_decrement_test, getting_started_counter_unknown_event_test, getting_started_counter_view_test, getting_started_counter_view_after_increments_test -- keep this code block in sync with the test -->
```elixir
defmodule MyApp.Counter do
  use Plushie.App

  alias Plushie.Event.WidgetEvent

  def init(_opts), do: %{count: 0}

  def update(model, %WidgetEvent{type: :click, id: "increment"}),
    do: %{model | count: model.count + 1}

  def update(model, %WidgetEvent{type: :click, id: "decrement"}),
    do: %{model | count: model.count - 1}

  def update(model, _event), do: model

  def view(model) do
    import Plushie.UI

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
mix plushie.gui MyApp.Counter
```

A native window appears with the count and two buttons.

## The Elm architecture

Plushie follows the Elm architecture. Your app module implements
callbacks via `Plushie.App`:

- **`init/1`** -- returns the initial model (any Elixir term).
- **`update/2`** -- takes the current model and an event, returns
  the new model. Pure function. To run side effects, return
  `{model, command}` instead. See [Commands](commands.md).
- **`view/1`** -- takes the model and returns a UI tree. Plushie diffs
  trees and sends only patches to the renderer.
- **`subscribe/1`** (optional) -- returns a list of active
  subscriptions (timers, keyboard events).

See [App behaviour](app-behaviour.md) for the full callback API.

## Event types

Events are structs under `Plushie.Event.*`. Pattern match in `update/2`:

| Event | Meaning |
|---|---|
| `%WidgetEvent{type: :click, id: id}` | Button click |
| `%WidgetEvent{type: :input, id: id, value: val}` | Text input change |
| `%WidgetEvent{type: :submit, id: id, value: val}` | Text input Enter |
| `%WidgetEvent{type: :toggle, id: id, value: val}` | Checkbox/toggler |
| `%WidgetEvent{type: :slide, id: id, value: val}` | Slider moved |
| `%WidgetEvent{type: :select, id: id, value: val}` | Pick list/radio |
| `%Timer{tag: tag, timestamp: ts}` | Timer fired |

See [Events](events.md) for the full taxonomy.

## Mix tasks

```bash
mix plushie.gui MyApp              # build and run
mix plushie.gui MyApp --build      # rebuild renderer first
mix plushie.gui MyApp --release    # use release build
mix plushie.build                  # build renderer only
mix plushie.build --release        # release build
mix plushie.gui MyApp --no-watch   # run without file watching
mix plushie.inspect MyApp          # print UI tree as JSON
```

## Debugging

Use JSON wire format to see messages between Elixir and the renderer:

```sh
mix plushie.gui MyApp --json
```

Enable verbose renderer logging:

```sh
RUST_LOG=plushie=debug mix plushie.gui MyApp
```

## Error handling

If `update/2` or `view/1` raises, the runtime catches the exception,
logs it, and continues with the previous state. The GUI does not
crash. Fix the code and the next event works normally. See the
[crash-test](https://github.com/plushie-ui/plushie-demos/tree/main/elixir/crash-test)
demo for all three failure paths (Elixir exceptions and Rust panics)
in action.

## Dev mode

Live code reloading without losing application state. Add
`:file_system` to your deps:

```elixir
{:file_system, "~> 1.0"}
```

In dev mode, `mix plushie.gui` watches all compilation directories
(`lib/`, `examples/`, etc.). Edit any `.ex` file, save, and the
GUI updates in place. The model is preserved -- only `view/1` is
re-evaluated with the new code. Pass `--no-watch` to disable.

Try it with an example -- run `mix plushie.gui Counter`, then edit
`examples/counter.ex` and save. The window updates instantly.

See `Plushie.DevServer` for configuration options.

## Next steps

- [Tutorial: building a todo app](tutorial.md) -- step-by-step guide
- Browse the [examples](https://github.com/plushie-ui/plushie-elixir/tree/main/examples) for patterns
- [App behaviour](app-behaviour.md) -- full callback API
- [Layout](layout.md) -- sizing and positioning widgets
- [Commands](commands.md) -- async work, file dialogs, effects
- [Events](events.md) -- complete event taxonomy
- [Testing](testing.md) -- writing tests against your UI
- [Theming](theming.md) -- custom themes and palettes
- [Demo apps](https://github.com/plushie-ui/plushie-demos/tree/main/elixir) -- collab scratchpad, gauge extension, sparkline dashboard
