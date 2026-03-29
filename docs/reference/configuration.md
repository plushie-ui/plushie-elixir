# Configuration reference

Plushie is configured through environment variables, application
config, and auto-detection. Most projects need zero configuration
beyond building the binary.

## Environment variables

| Variable | Purpose | Default |
|---|---|---|
| `PLUSHIE_BINARY_PATH` | Explicit path to the renderer binary (overrides all resolution) | unset |
| `PLUSHIE_SOURCE_PATH` | Path to local Rust source checkout (enables local-source builds) | unset |
| `PLUSHIE_TEST_BACKEND` | Test backend: `mock`, `headless`, `windowed` | `mock` |
| `PLUSHIE_UPDATE_SCREENSHOTS` | When set, update screenshot golden files instead of comparing | unset |
| `PLUSHIE_UPDATE_SNAPSHOTS` | When set, update tree-hash snapshot files instead of comparing | unset |
| `RUST_LOG` | Controls renderer log verbosity (`error`, `warn`, `info`, `debug`, `trace`). Bridge forwards this to the renderer process. | unset |

## Application config

Set in `config/*.exs` under `config :plushie`.

| Key | Type | Purpose | Default |
|---|---|---|---|
| `:binary_path` | `String.t()` | Explicit binary path (deployment) | `nil` |
| `:source_path` | `String.t()` | Rust source checkout path | `nil` |
| `:build_name` | `String.t()` | Custom binary name | `"app-renderer"` |
| `:build_profile` | `:release \| :debug` | Cargo build profile | `:debug` |
| `:artifacts` | `[:bin] \| [:bin, :wasm]` | Which artifacts to build/download | `[:bin]` |
| `:bin_file` | `String.t()` | Override binary output path | `nil` |
| `:wasm_dir` | `String.t()` | Override WASM output directory | `nil` |
| `:code_reloader` | `boolean() \| keyword()` | Dev-mode live reload. Keyword opts: `:debounce_ms`, `:rebuild_artifacts` | `false` |
| `:test_backend` | `:mock \| :headless \| :windowed` | Test backend selection | `:mock` |

## start_link options

`Plushie.start_link/1` accepts these options at runtime:

| Option | Type | Purpose | Default |
|---|---|---|---|
| `:app` | `module()` | App module implementing `Plushie.App` | (required) |
| `:app_opts` | `term()` | Forwarded to `app.init/1` | `[]` |
| `:binary` | `String.t()` | Path to renderer binary | auto-resolved |
| `:name` | `atom()` | Supervisor registration name | `Plushie` |
| `:daemon` | `boolean()` | Keep running after last window closes | `false` |
| `:code_reloader` | `boolean() \| keyword()` | Dev-mode live reload | `false` |
| `:transport` | `:spawn \| :stdio \| {:iostream, pid}` | Transport mode | `:spawn` |
| `:format` | `:msgpack \| :json` | Wire format | `:msgpack` |
| `:log_level` | `atom()` | Renderer log level | `:error` |
| `:renderer_args` | `[String.t()]` | Extra CLI args for renderer | `[]` |

## SDK-owned version

The `BINARY_VERSION` file at the package root contains the renderer
version this SDK targets. Read it via `Plushie.Binary.binary_version/0`.
This file is SDK-owned and should not be edited manually.

## Widget discovery

Native widgets are auto-detected via `Plushie.Widget.WidgetProtocol`
consolidation. `Plushie.WidgetRegistry` exposes the discovered
widgets at compile time. No configuration needed -- if a module
implements the protocol and exports `native_crate/0`, it is
included in `mix plushie.build` automatically.

## Transport modes and remote rendering

The renderer communicates with SDKs over a language-agnostic wire
protocol (MessagePack over a byte stream). The Elixir SDK supports
three transport modes, controlled by the `:transport` option:

| Mode | Description | Use case |
|---|---|---|
| `:spawn` | Spawns the renderer as a child process via Erlang Port | Default, local development |
| `:stdio` | Reads/writes the BEAM's stdin/stdout | `plushie --exec` (renderer spawns Elixir) |
| `{:iostream, pid}` | Message-based adapter for custom transports | SSH, TCP, Unix sockets, Nerves, remote desktop |

When `:transport` is `:stdio` or `{:iostream, pid}`, the `:binary`
option is ignored (no subprocess is spawned).

In a remote rendering setup, the Elixir side has minimal dependencies:
just the BEAM and MessagePack (the `:msgpax` package). No display
server, GPU, or windowing libraries are needed on the machine running
your application logic. The renderer binary runs on the machine with
the display.

### iostream adapter contract

The iostream adapter process must handle these messages:

| Direction | Message | Description |
|---|---|---|
| Bridge -> Adapter | `{:iostream_bridge, bridge_pid}` | Sent during init; adapter stores the bridge pid |
| Adapter -> Bridge | `{:iostream_data, binary}` | One complete protocol message per delivery |
| Bridge -> Adapter | `{:iostream_send, iodata}` | Adapter writes this to the underlying transport |
| Adapter -> Bridge | `{:iostream_closed, reason}` | Transport closed; bridge handles reconnect/shutdown |

See `Plushie.Bridge` for full transport and framing details.
`Plushie.Transport.Framing` provides frame encode/decode for raw
byte stream transports (SSH channels, raw sockets).

## See also

- [Mix tasks reference](mix-tasks.md) -- binary resolution order
- [Wire protocol reference](wire-protocol.md) -- message formats
  and framing
- `Plushie.Binary` -- binary resolution logic
- `Plushie.Bridge` -- transport and wire format details
- `Plushie.WidgetRegistry` -- widget discovery
