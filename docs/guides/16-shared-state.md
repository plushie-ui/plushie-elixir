# Shared State

The pad is feature-complete. In this final chapter we take it one step
further: make it **collaborative**. Multiple people connect to the same
pad over SSH and see each other's changes in real time.

## Architecture

Plushie apps communicate with the renderer over a byte stream. By
default that stream is stdio to a local process, but it can be any
transport, including an SSH channel.

The key insight: each connected client gets its own `Plushie.Runtime`.
A shared GenServer holds the authoritative model and broadcasts changes
to all clients via `Runtime.dispatch/2`. This gives you the full SDK
pipeline per client (error isolation, tree diffing, subscriptions,
event coalescing) while keeping state centralized.

```
 ssh client 1 ──SSH──┐              ┌── Runtime 1 (tree diff, patch)
                      ├── iostream ──┤
 ssh client 2 ──SSH──┘              └── Runtime 2 (tree diff, patch)
                                            │
                                    Shared GenServer
                                    (authoritative model,
                                     update/2, broadcast)
```

Each SSH channel acts as an iostream adapter. Events from any client
are decoded, forwarded to the shared server, which runs `update/2`
centrally and broadcasts the result. Each client's Runtime receives
the broadcast as a custom event, replaces its local model, re-renders,
diffs, and sends only the patches to the renderer.

## Broadcast event

Define a struct for the shared server to dispatch through each
client's Runtime:

```elixir
defmodule PlushiePad.Broadcast do
  @enforce_keys [:model]
  defstruct [:model]
end
```

Handle it in your app's `update/2` to replace the local model with
the authoritative state:

```elixir
def update(_model, %PlushiePad.Broadcast{model: shared_model}) do
  shared_model
end
```

## Shared state server

The shared GenServer holds the authoritative model, runs `update/2`
with error isolation, and broadcasts via `Runtime.dispatch/2`:

```elixir
defmodule PlushiePad.Shared do
  use GenServer

  require Logger

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, :ok, opts)
  def get_model(server), do: GenServer.call(server, :get_model)
  def connect(server, id, runtime), do: GenServer.call(server, {:connect, id, runtime})
  def disconnect(server, id), do: GenServer.cast(server, {:disconnect, id})
  def event(server, event), do: GenServer.cast(server, {:event, event})

  @impl true
  def init(:ok) do
    {:ok, %{model: PlushiePad.init([]), clients: %{}}}
  end

  @impl true
  def handle_call(:get_model, _from, state) do
    {:reply, state.model, state}
  end

  @impl true
  def handle_call({:connect, id, runtime}, _from, state) do
    Process.monitor(runtime)
    clients = Map.put(state.clients, id, runtime)
    {:reply, :ok, %{state | clients: clients}}
  end

  @impl true
  def handle_cast({:event, event}, state) do
    case safe_update(state.model, event) do
      {:ok, model} ->
        broadcast(state.clients, model)
        {:noreply, %{state | model: model}}

      :error ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    clients =
      state.clients
      |> Enum.reject(fn {_id, p} -> p == pid end)
      |> Map.new()

    {:noreply, %{state | clients: clients}}
  end

  defp safe_update(model, event) do
    try do
      result = PlushiePad.update(model, event)

      model =
        case result do
          {m, _commands} -> m
          m -> m
        end

      {:ok, model}
    rescue
      e ->
        Logger.error("Shared: update/2 crashed: #{Exception.message(e)}")
        :error
    end
  end

  defp broadcast(clients, model) do
    event = %PlushiePad.Broadcast{model: model}

    Enum.each(clients, fn {_id, runtime} ->
      Plushie.Runtime.dispatch(runtime, event)
    end)
  end
end
```

When any client sends an event, the server runs `update/2` inside a
`try/rescue` so one client's bad input cannot crash the shared state.
Process monitoring cleans up disconnected clients automatically.

The important detail: `Runtime.dispatch/2` pushes the broadcast event
through the standard Runtime pipeline. The Runtime calls `update/2`
with your broadcast struct, renders the new model via `view/1`, diffs
against the previous tree, and sends only the changed patches to the
renderer. No full snapshots, no manual tree normalization.

## SSH channel as iostream adapter

Each SSH connection gets a channel that acts as an iostream adapter
for a dedicated `Plushie.Runtime`. The channel translates between
SSH framing and the iostream protocol that the Bridge speaks:

```elixir
defmodule PlushiePad.SshChannel do
  @behaviour :ssh_server_channel

  alias Plushie.Transport.Framing

  defstruct [:shared, :client_id, :conn, :channel, :bridge, :plushie_sup, buffer: <<>>]

  @impl true
  def init([shared]) do
    {:ok, %__MODULE__{shared: shared, client_id: "ssh-#{:erlang.unique_integer([:positive])}"}}
  end

  @impl true
  def handle_msg({:ssh_channel_up, channel, conn}, state) do
    state = %{state | conn: conn, channel: channel}

    # Seed the client with the current authoritative model
    model = PlushiePad.Shared.get_model(state.shared)

    plushie_name = :"plushie_pad_#{state.client_id}"

    {:ok, sup} =
      Plushie.start_link(PlushiePad,
        name: plushie_name,
        transport: {:iostream, self()},
        format: :msgpack,
        daemon: true,
        app_opts: [shared_model: model]
      )

    runtime = Plushie.runtime_for(plushie_name)
    PlushiePad.Shared.connect(state.shared, state.client_id, runtime)

    {:ok, %{state | plushie_sup: sup}}
  end

  # iostream protocol: Bridge registers itself
  def handle_msg({:iostream_bridge, bridge_pid}, state) do
    {:ok, %{state | bridge: bridge_pid}}
  end

  # iostream protocol: Bridge sends data to the renderer
  def handle_msg({:iostream_send, data}, state) do
    packet = Framing.encode_packet(data) |> IO.iodata_to_binary()
    :ssh_connection.send(state.conn, state.channel, packet)
    {:ok, state}
  end

  def handle_msg(_msg, state), do: {:ok, state}

  @impl true
  def handle_ssh_msg({:ssh_cm, _conn, {:data, _channel, 0, data}}, state) do
    combined = state.buffer <> data
    {frames, buffer} = Framing.decode_packets(combined)
    state = Enum.reduce(frames, state, &handle_frame/2)
    {:ok, %{state | buffer: buffer}}
  end

  def handle_ssh_msg({:ssh_cm, _conn, {:closed, _channel}}, state) do
    cleanup(state)
    {:stop, state.channel, state}
  end

  def handle_ssh_msg(_msg, state), do: {:ok, state}

  @impl true
  def terminate(_reason, state) do
    cleanup(state)
    :ok
  end

  defp handle_frame(frame, state) do
    case Plushie.Protocol.Decode.decode_message(frame, :msgpack) do
      {:hello, _} ->
        # Handshake: forward to Bridge
        if state.bridge, do: send(state.bridge, {:iostream_data, frame})
        state

      %_{} = event ->
        # User events go to shared server for centralized update
        PlushiePad.Shared.event(state.shared, event)
        state

      _ ->
        if state.bridge, do: send(state.bridge, {:iostream_data, frame})
        state
    end
  end

  defp cleanup(state) do
    PlushiePad.Shared.disconnect(state.shared, state.client_id)
    if state.bridge, do: send(state.bridge, {:iostream_closed, :ssh_closed})

    if state.plushie_sup do
      try do
        Plushie.stop(state.plushie_sup)
      catch
        :exit, _ -> :ok
      end
    end
  end
end
```

The channel decodes incoming frames to separate handshake messages
(forwarded to Bridge) from user events (forwarded to Shared). Outgoing
data from the Bridge gets SSH framing added before transmission.

On channel open, the channel fetches the current model, starts a
Plushie supervisor with iostream transport, and registers the runtime
with the shared server. From then on, the shared server broadcasts
model changes to the runtime via `dispatch/2`, and the runtime handles
tree diffing and patching automatically.

## SSH server with key authentication

The server uses Erlang's built-in `:ssh` daemon. On first start, it
generates an Ed25519 host key (using `ssh-keygen` if available,
falling back to Erlang's `:public_key` module). Client authentication
uses the user's existing SSH keys via `~/.ssh/authorized_keys`:

```elixir
defmodule PlushiePad.SshServer do
  def start(shared, port \\ 2222) do
    :ok = Application.ensure_started(:crypto)
    :ok = Application.ensure_started(:asn1)
    :ok = Application.ensure_started(:public_key)
    :ok = Application.ensure_started(:ssh)

    system_dir = ensure_host_key()
    user_dir = Path.expand("~/.ssh")

    {:ok, _} =
      :ssh.daemon({127, 0, 0, 1}, port,
        system_dir: String.to_charlist(system_dir),
        user_dir: String.to_charlist(user_dir),
        auth_methods: ~c"publickey",
        subsystems: [{~c"plushie", {PlushiePad.SshChannel, [shared]}}]
      )

    IO.puts("SSH server listening on localhost:#{port}")
  end

  defp ensure_host_key do
    dir = Path.join(["priv", "ssh"])
    File.mkdir_p!(dir)
    key_file = Path.join(dir, "ssh_host_ed25519_key")

    unless File.exists?(key_file) do
      case System.find_executable("ssh-keygen") do
        nil -> generate_key_erlang(key_file)
        _ -> System.cmd("ssh-keygen", ["-t", "ed25519", "-f", key_file, "-N", "", "-q"])
      end

      IO.puts("Generated SSH host key: #{key_file}")
    end

    dir
  end

  defp generate_key_erlang(path) do
    key = :public_key.generate_key({:namedCurve, :ed25519})
    pem = :public_key.pem_encode([:public_key.pem_entry_encode(:ECPrivateKey, key)])
    File.write!(path, pem)
  end
end
```

The host key persists in `priv/ssh/` so the server identity is stable
across restarts. Clients authenticate with their existing SSH keys.

## Starting the server

Add a mix task to start everything:

```elixir
defmodule Mix.Tasks.PlushiePad.Server do
  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")
    {:ok, shared} = PlushiePad.Shared.start_link()
    PlushiePad.SshServer.start(shared)
    Process.sleep(:infinity)
  end
end
```

## Connecting

Start the server in one terminal:

```bash
mix plushie_pad.server
```

Connect from another terminal using the Plushie renderer over SSH:

```bash
plushie \
  --exec-bin ssh \
  --exec-arg -p \
  --exec-arg 2222 \
  --exec-arg localhost \
  --exec-arg -s \
  --exec-arg plushie
```

Open a third terminal and connect again. Both windows show the same
pad. Edit an experiment in one window and click Save. The other
window updates instantly.

This is the same wire protocol, the same renderer binary, the same
`view/1` function. The only difference is the transport: SSH instead
of stdio. Your Elixir code runs on the server; the renderer runs
wherever there is a screen.

## Why Runtime.dispatch?

The previous version of this demo sent full UI tree snapshots to each
client on every change. With `Runtime.dispatch/2`, you get:

- **Tree diffing**: only changed patches are sent, not the full tree
- **Error isolation**: if one client's event crashes `update/2`, the
  shared server catches it without affecting other clients
- **Subscriptions**: each client Runtime manages its own subscription
  lifecycle (timers, key events, etc.)
- **Event coalescing**: rapid events (typing, scrolling) are coalesced
  by the Runtime before rendering

The shared server stays simple: hold model, run update, broadcast.
The SDK pipeline handles everything else.

## Per-client state

When some state is per-client (like a dark mode toggle), define it
in your model and preserve it across broadcasts. The collab demo in
the `plushie-demos` repository shows this pattern:

```elixir
def update(model, %Collab.Broadcast{model: shared_model, originator_id: originator_id}) do
  if originator_id == model.client_id do
    # Originator: local model is already up to date, just sync status
    %{model | status: shared_model.status}
  else
    # Other clients: replace shared fields, keep per-client state
    %{shared_model | dark_mode: model.dark_mode, client_id: model.client_id}
  end
end
```

The originator_id pattern prevents double-applying state changes on the
client that originated the event. Other clients replace their shared
fields with the broadcast state while preserving local preferences.

## Verify it

The shared GenServer is a plain GenServer that can be tested without
SSH:

```elixir
test "shared server broadcasts model changes" do
  {:ok, shared} = PlushiePad.Shared.start_link()

  # Start a real Runtime as the client
  {:ok, sup} =
    Plushie.start_link(PlushiePad,
      name: :test_client,
      transport: {:iostream, self()},
      format: :msgpack,
      daemon: true,
      app_opts: [shared_model: PlushiePad.Shared.get_model(shared)]
    )

  runtime = Plushie.runtime_for(:test_client)
  PlushiePad.Shared.connect(shared, "test", runtime)

  PlushiePad.Shared.event(shared, %WidgetEvent{type: :click, id: "save"})

  # The runtime received a Broadcast event via dispatch, re-rendered,
  # and sent a patch to us (the iostream adapter)
  assert_receive {:iostream_send, _data}, 1000

  Plushie.stop(sup)
end
```

---

WebSocket is another viable transport for shared state, particularly
for browser-based collaboration where SSH is not available. The wire
protocol is the same; only the transport layer changes. See the collab
demo in the `plushie-demos` repository for a WebSocket-based example
that includes origin checking, rate limiting, and per-client state.

You now have a collaborative editor with file management, styling,
animation, subscriptions, effects, canvas drawing, custom widgets,
tests, and shared state over SSH. The
[reference docs](../reference/built-in-widgets.md) cover each topic
in depth when you need it.
