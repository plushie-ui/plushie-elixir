# Running plushie

Plushie's **renderer** draws windows and handles input. Your Elixir
code (the **host**) manages state and builds the UI tree. They talk
over a wire protocol -- locally through a pipe, remotely over SSH,
or through any transport you provide. This guide covers all the ways
to connect them.

## Local desktop

The simplest setup: the host spawns the renderer as a child process.

```sh
mix plushie.gui MyApp
```

Or from code:

<!-- test: running_start_link_default_test -- keep this code block in sync with the test -->
```elixir
{:ok, pid} = Plushie.start_link(MyApp)
```

The renderer is resolved automatically. For most projects,
`mix plushie.download` fetches a precompiled renderer and you're done.
If you have native Rust extensions, `mix plushie.build` compiles a
custom renderer. You can also set `PLUSHIE_BINARY_PATH` or
`config :plushie, :binary_path` explicitly.

### Dev mode

`mix plushie.gui` watches your source files and reloads on change.
Edit code, save, see the result instantly. The model state is preserved
across reloads.

```sh
mix plushie.gui MyApp              # live reload enabled
mix plushie.gui MyApp --no-watch   # disable file watching
```

### Exec mode

The renderer can spawn the host instead of the other way around. This
is useful when plushie is the entry point (a release binary or launcher)
and it's the foundation for remote rendering over SSH.

```sh
plushie --exec "mix plushie.stdio MyApp"
```

The renderer controls the lifecycle. When the user closes the window,
the renderer closes stdin, and the plushie process exits cleanly.

## Remote rendering

Your host runs on a server. You want to see its UI on your laptop.
The renderer runs locally (where your display is), the host runs
remotely (where the data is), and SSH connects them:

```
[your laptop]                    [server]
renderer        <--- SSH --->    host
  draws windows                    init/update/view
  handles input                    business logic
```

Your `init/update/view` code doesn't change at all.

### Prerequisites

- **Your laptop**: the `plushie` renderer installed and on your PATH.
  Download from the GitHub releases page, or build with
  `cargo install plushie` if you have a Rust toolchain.
- **The server**: your Elixir project deployed with its dependencies.
  The server does NOT need the renderer or a display server.
- **SSH access**: you can `ssh user@server` from your laptop.

### Quick start

```sh
plushie --exec "ssh user@server 'cd /app && mix plushie.stdio MyApp'"
```

The renderer on your laptop spawns an SSH session, which starts the
host on the server. The wire protocol flows through the SSH tunnel.
Each connection starts a fresh BEAM on the server, so there's a 1-2
second startup overhead.

### In-BEAM Erlang SSH

If your server already runs a BEAM (a Phoenix service, a data
pipeline, an embedded device), you can skip that startup entirely.
OTP includes a built-in SSH server. Start it in your supervisor, and
the renderer connects directly to the running VM. No new process, no
compilation, instant startup.

This gives you access to everything in the running VM: ETS tables,
GenServers, PubSub, your database pool. It's the path to building
dashboards for live server state, admin tools backed by real data,
and diagnostic UIs for embedded devices.

Setting this up requires familiarity with OTP's `:ssh` application.
The [custom transports](#example-erlang-ssh-channel-adapter) section
has a full SSH channel adapter example with commentary.

### Binary distribution

The renderer always runs on the **display machine** (your laptop,
not the server). How you get it there depends on your project:

| Your project uses | Renderer needed | How to get it |
|---|---|---|
| Built-in widgets only | Precompiled | `mix plushie.download` or GitHub release |
| Pure Elixir extensions | Precompiled | Same -- composites don't need a custom build |
| Native Rust extensions | Custom build | `mix plushie.build` targeting your laptop's architecture |

The server doesn't need the renderer at all. It only needs your
Elixir project and its dependencies.

## Resiliency

Things go wrong. Renderers crash, code has bugs, networks drop.
Plushie handles these without losing your model state.

### Renderer crashes

If the renderer crashes (segfault, GPU error, out of memory), the
host detects it and restarts automatically with exponential backoff.
Your model state is preserved -- the new renderer receives fresh
settings, a full snapshot of the current UI, and re-synced
subscriptions and windows. The user sees a brief flicker, then the
UI is back.

The host retries up to 5 times (100ms, 200ms, 400ms, 800ms, 1.6s).
If all retries fail, it logs troubleshooting steps and the plushie
supervisor stops. The rest of your application is unaffected -- only
the plushie process tree exits. A successful connection resets the
retry counter, so intermittent crashes get a fresh budget each time.

### Exceptions in your code

If `update/2` or `view/1` raises, the runtime catches it, logs the
error with a full stacktrace, and keeps the previous model state.
The window stays open and continues responding to events. You don't
need try/rescue in your callbacks.

After 100 consecutive errors, log output is suppressed to prevent
flooding, with periodic reminders every 1000 errors. Telemetry
events continue firing for monitoring.

### Network drops

When an SSH connection drops, both sides detect the broken pipe:

- **The renderer** sees the host's stdout close. It can display an
  error or retry the connection.
- **The host** sees stdin close. Without daemon mode, the plushie
  process exits (the rest of your service is unaffected). With
  daemon mode, plushie keeps running with the model preserved.

When a new renderer connects (another SSH session), the host sends a
snapshot of the current state. No restart, no state loss, no cold
start.

<!-- test: running_start_link_stdio_daemon_test -- keep this code block in sync with the test -->
```elixir
Plushie.start_link(MyApp, transport: :stdio, daemon: true)
```

### Window close

When the user closes the last window, your `update/2` receives the
event. You can save state, persist data, or show a confirmation
dialog. In non-daemon mode, the plushie process exits. In daemon mode,
plushie keeps running and waits for a new renderer to connect.

## Event rate limiting

Over a network, continuous events like mouse moves, scroll, and
slider drags can overwhelm the connection. A standard mouse generates
60+ events per second; a gaming mouse can hit 1000. Rate limiting
tells the renderer to buffer these and deliver at a controlled
frequency. Discrete events like clicks and key presses are never
rate-limited.

Rate limiting is useful locally too -- a dashboard doesn't need 1000
mouse move updates per second even on a fast machine.

### Global default

Set `default_event_rate` in your module's `settings/0` callback:

<!-- test: running_settings_default_event_rate_test -- keep this code block in sync with the test -->
```elixir
def settings do
  [default_event_rate: 60]   # 60 events/sec -- good for most cases
end
```

For a monitoring dashboard:

<!-- test: running_settings_low_event_rate_test -- keep this code block in sync with the test -->
```elixir
def settings do
  [default_event_rate: 15]
end
```

### Per-subscription

Override the global rate for specific event sources:

<!-- test: running_subscription_mouse_move_with_rate_test -- keep this code block in sync with the test -->
```elixir
def subscribe(model) do
  [
    Subscription.on_mouse_move(:mouse, max_rate: 30),
    Subscription.on_animation_frame(:frame, max_rate: 60),
    Subscription.on_mouse_move(:capture, max_rate: 0)   # capture only, no events
  ]
end
```

### Per-widget

Override the rate on individual widgets:

```elixir
slider("volume", {0, 100}, model.volume, event_rate: 15)
slider("seek", {0, model.duration}, model.position, event_rate: 60)
```

### Latency and animations

| Transport | Localhost | LAN | WAN |
|---|---|---|---|
| Port (local) | < 1ms | -- | -- |
| SSH | -- | 1-5ms | 20-150ms |

On a LAN, animations are smooth and interactions feel instant. Over a
WAN (50ms+), user interactions have a visible round-trip delay. Design
for this by keeping UI responsive to local input (hover effects, focus
states) and accepting that model updates lag by the round-trip time.

## Custom transports

For advanced use cases, the iostream transport lets you bridge any
I/O mechanism to plushie. Write an adapter process that speaks a simple
four-message protocol, and plushie handles the rest. Most projects
don't need this -- the built-in local and SSH transports cover the
common cases.

### The protocol

| Direction | Message | Purpose |
|---|---|---|
| Bridge -> Adapter | `{:iostream_bridge, bridge_pid}` | Init handshake. Adapter stores the pid. |
| Adapter -> Bridge | `{:iostream_data, binary}` | One complete protocol message. |
| Bridge -> Adapter | `{:iostream_send, iodata}` | Protocol message to send. |
| Adapter -> Bridge | `{:iostream_closed, reason}` | Transport closed. Bridge shuts down. |

The Bridge monitors the adapter process. If it exits, the Bridge
shuts down and notifies the runtime.

### Example: TCP adapter

A minimal adapter for TCP sockets:

<!-- test: running_tcp_adapter_compiles_test -- keep this code block in sync with the test -->
```elixir
defmodule MyApp.TCPAdapter do
  use GenServer

  def start_link(socket), do: GenServer.start_link(__MODULE__, socket)

  def init(socket) do
    # Active mode: TCP data arrives as messages
    :inet.setopts(socket, active: true)
    {:ok, %{socket: socket, bridge: nil, buffer: <<>>}}
  end

  # Bridge registered itself on init
  def handle_info({:iostream_bridge, bridge_pid}, state) do
    {:noreply, %{state | bridge: bridge_pid}}
  end

  # Bridge wants to send data to the renderer
  def handle_info({:iostream_send, iodata}, state) do
    :gen_tcp.send(state.socket, Plushie.Transport.Framing.encode_packet(iodata))
    {:noreply, state}
  end

  # TCP data arrived -- decode frames and forward complete messages
  def handle_info({:tcp, _socket, data}, state) do
    {messages, buffer} =
      Plushie.Transport.Framing.decode_packets(state.buffer <> data)

    for msg <- messages, do: send(state.bridge, {:iostream_data, msg})
    {:noreply, %{state | buffer: buffer}}
  end

  # TCP closed -- tell the Bridge
  def handle_info({:tcp_closed, _socket}, state) do
    if state.bridge, do: send(state.bridge, {:iostream_closed, :tcp_closed})
    {:stop, :normal, state}
  end
end
```

### Example: Erlang SSH channel adapter

This adapter uses OTP's built-in `:ssh` server to accept renderer
connections directly into a running BEAM. It requires familiarity with
the `:ssh_server_channel` behaviour.

First, start an SSH daemon in your supervisor:

```elixir
:ssh.daemon(2022,
  system_dir: ~c"/etc/plushie_ssh",
  user_dir: ~c"~/.ssh",
  subsystems: [{~c"plushie", {MyApp.SSH.Channel, []}}]
)
```

Then implement the channel handler. The key callbacks:

- `handle_msg({:ssh_channel_up, ...})` fires when the SSH channel
  opens. This is where you start the host with iostream transport.
- `handle_ssh_msg({:ssh_cm, _, {:data, ...}})` fires when bytes
  arrive from the renderer. Decode frames and forward to the Bridge.
- `handle_msg({:iostream_send, ...})` fires when the Bridge has
  data for the renderer. Encode and write to the SSH channel.
- `handle_msg({:iostream_bridge, pid})` fires during startup.
  Store the Bridge pid for forwarding.

```elixir
defmodule MyApp.SSH.Channel do
  @behaviour :ssh_server_channel

  @impl true
  def init(_args) do
    {:ok, %{bridge: nil, conn: nil, channel: nil, buffer: <<>>}}
  end

  # Renderer data arrived over SSH -- decode and forward to Bridge
  @impl true
  def handle_ssh_msg({:ssh_cm, _conn, {:data, _channel, 0, data}}, state) do
    {messages, buffer} =
      Plushie.Transport.Framing.decode_packets(state.buffer <> data)

    for msg <- messages, do: send(state.bridge, {:iostream_data, msg})
    {:ok, %{state | buffer: buffer}}
  end

  # Bridge registered itself during Plushie.start_link
  @impl true
  def handle_msg({:iostream_bridge, bridge_pid}, state) do
    {:ok, %{state | bridge: bridge_pid}}
  end

  # Bridge wants to send data to the renderer
  def handle_msg({:iostream_send, iodata}, %{conn: conn, channel: ch} = state) do
    framed = Plushie.Transport.Framing.encode_packet(iodata)
    :ssh_connection.send(conn, ch, IO.iodata_to_binary(framed))
    {:ok, state}
  end

  # SSH channel is ready -- start the host
  def handle_msg({:ssh_channel_up, channel, conn}, state) do
    {:ok, _pid} =
      Plushie.start_link(MyApp,
        transport: {:iostream, self()},
        format: :msgpack
      )

    {:ok, %{state | conn: conn, channel: channel}}
  end
end
```

### Framing

Raw byte streams (SSH channels, raw sockets) need message boundaries.
`Plushie.Transport.Framing` handles this. Transports with built-in
framing (Erlang Ports, `:gen_tcp` with `{:packet, 4}`) don't need it.

```elixir
# MessagePack: 4-byte length prefix
encoded = Framing.encode_packet(data)
{messages, remaining} = Framing.decode_packets(buffer <> chunk)

# JSON: newline-delimited
encoded = Framing.encode_line(data)
{lines, remaining} = Framing.decode_lines(buffer <> chunk)
```

## Testing

See [Testing](testing.md) for the full guide. Quick summary:

```sh
mix test                                      # pooled mock (fast, no display)
PLUSHIE_TEST_BACKEND=headless mix test          # real rendering, no display
PLUSHIE_TEST_BACKEND=windowed mix test          # real windows (needs display)
```

## How props reach the renderer

You don't need to understand this to use plushie. It's here for when
you're debugging wire format issues or writing extensions.

When you return a tree from `view/1`, it passes through four stages
before reaching the wire:

1. **Widget builders** (`Plushie.UI` macros, `Plushie.Widget.*` modules)
   return structs with raw Elixir values -- atoms, tuples, structs.

2. **Widget protocol** (`Plushie.Widget.to_node/1`) converts typed
   widget structs to plain `%{id, type, props, children}` maps.
   Values stay as raw Elixir terms.

3. **Tree normalization** (`Plushie.Tree.normalize/1`) walks the tree
   and encodes each prop value via the `Plushie.Encode` protocol:
   atoms become strings, tuples become lists, structs become maps.
   Scoped IDs are also resolved here.

4. **Protocol encoding** stringifies atom map keys to strings,
   then serializes to MessagePack or JSON.

Each stage has one job. Widget builders don't worry about wire format.
The Encode protocol doesn't know about serialization. And the Protocol
layer doesn't know about widget types.

If you call `build()` on a widget directly (e.g., in tests), you get
the raw stage-2 output -- atom keys, raw values. After `normalize`,
values are encoded. After Protocol encoding, keys are strings. This
matters when writing assertions: `build()` output has `:fill`, the
wire has `"fill"`.

## Next steps

- [Getting started](getting-started.md) -- setup, first app
- [Commands and subscriptions](commands.md) -- event rate limiting details
- [Testing](testing.md) -- three-backend test framework
- [Extensions](extensions.md) -- custom widgets, CoalesceHint for throttling
