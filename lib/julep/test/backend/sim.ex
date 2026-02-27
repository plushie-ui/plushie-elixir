defmodule Julep.Test.Backend.Sim do
  @moduledoc """
  Simulated test backend. Pure Elixir, no Rust.

  Runs the app's `init/update/view` loop in-process. Interactions are
  simulated by inferring events from widget types via `Julep.Test.EventMap`.

  ## Limitations

  - Cannot take pixel snapshots (use `:headless` or `:full` for that).
  - Commands from `update/2` are collected but not executed.
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
  def snapshot(_pid, _name) do
    raise RuntimeError,
          "pixel snapshots require the :headless or :full backend -- " <>
            "the :sim backend only tests logic and tree structure"
  end

  @impl Julep.Test.Backend
  def reset(pid), do: GenServer.call(pid, :reset)

  @impl Julep.Test.Backend
  def await_async(_pid, _tag, _timeout \\ 5000), do: :ok

  # -- GenServer implementation --

  @impl GenServer
  def init({app, opts}) do
    {model, _commands} = init_app(app, opts)
    tree = render_tree(app, model)
    {:ok, %{app: app, opts: opts, model: model, tree: tree}}
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
    state = interact(state, selector, &EventMap.input(&1, text))
    {:reply, :ok, state}
  end

  def handle_call({:submit, selector}, _from, state) do
    state = interact(state, selector, &EventMap.submit/1)
    {:reply, :ok, state}
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

  def handle_call(:reset, _from, state) do
    {model, _commands} = init_app(state.app, state.opts)
    tree = render_tree(state.app, model)
    {:reply, :ok, %{state | model: model, tree: tree}}
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
        {model, _commands} = dispatch_update(state.app, state.model, event)
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
