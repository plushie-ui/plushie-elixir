# Tooling and Deployment

This chapter covers the practical tooling you use day to day when developing
Plushie apps: running, building, debugging, and preparing for CI.

## Running your app

```bash
mix plushie.gui PlushiePad
```

This resolves the renderer binary, starts the supervision tree, and opens
your app's windows. Common flags:

| Flag | Effect |
|---|---|
| `--build` | Build the renderer before starting |
| `--release` | Use an optimised release build |
| `--json` | Use JSON wire protocol (for debugging) |
| `--daemon` | Keep running after the last window closes |
| `--watch` | Enable hot code reloading (see below) |

See `mix help plushie.gui` for all options.

## Hot reload

Plushie can watch your source files and recompile on change. Enable it in
`config/dev.exs`:

```elixir
import Config

config :plushie, code_reloader: true
```

Or per-run with `--watch`:

```bash
mix plushie.gui PlushiePad --watch
```

When enabled:

- **Elixir changes**: any `.ex` file in your compilation paths triggers
  recompilation. The runtime calls `view/1` with the current model and
  patches the UI. Model state is preserved.
- **Rust changes** (native widgets only): `.rs` and `Cargo.toml` changes
  trigger `cargo build`. On success, the renderer restarts and the runtime
  re-syncs its state.
- **Dev overlay**: a status bar appears at the top of each window during
  rebuilds. It shows "Rebuilding..." with build output in a collapsible
  drawer, auto-dismisses on success, and persists on failure with error
  details.

The debounce is 100ms for Elixir and 200ms for Rust. You can adjust the
Elixir debounce:

```bash
mix plushie.gui PlushiePad --watch --debounce 200
```

## Building

```bash
mix plushie.build              # debug build (default)
mix plushie.build --release    # optimised build
```

`mix plushie.build` generates a Cargo workspace and compiles the renderer
binary. The workspace includes:

- The core renderer crate
- Any native widgets detected via `Plushie.Widget.WidgetProtocol`
  consolidation (auto-detected, no configuration needed)
- A generated `main.rs` that registers all native widgets

### Local source vs crates.io

By default, Rust dependencies are pulled from crates.io using the version
in the `BINARY_VERSION` file. For development against a local renderer
checkout:

```bash
PLUSHIE_SOURCE_PATH=~/projects/plushie-renderer mix plushie.build
```

Or in `config/config.exs`:

```elixir
config :plushie, source_path: "~/projects/plushie-renderer"
```

This adds `[patch.crates-io]` to the generated workspace so all crates share
the same types.

### WASM renderer

Plushie supports building a WASM renderer for browser deployment:

```bash
mix plushie.build --wasm           # build WASM via wasm-pack
mix plushie.build --wasm --release # optimised WASM build
```

This produces `plushie_renderer_wasm.js` and `plushie_renderer_wasm_bg.wasm`
for embedding in web applications. Requires a local renderer source checkout
(`PLUSHIE_SOURCE_PATH`). `--bin` and `--wasm` can be combined to build both
artifacts in one pass.

## Downloading precompiled binaries

```bash
mix plushie.download               # native binary
mix plushie.download --wasm        # WASM renderer
```

Downloads a precompiled binary from GitHub releases and verifies its SHA256
checksum. This is the fastest way to get started, but it **refuses to
download when native widgets are detected** -- native widgets require a
custom build.

## Inspecting the tree

```bash
mix plushie.inspect PlushiePad
```

Calls `init/1` and `view/1`, normalizes the tree, and pretty-prints it as
JSON. Useful for debugging layout and prop issues without starting the
renderer.

## Debugging with JSON

```bash
mix plushie.gui PlushiePad --json
```

Switches the wire protocol from MessagePack to JSON. Messages are
human-readable, which helps when debugging protocol-level issues. You can
also set `RUST_LOG=plushie=debug` for verbose renderer logging:

```bash
RUST_LOG=plushie=debug mix plushie.gui PlushiePad --json
```

## Preflight checks

```bash
mix preflight
```

Runs the full CI check suite in order:

1. `mix format --check-formatted`
2. `mix compile --warnings-as-errors`
3. `mix credo --strict`
4. `mix test`
5. `mix docs --warnings-as-errors`
6. `mix dialyzer`

Exits on the first failure. If preflight passes locally, CI will pass.

## Connecting to a remote renderer

The renderer and the Elixir app do not have to run on the same machine.
`mix plushie.connect` attaches to a renderer listening on a socket:

```bash
# Unix domain socket
mix plushie.connect PlushiePad /tmp/plushie.sock

# TCP
mix plushie.connect PlushiePad :4567
```

This is useful for remote rendering scenarios: your Elixir app runs on a
server or embedded device (like a Nerves-powered board), and the renderer
runs on a machine with a display. The server side needs only the BEAM and
MessagePack -- no display server, no GPU, no windowing dependencies. The
wire protocol is the same; it just travels over a socket instead of stdio.

Plushie supports three transport modes:

- `:spawn` (default) -- Elixir spawns the renderer as a child process
- `:stdio` -- the renderer spawns Elixir (for `plushie --exec` mode)
- `{:iostream, pid}` -- custom transport adapter (TCP, SSH, WebSocket, etc.)

See the [Configuration reference](../reference/configuration.md) for
transport setup details and the iostream adapter contract.

## Publishing widget packages

If you have built reusable widgets and want to publish them on Hex:

- **Pure Elixir widgets** work with precompiled binaries. Consumers can
  `mix plushie.download` and use your widgets immediately.
- **Native widgets** require the consumer to build the renderer with
  `mix plushie.build`. The build system auto-detects native widgets from
  dependencies -- no extra configuration needed.

See the [Custom Widgets reference](../reference/custom-widgets.md) for
packaging details.

## Summary

| Task | Command |
|---|---|
| Run app | `mix plushie.gui MyApp` |
| Run with hot reload | `mix plushie.gui MyApp --watch` |
| Build renderer | `mix plushie.build` |
| Build optimised | `mix plushie.build --release` |
| Download binary | `mix plushie.download` |
| Inspect tree | `mix plushie.inspect MyApp` |
| Debug protocol | `mix plushie.gui MyApp --json` |
| Run CI checks | `mix preflight` |
| Connect remote | `mix plushie.connect MyApp :port` |
| Run tests | `mix test` |
| Run headless tests | `PLUSHIE_TEST_BACKEND=headless mix test` |
