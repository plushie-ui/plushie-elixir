# Shared State

The pad is feature-complete. In this final chapter we take it one step
further: make it **collaborative**. Multiple people connect to the same
pad over SSH and see each other's changes in real time.

## Architecture

Plushie apps communicate with the renderer over a byte stream. By
default that stream is stdio to a local process, but it can be any
transport, including an SSH channel. We will build a server that
accepts SSH connections and gives each client a live view of the
shared pad state.

```
 ssh client 1 ──SSH──┐
                      ├── Shared GenServer ── PlushiePad.update/2
 ssh client 2 ──SSH──┘        │
                          broadcasts
                          model to all
```

Each client gets an SSH channel adapter that speaks the Plushie wire
protocol. Events from any client go through `update/2`, and the new
model is broadcast to everyone.

## Shared state server

The shared GenServer holds the authoritative model and a registry of
connected clients:

```elixir
defmodule PlushiePad.Shared do
  use GenServer

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, :ok, opts)

  def connect(server, client_id),
    do: GenServer.call(server, {:connect, client_id, self()})

  def disconnect(server, client_id),
    do: GenServer.cast(server, {:disconnect, client_id})

  def event(server, event),
    do: GenServer.cast(server, {:event, event})

  @impl true
  def init(:ok) do
    {:ok, %{model: PlushiePad.init([]), clients: %{}}}
  end

  @impl true
  def handle_call({:connect, id, pid}, _from, state) do
    Process.monitor(pid)
    clients = Map.put(state.clients, id, pid)
    broadcast(clients, state.model)
    {:reply, :ok, %{state | clients: clients}}
  end

  @impl true
  def handle_cast({:disconnect, id}, state) do
    {:noreply, %{state | clients: Map.delete(state.clients, id)}}
  end

  @impl true
  def handle_cast({:event, event}, state) do
    model = PlushiePad.update(state.model, event)
    broadcast(state.clients, model)
    {:noreply, %{state | model: model}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    clients =
      state.clients
      |> Enum.reject(fn {_id, p} -> p == pid end)
      |> Map.new()

    {:noreply, %{state | clients: clients}}
  end

  defp broadcast(clients, model) do
    Enum.each(clients, fn {_id, pid} ->
      send(pid, {:model_changed, model})
    end)
  end
end
```

When any client sends an event, the server runs `PlushiePad.update/2`
and broadcasts the new model to all connected clients. Process
monitoring cleans up crashed connections automatically.

## SSH channel adapter

Each SSH connection gets a channel adapter that speaks the Plushie wire
protocol (MessagePack with 4-byte length-prefixed framing):

```elixir
defmodule PlushiePad.SshChannel do
  @behaviour :ssh_server_channel

  alias Plushie.Event.WidgetEvent
  alias Plushie.Transport.Framing

  defstruct [:shared, :client_id, :conn, :channel, buffer: <<>>, handshake_done: false]

  @impl true
  def init([shared]) do
    {:ok, %__MODULE__{shared: shared, client_id: "ssh-#{:erlang.unique_integer([:positive])}"}}
  end

  @impl true
  def handle_msg({:ssh_channel_up, channel, conn}, state) do
    state = %{state | conn: conn, channel: channel}

    settings =
      Plushie.Protocol.encode_settings(
        %{"antialiasing" => true, "default_text_size" => 16.0},
        :msgpack
      )

    send_packet(state, settings)
    {:ok, state}
  end

  def handle_msg({:model_changed, model}, state) do
    if state.handshake_done, do: send_snapshot(model, state)
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
    {:stop, state.channel, state}
  end

  def handle_ssh_msg(_msg, state), do: {:ok, state}

  @impl true
  def terminate(_reason, state) do
    if state.handshake_done,
      do: PlushiePad.Shared.disconnect(state.shared, state.client_id)

    :ok
  end

  defp handle_frame(frame, state) do
    case Plushie.Protocol.decode_message(frame, :msgpack) do
      {:hello, _} ->
        PlushiePad.Shared.connect(state.shared, state.client_id)
        %{state | handshake_done: true}

      %WidgetEvent{} = event ->
        if state.handshake_done,
          do: PlushiePad.Shared.event(state.shared, event)

        state

      _ ->
        state
    end
  end

  defp send_snapshot(model, state) do
    tree = PlushiePad.view(model) |> Plushie.Tree.normalize()
    data = Plushie.Protocol.encode_snapshot(tree, :msgpack)
    send_packet(state, data)
  end

  defp send_packet(state, data) do
    packet = Framing.encode_packet(data) |> IO.iodata_to_binary()
    :ssh_connection.send(state.conn, state.channel, packet)
  end
end
```

The handshake is simple: we send settings, the renderer replies with
`{:hello, _}`, and we register with the shared GenServer. From then
on, every model change triggers a full snapshot to the client. Cleanup
happens in `terminate/2`, which is called for all shutdown paths.

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
across restarts. Clients authenticate with their existing SSH keys --
no passwords, no extra configuration.

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
plushie --exec "ssh -p 2222 localhost -s plushie"
```

Open a third terminal and connect again. Both windows show the same
pad. Edit an experiment in one window and click Save. The other
window updates instantly.

This is the same wire protocol, the same renderer binary, the same
`view/1` function. The only difference is the transport: SSH instead
of stdio. Your Elixir code runs on the server; the renderer runs
wherever there is a screen.

## Verify it

The shared GenServer is a plain GenServer that can be tested without
SSH:

```elixir
test "shared server broadcasts model changes" do
  {:ok, shared} = PlushiePad.Shared.start_link()
  PlushiePad.Shared.connect(shared, "test-client")

  PlushiePad.Shared.event(shared, %WidgetEvent{type: :click, id: "save"})

  assert_receive {:model_changed, model}
  assert model.preview != nil
end
```

---

You now have a collaborative editor with file management, styling,
animation, subscriptions, effects, canvas drawing, custom widgets,
tests, and shared state over SSH. The
[reference docs](../reference/built-in-widgets.md) cover each topic
in depth when you need it.
