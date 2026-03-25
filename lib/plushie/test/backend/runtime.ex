defmodule Plushie.Test.Backend.Runtime do
  @moduledoc """
  Test backend that starts a real Plushie app (Runtime + Bridge).

  Starts the full Plushie supervisor tree connected to the shared
  SessionPool via a PoolAdapter. All event processing goes through
  the real Runtime, giving tests production-equivalent behavior.
  Canvas widget state, event transformation, subscriptions, effects,
  and scoped IDs all work identically to production.

  ## Architecture

      Test process
        |
        v
      Backend.Runtime (GenServer)
        |-- owns Plushie supervisor (Bridge + Runtime)
        |-- PoolAdapter connects Bridge <-> SessionPool
        |-- queries go to Runtime.get_model/get_tree
        |-- interactions go to Runtime.interact -> Bridge -> renderer

  ## Options

  Passed through from `start/2`:

  - `:pool` -- the SessionPool server (default: `Plushie.TestPool`)
  - `:format` -- wire format (default: `:msgpack`)
  - `:init_arg` -- argument passed to the app's `init/1` callback

  ## Example

      {:ok, pid} = Plushie.Test.Backend.Runtime.start(MyApp, pool: Plushie.TestPool)
      :ok = Plushie.Test.Backend.Runtime.click(pid, "#save")
      model = Plushie.Test.Backend.Runtime.model(pid)
      assert model.saved?
      Plushie.Test.Backend.Runtime.stop(pid)
  """

  use GenServer

  alias Plushie.Test.Element
  alias Plushie.Test.PoolAdapter

  defstruct [:pool, :sup, :instance_name, :runtime, :app, :format]

  # -- Backend callbacks -------------------------------------------------------

  def start(app, opts) do
    GenServer.start_link(__MODULE__, {app, opts})
  end

  def stop(pid), do: GenServer.stop(pid, :normal, 10_000)

  def find(pid, selector), do: GenServer.call(pid, {:find, selector})

  def find!(pid, selector) do
    case find(pid, selector) do
      nil -> raise "element not found: #{inspect(selector)}"
      element -> element
    end
  end

  def click(pid, selector), do: do_interact(pid, "click", selector, %{})

  def type_text(pid, selector, text),
    do: do_interact(pid, "type_text", selector, %{text: text})

  def submit(pid, selector) do
    # The renderer's interact path needs the current text value.
    value = GenServer.call(pid, {:read_prop, selector, :submit_value})
    do_interact(pid, "submit", selector, %{value: value})
  end

  def toggle(pid, selector, value \\ nil) do
    target =
      if is_boolean(value) do
        value
      else
        # No explicit value: read current state and negate (.ice compat)
        current = GenServer.call(pid, {:read_prop, selector, :toggle_value})
        !current
      end

    do_interact(pid, "toggle", selector, %{value: target})
  end

  def select(pid, selector, value),
    do: do_interact(pid, "select", selector, %{value: value})

  def slide(pid, selector, value),
    do: do_interact(pid, "slide", selector, %{value: value})

  def model(pid), do: GenServer.call(pid, :model)

  def tree(pid), do: GenServer.call(pid, :tree)

  def tree_hash(_pid, name) do
    %Plushie.Test.TreeHash{name: name, hash: ""}
  end

  def screenshot(_pid, name) do
    %Plushie.Test.Screenshot{name: name, hash: "", size: {0, 0}, rgba_data: nil}
  end

  def reset(pid), do: GenServer.call(pid, :reset, 10_000)

  def await_async(pid, tag, timeout \\ 5000) do
    runtime = GenServer.call(pid, :runtime)
    Plushie.Runtime.await_async(runtime, tag, timeout)
  end

  def press(pid, key) do
    {key_name, mods} = parse_key(key)
    do_interact(pid, "press", nil, %{key: key_name, modifiers: mods})
  end

  def release(pid, key) do
    {key_name, mods} = parse_key(key)
    do_interact(pid, "release", nil, %{key: key_name, modifiers: mods})
  end

  def move_to(pid, x, y), do: do_interact(pid, "move_to", nil, %{x: x, y: y})

  def type_key(pid, key) do
    {key_name, mods} = parse_key(key)
    do_interact(pid, "type_key", nil, %{key: key_name, modifiers: mods})
  end

  def scroll(pid, selector, delta_x, delta_y),
    do: do_interact(pid, "scroll", selector, %{delta_x: delta_x, delta_y: delta_y})

  def paste(pid, selector, text),
    do: do_interact(pid, "paste", selector, %{text: text})

  def sort(pid, selector, column, direction),
    do: do_interact(pid, "sort", selector, %{column: column, direction: direction})

  def canvas_press(pid, selector, x, y, button),
    do: do_interact(pid, "canvas_press", selector, %{x: x, y: y, button: button})

  def canvas_release(pid, selector, x, y, button),
    do: do_interact(pid, "canvas_release", selector, %{x: x, y: y, button: button})

  def canvas_move(pid, selector, x, y),
    do: do_interact(pid, "canvas_move", selector, %{x: x, y: y})

  def pane_focus_cycle(pid, selector),
    do: do_interact(pid, "pane_focus_cycle", selector, %{})

  def register_effect_stub(pid, kind, response),
    do: GenServer.call(pid, {:register_effect_stub, kind, response}, 10_000)

  def unregister_effect_stub(pid, kind),
    do: GenServer.call(pid, {:unregister_effect_stub, kind}, 10_000)

  def get_diagnostics(pid),
    do: GenServer.call(pid, :get_diagnostics)

  defp do_interact(pid, action, selector, payload) do
    case GenServer.call(pid, {:interact, action, selector, payload}, 10_000) do
      :ok -> :ok
      {:error, reason} -> raise "interaction failed: #{inspect(reason)}"
    end
  catch
    :exit, reason -> raise "runtime crashed during interaction: #{inspect(reason)}"
  end

  # -- GenServer ---------------------------------------------------------------

  @impl GenServer
  def init({app, opts}) do
    pool = Keyword.get(opts, :pool, Plushie.TestPool)
    format = Keyword.get(opts, :format, :msgpack)

    # Start pool adapter that connects Bridge <-> SessionPool.
    {:ok, adapter_pid, session_id} = PoolAdapter.start_link(pool: pool, format: format)
    Process.monitor(adapter_pid)

    # Generate a unique instance name for this test session.
    tag = :erlang.unique_integer([:positive])
    instance_name = :"plushie_test_#{tag}"

    # Start the full Plushie supervisor tree with iostream transport.
    {:ok, sup} =
      Plushie.start_link(app,
        name: instance_name,
        transport: {:iostream, adapter_pid},
        format: format,
        session_id: session_id,
        app_opts: Keyword.get(opts, :init_arg) |> List.wrap()
      )

    runtime = Plushie.runtime_for(instance_name)

    # Wait for initial render to complete.
    :sys.get_state(runtime)

    {:ok,
     %__MODULE__{
       pool: pool,
       sup: sup,
       instance_name: instance_name,
       runtime: runtime,
       app: app,
       format: format
     }}
  end

  @impl GenServer
  def handle_call(:runtime, _from, state) do
    {:reply, state.runtime, state}
  end

  def handle_call(:model, _from, state) do
    model = Plushie.Runtime.get_model(state.runtime)
    {:reply, model, state}
  end

  def handle_call(:tree, _from, state) do
    tree = Plushie.Runtime.get_tree(state.runtime)
    {:reply, tree, state}
  end

  def handle_call({:find, selector}, _from, state) do
    tree = Plushie.Runtime.get_tree(state.runtime)
    element = find_in_tree(tree, selector)
    {:reply, element, state}
  end

  def handle_call({:read_prop, selector, :toggle_value}, _from, state) do
    tree = Plushie.Runtime.get_tree(state.runtime)
    node = find_node_in_tree(tree, selector)
    props = (node && node[:props]) || %{}

    value =
      props[:is_toggled] || props["is_toggled"] ||
        props[:checked] || props["checked"] || false

    {:reply, value, state}
  end

  def handle_call({:read_prop, selector, :submit_value}, _from, state) do
    tree = Plushie.Runtime.get_tree(state.runtime)
    node = find_node_in_tree(tree, selector)
    props = (node && node[:props]) || %{}
    value = props[:value] || props["value"] || ""
    {:reply, value, state}
  end

  def handle_call({:interact, action, selector, payload}, _from, state) do
    tree = Plushie.Runtime.get_tree(state.runtime)
    sel = encode_selector(selector, tree)
    result = Plushie.Runtime.interact(state.runtime, action, sel, payload)
    {:reply, result, state}
  end

  def handle_call({:register_effect_stub, kind, response}, _from, state) do
    result = Plushie.Runtime.register_effect_stub(state.runtime, kind, response)
    {:reply, result, state}
  end

  def handle_call({:unregister_effect_stub, kind}, _from, state) do
    result = Plushie.Runtime.unregister_effect_stub(state.runtime, kind)
    {:reply, result, state}
  end

  def handle_call(:get_diagnostics, _from, state) do
    result = Plushie.Runtime.get_diagnostics(state.runtime)
    {:reply, result, state}
  end

  def handle_call(:reset, _from, state) do
    # Stop the existing supervisor and start fresh.
    Plushie.stop(state.sup)

    {:ok, adapter_pid, session_id} =
      PoolAdapter.start_link(pool: state.pool, format: state.format)

    Process.monitor(adapter_pid)

    tag = :erlang.unique_integer([:positive])
    instance_name = :"plushie_test_#{tag}"

    {:ok, sup} =
      Plushie.start_link(state.app,
        name: instance_name,
        transport: {:iostream, adapter_pid},
        format: state.format,
        session_id: session_id
      )

    runtime = Plushie.runtime_for(instance_name)
    :sys.get_state(runtime)

    {:reply, :ok, %{state | sup: sup, instance_name: instance_name, runtime: runtime}}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, state) do
    if state.sup && Process.alive?(state.sup) do
      try do
        Plushie.stop(state.sup)
      catch
        :exit, _ -> :ok
      end
    end

    :ok
  end

  # -- Helpers -----------------------------------------------------------------

  defp find_in_tree(nil, _selector), do: nil

  defp find_in_tree(tree, "#" <> id) do
    case Plushie.Tree.find(tree, id) do
      nil -> nil
      node -> Element.from_node(node)
    end
  end

  defp find_in_tree(tree, {:role, role}) do
    node =
      Plushie.Tree.find_all(tree, fn n ->
        a11y = n[:props][:a11y] || n[:props]["a11y"] || %{}
        (a11y[:role] || a11y["role"]) == role
      end)
      |> List.first()

    if node, do: Element.from_node(node)
  end

  defp find_in_tree(tree, {:label, label}) do
    node =
      Plushie.Tree.find_all(tree, fn n ->
        a11y = n[:props][:a11y] || n[:props]["a11y"] || %{}
        (a11y[:label] || a11y["label"]) == label
      end)
      |> List.first()

    if node, do: Element.from_node(node)
  end

  defp find_in_tree(tree, text) when is_binary(text) do
    node =
      Plushie.Tree.find_all(tree, fn n ->
        type = n[:type] || n["type"]
        content = (n[:props] || %{})[:content] || (n[:props] || %{})["content"]
        type == "text" and content == text
      end)
      |> List.first()

    if node, do: Element.from_node(node)
  end

  defp find_in_tree(_tree, :focused), do: nil

  # Returns the raw tree node (not wrapped in Element) for reading props.
  defp find_node_in_tree(nil, _selector), do: nil

  defp find_node_in_tree(tree, "#" <> id) do
    Plushie.Tree.find(tree, id)
  end

  defp find_node_in_tree(_tree, _selector), do: nil

  defp encode_selector(nil, _tree), do: %{}

  defp encode_selector("#" <> id, tree) do
    resolved =
      if String.contains?(id, "/") do
        id
      else
        case Plushie.Tree.find(tree, id) do
          %{id: scoped_id} -> scoped_id
          _ -> id
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

  # Valid modifier prefixes for key combos (e.g. "Shift+ArrowRight").
  @valid_modifiers %{
    "Shift" => :shift,
    "Ctrl" => :ctrl,
    "Alt" => :alt,
    "Logo" => :logo,
    "Command" => :command
  }

  defp parse_key(key) when is_binary(key) do
    parts = String.split(key, "+")
    {mods, [key_name]} = Enum.split(parts, -1)

    modifiers =
      for mod <- mods, into: %{} do
        case Map.get(@valid_modifiers, mod) do
          nil ->
            raise ArgumentError,
                  "unknown modifier #{inspect(mod)} in key #{inspect(key)}. " <>
                    "Valid: Shift, Ctrl, Alt, Logo, Command"

          atom ->
            {atom, true}
        end
      end

    # Single printable characters are valid (sent as Key::Character).
    # Named keys must be in the set recognized by the renderer.
    unless String.length(key_name) == 1 or Plushie.Protocol.Keys.valid_key?(key_name) do
      raise ArgumentError,
            "unknown key #{inspect(key_name)} in #{inspect(key)}. " <>
              "Use PascalCase named keys (ArrowRight, PageUp, Tab) " <>
              "or single characters (a, Z). " <>
              "See Plushie.Protocol.Keys for the full list"
    end

    {key_name, modifiers}
  end
end
