defmodule Julep.Test.Backend.Headless do
  @moduledoc """
  Headless test backend using the Rust renderer with iced_test Simulator.

  Spawns `julep_gui --headless` as a Port and communicates via JSONL with
  correlation-ID protocol. Provides pixel snapshots via tiny-skia (no display
  server required) and real widget rendering for visual regression testing.

  ## Requirements

  Build the renderer with headless support:

      cd native/julep_gui && cargo build --features headless

  ## Limitations

  - No real windows or GPU rendering (use `:full` for that).
  - Effects (file dialogs, clipboard) are not executed.
  - Subscriptions are not active.

  ## When to use

  Visual regression testing and protocol round-trip verification. Proves
  wire format correctness end-to-end without needing a display server.
  """

  @behaviour Julep.Test.Backend

  use GenServer

  alias Julep.Test.Element
  alias Julep.Test.Screenshot
  alias Julep.Test.Snapshot

  # -- Backend callbacks --

  @impl Julep.Test.Backend
  def start(app, opts \\ []) do
    GenServer.start(__MODULE__, {app, opts})
  end

  @impl Julep.Test.Backend
  def stop(pid), do: GenServer.stop(pid)

  @impl Julep.Test.Backend
  def find(pid, selector), do: GenServer.call(pid, {:find, selector}, 10_000)

  @impl Julep.Test.Backend
  def find!(pid, selector) do
    case find(pid, selector) do
      nil -> raise "Element not found: #{inspect(selector)}"
      element -> element
    end
  end

  @impl Julep.Test.Backend
  def click(pid, selector), do: GenServer.call(pid, {:interact, "click", selector, %{}}, 10_000)

  @impl Julep.Test.Backend
  def type_text(pid, selector, text) do
    GenServer.call(pid, {:interact, "type_text", selector, %{"text" => text}}, 10_000)
  end

  @impl Julep.Test.Backend
  def submit(pid, selector) do
    GenServer.call(pid, {:interact, "submit", selector, %{}}, 10_000)
  end

  @impl Julep.Test.Backend
  def toggle(pid, selector) do
    GenServer.call(pid, {:interact, "toggle", selector, %{}}, 10_000)
  end

  @impl Julep.Test.Backend
  def select(pid, selector, value) do
    GenServer.call(pid, {:interact, "select", selector, %{"value" => value}}, 10_000)
  end

  @impl Julep.Test.Backend
  def slide(pid, selector, value) do
    GenServer.call(pid, {:interact, "slide", selector, %{"value" => value}}, 10_000)
  end

  @impl Julep.Test.Backend
  def model(pid), do: GenServer.call(pid, :model)

  @impl Julep.Test.Backend
  def tree(pid), do: GenServer.call(pid, :tree, 10_000)

  @impl Julep.Test.Backend
  def snapshot(pid, name), do: GenServer.call(pid, {:snapshot, name}, 30_000)

  @impl Julep.Test.Backend
  def screenshot(_pid, name) do
    %Screenshot{name: name, hash: "", size: {0, 0}, rgba_data: nil}
  end

  @impl Julep.Test.Backend
  def reset(pid), do: GenServer.call(pid, :reset, 10_000)

  @impl Julep.Test.Backend
  def await_async(_pid, _tag, _timeout \\ 5000), do: :ok

  # -- GenServer --

  @impl GenServer
  def init({app, opts}) do
    renderer_path = resolve_renderer_path()

    port =
      Port.open({:spawn_executable, renderer_path}, [
        :binary,
        :exit_status,
        {:line, 65_536},
        {:args, ["--headless"]}
      ])

    {model, _commands} = init_app(app, opts)
    tree = render_tree(app, model)

    # Send initial snapshot to the renderer
    snapshot_msg = Jason.encode!(%{type: "snapshot", tree: tree})
    Port.command(port, [snapshot_msg, "\n"])

    {:ok,
     %{
       port: port,
       app: app,
       opts: opts,
       model: model,
       tree: tree,
       buffer: "",
       pending: %{},
       next_id: 1
     }}
  end

  @impl GenServer
  def handle_call({:find, selector}, from, state) do
    {id, state} = next_id(state)
    sel = encode_selector(selector)
    send_message(state.port, %{type: "query", id: id, target: "find", selector: sel})
    {:noreply, put_in(state, [:pending, id], {:find, from})}
  end

  def handle_call(:tree, from, state) do
    {id, state} = next_id(state)
    send_message(state.port, %{type: "query", id: id, target: "tree", selector: %{}})
    {:noreply, put_in(state, [:pending, id], {:tree, from})}
  end

  def handle_call({:interact, action, selector, payload}, from, state) do
    {id, state} = next_id(state)
    sel = encode_selector(selector)

    send_message(state.port, %{
      type: "interact",
      id: id,
      action: action,
      selector: sel,
      payload: payload
    })

    {:noreply, put_in(state, [:pending, id], {:interact, from, action})}
  end

  def handle_call({:snapshot, name}, from, state) do
    {id, state} = next_id(state)

    send_message(state.port, %{
      type: "snapshot_capture",
      id: id,
      name: name,
      theme: %{},
      viewport: %{}
    })

    {:noreply, put_in(state, [:pending, id], {:snapshot, from, name})}
  end

  def handle_call(:model, _from, state) do
    {:reply, state.model, state}
  end

  def handle_call(:reset, from, state) do
    {id, state} = next_id(state)
    send_message(state.port, %{type: "reset", id: id})

    {model, _commands} = init_app(state.app, state.opts)
    tree = render_tree(state.app, model)
    snapshot_msg = Jason.encode!(%{type: "snapshot", tree: tree})
    Port.command(state.port, [snapshot_msg, "\n"])

    {:noreply, put_in(%{state | model: model, tree: tree}, [:pending, id], {:reset, from})}
  end

  @impl GenServer
  def handle_info({port, {:data, {:eol, line}}}, %{port: port} = state) do
    full_line = state.buffer <> line
    state = %{state | buffer: ""}

    case Jason.decode(full_line) do
      {:ok, response} ->
        state = handle_response(response, state)
        {:noreply, state}

      {:error, _} ->
        {:noreply, state}
    end
  end

  def handle_info({port, {:data, {:noeol, chunk}}}, %{port: port} = state) do
    {:noreply, %{state | buffer: state.buffer <> chunk}}
  end

  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    # Reply to all pending callers with an error
    for {_id, pending} <- state.pending do
      case pending do
        {_type, from} -> GenServer.reply(from, {:error, {:renderer_exited, code}})
        {_type, from, _extra} -> GenServer.reply(from, {:error, {:renderer_exited, code}})
      end
    end

    {:stop, {:renderer_exited, code}, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # -- Response handling --

  defp handle_response(%{"type" => "query_response", "id" => id} = resp, state) do
    case Map.pop(state.pending, id) do
      {nil, _} ->
        state

      {{:find, from}, pending} ->
        element =
          case resp["data"] do
            nil -> nil
            data when data == %{} -> nil
            data -> Element.from_node(data)
          end

        GenServer.reply(from, element)
        %{state | pending: pending}

      {{:tree, from}, pending} ->
        GenServer.reply(from, resp["data"])
        %{state | pending: pending}
    end
  end

  defp handle_response(%{"type" => "interact_response", "id" => id} = resp, state) do
    case Map.pop(state.pending, id) do
      {nil, _} ->
        state

      {{:interact, from, _action}, pending} ->
        # Dispatch events through local update loop
        state = dispatch_events(resp["events"] || [], state)
        GenServer.reply(from, :ok)
        %{state | pending: pending}
    end
  end

  defp handle_response(%{"type" => "snapshot_response", "id" => id} = resp, state) do
    case Map.pop(state.pending, id) do
      {nil, _} ->
        state

      {{:snapshot, from, _name}, pending} ->
        snapshot = %Snapshot{
          name: resp["name"],
          hash: resp["hash"],
          size: {resp["width"] || 0, resp["height"] || 0},
          rgba_data: decode_rgba(resp["rgba_base64"])
        }

        GenServer.reply(from, snapshot)
        %{state | pending: pending}
    end
  end

  defp handle_response(%{"type" => "reset_response", "id" => id}, state) do
    case Map.pop(state.pending, id) do
      {nil, _} ->
        state

      {{:reset, from}, pending} ->
        GenServer.reply(from, :ok)
        %{state | pending: pending}
    end
  end

  defp handle_response(%{"type" => "event"} = event, state) do
    # Events from the renderer -- dispatch through update loop
    state = dispatch_event(event, state)
    state
  end

  defp handle_response(_unknown, state), do: state

  # -- Event dispatching --

  defp dispatch_events(events, state) do
    Enum.reduce(events, state, fn event, acc -> dispatch_event(event, acc) end)
  end

  defp dispatch_event(%{"event" => type, "id" => id} = event, state) do
    elixir_event = decode_event(type, id, event)

    {model, _commands} =
      case state.app.update(state.model, elixir_event) do
        {m, c} -> {m, c}
        m -> {m, []}
      end

    tree = render_tree(state.app, model)

    # Send updated tree to renderer
    snapshot_msg = Jason.encode!(%{type: "snapshot", tree: tree})
    Port.command(state.port, [snapshot_msg, "\n"])

    %{state | model: model, tree: tree}
  end

  defp dispatch_event(_event, state), do: state

  defp decode_event("click", id, _event), do: {:click, id}
  defp decode_event("input", id, event), do: {:input, id, event["value"] || ""}
  defp decode_event("submit", id, event), do: {:submit, id, event["value"] || ""}
  defp decode_event("toggle", id, event), do: {:toggle, id, event["value"] || false}
  defp decode_event("select", id, event), do: {:select, id, event["value"] || ""}
  defp decode_event("slide", id, event), do: {:slide, id, event["value"] || 0}
  defp decode_event(type, id, _event), do: {String.to_atom(type), id}

  # -- Helpers --

  defp init_app(app, opts) do
    case app.init(opts) do
      {model, commands} -> {model, commands}
      model -> {model, []}
    end
  end

  defp render_tree(app, model) do
    app.view(model) |> Julep.Tree.normalize()
  end

  defp resolve_renderer_path do
    Julep.Binary.renderer_path()
  end

  defp next_id(state) do
    id = "req_#{state.next_id}"
    {id, %{state | next_id: state.next_id + 1}}
  end

  defp encode_selector("#" <> id), do: %{"by" => "id", "value" => id}
  defp encode_selector(text) when is_binary(text), do: %{"by" => "text", "value" => text}

  defp send_message(port, msg) do
    json = Jason.encode!(msg)
    Port.command(port, [json, "\n"])
  end

  defp decode_rgba(nil), do: nil
  defp decode_rgba(base64) when is_binary(base64), do: Base.decode64!(base64)
end
