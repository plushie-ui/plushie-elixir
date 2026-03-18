defmodule Julep.Test.Backend.Pooled do
  @moduledoc """
  Test backend that shares a single renderer process across tests.

  Each test gets its own GenServer managing model, tree, and event
  dispatch, but wire I/O goes through a shared `SessionPool`. This
  enables concurrent test execution against one renderer process.

  ## Usage

  Start a pool in `test_helper.exs`:

      {:ok, pool} = Julep.Test.SessionPool.start_link(
        mode: :mock,
        max_sessions: System.schedulers_online() * 2,
        name: Julep.TestPool
      )

  Configure the backend in `config/test.exs`:

      config :julep, :test_backend, :pooled_mock

  Or per-test:

      use Julep.Test.Case, app: MyApp, backend: :pooled_mock

  ## Options

  Passed through from `start/2` opts:

  - `:pool` -- the SessionPool server (default: `Julep.TestPool`)
  """

  @behaviour Julep.Test.Backend

  use GenServer

  alias Julep.Test.Backend.CommandProcessor
  alias Julep.Test.SessionPool

  # -- Backend callbacks (delegate to GenServer) --------------------------------

  @impl Julep.Test.Backend
  def start(app, opts) do
    GenServer.start_link(__MODULE__, {app, opts})
  end

  @impl Julep.Test.Backend
  def stop(pid), do: GenServer.call(pid, :stop)

  @impl Julep.Test.Backend
  def find(pid, selector), do: GenServer.call(pid, {:find, selector})

  @impl Julep.Test.Backend
  def find!(pid, selector) do
    case find(pid, selector) do
      nil ->
        raise "element not found: #{inspect(selector)}"

      element ->
        element
    end
  end

  @impl Julep.Test.Backend
  def click(pid, selector), do: GenServer.call(pid, {:interact, "click", selector, %{}})

  @impl Julep.Test.Backend
  def type_text(pid, selector, text),
    do: GenServer.call(pid, {:interact, "type_text", selector, %{text: text}})

  @impl Julep.Test.Backend
  def submit(pid, selector), do: GenServer.call(pid, {:submit, selector})

  @impl Julep.Test.Backend
  def toggle(pid, selector), do: GenServer.call(pid, {:toggle, selector})

  @impl Julep.Test.Backend
  def select(pid, selector, value),
    do: GenServer.call(pid, {:interact, "select", selector, %{value: value}})

  @impl Julep.Test.Backend
  def slide(pid, selector, value),
    do: GenServer.call(pid, {:interact, "slide", selector, %{value: value}})

  @impl Julep.Test.Backend
  def model(pid), do: GenServer.call(pid, :model)

  @impl Julep.Test.Backend
  def tree(pid), do: GenServer.call(pid, :tree)

  @impl Julep.Test.Backend
  def snapshot(pid, name), do: GenServer.call(pid, {:snapshot, name})

  @impl Julep.Test.Backend
  def screenshot(pid, name), do: GenServer.call(pid, {:screenshot, name})

  @impl Julep.Test.Backend
  def reset(pid), do: GenServer.call(pid, :reset)

  @impl Julep.Test.Backend
  def await_async(pid, tag, timeout \\ 5000),
    do: GenServer.call(pid, {:await_async, tag, timeout}, timeout + 1000)

  @impl Julep.Test.Backend
  def press(pid, key), do: GenServer.call(pid, {:interact, "press", nil, parse_key(key)})

  @impl Julep.Test.Backend
  def release(pid, key), do: GenServer.call(pid, {:interact, "release", nil, parse_key(key)})

  @impl Julep.Test.Backend
  def move_to(pid, x, y), do: GenServer.call(pid, {:interact, "move_to", nil, %{x: x, y: y}})

  @impl Julep.Test.Backend
  def type_key(pid, key), do: GenServer.call(pid, {:interact, "type_key", nil, parse_key(key)})

  # -- GenServer Implementation -----------------------------------------------

  defmodule State do
    @moduledoc false
    defstruct [:pool, :session_id, :app, :opts, :model, :tree]
  end

  @impl GenServer
  def init({app, opts}) do
    pool = Keyword.get(opts, :pool, Julep.TestPool)
    session_id = SessionPool.register(pool)

    {model, commands} = init_app(app, opts)
    model = CommandProcessor.process(app, model, commands)
    tree = render_tree(app, model)

    # Send initial snapshot to the renderer session.
    SessionPool.send_message(pool, session_id, %{type: "snapshot", tree: tree})

    {:ok,
     %State{pool: pool, session_id: session_id, app: app, opts: opts, model: model, tree: tree}}
  end

  @impl GenServer
  def handle_call(:stop, _from, state) do
    SessionPool.unregister(state.pool, state.session_id)
    {:stop, :normal, :ok, state}
  end

  def handle_call({:find, selector}, _from, state) do
    sel = encode_selector(selector)

    case SessionPool.send_message(
           state.pool,
           state.session_id,
           %{type: "query", target: "find", selector: sel},
           "query_response"
         ) do
      {:ok, %{"data" => data}} when data != nil and data != %{} ->
        {:reply, Julep.Test.Element.from_node(data), state}

      _ ->
        {:reply, nil, state}
    end
  end

  def handle_call(:model, _from, state), do: {:reply, state.model, state}

  def handle_call(:tree, _from, state) do
    case SessionPool.send_message(
           state.pool,
           state.session_id,
           %{type: "query", target: "tree", selector: %{}},
           "query_response"
         ) do
      {:ok, %{"data" => data}} -> {:reply, data, state}
      _ -> {:reply, nil, state}
    end
  end

  def handle_call({:toggle, selector}, from, state) do
    # Toggle needs the current value from the tree to invert it.
    # The --mock renderer doesn't track widget state, so we compute
    # the correct value from our local tree.
    element = find_in_tree(state.tree, selector)

    value =
      case element do
        %{type: "checkbox", props: props} -> !(props["is_checked"] || false)
        %{type: "toggler", props: props} -> !(props["is_toggled"] || false)
        _ -> true
      end

    handle_call({:interact, "toggle", selector, %{value: value}}, from, state)
  end

  def handle_call({:submit, selector}, from, state) do
    # Submit needs the current text value from the tree.
    element = find_in_tree(state.tree, selector)

    value =
      case element do
        %{props: props} -> props["value"] || ""
        _ -> ""
      end

    handle_call({:interact, "submit", selector, %{value: value}}, from, state)
  end

  def handle_call({:interact, action, selector, payload}, _from, state) do
    sel = if selector, do: encode_selector(selector), else: %{}

    case SessionPool.send_message(
           state.pool,
           state.session_id,
           %{type: "interact", action: action, selector: sel, payload: payload},
           "interact_response"
         ) do
      {:ok, %{"events" => events}} ->
        state = dispatch_events(events, state)
        {:reply, :ok, state}

      _ ->
        {:reply, :ok, state}
    end
  end

  def handle_call({:snapshot, name}, _from, state) do
    case SessionPool.send_message(
           state.pool,
           state.session_id,
           %{type: "snapshot_capture", name: name, theme: %{}, viewport: %{}},
           "snapshot_response"
         ) do
      {:ok, resp} ->
        snapshot = %Julep.Test.Snapshot{
          name: resp["name"],
          hash: resp["hash"],
          size: {resp["width"] || 0, resp["height"] || 0}
        }

        {:reply, snapshot, state}

      _ ->
        {:reply, %Julep.Test.Snapshot{name: name, hash: "", size: {0, 0}}, state}
    end
  end

  def handle_call({:screenshot, name}, _from, state) do
    case SessionPool.send_message(
           state.pool,
           state.session_id,
           %{type: "screenshot_capture", name: name, width: 1024, height: 768},
           "screenshot_response"
         ) do
      {:ok, resp} ->
        screenshot = %Julep.Test.Screenshot{
          name: resp["name"],
          hash: resp["hash"] || "",
          size: {resp["width"] || 0, resp["height"] || 0},
          rgba_data: extract_rgba(resp)
        }

        {:reply, screenshot, state}

      _ ->
        {:reply, %Julep.Test.Screenshot{name: name, hash: "", size: {0, 0}, rgba_data: nil},
         state}
    end
  end

  def handle_call(:reset, _from, state) do
    {model, commands} = init_app(state.app, state.opts)
    model = CommandProcessor.process(state.app, model, commands)
    tree = render_tree(state.app, model)

    # Reset the renderer session, then send fresh snapshot.
    SessionPool.send_message(state.pool, state.session_id, %{type: "reset"}, "reset_response")
    SessionPool.send_message(state.pool, state.session_id, %{type: "snapshot", tree: tree})

    {:reply, :ok, %{state | model: model, tree: tree}}
  end

  def handle_call({:await_async, _tag, _timeout}, _from, state) do
    # Pooled backend processes commands synchronously like mock.
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info({:julep_pool_event, _session_id, event}, state) do
    state = dispatch_event_map(event, state)
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # -- Internal helpers --------------------------------------------------------

  defp init_app(app, opts) do
    init_arg = Keyword.get(opts, :init_arg)

    case app.init(init_arg) do
      {model, commands} when is_list(commands) -> {model, commands}
      {model, %Julep.Command{} = cmd} -> {model, [cmd]}
      model -> {model, []}
    end
  end

  defp render_tree(app, model) do
    app.view(model) |> Julep.Tree.normalize()
  end

  # Walk the local tree to find a node by selector. Used by toggle/submit
  # to read the current widget state before sending the interact message.
  defp find_in_tree(tree, selector) do
    case selector do
      "#" <> id -> find_node_by_id(tree, id)
      _ -> nil
    end
  end

  defp find_node_by_id(nil, _id), do: nil
  defp find_node_by_id(%{id: id} = node, target_id) when id == target_id, do: node

  defp find_node_by_id(%{children: children}, target_id) when is_list(children) do
    Enum.find_value(children, fn child -> find_node_by_id(child, target_id) end)
  end

  defp find_node_by_id(_, _), do: nil

  defp dispatch_events(events, state) when is_list(events) do
    Enum.reduce(events, state, &dispatch_event_map(&1, &2))
  end

  defp dispatch_event_map(%{"family" => family, "id" => id} = event, state) do
    elixir_event = decode_event(family, id, event)

    if elixir_event do
      {model, commands} = CommandProcessor.dispatch_update(state.app, state.model, elixir_event)
      model = CommandProcessor.process(state.app, model, commands)
      tree = render_tree(state.app, model)
      SessionPool.send_message(state.pool, state.session_id, %{type: "snapshot", tree: tree})
      %{state | model: model, tree: tree}
    else
      state
    end
  end

  defp dispatch_event_map(_event, state), do: state

  defp decode_event("click", id, _event),
    do: %Julep.Event.Widget{type: :click, id: id}

  defp decode_event("input", id, %{"value" => value}),
    do: %Julep.Event.Widget{type: :input, id: id, value: value}

  defp decode_event("submit", id, %{"value" => value}),
    do: %Julep.Event.Widget{type: :submit, id: id, value: value}

  defp decode_event("toggle", id, %{"value" => value}),
    do: %Julep.Event.Widget{type: :toggle, id: id, value: value}

  defp decode_event("select", id, %{"value" => value}),
    do: %Julep.Event.Widget{type: :select, id: id, value: value}

  defp decode_event("slide", id, %{"value" => value}),
    do: %Julep.Event.Widget{type: :slide, id: id, value: value}

  defp decode_event("slide_release", id, %{"value" => value}),
    do: %Julep.Event.Widget{type: :slide_release, id: id, value: value}

  defp decode_event("paste", id, %{"value" => value}),
    do: %Julep.Event.Widget{type: :paste, id: id, value: value}

  defp decode_event(_family, _id, _event), do: nil

  defp encode_selector(nil), do: %{}
  defp encode_selector("#" <> id), do: %{"by" => "id", "value" => id}
  defp encode_selector({:role, role}) when is_binary(role), do: %{"by" => "role", "value" => role}

  defp encode_selector({:label, label}) when is_binary(label),
    do: %{"by" => "label", "value" => label}

  defp encode_selector(:focused), do: %{"by" => "focused"}
  defp encode_selector(text) when is_binary(text), do: %{"by" => "text", "value" => text}

  defp parse_key(key) when is_binary(key) do
    parts = String.split(key, "+")
    {mods, [key_name]} = Enum.split(parts, -1)

    modifiers =
      Enum.reduce(mods, %{}, fn
        "ctrl", acc -> Map.put(acc, :ctrl, true)
        "shift", acc -> Map.put(acc, :shift, true)
        "alt", acc -> Map.put(acc, :alt, true)
        "logo", acc -> Map.put(acc, :logo, true)
        "command", acc -> Map.put(acc, :command, true)
        _, acc -> acc
      end)

    %{key: key_name, modifiers: modifiers}
  end

  defp extract_rgba(%{"rgba" => rgba}) when is_binary(rgba), do: rgba
  defp extract_rgba(%{"rgba_base64" => b64}) when is_binary(b64), do: Base.decode64!(b64)
  defp extract_rgba(_), do: nil
end
