defmodule Julep.Test.Backend.Sim do
  @moduledoc """
  Simulated test backend. Pure Elixir, no Rust.

  Runs the app's `init/update/view` loop in-process. Interactions are
  simulated by inferring events from widget types via `Julep.Test.EventMap`.

  ## Limitations

  - Cannot take pixel screenshots (use `:full` for that). Structural
    snapshots work via tree hashing.
  - Widget ops (focus, scroll), window ops, and timers are silently skipped
    (they need a renderer). Async, stream, done, and batch commands are
    executed synchronously so `update/2` chains work without waiting.
  - Cannot detect encoding bugs in the wire protocol.
  - Event inference may not match real iced behavior for edge cases.

  ## When to use

  Fast iteration on app logic and tree structure. Runs in ~ms with zero
  external dependencies.
  """

  @behaviour Julep.Test.Backend

  use GenServer

  alias Julep.Event.Key, as: KeyEvent
  alias Julep.Event.Mouse, as: MouseEvent
  alias Julep.Event.Widget, as: WidgetEvent
  alias Julep.Test.Backend.CommandProcessor
  alias Julep.Test.Element
  alias Julep.Test.EventMap
  alias Julep.Test.Screenshot
  alias Julep.Test.Snapshot

  # -- Backend callbacks (delegate to GenServer) --

  @impl Julep.Test.Backend
  def start(app, opts \\ []) do
    GenServer.start(__MODULE__, {app, opts})
  end

  @impl Julep.Test.Backend
  def stop(pid), do: GenServer.stop(pid)

  @impl Julep.Test.Backend
  def find(pid, selector), do: GenServer.call(pid, {:find, selector})

  @impl Julep.Test.Backend
  def find!(pid, selector) do
    case find(pid, selector) do
      nil -> raise "Element not found: #{inspect(selector)}"
      element -> element
    end
  end

  @impl Julep.Test.Backend
  def click(pid, selector), do: GenServer.call(pid, {:click, selector})

  @impl Julep.Test.Backend
  def type_text(pid, selector, text), do: GenServer.call(pid, {:type_text, selector, text})

  @impl Julep.Test.Backend
  def submit(pid, selector), do: GenServer.call(pid, {:submit, selector})

  @impl Julep.Test.Backend
  def toggle(pid, selector), do: GenServer.call(pid, {:toggle, selector})

  @impl Julep.Test.Backend
  def select(pid, selector, value), do: GenServer.call(pid, {:select, selector, value})

  @impl Julep.Test.Backend
  def slide(pid, selector, value), do: GenServer.call(pid, {:slide, selector, value})

  @impl Julep.Test.Backend
  def model(pid), do: GenServer.call(pid, :model)

  @impl Julep.Test.Backend
  def tree(pid), do: GenServer.call(pid, :tree)

  @impl Julep.Test.Backend
  def snapshot(pid, name), do: GenServer.call(pid, {:snapshot, name})

  @impl Julep.Test.Backend
  def screenshot(_pid, name) do
    %Screenshot{name: name, hash: "", size: {0, 0}, rgba_data: nil}
  end

  @impl Julep.Test.Backend
  def reset(pid), do: GenServer.call(pid, :reset)

  @impl Julep.Test.Backend
  def await_async(_pid, _tag, _timeout \\ 5000), do: :ok

  @impl Julep.Test.Backend
  def press(pid, key), do: GenServer.call(pid, {:press, key})

  @impl Julep.Test.Backend
  def release(pid, key), do: GenServer.call(pid, {:release, key})

  @impl Julep.Test.Backend
  def move_to(pid, x, y), do: GenServer.call(pid, {:move_to, x, y})

  @impl Julep.Test.Backend
  def type_key(pid, key), do: GenServer.call(pid, {:type_key, key})

  # -- GenServer implementation --

  @impl GenServer
  def init({app, opts}) do
    {model, commands} = init_app(app, opts)
    model = CommandProcessor.process(app, model, commands)
    tree = render_tree(app, model)
    {:ok, %{app: app, opts: opts, model: model, tree: tree, typed_text: %{}}}
  end

  @impl GenServer
  def handle_call({:find, selector}, _from, state) do
    element = find_in_tree(state.tree, selector)
    {:reply, element, state}
  end

  def handle_call({:click, selector}, _from, state) do
    state = interact(state, selector, &EventMap.click/1)
    {:reply, :ok, state}
  end

  def handle_call({:type_text, selector, text}, _from, state) do
    element = find_in_tree(state.tree, selector)
    unless element, do: raise("Element not found: #{inspect(selector)}")

    state = interact(state, selector, &EventMap.input(&1, text))
    state = %{state | typed_text: Map.put(state.typed_text, element.id, text)}
    {:reply, :ok, state}
  end

  def handle_call({:submit, selector}, _from, state) do
    element = find_in_tree(state.tree, selector)
    unless element, do: raise("Element not found: #{inspect(selector)}")

    # Use typed text if available, otherwise fall back to EventMap.submit
    case Map.get(state.typed_text, element.id) do
      nil ->
        state = interact(state, selector, &EventMap.submit/1)
        {:reply, :ok, state}

      text ->
        state =
          interact(state, selector, fn _el ->
            {:ok, %WidgetEvent{type: :submit, id: element.id, value: text}}
          end)

        state = %{state | typed_text: Map.delete(state.typed_text, element.id)}
        {:reply, :ok, state}
    end
  end

  def handle_call({:toggle, selector}, _from, state) do
    state = interact(state, selector, &EventMap.toggle/1)
    {:reply, :ok, state}
  end

  def handle_call({:select, selector, value}, _from, state) do
    state = interact(state, selector, &EventMap.select(&1, value))
    {:reply, :ok, state}
  end

  def handle_call({:slide, selector, value}, _from, state) do
    state = interact(state, selector, &EventMap.slide(&1, value))
    {:reply, :ok, state}
  end

  def handle_call(:model, _from, state) do
    {:reply, state.model, state}
  end

  def handle_call(:tree, _from, state) do
    {:reply, state.tree, state}
  end

  def handle_call({:snapshot, name}, _from, state) do
    json = Jason.encode!(state.tree)
    hash = Snapshot.hash(json)
    snap = %Snapshot{name: name, hash: hash, size: {0, 0}}
    {:reply, snap, state}
  end

  def handle_call(:reset, _from, state) do
    {model, commands} = init_app(state.app, state.opts)
    model = CommandProcessor.process(state.app, model, commands)
    tree = render_tree(state.app, model)
    {:reply, :ok, %{state | model: model, tree: tree, typed_text: %{}}}
  end

  def handle_call({:press, key}, _from, state) do
    {modifiers, parsed_key} = parse_key_string(key)
    key_event = build_key_event(:press, parsed_key, modifiers)
    state = dispatch_raw(state, key_event)
    {:reply, :ok, state}
  end

  def handle_call({:release, key}, _from, state) do
    {modifiers, parsed_key} = parse_key_string(key)
    key_event = build_key_event(:release, parsed_key, modifiers)
    state = dispatch_raw(state, key_event)
    {:reply, :ok, state}
  end

  def handle_call({:move_to, x, y}, _from, state) do
    state = dispatch_raw(state, %MouseEvent{type: :moved, x: x, y: y})
    {:reply, :ok, state}
  end

  def handle_call({:type_key, key}, _from, state) do
    {modifiers, parsed_key} = parse_key_string(key)
    press_event = build_key_event(:press, parsed_key, modifiers)
    release_event = build_key_event(:release, parsed_key, modifiers)
    state = dispatch_raw(state, press_event)
    state = dispatch_raw(state, release_event)
    {:reply, :ok, state}
  end

  # -- Private helpers --

  defp init_app(app, opts) do
    case app.init(opts) do
      {model, commands} when is_list(commands) -> {model, commands}
      {model, %Julep.Command{} = cmd} -> {model, [cmd]}
      model -> {model, []}
    end
  end

  defp render_tree(app, model) do
    tree = app.view(model)
    Julep.Tree.normalize(tree)
  end

  defp interact(state, selector, event_fn) do
    element = find_in_tree(state.tree, selector)

    unless element do
      raise "Element not found: #{inspect(selector)}"
    end

    case event_fn.(element) do
      {:ok, event} ->
        {model, commands} = CommandProcessor.dispatch_update(state.app, state.model, event)
        model = CommandProcessor.process(state.app, model, commands)
        tree = render_tree(state.app, model)
        %{state | model: model, tree: tree}

      {:error, reason} ->
        raise reason
    end
  end

  defp find_in_tree(tree, "#" <> id) do
    find_by_id(tree, id)
  end

  defp find_in_tree(tree, {:role, role}) when is_binary(role) do
    find_by_role(tree, role)
  end

  defp find_in_tree(tree, {:label, label}) when is_binary(label) do
    find_by_label(tree, label)
  end

  defp find_in_tree(tree, :focused) do
    find_focused_node(tree)
  end

  defp find_in_tree(tree, text) when is_binary(text) do
    find_by_text(tree, text)
  end

  defp find_by_id(nil, _id), do: nil

  defp find_by_id(%{} = node, id) do
    node_id = node[:id] || node["id"]

    if node_id == id do
      Element.from_node(node)
    else
      children = node[:children] || node["children"] || []
      Enum.find_value(children, &find_by_id(&1, id))
    end
  end

  defp find_by_text(nil, _text), do: nil

  defp find_by_text(%{} = node, text) do
    element = Element.from_node(node)

    if Element.text(element) == text do
      element
    else
      children = node[:children] || node["children"] || []
      Enum.find_value(children, &find_by_text(&1, text))
    end
  end

  defp find_by_role(nil, _role), do: nil

  defp find_by_role(%{} = node, role) do
    element = Element.from_node(node)

    if Element.inferred_role(element) == role do
      element
    else
      children = node[:children] || node["children"] || []
      Enum.find_value(children, &find_by_role(&1, role))
    end
  end

  defp find_by_label(nil, _label), do: nil

  defp find_by_label(%{} = node, label) do
    a11y = (node[:props] || node["props"] || %{})["a11y"]

    if is_map(a11y) and a11y["label"] == label do
      Element.from_node(node)
    else
      children = node[:children] || node["children"] || []
      Enum.find_value(children, &find_by_label(&1, label))
    end
  end

  defp find_focused_node(nil), do: nil

  defp find_focused_node(%{} = node) do
    props = node[:props] || node["props"] || %{}

    if props["focused"] == true do
      Element.from_node(node)
    else
      children = node[:children] || node["children"] || []
      Enum.find_value(children, &find_focused_node/1)
    end
  end

  # -- Raw input helpers --

  defp dispatch_raw(state, event) do
    {model, commands} = CommandProcessor.dispatch_update(state.app, state.model, event)
    model = CommandProcessor.process(state.app, model, commands)
    tree = render_tree(state.app, model)
    %{state | model: model, tree: tree}
  end

  defp build_key_event(type, parsed_key, modifiers) do
    text =
      if is_binary(parsed_key) and byte_size(parsed_key) == 1,
        do: parsed_key,
        else: nil

    %KeyEvent{
      type: type,
      key: parsed_key,
      modified_key: parsed_key,
      physical_key: nil,
      location: :standard,
      modifiers: modifiers,
      text: text,
      repeat: false
    }
  end

  # NOTE: Sim key parsing is Linux-centric. "command" maps to ctrl
  # (not logo/super on macOS). This matches the headless backend
  # behaviour but may differ from native macOS key handling.
  @modifier_names ~w(ctrl shift alt logo command)

  defp parse_key_string(key_string) do
    parts = String.split(key_string, "+")

    {mod_parts, key_parts} =
      Enum.split_with(parts, fn part -> part in @modifier_names end)

    modifiers =
      Enum.reduce(mod_parts, %Julep.KeyModifiers{}, fn
        "ctrl", acc -> %{acc | ctrl: true, command: true}
        "shift", acc -> %{acc | shift: true}
        "alt", acc -> %{acc | alt: true}
        "logo", acc -> %{acc | logo: true}
        "command", acc -> %{acc | command: true, ctrl: true}
      end)

    key_name =
      case key_parts do
        [name] -> parse_key_name(name)
        [] -> raise ArgumentError, "No key name in key string: #{inspect(key_string)}"
        _ -> raise ArgumentError, "Multiple key names in key string: #{inspect(key_string)}"
      end

    {modifiers, key_name}
  end

  @named_keys %{
    "enter" => :enter,
    "escape" => :escape,
    "tab" => :tab,
    "backspace" => :backspace,
    "space" => :space,
    "delete" => :delete,
    "up" => :up,
    "down" => :down,
    "left" => :left,
    "right" => :right,
    "home" => :home,
    "end" => :end,
    "page_up" => :page_up,
    "page_down" => :page_down,
    "f1" => :f1,
    "f2" => :f2,
    "f3" => :f3,
    "f4" => :f4,
    "f5" => :f5,
    "f6" => :f6,
    "f7" => :f7,
    "f8" => :f8,
    "f9" => :f9,
    "f10" => :f10,
    "f11" => :f11,
    "f12" => :f12
  }

  defp parse_key_name(name) do
    Map.get(@named_keys, name, name)
  end
end
