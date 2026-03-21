# Running toddy

## Overview

Toddy separates the **Elixir runtime** (your app logic: init/update/view)
from the **renderer** (the Rust binary that draws windows). They
communicate over a wire protocol using stdin/stdout, SSH channels, or
any custom transport.

This separation enables several deployment modes:

| Mode | Description | Latency | Use case |
|---|---|---|---|
| Local spawn | Elixir spawns the renderer binary | ~0ms | Development, desktop apps |
| Exec (stdio) | Renderer spawns the Elixir process | ~0ms | Release binaries, launcher integration |
| External SSH | Renderer pipes through `ssh` | Network RTT | Remote apps, thin clients |
| In-BEAM SSH | Renderer connects to Erlang SSH daemon | Network RTT | Existing server, no new BEAM startup |
| Custom iostream | Any adapter process bridges the gap | Varies | TCP, WebSocket, custom protocols |

## Local desktop

### Standard (Elixir spawns renderer)

The default mode. Elixir starts the renderer binary as a child process:

```elixir
# From mix:
mix toddy.gui MyApp

# From code:
{:ok, pid} = Toddy.start_link(MyApp)

# Under a supervisor:
children = [{Toddy, app: MyApp}]
```

The renderer binary must be available. Toddy resolves it in order:

1. `TODDY_BINARY_PATH` environment variable
2. `config :toddy, :binary_path` application config
3. `mix toddy.download` precompiled binary in `_build`
4. `mix toddy.build` custom binary in `_build`

### Exec mode (renderer spawns Elixir)

The renderer launches the Elixir process and connects via stdin/stdout:

```sh
toddy --exec "mix toddy.stdio MyApp"
```

The Elixir side uses `:stdio` transport:

```elixir
Toddy.start_link(MyApp, transport: :stdio)
```

The `:binary` option is ignored in this mode -- no subprocess is spawned.

### Dev mode

File watching with live code reloading:

```sh
mix toddy.gui MyApp          # watches lib/, recompiles and re-renders on change
mix toddy.gui MyApp --no-watch  # disable watching
```

Or from code:

```elixir
Toddy.start_link(MyApp, dev: true)
```

## Binary distribution

| Extension type | Binary needed | How to get it |
|---|---|---|
| None (pure Elixir app) | Precompiled | `mix toddy.download` |
| Pure Elixir widget extensions | Precompiled | `mix toddy.download` |
| Native widget extensions | Custom build | `mix toddy.build` |

`mix toddy.download` fetches a precompiled binary matching your platform
and the `binary_version` in `mix.exs`. `mix toddy.build` compiles from
the Rust source (requires `TODDY_SOURCE_PATH` or `config :toddy, :source_path`).

## Remote rendering

The key insight: the **renderer runs where the display is** (the local
machine), while the **Elixir app runs where the data is** (the server).
The wire protocol connects them.

### Architecture

```
[Local machine]              [Remote server]
toddy renderer  <-- SSH -->  Elixir app (MyApp)
  draws windows               init/update/view
  handles input                business logic
```

### External SSH

The renderer pipes stdio through an SSH connection:

```sh
toddy --exec "ssh user@server 'cd /app && mix toddy.stdio MyApp'"
```

This starts a new BEAM on the remote server for each connection. Simple
to set up, but has BEAM startup overhead (~1-2s).

### In-BEAM Erlang SSH

For apps already running on a server (Phoenix, embedded systems), you
can skip the BEAM startup entirely. The renderer connects to an Erlang
SSH daemon running inside the existing BEAM. The toddy app starts
directly in the server's VM using the iostream transport.

This means:

- No new OS process or BEAM startup
- App modules are already compiled and loaded
- Access to existing ETS tables, GenServers, and application state
- Sub-second connection time

### Setting up Erlang SSH

Start an SSH daemon in your application supervisor:

```elixir
# In your application.ex or supervisor:
:ssh.daemon(2022, [
  system_dir: ~c"/etc/toddy_ssh",
  user_dir: ~c"~/.ssh",
  ssh_cli: {MyApp.SSH.CLI, []},
  # Or for channel-based handling:
  subsystems: [
    {~c"toddy", {MyApp.SSH.Channel, []}}
  ]
])
```

The SSH channel handler bridges the SSH channel to a toddy iostream
transport:

```elixir
defmodule MyApp.SSH.Channel do
  @behaviour :ssh_server_channel

  @impl true
  def init(_args) do
    {:ok, %{bridge: nil, conn: nil, channel: nil, buffer: <<>>}}
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, conn, {:data, channel, 0, data}}, state) do
    # Incoming data from the renderer -- decode frames and forward.
    {messages, buffer} =
      Toddy.Transport.Framing.decode_packets(state.buffer <> data)

    for msg <- messages do
      send(state.bridge, {:iostream_data, msg})
    end

    {:ok, %{state | buffer: buffer}}
  end

  @impl true
  def handle_msg({:iostream_bridge, bridge_pid}, state) do
    {:ok, %{state | bridge: bridge_pid}}
  end

  def handle_msg({:iostream_send, iodata}, %{conn: conn, channel: ch} = state) do
    # Outgoing data to the renderer -- frame and send over SSH.
    framed = Toddy.Transport.Framing.encode_packet(iodata)
    :ssh_connection.send(conn, ch, IO.iodata_to_binary(framed))
    {:ok, state}
  end

  def handle_msg({:ssh_channel_up, channel, conn}, state) do
    # Channel is open -- start the toddy app with iostream transport.
    {:ok, _pid} =
      Toddy.start_link(MyApp,
        transport: {:iostream, self()},
        format: :msgpack
      )

    {:ok, %{state | conn: conn, channel: channel}}
  end
end
```

## Performance tuning

### Event rate limiting

Toddy provides rate limiting at several levels to prevent flooding:

- **`default_event_rate`** in settings -- global rate limit for all
  widget events (events per second). Set via `settings/0` callback.
- **`max_rate`** per subscription -- limits events from a specific
  subscription (e.g., mouse move at 60fps instead of unlimited).
- **`event_rate`** per widget -- set on individual widgets to override
  the global default (e.g., a slider that needs high-frequency updates).

The renderer coalesces events at the configured rate, dropping
intermediate values and delivering only the latest. The Elixir side
processes events serially -- if `update/2` is slow, events naturally
queue in the mailbox.

### Latency characteristics

| Transport | Localhost RTT | LAN RTT | WAN RTT |
|---|---|---|---|
| Port (spawn) | < 1ms | -- | -- |
| stdio (exec) | < 1ms | -- | -- |
| SSH (LAN) | -- | 1-5ms | -- |
| SSH (WAN) | -- | -- | 20-150ms |
| Custom TCP | < 1ms | 1-5ms | 20-150ms |

### Animation behaviour over latency

- **Local / LAN**: Smooth. Animations play at full frame rate with
  imperceptible lag.
- **WAN (50-150ms)**: Animations play on the renderer side but user
  interactions (clicks, typing) have visible round-trip delay. Design
  for this by keeping animations renderer-side (CSS-like transitions in
  widget props) and avoiding animations that depend on rapid model updates.

## Custom transports (iostream)

The iostream transport lets you bridge any I/O mechanism to toddy.
Write an adapter process that speaks the iostream protocol, and toddy
handles the rest.

### The iostream protocol

Four messages define the contract between the Bridge and the adapter:

| Direction | Message | Purpose |
|---|---|---|
| Bridge -> Adapter | `{:iostream_bridge, bridge_pid}` | Sent during init. Adapter stores the bridge pid. |
| Adapter -> Bridge | `{:iostream_data, binary}` | One complete protocol message from the renderer. |
| Bridge -> Adapter | `{:iostream_send, iodata}` | Protocol message to send to the renderer. |
| Adapter -> Bridge | `{:iostream_closed, reason}` | Transport is closed. Bridge shuts down. |

The Bridge also monitors the adapter process. If it exits, the Bridge
shuts down and notifies the runtime.

### Writing an adapter

An adapter is any process that:

1. Receives `{:iostream_bridge, bridge_pid}` and stores the pid
2. Reads from its transport, delivers complete messages as
   `{:iostream_data, binary}`
3. Handles `{:iostream_send, iodata}` by writing to its transport
4. Sends `{:iostream_closed, reason}` when the transport closes

For raw byte streams (TCP sockets, SSH channels), use
`Toddy.Transport.Framing` to handle message boundaries:

```elixir
defmodule MyApp.TCPAdapter do
  use GenServer

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    :inet.setopts(socket, active: true)
    {:ok, %{socket: socket, bridge: nil, buffer: <<>>}}
  end

  # Bridge registered itself
  def handle_info({:iostream_bridge, bridge_pid}, state) do
    {:noreply, %{state | bridge: bridge_pid}}
  end

  # Bridge wants to send data to the renderer
  def handle_info({:iostream_send, iodata}, state) do
    framed = Toddy.Transport.Framing.encode_packet(iodata)
    :gen_tcp.send(state.socket, framed)
    {:noreply, state}
  end

  # TCP data arrived -- decode frames and forward complete messages
  def handle_info({:tcp, _socket, data}, state) do
    {messages, buffer} =
      Toddy.Transport.Framing.decode_packets(state.buffer <> data)

    for msg <- messages do
      send(state.bridge, {:iostream_data, msg})
    end

    {:noreply, %{state | buffer: buffer}}
  end

  # TCP closed
  def handle_info({:tcp_closed, _socket}, state) do
    if state.bridge, do: send(state.bridge, {:iostream_closed, :tcp_closed})
    {:stop, :normal, state}
  end
end
```

### Framing

`Toddy.Transport.Framing` provides frame encoding/decoding for raw byte
streams. Transports with built-in framing (Erlang Ports, `:gen_tcp` with
`{:packet, 4}`) don't need it.

- **MessagePack mode**: 4-byte big-endian length prefix per message.
  Use `encode_packet/1` and `decode_packets/1`.
- **JSON mode**: newline-delimited. Use `encode_line/1` and
  `decode_lines/1`.

## Testing

See [testing.md](testing.md) for the full testing guide. Three backends
at different fidelity levels:

- **`:pooled_mock`** (default) -- fast, no renderer, pure Elixir
- **`:headless`** -- real rendering, no display server
- **`:windowed`** -- real windows, needs Xvfb or a display

```sh
mix test                                      # pooled_mock
TODDY_TEST_BACKEND=headless mix test          # headless
TODDY_TEST_BACKEND=windowed mix test          # windowed (needs display)
```

## The prop encoding pipeline

Understanding how values flow from `view/1` to the wire helps when
debugging unexpected renderer behaviour or writing extensions.

```
view/1
  |  Widget builders (Toddy.UI macros, Toddy.Iced functions)
  |  return structs with raw Elixir values: atoms, tuples, structs
  v
Toddy.Widget protocol (to_node/1)
  |  Converts typed widget structs to plain %{id, type, props, children} maps
  |  Values stay as raw Elixir terms at this stage
  v
Toddy.Tree.normalize/1
  |  Walks the tree, applying the Toddy.Encode protocol to each prop value:
  |    atoms -> strings (except true/false/nil)
  |    tuples -> lists
  |    structs -> via their Toddy.Encode implementation
  |  Also handles scoped ID prefixing
  v
Toddy.Protocol.Encode
  |  stringify_keys/1 converts atom keys to string keys
  |  Serializes with Jason (JSON) or Msgpax (MessagePack)
  v
Wire bytes (sent to renderer via Port, stdio, or iostream)
```

Each stage has a single responsibility. Widget builders don't worry
about wire encoding. The Encode protocol doesn't worry about
serialization format. And the Protocol layer doesn't know about widget
types.
