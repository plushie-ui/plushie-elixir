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

  # -- GenServer implementation --

  @impl GenServer
  def init({app, opts}) do
    {model, commands} = init_app(app, opts)
    model = process_commands(app, model, commands)
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
        state = interact(state, selector, fn _el -> {:ok, {:submit, element.id, text}} end)
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
    model = process_commands(state.app, model, commands)
    tree = render_tree(state.app, model)
    {:reply, :ok, %{state | model: model, tree: tree, typed_text: %{}}}
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
        {model, commands} = dispatch_update(state.app, state.model, event)
        model = process_commands(state.app, model, commands)
        tree = render_tree(state.app, model)
        %{state | model: model, tree: tree}

      {:error, reason} ->
        raise reason
    end
  end

  defp dispatch_update(app, model, event) do
    case app.update(model, event) do
      {model, commands} when is_list(commands) -> {model, commands}
      {model, %Julep.Command{} = cmd} -> {model, [cmd]}
      model -> {model, []}
    end
  end

  # Maximum recursion depth to prevent infinite command loops.
  @max_command_depth 100

  defp process_commands(app, model, commands, depth \\ 0)
  defp process_commands(_app, model, [], _depth), do: model
  defp process_commands(_app, model, _commands, depth) when depth > @max_command_depth, do: model

  defp process_commands(app, model, commands, depth) do
    Enum.reduce(commands, model, fn
      %Julep.Command{type: :async, payload: %{fun: fun, tag: tag}}, acc ->
        result = fun.()
        {new_model, new_commands} = dispatch_update(app, acc, {tag, result})
        process_commands(app, new_model, new_commands, depth + 1)

      %Julep.Command{type: :stream, payload: %{fun: fun, tag: tag}}, acc ->
        # Run stream synchronously. Collect emitted values via the mailbox,
        # then process each as {tag, value}. The final return value is also
        # dispatched, matching Runtime behaviour.
        ref = make_ref()
        parent = self()
        emit = fn value -> send(parent, {:sim_stream, ref, value}) end
        final = fun.(emit)

        acc = drain_stream_messages(app, acc, tag, ref, depth)

        {new_model, new_commands} = dispatch_update(app, acc, {tag, final})
        process_commands(app, new_model, new_commands, depth + 1)

      %Julep.Command{type: :done, payload: %{value: value, mapper: mapper}}, acc ->
        event = mapper.(value)
        {new_model, new_commands} = dispatch_update(app, acc, event)
        process_commands(app, new_model, new_commands, depth + 1)

      %Julep.Command{type: :batch, payload: %{commands: cmds}}, acc ->
        process_commands(app, acc, cmds, depth + 1)

      %Julep.Command{type: :none}, acc ->
        acc

      %Julep.Command{}, acc ->
        # Widget ops, window ops, timers, cancel -- skip (needs renderer)
        acc
    end)
  end

  defp drain_stream_messages(app, model, tag, ref, depth) do
    receive do
      {:sim_stream, ^ref, value} ->
        {new_model, new_commands} = dispatch_update(app, model, {tag, value})
        new_model = process_commands(app, new_model, new_commands, depth + 1)
        drain_stream_messages(app, new_model, tag, ref, depth)
    after
      0 -> model
    end
  end

  defp find_in_tree(tree, "#" <> id) do
    find_by_id(tree, id)
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
end
