# Configuration

Plushie is configured at three levels: environment variables for
deployment and CI, application config for project-wide defaults, and
runtime options on `Plushie.start_link/2` for per-instance control.
Most projects need minimal configuration. Build or download the
binary and go.

## Environment variables

| Variable | Purpose |
|---|---|
| `PLUSHIE_BINARY_PATH` | Explicit path to the renderer binary. Overrides all other binary resolution. |
| `PLUSHIE_SOURCE_PATH` | Path to a local [plushie-renderer](https://github.com/plushie-ui/plushie-renderer) checkout for source builds. |
| `PLUSHIE_TEST_BACKEND` | Test backend: `mock` (default), `headless`, or `windowed`. |
| `PLUSHIE_UPDATE_SCREENSHOTS` | When set to any value, update screenshot golden files instead of comparing. |
| `PLUSHIE_UPDATE_SNAPSHOTS` | When set to any value, update tree-hash snapshot files instead of comparing. |
| `RUST_LOG` | Renderer log verbosity. Set to `plushie=debug` for full protocol logging. Overrides the `:log_level` runtime option when set. |

### PLUSHIE_BINARY_PATH

Forces a specific renderer binary. Useful in CI where the binary is
pre-built and stored at a known path, or in production deployments
where the binary ships alongside the release. If set but pointing to
a missing file, resolution raises immediately rather than falling
through to other paths.

### PLUSHIE_SOURCE_PATH

Points to a local checkout of the
[plushie-renderer](https://github.com/plushie-ui/plushie-renderer)
repository. When set, `mix plushie.build` uses local path dependencies
instead of crates.io, and the dev server watches `.rs` files for hot
reload. The typical setup is a sibling directory:

```bash
git clone https://github.com/plushie-ui/plushie-renderer ../plushie-renderer
PLUSHIE_SOURCE_PATH=../plushie-renderer mix plushie.build
```

### RUST_LOG

Controls the renderer's log output using the standard
[`env_logger`](https://docs.rs/env_logger/) format. The Bridge forwards
this to the renderer process at startup. Common values:

- `plushie=debug` - full protocol and rendering detail
- `plushie=info` - connection events and major state changes
- `plushie=warn` - warnings only (default-like)

When `RUST_LOG` is set, the `:log_level` option on `start_link/2` is
ignored. Combine with `--json` for full wire protocol visibility:

```bash
RUST_LOG=plushie=debug mix plushie.gui MyApp --json
```

## Application config

Set in `config/*.exs` under `config :plushie`. A typical development
setup looks like this:

```elixir
# config/dev.exs
import Config

config :plushie, code_reloader: true
```

Most projects only need `:code_reloader` in dev. The remaining options
are for customising builds, binary paths, and test backends.

### Binary and build

| Key | Type | Default | Purpose |
|---|---|---|---|
| `:binary_path` | `String.t()` | `nil` | Explicit binary path. The env var `PLUSHIE_BINARY_PATH` takes precedence if set. |
| `:source_path` | `String.t()` | `nil` | Rust source checkout path. The env var `PLUSHIE_SOURCE_PATH` takes precedence if set. |
| `:build_name` | `String.t()` | `"app-renderer"` | Custom binary name for `mix plushie.build` output. |
| `:build_profile` | `:release \| :debug` | `:debug` | Cargo build profile. `:release` enables optimisations. |
| `:artifacts` | `[:bin] \| [:bin, :wasm]` | `[:bin]` | Which artifacts `mix plushie.build` and `mix plushie.download` install. |
| `:bin_file` | `String.t()` | `nil` | Override binary output path for build/download. |
| `:wasm_dir` | `String.t()` | `nil` | Override WASM output directory for build/download. |

### Development

| Key | Type | Default | Purpose |
|---|---|---|---|
| `:code_reloader` | `boolean() \| keyword()` | `false` | Enable hot code reloading in dev. |
| `:test_backend` | `:mock \| :headless \| :windowed` | `:mock` | Test backend selection. |
| `:validate_props` | `boolean()` | `false` | Enable renderer-side prop validation. When `true`, the renderer emits diagnostic events for unknown or invalid props. Useful in dev/test to catch typos and type mismatches early. |

#### Code reloader options

When `:code_reloader` is set to a keyword list, these options are
supported:

| Key | Type | Default | Purpose |
|---|---|---|---|
| `:debounce_ms` | `integer()` | `100` | Milliseconds to wait after a file change before recompiling. Prevents rapid recompilation during multi-file saves. |
| `:rebuild_artifacts` | `[:bin] \| [:bin, :wasm]` | `[:bin]` | Which Rust artifacts to rebuild when `.rs` files change. Add `:wasm` to also rebuild the WASM renderer. |
| `:dirs` | `[String.t()]` | Mix project's `elixirc_paths` | Directories to watch for Elixir file changes. Override if your source lives outside the standard paths. |

Rust file changes (`.rs`, `Cargo.toml`) use a separate debounce of
200ms (not configurable) because Cargo builds are heavier and benefit
from more coalescing.

## Runtime options (start_link/2)

`Plushie.start_link/2` starts a Plushie application. The first argument
is the app module (implementing `Plushie.App`), and the second is an
optional keyword list of options:

```elixir
Plushie.start_link(MyApp, binary: Plushie.Binary.path!(), daemon: true)
```

### Common options

| Option | Type | Default | Purpose |
|---|---|---|---|
| `:app_opts` | `term()` | `[]` | Forwarded to `app.init/1`. Use this to pass startup configuration to your app. |
| `:binary` | `String.t()` | auto-resolved | Path to the renderer binary. Usually resolved automatically via `Plushie.Binary.path!/0`. |
| `:name` | `atom()` | `Plushie` | Supervisor registration name. The Runtime registers as `{name}.Runtime`, the Bridge as `{name}.Bridge`. |
| `:daemon` | `boolean()` | `false` | Keep running after the last window closes. In both modes, `update/2` receives `%SystemEvent{type: :all_windows_closed}`. Without daemon, the runtime shuts down after that update. With daemon, it continues running so you can open new windows. |

### Transport

| Option | Type | Default | Purpose |
|---|---|---|---|
| `:transport` | `:spawn \| :stdio \| {:iostream, pid}` | `:spawn` | How the SDK communicates with the renderer. See [transport modes](#transport-modes). |
| `:format` | `:msgpack \| :json` | `:msgpack` | Wire protocol format. JSON is human-readable, useful for debugging. |

### Advanced

| Option | Type | Default | Purpose |
|---|---|---|---|
| `:code_reloader` | `boolean() \| keyword()` | `false` | Override the config-level code_reloader setting for this instance. |
| `:log_level` | `atom()` | `:error` | Renderer log level (`:error`, `:warn`, `:info`, `:debug`). Ignored if `RUST_LOG` is set. |
| `:renderer_args` | `[String.t()]` | `[]` | Extra CLI arguments appended to the renderer command. Only applies in `:spawn` transport mode. |

## App settings callback

The optional `c:Plushie.App.settings/0` callback provides
application-level defaults to the renderer at startup. These are
sent once during the initial handshake and affect all windows.

```elixir
defmodule MyApp do
  use Plushie.App
  import Plushie.UI

  def settings do
    [
      default_text_size: 16,
      theme: :dark,
      fonts: ["priv/fonts/inter.ttf"],
      default_event_rate: 60
    ]
  end

  def init(_opts), do: %{}
  def update(model, _event), do: model

  def view(_model) do
    window "main", title: "MyApp" do
      text("hello", "Hello")
    end
  end
end
```

| Key | Type | Default | Purpose |
|---|---|---|---|
| `default_font` | `map()` | system default | Default font specification (same format as font props). |
| `default_text_size` | `number()` | renderer default | Default text size in pixels for all text widgets. |
| `antialiasing` | `boolean()` | `true` | Enable font antialiasing. |
| `vsync` | `boolean()` | `true` | Synchronize frame presentation with the display refresh rate. Disabling can improve performance on some platforms. |
| `scale_factor` | `number()` | `1.0` | Multiplier on top of OS DPI scaling. Setting `2.0` on a 2x HiDPI display gives 4x physical pixels per logical pixel. Per-window overrides are available via the `scale_factor` window prop. |
| `theme` | `atom() \| map()` | renderer default | Built-in theme (`:dark`, `:light`, `:nord`, `:system`, etc.) or a custom palette. See `Plushie.Type.Theme`. |
| `fonts` | `[String.t()]` | `[]` | Paths to font files to load. Loaded fonts are available by family name in any widget's `font:` prop. |
| `default_event_rate` | `integer()` | unlimited | Maximum events per second for coalescable event types (mouse moves, scroll, slider drags, animation frames). Set to 60 for most apps, lower for remote rendering. Per-subscription `max_rate` and per-widget `event_rate` override this. |

## Widget discovery

Native widgets are auto-detected via `Plushie.Widget.WidgetProtocol`
protocol consolidation at compile time. Any module that implements the
protocol and exports `native_crate/0` is included in `mix plushie.build`
automatically.

`Plushie.WidgetRegistry` exposes the discovered widgets. No
configuration is needed. Add a native widget to your dependencies
and it appears in the next build.

Pure Elixir widgets (those with `view/2` or `view/3` callbacks) do not
require protocol consolidation or build system integration. They work
with any renderer binary, including precompiled downloads.

## Transport modes

The renderer communicates with the SDK over a language-agnostic wire
protocol ([MessagePack](https://msgpack.org/) or JSON over a byte
stream). The SDK supports three transport modes:

### :spawn (default)

The SDK spawns the renderer as a child process via an
[Erlang Port](https://www.erlang.org/doc/apps/erts/ports.html).
Communication happens over the process's stdin/stdout. This is the
default for local development. `mix plushie.gui` uses this mode.

The Bridge manages the Port lifecycle: starting, monitoring, and
restarting the renderer on crash (with exponential backoff). The
renderer process inherits `RUST_LOG` from the environment.

### :stdio

The renderer spawns the Elixir app (via `plushie --exec "mix ..."`).
Communication happens over the BEAM's own stdin/stdout. The Elixir app
reads events from stdin and writes snapshots/patches to stdout.

This mode is used by the renderer's `--exec` flag, which starts the
renderer first, then launches the Elixir app as a subprocess. The
`:binary` option is ignored since no subprocess is spawned from the
Elixir side.

### {:iostream, pid}

A message-based adapter for custom transports. The `pid` is a process
that bridges between the wire protocol and an arbitrary transport (SSH
channel, TCP socket, Unix socket, WebSocket, etc.).

The adapter process must handle these messages:

| Direction | Message | Description |
|---|---|---|
| Bridge -> Adapter | `{:iostream_bridge, bridge_pid}` | Sent during init. The adapter stores the bridge pid for sending data back. |
| Bridge -> Adapter | `{:iostream_send, iodata}` | Protocol data to write to the transport. |
| Adapter -> Bridge | `{:iostream_data, binary}` | One complete protocol message received from the transport. |
| Adapter -> Bridge | `{:iostream_closed, reason}` | Transport closed. The bridge handles shutdown. |

The adapter is responsible for framing, splitting the byte stream
into complete protocol messages before sending `{:iostream_data, ...}`.
`Plushie.Transport.Framing` provides frame encode/decode for
length-prefixed byte streams (the standard wire framing).

This mode enables remote rendering: the Elixir app runs on one machine
(server, embedded device, cloud), the renderer runs on another (desktop,
laptop, mobile). The wire protocol is identical; only the transport
layer differs. See the [Shared State guide](../guides/16-shared-state.md)
for a complete SSH example.

## Test configuration

`Plushie.Test.setup!/1` accepts options for the test session pool:

| Option | Type | Default | Purpose |
|---|---|---|---|
| `:pool_name` | `atom()` | `Plushie.TestPool` | Registration name for the session pool process. |
| `:max_sessions` | `integer()` | `max(schedulers * 8, 128)` | Maximum concurrent test sessions. Higher values allow more parallel tests but use more renderer memory. |

The test backend is selected via the `PLUSHIE_TEST_BACKEND` environment
variable or `config :plushie, :test_backend`. See the
[Testing reference](testing.md) for backend setup and CI configuration.

## See also

- [Mix Tasks reference](mix-tasks.md) - binary resolution, build
  options, and all task flags
- [Wire Protocol reference](wire-protocol.md) - message formats and
  framing details
- [Testing reference](testing.md) - test backends and session pool
- `Plushie.Binary` - binary resolution logic and version
- `Plushie.Bridge` - transport management and restart behaviour
- `Plushie.WidgetRegistry` - widget discovery at compile time
- `Plushie.App` - the full callback specification including `settings/0`
