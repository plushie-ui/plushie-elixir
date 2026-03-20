defmodule Toddy.Test.Backend.Pooled do
  @moduledoc """
  Test backend that shares a single renderer process across tests.

  Each test gets its own GenServer managing model, tree, and event
  dispatch, but wire I/O goes through a shared `SessionPool`. This
  enables concurrent test execution against one renderer process.

  ## Usage

  Start a pool in `test_helper.exs`:

      {:ok, pool} = Toddy.Test.SessionPool.start_link(
        mode: :mock,
        max_sessions: System.schedulers_online() * 2,
        name: Toddy.TestPool
      )

  Configure the backend in `config/test.exs`:

      config :toddy, :test_backend, :pooled_mock

  Or per-test:

      use Toddy.Test.Case, app: MyApp, backend: :pooled_mock

  ## Options

  Passed through from `start/2` opts:

  - `:pool` -- the SessionPool server (default: `Toddy.TestPool`)
  """

  @behaviour Toddy.Test.Backend

  use GenServer

  alias Toddy.Test.Backend.CommandProcessor
  alias Toddy.Test.Backend.EventDecoder
  alias Toddy.Test.SessionPool

  # -- Backend callbacks (delegate to GenServer) --------------------------------

  @impl Toddy.Test.Backend
  def start(app, opts) do
    GenServer.start_link(__MODULE__, {app, opts})
  end

  @impl Toddy.Test.Backend
  def stop(pid), do: GenServer.call(pid, :stop)

  @impl Toddy.Test.Backend
  def find(pid, selector), do: GenServer.call(pid, {:find, selector})

  @impl Toddy.Test.Backend
  def find!(pid, selector) do
    case find(pid, selector) do
      nil ->
        raise "element not found: #{inspect(selector)}"

      element ->
        element
    end
  end

  @impl Toddy.Test.Backend
  def click(pid, selector), do: interact!(pid, {:interact, "click", selector, %{}})

  @impl Toddy.Test.Backend
  def type_text(pid, selector, text),
    do: interact!(pid, {:interact, "type_text", selector, %{text: text}})

  @impl Toddy.Test.Backend
  def submit(pid, selector), do: interact!(pid, {:submit, selector})

  @impl Toddy.Test.Backend
  def toggle(pid, selector), do: interact!(pid, {:toggle, selector})

  @impl Toddy.Test.Backend
  def select(pid, selector, value),
    do: interact!(pid, {:interact, "select", selector, %{value: value}})

  @impl Toddy.Test.Backend
  def slide(pid, selector, value),
    do: interact!(pid, {:interact, "slide", selector, %{value: value}})

  @impl Toddy.Test.Backend
  def model(pid), do: GenServer.call(pid, :model)

  @impl Toddy.Test.Backend
  def tree(pid), do: GenServer.call(pid, :tree)

  @impl Toddy.Test.Backend
  def tree_hash(pid, name), do: GenServer.call(pid, {:tree_hash, name})

  @impl Toddy.Test.Backend
  def screenshot(pid, name), do: GenServer.call(pid, {:screenshot, name})

  @impl Toddy.Test.Backend
  def reset(pid), do: GenServer.call(pid, :reset)

  @impl Toddy.Test.Backend
  def await_async(pid, tag, timeout \\ 5000),
    do: GenServer.call(pid, {:await_async, tag, timeout}, timeout + 1000)

  @impl Toddy.Test.Backend
  def press(pid, key), do: interact!(pid, {:interact, "press", nil, parse_key(key)})

  @impl Toddy.Test.Backend
  def release(pid, key), do: interact!(pid, {:interact, "release", nil, parse_key(key)})

  @impl Toddy.Test.Backend
  def move_to(pid, x, y), do: interact!(pid, {:interact, "move_to", nil, %{x: x, y: y}})

  @impl Toddy.Test.Backend
  def type_key(pid, key), do: interact!(pid, {:interact, "type_key", nil, parse_key(key)})

  # All interact-like callbacks route through this wrapper.
  # Handles both the normal error reply (from :DOWN handler) and
  # the edge case where the GenServer exits before replying.
  defp interact!(pid, msg) do
    case GenServer.call(pid, msg) do
      :ok -> :ok
      {:error, reason} -> raise "renderer error during interaction: #{inspect(reason)}"
    end
  catch
    :exit, reason ->
      raise "renderer crashed during interaction: #{inspect(reason)}"
  end

  # -- GenServer Implementation -----------------------------------------------

  defmodule State do
    @moduledoc false
    defstruct [:pool, :session_id, :app, :opts, :model, :tree, :interact_from]
  end

  @impl GenServer
  def init({app, opts}) do
    pool = Keyword.get(opts, :pool, Toddy.TestPool)
    Process.monitor(pool)
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
    sel = encode_selector(selector, state.tree)

    case SessionPool.send_message(
           state.pool,
           state.session_id,
           %{type: "query", target: "find", selector: sel},
           "query_response"
         ) do
      {:ok, %{"data" => data}} when data != nil and data != %{} ->
        {:reply, Toddy.Test.Element.from_node(data), state}

      {:ok, _} ->
        {:reply, nil, state}

      {:error, reason} ->
        raise "renderer error during find: #{inspect(reason)}"
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
      {:ok, _} -> {:reply, nil, state}
      {:error, reason} -> raise "renderer error during tree query: #{inspect(reason)}"
    end
  end

  def handle_call({:toggle, selector}, from, state) do
    # Toggle needs the current value from the tree to invert it.
    # The --mock renderer doesn't track widget state, so we compute
    # the correct value from our local tree.
    element = find_in_tree(state.tree, selector)

    value =
      case element do
        %{type: "checkbox", props: props} -> !(props[:is_checked] || false)
        %{type: "toggler", props: props} -> !(props[:is_toggled] || false)
        _ -> true
      end

    handle_call({:interact, "toggle", selector, %{value: value}}, from, state)
  end

  def handle_call({:submit, selector}, from, state) do
    # Submit needs the current text value from the tree.
    element = find_in_tree(state.tree, selector)

    value =
      case element do
        %{props: props} -> props[:value] || ""
        _ -> ""
      end

    handle_call({:interact, "submit", selector, %{value: value}}, from, state)
  end

  def handle_call({:interact, action, selector, payload}, from, state) do
    sel = if selector, do: encode_selector(selector, state.tree), else: %{}

    # Send the interact via send_interact (non-blocking). The
    # renderer will send back zero or more interact_step messages
    # (each triggering a snapshot round-trip) followed by a final
    # interact_response. All arrive via handle_info. We store
    # `from` to reply when the final interact_response arrives.
    _req_id =
      SessionPool.send_interact(
        state.pool,
        state.session_id,
        %{type: "interact", action: action, selector: sel, payload: payload}
      )

    {:noreply, %{state | interact_from: from}}
  end

  def handle_call({:tree_hash, name}, _from, state) do
    case SessionPool.send_message(
           state.pool,
           state.session_id,
           %{type: "tree_hash", name: name},
           "tree_hash_response"
         ) do
      {:ok, resp} ->
        tree_hash = %Toddy.Test.TreeHash{
          name: resp["name"],
          hash: resp["hash"]
        }

        {:reply, tree_hash, state}

      {:error, reason} ->
        raise "renderer error during tree_hash: #{inspect(reason)}"
    end
  end

  def handle_call({:screenshot, name}, _from, state) do
    case SessionPool.send_message(
           state.pool,
           state.session_id,
           %{type: "screenshot", name: name, width: 1024, height: 768},
           "screenshot_response"
         ) do
      {:ok, resp} ->
        screenshot = %Toddy.Test.Screenshot{
          name: resp["name"],
          hash: resp["hash"] || "",
          size: {resp["width"] || 0, resp["height"] || 0},
          rgba_data: extract_rgba(resp)
        }

        {:reply, screenshot, state}

      {:error, reason} ->
        raise "renderer error during screenshot: #{inspect(reason)}"
    end
  end

  def handle_call(:reset, _from, state) do
    {model, commands} = init_app(state.app, state.opts)
    model = CommandProcessor.process(state.app, model, commands)
    tree = render_tree(state.app, model)

    # Reset the renderer session, then send fresh snapshot.
    case SessionPool.send_message(
           state.pool,
           state.session_id,
           %{type: "reset"},
           "reset_response"
         ) do
      {:ok, _} -> :ok
      {:error, reason} -> raise "renderer error during reset: #{inspect(reason)}"
    end

    SessionPool.send_message(state.pool, state.session_id, %{type: "snapshot", tree: tree})

    {:reply, :ok, %{state | model: model, tree: tree}}
  end

  def handle_call({:await_async, _tag, _timeout}, _from, state) do
    # Pooled backend processes commands synchronously like mock.
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info(
        {:toddy_pool_event, _session_id, %{"type" => "interact_step", "events" => events}},
        state
      ) do
    # Iterative interact: the renderer emitted an intermediate batch
    # of events from a single iced event injection and is waiting for
    # us to send back ONE snapshot with the updated tree.
    #
    # Process all events in the step through app.update (updating the
    # model), then re-render and send a single snapshot. This differs
    # from dispatch_events which sends a snapshot per event -- that
    # behavior is correct for inter-step processing but within a
    # single step, all events came from one atomic iced event and
    # the renderer expects exactly one snapshot response.
    state =
      Enum.reduce(events, state, fn event_map, acc ->
        case EventDecoder.decode(
               event_map["family"] || "",
               event_map["id"] || "",
               event_map
             ) do
          nil ->
            acc

          elixir_event ->
            {model, commands} =
              CommandProcessor.dispatch_update(acc.app, acc.model, elixir_event)

            model = CommandProcessor.process(acc.app, model, commands)
            %{acc | model: model}
        end
      end)

    tree = render_tree(state.app, state.model)
    SessionPool.send_message(state.pool, state.session_id, %{type: "snapshot", tree: tree})
    {:noreply, %{state | tree: tree}}
  end

  def handle_info(
        {:toddy_pool_event, _session_id, %{"type" => "interact_response", "events" => events}},
        state
      ) do
    # Final interact response. Process any remaining events (for
    # synthetic-only actions that don't use interact_step), then
    # reply to the blocked caller.
    state = dispatch_events(events, state)

    if state.interact_from do
      GenServer.reply(state.interact_from, :ok)
    end

    {:noreply, %{state | interact_from: nil}}
  end

  def handle_info({:toddy_pool_event, _session_id, event}, state) do
    state = dispatch_event_map(event, state)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pool, reason}, %{pool: pool} = state) do
    # The SessionPool crashed (renderer exited). If we're mid-interact,
    # reply with an error so the caller gets a clear crash message
    # instead of a GenServer timeout.
    if state.interact_from do
      GenServer.reply(state.interact_from, {:error, {:renderer_crashed, reason}})
    end

    {:stop, {:renderer_crashed, reason}, %{state | interact_from: nil}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # -- Internal helpers --------------------------------------------------------

  defp init_app(app, opts) do
    init_arg = Keyword.get(opts, :init_arg)

    case app.init(init_arg) do
      {model, commands} when is_list(commands) -> {model, commands}
      {model, %Toddy.Command{} = cmd} -> {model, [cmd]}
      model -> {model, []}
    end
  end

  defp render_tree(app, model) do
    app.view(model) |> Toddy.Tree.normalize()
  end

  # Walk the local tree to find a node by selector. Used by toggle/submit
  # to read the current widget state before sending the interact message.
  #
  # Only supports ID selectors (#id). Text, role, label, and focused
  # selectors fall back to nil, causing toggle to default to true and
  # submit to default to "". In practice toggle/submit are always
  # called with ID selectors. If this becomes a problem, extend this
  # to walk the tree for other selector types.
  defp find_in_tree(tree, selector) do
    case selector do
      "#" <> id ->
        if String.contains?(id, "/") do
          find_node_by_id(tree, id)
        else
          find_node_by_local_id(tree, id)
        end

      _ ->
        nil
    end
  end

  defp find_node_by_id(nil, _id), do: nil
  defp find_node_by_id(%{id: id} = node, target_id) when id == target_id, do: node

  defp find_node_by_id(%{children: children}, target_id) when is_list(children) do
    Enum.find_value(children, fn child -> find_node_by_id(child, target_id) end)
  end

  defp find_node_by_id(_, _), do: nil

  # Find a node whose local ID (last segment after "/") matches
  defp find_node_by_local_id(nil, _id), do: nil

  defp find_node_by_local_id(%{id: node_id} = node, target_id) do
    local = local_id(node_id)

    if local == target_id do
      node
    else
      case node do
        %{children: children} when is_list(children) ->
          Enum.find_value(children, fn child -> find_node_by_local_id(child, target_id) end)

        _ ->
          nil
      end
    end
  end

  defp find_node_by_local_id(_, _), do: nil

  defp local_id(id) do
    case String.split(id, "/") do
      [local] -> local
      parts -> List.last(parts)
    end
  end

  # Process each event individually with its own update/render/snapshot
  # cycle. This matches production behaviour where each renderer event
  # triggers a full host round-trip. Batching would skip intermediate
  # tree states that extensions (prepare) and the renderer (settle_ui)
  # observe in production. The overhead is one cast per event -- negligible.
  defp dispatch_events(events, state) when is_list(events) do
    Enum.reduce(events, state, &dispatch_event_map(&1, &2))
  end

  defp dispatch_event_map(%{"family" => family, "id" => id} = event, state) do
    elixir_event = EventDecoder.decode(family, id, event)

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

  defp encode_selector(nil, _tree), do: %{}

  defp encode_selector("#" <> id, tree) do
    resolved =
      if String.contains?(id, "/") do
        id
      else
        case find_node_by_local_id(tree, id) do
          %{id: scoped_id} -> scoped_id
          nil -> id
        end
      end

    %{"by" => "id", "value" => resolved}
  end

  defp encode_selector({:role, role}, _tree) when is_binary(role),
    do: %{"by" => "role", "value" => role}

  defp encode_selector({:label, label}, _tree) when is_binary(label),
    do: %{"by" => "label", "value" => label}

  defp encode_selector(:focused, _tree), do: %{"by" => "focused"}
  defp encode_selector(text, _tree) when is_binary(text), do: %{"by" => "text", "value" => text}

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
