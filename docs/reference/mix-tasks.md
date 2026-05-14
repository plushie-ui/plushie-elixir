# Mix Tasks

Plushie ships mix tasks for running, building, downloading, inspecting,
and debugging Plushie applications and renderer binaries.

| Task | Purpose |
|---|---|
| [`plushie.gui`](#plushiegui) | Run a Plushie app |
| [`plushie.build`](#plushiebuild) | Build the renderer binary from source |
| [`plushie.download`](#plushiedownload) | Download a precompiled renderer binary |
| [`plushie.package`](#plushiepackage) | Build a standalone package payload |
| [`plushie.inspect`](#plushieinspect) | Print the UI tree as JSON |
| [`plushie.connect`](#plushieconnect) | Connect to a remote renderer |
| [`plushie.script`](#plushiescript) | Run automation scripts headlessly |
| [`plushie.replay`](#plushiereplay) | Replay scripts with real windows |
| [`preflight`](#preflight) | Run all CI checks locally |

## plushie.gui

Starts a Plushie application with a renderer binary.

```bash
mix plushie.gui PlushiePad
```

This compiles your project, resolves the renderer binary (see
[binary resolution](#binary-resolution)), starts the Plushie supervision
tree (Bridge + Runtime), and opens your app's windows. The task blocks
until the app exits, either by closing the last window or pressing
Ctrl+C.

### Flags

| Flag | Description |
|---|---|
| `--build` | Run `mix plushie.build` before starting |
| `--release` | Build with optimisations (requires `--build`) |
| `--json` | Switch wire protocol to JSON (see [debugging](#json-debugging)) |
| `--watch` | Enable hot code reloading |
| `--no-watch` | Disable hot reload even if config enables it |
| `--debounce MS` | File watch debounce interval in milliseconds (default: 100) |
| `--daemon` | Keep running after the last window closes |

**Daemon mode** is useful for apps that manage their own window lifecycle.
In both modes, closing all windows delivers
`%SystemEvent{type: :all_windows_closed}` to `update/2`. Without
`--daemon`, the runtime shuts down after that update. With `--daemon`,
it continues running so you can open new windows, show a tray menu, etc.

### Hot reload

Hot reload watches your source files and recompiles on change, updating
the running UI without restarting. Enable it with `--watch` or
permanently in `config/dev.exs`:

```elixir
config :plushie, code_reloader: true
```

Flag priority: `--watch` > `--no-watch` > config > disabled.

When active:

- **Elixir changes**: any `.ex` file in your compilation paths triggers
  recompilation. The runtime re-calls `view/1` with the **current model**
  (not a fresh `init/1`) and diffs the new tree against the old one.
  Only the changes are sent to the renderer. This means your application
  state (form inputs, scroll positions, navigation) is preserved
  across recompilations. The debounce (default 100ms) prevents rapid
  recompilation when your editor writes multiple files.
- **Rust changes** (native widgets only): `.rs` and `Cargo.toml` changes
  trigger `cargo build` with a longer debounce (200ms). On success, the
  Bridge calls `restart_renderer/1` which cleanly shuts down the old
  renderer process and starts a new one. The runtime re-syncs by sending
  a fresh settings message and full snapshot to the new process. Widget
  state managed by the runtime (Elixir-side) is preserved; widget state
  managed by the renderer (scroll offsets, cursor positions) resets.
- **Dev overlay**: a status bar appears at the top of each window during
  rebuilds. It uses the `__plushie_dev__/` ID prefix so its events are
  intercepted by the runtime before reaching your `update/2`. The overlay
  shows "Rebuilding..." with a collapsible drawer for build output. It
  auto-dismisses on success (unless expanded) and persists on failure
  with error details and a dismiss button.

### JSON debugging

```bash
mix plushie.gui PlushiePad --json
```

Switches the wire protocol from [MessagePack](https://msgpack.org/) to
newline-delimited JSON. Each message is a complete JSON object on its own
line, making it straightforward to inspect with
[`jq`](https://jqlang.github.io/jq/) or pipe to a file:

```bash
mix plushie.gui PlushiePad --json 2>protocol.log
```

For renderer-side logging, set the `RUST_LOG` environment variable:

```bash
RUST_LOG=plushie=debug mix plushie.gui PlushiePad --json
```

This prints every protocol message the renderer sends and receives, plus
internal decisions (widget rendering, event dispatch, animation frames)
to stderr. The combination of `--json` (human-readable wire format) and
`RUST_LOG` (renderer internals) gives full visibility into both sides of
the protocol.

See the [Wire Protocol reference](wire-protocol.md) for the message
format and field descriptions.

## plushie.build

Delegates renderer workspace generation to the `cargo-plushie` Cargo
subcommand and produces the renderer binary.

```bash
mix plushie.build              # debug build
mix plushie.build --release    # optimised build
```

Plushie apps are two processes: your Elixir app (state, events, UI
trees) and a Rust renderer (window management, GPU rendering, platform
integration). The renderer is a compiled binary that the SDK communicates
with over a wire protocol. This task builds that binary.

Most apps use `mix plushie.download` for a precompiled binary and never
need to build from source. Building is required when you have
[native widgets](custom-widgets.md) (Rust-backed custom rendering) or
want to work against a local renderer checkout.

### Flags

| Flag | Description |
|---|---|
| `--bin` | Build the native binary (default if no flags given) |
| `--wasm` | Build the WASM renderer via [wasm-pack](https://rustwasm.github.io/wasm-pack/) |
| `--release` | Build with optimisations (also enabled by `config :plushie, build_profile: :release`) |
| `--verbose` | Print full Cargo output even on success |
| `--update` | Wipe the spec scratch dir to force a clean regen |
| `--bin-file PATH` | Override native binary destination |
| `--wasm-dir PATH` | Override WASM output directory |

`--bin` and `--wasm` can be combined to build both artifacts in one pass.

### What it generates

The Mix task itself writes a small "renderer spec" manifest that
cargo-plushie reads via `cargo metadata`:

- `_build/<env>/plushie-renderer-spec/Cargo.toml` - minimal manifest
  listing each detected native widget crate as a path dependency and
  carrying `[package.metadata.plushie]` (binary name, source path).
- `_build/<env>/plushie-renderer-spec/src/lib.rs` - placeholder so the
  manifest parses cleanly.

cargo-plushie produces the real renderer workspace and binary:

- `_build/<env>/plushie-renderer-spec/target/plushie-renderer/` - the
  generated Cargo workspace (Cargo.toml + main.rs + Cargo.lock).
- `_build/<env>/plushie-renderer-spec/target/plushie-renderer/target/<profile>/<bin>` -
  the compiled binary, copied to `_build/plushie/bin/` after a successful
  build.

Using `PLUSHIE_RUST_SOURCE_PATH`, cargo-plushie emits `[patch.crates-io]`
redirecting plushie crates (and any workspace-level patches declared in
`plushie-rust/Cargo.toml` or its `.cargo/config.toml`) to the local
checkout.

### cargo-plushie resolution

The task's internal helper decides how to invoke the subcommand:

1. **`PLUSHIE_RUST_SOURCE_PATH` set**: run from source via
   `cargo run -p cargo-plushie --release --quiet -- ...`. Always works
   during local plushie-rust development.
2. **Otherwise**: expect `cargo-plushie` on PATH at the exact version
   the SDK targets (`Plushie.Binary.plushie_rust_version/0`). Install
   with `cargo install cargo-plushie --version X.Y.Z --locked`.
3. **Missing or mismatched**: the task raises with an install hint;
   no auto-install.

### Native widget auto-detection

Native widgets are discovered automatically via `Plushie.Tree.Node`
protocol consolidation at compile time. Any module that implements the
protocol and exports `native_crate/0` is listed as a path dependency
in the spec manifest. No Elixir-side configuration needed beyond
declaring the widget dependency in `mix.exs`.

Each widget's Rust crate must declare `[package.metadata.plushie.widget]`
with `type_name` and `constructor` fields in its own `Cargo.toml`.
cargo-plushie reads these tables via `cargo metadata` to wire widgets
into the generated `main.rs` and to run collision checks (duplicate
type names, built-in shadows, duplicate crate basenames).

**Removing native widgets**: when you remove a native widget dependency
from your project, run `mix clean` before the next build. Protocol
consolidation reads compiled BEAM files, so stale `.beam` files from
the removed widget will cause phantom detection until they are cleaned
out.

### Local source vs crates.io

By default, Rust dependencies come from crates.io using the version in
the `PLUSHIE_RUST_VERSION` file at the project root. For development against a
local renderer checkout, clone it as a sibling directory:

```bash
git clone https://github.com/plushie-ui/plushie-rust ../plushie-rust
```

Then point the build at it:

```bash
PLUSHIE_RUST_SOURCE_PATH=../plushie-rust mix plushie.build
```

Or permanently in config:

```elixir
config :plushie, source_path: "../plushie-rust"
```

This adds `[patch.crates-io]` to the generated Cargo workspace,
redirecting all crate dependencies to local paths. This is essential when
modifying the renderer alongside the SDK. Without it, the build would
mix crates.io types with local types, causing Rust compilation errors.

To build against the latest renderer `main` branch:

```bash
cd ../plushie-rust && git pull
cd ../plushie-elixir && PLUSHIE_RUST_SOURCE_PATH=../plushie-rust mix plushie.build
```

### WASM builds

```bash
mix plushie.build --wasm
mix plushie.build --wasm --release
```

Shells out to `cargo plushie build --wasm`, which in turn drives
[wasm-pack](https://rustwasm.github.io/wasm-pack/) with `--target web`.
The output files (`plushie_renderer_wasm.js` and
`plushie_renderer_wasm_bg.wasm`) go to `_build/plushie-renderer/wasm/`
by default.

WASM builds require `PLUSHIE_RUST_SOURCE_PATH` set to a local plushie-rust
checkout and `wasm-pack` on the PATH. There is no crates.io path: the
WASM renderer has no pre-built bundle to fetch.

### Requirements

- [Rust](https://rustup.rs/) 1.92+ (checked at build time via
  `rustc --version`)
- `cargo` on the PATH
- `cargo-plushie` at the matching `PLUSHIE_RUST_VERSION`, installed
  with `cargo install cargo-plushie --version <PLUSHIE_RUST_VERSION> --locked`,
  or `PLUSHIE_RUST_SOURCE_PATH` set to a local plushie-rust checkout
- For WASM: [wasm-pack](https://rustwasm.github.io/wasm-pack/) on the
  PATH and `PLUSHIE_RUST_SOURCE_PATH` set (WASM builds always run
  against local plushie-rust source)

## plushie.download

Downloads a precompiled renderer binary from GitHub releases.

```bash
mix plushie.download               # native binary
mix plushie.download --wasm        # WASM renderer
```

This is the fastest way to get a working renderer. The binary is
platform-specific (OS + architecture) and version-matched to the SDK
via the `PLUSHIE_RUST_VERSION` file.

### Flags

| Flag | Description |
|---|---|
| `--bin` | Download the native binary (default if no flags given) |
| `--wasm` | Download the WASM renderer tarball |
| `--force` | Re-download even if files already exist |
| `--bin-file PATH` | Override native binary destination |
| `--wasm-dir PATH` | Override WASM output directory |

### Checksum verification

Every download is verified against a SHA256 checksum fetched from the
same GitHub release. If the checksum does not match, the downloaded file
is deleted and an error is raised. There is no option to skip
verification. This is intentional, as the binary runs as a child
process of your application.

### Native widget refusal

If your project contains native widgets (detected via protocol
consolidation at compile time), the download task refuses to proceed and
lists the detected widgets. Native widgets add Rust crate dependencies
to the renderer, which means a precompiled binary cannot include them.
Use `mix plushie.build` instead.

Pure Elixir widgets (those with `view/2` or `view/3` callbacks but no
`native_crate/0`) work fine with precompiled binaries. They compose
existing renderer widgets and do not require a custom build.

## plushie.package

Builds an Elixir release payload and `plushie-package.toml` manifest
for the shared Rust launcher.

```bash
MIX_ENV=prod mix plushie.package MyApp --app-id dev.example.my_app
cargo plushie package --manifest dist/plushie-package.toml --release
```

This task owns the Elixir-specific part of standalone packaging:

- Builds the Mix release.
- Copies the release into `dist/payload/`.
- Places the selected renderer in the payload.
- Writes `bin/connect`, which starts the release and calls
  `Plushie.Connect.run/2`.
- Archives the payload as `dist/payload.tar.zst`.
- Writes `dist/plushie-package.toml` for `cargo plushie package`.

The shared Rust package command remains language-agnostic. It consumes
the manifest and embedded payload archive produced here.

### Flags

| Flag | Description |
|---|---|
| `--app-id ID` | Package app identifier. Required |
| `--release NAME` | Mix release name. Defaults to the current Mix app |
| `--output DIR` | Output directory. Defaults to `dist` |
| `--renderer auto|stock|custom` | Renderer selection. Defaults to `auto` |
| `--renderer-bin PATH` | Use an existing renderer binary |
| `--load MODULE` | Load a module before native widget discovery |

`--renderer auto` uses a stock renderer when no native widgets are
discovered and builds a custom renderer when native widgets are present.
Requesting `--renderer stock` for an app with native widgets fails
fast, because a stock renderer cannot include those widget crates.

Use `--load MODULE` when a native widget module is not otherwise loaded
before protocol consolidation. The package task loads these modules
before native widget discovery.

## plushie.inspect

Prints a Plushie app's initial UI tree as pretty-printed JSON, without
starting a renderer.

```bash
mix plushie.inspect PlushiePad
```

The task calls `init/1` to get the initial model, then `view/1` to
produce the UI tree, then `Plushie.Tree.normalize/1` to convert widget
structs to plain maps. The result is printed as formatted JSON via
`Jason.encode!/2`.

This is useful for:
- Debugging layout structure and widget nesting
- Verifying prop values without opening a window
- Quick inspection in CI or scripts
- Checking that `view/1` doesn't crash with a fresh model

No renderer binary is needed. The tree is computed entirely in Elixir.

### Script mode

```bash
mix plushie.inspect PlushiePad --script test.plushie
```

With `--script`, the task starts a real test session (with a renderer),
executes the `.plushie` script instructions, and prints the tree after
execution. This lets you inspect the tree at a specific point in an
interaction sequence. Script failures are reported with the action,
selector, expected value, and error message.

## plushie.connect

Connects a Plushie application to an already-listening renderer via a
Unix domain socket or TCP port.

```bash
mix plushie.connect PlushiePad /tmp/plushie.sock   # Unix socket
mix plushie.connect PlushiePad :4567               # TCP port
```

This is the Elixir side of Plushie's remote rendering architecture.
Normally, `plushie.gui` spawns the renderer as a child process (the
`:spawn` transport). With `plushie.connect`, the renderer is already
running elsewhere and listening on a socket. The SDK connects to it
and communicates over the same wire protocol. The app code is
identical either way.

### Flags

| Flag | Description |
|---|---|
| `--token TOKEN` | Shared authentication token used to compute `settings.token_sha256` |
| `--json` | Use JSON wire format instead of MessagePack |
| `--daemon` | Keep running after all windows close |

### Resolution

The socket path comes from the CLI argument or `PLUSHIE_SOCKET`
environment variable. The authentication token is resolved in priority
order: `--token` flag, `PLUSHIE_TOKEN` environment variable, or a JSON
negotiation line on stdin (1-second timeout).

When a token is available, the SDK sends `settings.token_sha256` in the
Settings message. It does not send the plaintext token to the renderer.

### The remote rendering flow

1. Start the renderer with `plushie --listen --exec-bin ...`:
   ```bash
   plushie --listen --exec-bin mix --exec-arg plushie.connect --exec-arg PlushiePad
   ```
   The renderer starts, binds a socket, and spawns the command. The
   socket path is passed to the command via `PLUSHIE_SOCKET`.

2. `mix plushie.connect` reads `PLUSHIE_SOCKET`, resolves `PLUSHIE_TOKEN`
   or stdin negotiation, connects, and starts the Plushie supervision tree
   with `transport: {:iostream, adapter}`.

3. From this point, the protocol is identical to local mode. The only
   difference is latency, since messages travel over a socket instead of
   stdio pipes.

This pattern enables:
- **Remote desktop**: Elixir on a server, renderer on a workstation
- **Embedded devices**: Elixir on a [Nerves](https://nerves-project.org/)
  board, renderer on a connected display
- **SSH tunnels**: pipe the socket through SSH for encrypted remote GUI
- **Custom transports**: WebSocket bridges, TCP adapters, etc.

See the [Configuration reference](configuration.md) for transport mode
details and the iostream adapter contract.

## plushie.script

Runs [`.plushie` automation scripts](testing.md) headlessly.

```bash
mix plushie.script                           # all in test/scripts/
mix plushie.script path/to/test.plushie      # specific script
```

Without arguments, discovers and runs all `.plushie` files under
`test/scripts/`. Each script starts a fresh app session against the
mock backend, executes the instructions, and reports pass/fail.

The task suppresses runtime log output (sets Logger to `:warning`)
during execution to keep the output clean. Artifacts (screenshots, tree
hashes) are written to `tmp/plushie_automation/`.

Exit code is 0 if all scripts pass, 1 if any fail.

## plushie.replay

Replays a `.plushie` script with real windows and real timing.

```bash
mix plushie.replay path/to/test.plushie
```

Unlike `plushie.script` (which runs headlessly against the mock backend),
replay uses the `:windowed` backend. This means real windows appear on
screen, GPU rendering is active, and `wait` timing directives in the
script are respected. The script plays out in real time.

Useful for:
- Visually verifying that an automation script does what you expect
- Creating demo recordings or walkthroughs
- Debugging interaction sequences that behave differently with real
  rendering (timing, animation, focus)

## preflight

Runs the full CI check suite locally, stopping at the first failure.

```bash
mix preflight
```

Steps, in order:

1. `mix format --check-formatted` - code formatting
2. `mix compile --warnings-as-errors` - compilation with strict warnings
3. `mix credo --strict` - static analysis and style checking
4. `mix test` - test suite (default backend from app config)
5. `PLUSHIE_TEST_BACKEND=headless mix test` - test suite with headless backend
6. `mix docs --warnings-as-errors` - documentation generation (dev env)
7. `mix dialyzer` - type checking via [Dialyzer](https://www.erlang.org/doc/apps/dialyzer/)

The order is deliberate: fast, cheap checks first (formatting takes
milliseconds), expensive checks last (Dialyzer can take minutes on first
run). Stopping at the first failure avoids wasting time on downstream
checks when an earlier one fails.

Each step streams its output directly to the terminal. A green PASS or
red FAIL marker appears after each step. If all steps pass, the task
prints "All checks passed." and exits with code 0.

**If preflight passes locally, CI will pass.** Run it before pushing.

## Binary resolution

Several tasks need the renderer binary. `Plushie.Binary.path!/0`
resolves it in priority order:

1. `PLUSHIE_BINARY_PATH` environment variable - explicit override,
   useful for CI or custom build pipelines
2. Application config `:binary_path` - explicit per-environment path
3. Custom widget build under
   `_build/<env>/plushie-renderer-spec/target/plushie-renderer/target/` -
   auto-detected after `mix plushie.build`
4. Downloaded binary in `_build/plushie/bin/` - auto-detected after
   `mix plushie.download`

Steps 1 and 2 are explicit: if set but pointing to a missing file, they
raise immediately with a clear error. Steps 3 and 4 are implicit
discovery: they check the path silently and fall through to the next
option if not found.

The resolved binary is validated for the current OS and architecture
before use. See `Plushie.Binary` for the full resolution logic and
version information.

## See also

- [Configuration reference](configuration.md) - environment variables,
  application config, and transport modes
- [Testing reference](testing.md) - test backends, CI setup, and the
  full test helper API
- [Wire Protocol reference](wire-protocol.md) - message format for
  `--json` debugging
- `Plushie.Binary` - binary path resolution and version
- [Guide: Getting Started](../guides/02-getting-started.md) - first
  use of `plushie.download` and `plushie.gui`
- [Guide: Shared State](../guides/16-shared-state.md) - remote
  rendering with SSH transport
