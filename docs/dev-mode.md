# Dev Mode (Live Code Reloading)

Julep includes a dev-mode server that watches your source files, recompiles on
change, and re-renders the UI without losing application state.

## Quick start

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

## How it works

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

## Setup

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

## Usage

### From IEx

```elixir
# Basic dev mode
iex> Julep.start(MyApp, dev: true)

# With options
iex> Julep.start(MyApp, dev: true, dev_opts: [debounce_ms: 200])

# Custom watch directories
iex> Julep.start(MyApp, dev: true, dev_opts: [dirs: ["lib", "config"]])
```

### From Mix

```bash
mix julep.dev MyApp              # default: debug build, 100ms debounce
mix julep.dev MyApp --build      # build renderer first
mix julep.dev MyApp --release    # use release build
mix julep.dev MyApp --debounce 200  # custom debounce interval (ms)
```

The Mix task is just a convenience wrapper around `Julep.start/2` with
`dev: true`.

## What triggers a reload

- Any `.ex` or `.exs` file change under the watched directories (default: `lib/`)
- Files in `_build/` are ignored

## What doesn't reload

- **Rust renderer changes** -- rebuild the renderer manually or pass `--build`
- **Model shape changes** -- if your `init/1` returns a different model
  structure, the existing model won't match what `view/1` expects. The view
  will raise, the old tree is preserved, and you'll see the error in the
  terminal. Restart the app to pick up model shape changes.

## Architecture

The `Julep.DevServer` is a regular GenServer supervised alongside Runtime and
Bridge in the Julep supervisor tree. It has no dependency on Mix tasks or IEx
-- it uses `Code.compile_file/1` directly and the `:file_system` package for
OS-native file watching. When `dev: true` is not set, the DevServer is simply
not started and adds zero overhead.
