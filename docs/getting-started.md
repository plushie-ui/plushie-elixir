# Getting started

Build native desktop GUIs from Elixir. julep handles rendering via iced (Rust)
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

### 2. Add julep as a dependency

```elixir
# mix.exs
defp deps do
  [
    {:julep, "~> 0.1"}
  ]
end
```

### 3. Formatter config

julep exports formatter settings so `mix format` won't add parentheses
to `Julep.UI` widget definitions. Add `:julep` to `import_deps` in
your `.formatter.exs`:

```elixir
# .formatter.exs
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:julep]
]
```

This keeps layout blocks paren-free so they read like declarative markup.

### 4. Fetch dependencies and build the renderer

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

  alias Julep.Event.Widget

  # Initial state
  def init(_opts), do: %{count: 0}

  # Handle events
  def update(model, %Widget{type: :click, id: "increment"}), do: %{model | count: model.count + 1}
  def update(model, %Widget{type: :click, id: "decrement"}), do: %{model | count: model.count - 1}
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

julep follows the Elm architecture. Your app module implements four callbacks
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
alias Julep.Event.Widget

def update(model, %Widget{type: :click, id: "increment"}), do: %{model | count: model.count + 1}
def update(model, _event), do: model
```

To run side effects (async work, file dialogs, clipboard), return a
`{model, command}` tuple instead. See [commands.md](commands.md).

### `view/1` -- describe the UI

Takes the model and returns a UI tree. julep diffs consecutive trees and
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

Events are structs under `Julep.Event.*`. The struct type identifies the
event family:

| Event | Meaning |
|---|---|
| `%Widget{type: :click, id: id}` | Button click |
| `%Widget{type: :input, id: id, value: val}` | Text input change |
| `%Widget{type: :submit, id: id, value: val}` | Text input submitted (Enter) |
| `%Widget{type: :toggle, id: id, value: checked}` | Checkbox or toggler toggled |
| `%Widget{type: :slide, id: id, value: val}` | Slider moved |
| `%Widget{type: :select, id: id, value: val}` | Pick list, combo box, or radio selected |
| `%Timer{tag: :tick, timestamp: ts}` | Timer subscription fired |
| `%Key{type: :press, ...}` | Keyboard subscription fired |

See [events.md](events.md) for the full taxonomy.

## Mix tasks

### mix julep.gui

Builds (if needed) and launches the renderer with your app.

```bash
mix julep.gui MyApp                # debug build, auto-build renderer
mix julep.gui MyApp --release      # release build
mix julep.gui MyApp --no-build     # skip cargo build, use existing binary
mix julep.gui MyApp --renderer /path/to/julep  # explicit binary path
```

### mix julep.build

Builds the renderer binary without running it.

```bash
mix julep.build              # debug
mix julep.build --release    # release
```

### mix julep.inspect

Runs your app without the renderer and prints the UI tree as JSON.

```bash
mix julep.inspect MyApp
mix julep.inspect MyApp --events '["click:inc", "click:inc"]'
mix julep.inspect MyApp --pretty
```

## IEx workflow

```elixir
iex -S mix

# Start the GUI
{:ok, pid} = Julep.start(MyApp)

# Or start without the renderer (headless, for inspection)
{:ok, pid} = Julep.start(MyApp, renderer: false)

# Inspect current state
Julep.snapshot(pid)

# Inspect current UI tree
Julep.tree(pid)
Julep.tree(pid) |> Jason.encode!(pretty: true) |> IO.puts()

# Dispatch events manually
Julep.dispatch(pid, %Widget{type: :click, id: "inc"})

# Stop
Julep.stop(pid)
```

## Debugging

Use JSONL wire format to inspect messages between Elixir and the renderer:

```sh
mix julep.gui --json MyApp.Counter
```

Enable verbose renderer logging:

```sh
RUST_LOG=julep=debug mix julep.gui MyApp.Counter
```

## Error handling

If `update/2` raises, the runtime catches the exception, logs it, and
continues with the previous model. The app does not crash. If `view/1`
raises, the runtime logs the error and sends the previous tree. A bug
in your event handler or view function does not crash the GUI -- you see
the error in the console, fix it, and the next event works.

## Project structure

A minimal julep app:

```
my_app/
  lib/
    my_app.ex          # Julep.App implementation
  mix.exs
```

A larger app might organize by feature:

```
my_app/
  lib/
    my_app.ex              # Julep.App, delegates to feature modules
    my_app/
      views/
        sidebar.ex         # view helper functions
        main_content.ex
      models/
        todo.ex            # domain structs
      events.ex            # event handling, delegates per feature
  test/
    my_app_test.exs
    snapshots/             # UI tree snapshots
  mix.exs
```

There is no prescribed structure. A julep app is a normal Elixir project.
Organize it however makes sense for your domain.

## State helpers

julep includes pure-data modules for common UI state patterns:
`Julep.State` (change tracking), `Julep.Undo` (undo/redo),
`Julep.Selection` (single/multi select), `Julep.Route` (navigation),
and `Julep.Data` (in-memory queries). Plain structs, no processes.

## Dev mode (live code reloading)

Julep includes a dev-mode server that watches your source files, recompiles on
change, and re-renders the UI without losing application state.

### Quick start

From a Mix task:

```bash
mix julep.dev MyApp
```

From IEx:

```elixir
iex> Julep.start(MyApp, dev: true)
```

Edit any `.ex` or `.exs` file under `lib/`, save, and the running GUI updates
in place.

### How it works

The Elm architecture makes live reload safe by design:

1. **File watcher** (`Julep.DevServer`) monitors `lib/` via the `:file_system`
   package (inotify on Linux, fsevents on macOS).
2. **Debounce** -- rapid saves within 100ms (configurable) are batched into a
   single recompile. Changed file paths are collected during the window.
3. **Recompile** -- each changed file is compiled via `Code.compile_file/1`,
   which directly loads the new module bytecode into the running BEAM.
4. **Re-render** -- the Runtime re-evaluates `view(model)` with the new code.
   The model in memory is untouched.
5. **Diff and patch** -- the new tree is diffed against the old one. Only
   changed nodes produce patches sent to the renderer.
6. **Renderer applies patches** -- the GUI updates. Widget state (text input
   content, scroll position, focus) is preserved because unchanged widgets
   aren't touched.

If `view/1` raises after a bad edit, the old tree is preserved and the error
is logged. Fix the code, save again, and the UI recovers.

### Setup

Add `:file_system` to your project's deps:

```elixir
defp deps do
  [
    {:julep, "~> 0.1"},
    {:file_system, "~> 1.0"}
  ]
end
```

On Linux, `inotify-tools` must be installed:

```bash
# Arch
pacman -S inotify-tools

# Debian/Ubuntu
apt install inotify-tools
```

### Usage

#### From IEx

```elixir
# Basic dev mode
iex> Julep.start(MyApp, dev: true)

# With options
iex> Julep.start(MyApp, dev: true, dev_opts: [debounce_ms: 200])

# Custom watch directories
iex> Julep.start(MyApp, dev: true, dev_opts: [dirs: ["lib", "config"]])
```

#### From Mix

```bash
mix julep.dev MyApp              # default: debug build, 100ms debounce
mix julep.dev MyApp --build      # build renderer first
mix julep.dev MyApp --release    # use release build
mix julep.dev MyApp --debounce 200  # custom debounce interval (ms)
```

The Mix task is a convenience wrapper around `Julep.start/2` with `dev: true`.

### What triggers a reload

- Any `.ex` or `.exs` file change under the watched directories (default: `lib/`)
- Files in `_build/` are ignored

### What doesn't reload

- **Rust renderer changes** -- rebuild the renderer manually or pass `--build`
- **Model shape changes** -- if your `init/1` returns a different model
  structure, the existing model won't match what `view/1` expects. The view
  will raise, the old tree is preserved, and you'll see the error in the
  terminal. Restart the app to pick up model shape changes.

### Architecture

The `Julep.DevServer` is a regular GenServer supervised alongside Runtime and
Bridge in the Julep supervisor tree. It has no dependency on Mix tasks or IEx
-- it uses `Code.compile_file/1` directly and the `:file_system` package for
OS-native file watching. When `dev: true` is not set, the DevServer is simply
not started and adds zero overhead.

## Next steps

- Browse the [examples](../lib/julep/examples/) for patterns beyond the counter
- Read [app-behaviour.md](app-behaviour.md) for the full callback API
- Read [commands.md](commands.md) for async work, file dialogs, and effects
- Read [events.md](events.md) for the complete event taxonomy
- Read [theming.md](theming.md) for custom themes and palettes
- Read [testing.md](testing.md) for writing tests against your UI
