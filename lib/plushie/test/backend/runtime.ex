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

  Windowed sessions wait after interactions, before the backend asks the
  renderer for tree hashes. That keeps renderer-backed reads from racing the
  last update without adding extra startup work to every session.

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

  require Logger

  alias Plushie.Automation.Selector
  alias Plushie.Test.{PoolAdapter, Screenshot, TreeHash}

  @typedoc "Renderer mode used by the test backend."
  @type mode :: :mock | :headless | :windowed
  @type t :: %__MODULE__{
          pool: GenServer.server(),
          session_id: String.t(),
          mode: mode(),
          sup: pid(),
          plushie_name: atom(),
          runtime: pid(),
          app: module(),
          format: :json | :msgpack
        }

  defstruct [:pool, :session_id, :mode, :sup, :plushie_name, :runtime, :app, :format]

  # -- Public API --------------------------------------------------------------

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

  def click(pid, selector, opts \\ []), do: do_interact(pid, "click", selector, %{}, opts)

  def type_text(pid, selector, text, opts \\ []),
    do: do_interact(pid, "type_text", selector, %{text: text}, opts)

  def submit(pid, selector, opts \\ []) do
    value = GenServer.call(pid, {:read_prop, selector, :submit_value})
    do_interact(pid, "submit", selector, %{value: value}, opts)
  end

  def toggle(pid, selector, value \\ nil, opts \\ []) do
    target =
      if is_boolean(value) do
        value
      else
        current = GenServer.call(pid, {:read_prop, selector, :toggle_value})
        !current
      end

    do_interact(pid, "toggle", selector, %{value: target}, opts)
  end

  def select(pid, selector, value, opts \\ []),
    do: do_interact(pid, "select", selector, %{value: value}, opts)

  def slide(pid, selector, value, opts \\ []),
    do: do_interact(pid, "slide", selector, %{value: value}, opts)

  def advance_frame(pid, timestamp),
    do: GenServer.call(pid, {:advance_frame, timestamp})

  def model(pid), do: GenServer.call(pid, :model)

  def tree(pid), do: GenServer.call(pid, :tree)

  def tree_hash(pid, name), do: GenServer.call(pid, {:tree_hash, name}, 30_000)

  def screenshot(pid, name, opts \\ []),
    do: GenServer.call(pid, {:screenshot, name, opts}, 30_000)

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

  def scroll(pid, selector, delta_x, delta_y, opts \\ []),
    do: do_interact(pid, "scroll", selector, %{delta_x: delta_x, delta_y: delta_y}, opts)

  def paste(pid, selector, text, opts \\ []),
    do: do_interact(pid, "paste", selector, %{text: text}, opts)

  def sort(pid, selector, column, direction, opts \\ []),
    do: do_interact(pid, "sort", selector, %{column: column, direction: direction}, opts)

  def canvas_press(pid, selector, x, y, button, opts \\ []),
    do: do_interact(pid, "canvas_press", selector, %{x: x, y: y, button: button}, opts)

  def canvas_release(pid, selector, x, y, button, opts \\ []),
    do: do_interact(pid, "canvas_release", selector, %{x: x, y: y, button: button}, opts)

  def canvas_move(pid, selector, x, y, opts \\ []),
    do: do_interact(pid, "canvas_move", selector, %{x: x, y: y}, opts)

  def pane_focus_cycle(pid, selector, opts \\ []),
    do: do_interact(pid, "pane_focus_cycle", selector, %{}, opts)

  def register_effect_stub(pid, kind, response),
    do: GenServer.call(pid, {:register_effect_stub, kind, response}, 10_000)

  def unregister_effect_stub(pid, kind),
    do: GenServer.call(pid, {:unregister_effect_stub, kind}, 10_000)

  def get_diagnostics(pid),
    do: GenServer.call(pid, :get_diagnostics)

  defp do_interact(pid, action, selector, payload, opts \\ []) do
    explicit_window = Keyword.get(opts, :window)

    # Extract window_id from window-qualified selector syntax, falling
    # back to the explicit :window option.
    {parsed_window, _} = if selector, do: Selector.parse(selector), else: {nil, selector}
    window_id = explicit_window || parsed_window

    # For widget-targeted actions, validate the selector resolves before
    # sending the interact request. Fail fast with a clear error.
    if selector != nil do
      validate_selector!(pid, action, selector, window_id)
    end

    case GenServer.call(
           pid,
           {:interact, action, selector, payload, window_id},
           10_000
         ) do
      :ok -> :ok
      {:error, reason} -> raise "interaction failed: #{inspect(reason)}"
    end
  catch
    :exit, reason -> raise "runtime crashed during interaction: #{inspect(reason)}"
  end

  defp validate_selector!(pid, action, selector, window_id) do
    # Only validate selectors we can resolve Elixir-side. Text-content
    # selectors (bare strings, {:role, _}, {:label, _}) and :focused are
    # resolved by the renderer during the interact step.
    if id_selector?(selector) do
      # Scoped IDs like "#canvas/element" reference canvas interactive
      # elements. The element isn't a tree node, so validate the parent
      # canvas node instead. Element existence is verified renderer-side.
      lookup = scoped_parent_selector(selector) || selector

      # Extract window_id from the selector if present, falling back to
      # the explicit window_id option.
      {parsed_window, _} = Selector.parse(selector)
      effective_window = window_id || parsed_window

      case GenServer.call(pid, {:find, lookup}, 10_000) do
        nil ->
          hint =
            if effective_window,
              do: " (window: #{inspect(effective_window)})",
              else: ""

          raise "widget not found: #{inspect(selector)}#{hint}. " <>
                  "The #{action} action requires a valid widget selector."

        _element ->
          :ok
      end
    end
  end

  # For scoped selectors like "#canvas/element" or "main#canvas/element",
  # returns the parent selector. Returns nil for non-scoped selectors.
  defp scoped_parent_selector(selector) when is_binary(selector) do
    {window_id, resolved} = Selector.parse(selector)

    case resolved do
      "#" <> rest ->
        case String.split(rest, "/", parts: 2) do
          [parent, _element] ->
            prefix = if window_id, do: window_id <> "#", else: "#"
            prefix <> parent

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp scoped_parent_selector(_), do: nil

  defp id_selector?(selector) when is_binary(selector) do
    case Selector.parse(selector) do
      {_window_id, "#" <> _} -> true
      _ -> false
    end
  end

  defp id_selector?(_), do: false

  # -- GenServer ---------------------------------------------------------------

  @impl GenServer
  def init({app, opts}) do
    pool = Keyword.get(opts, :pool, Plushie.TestPool)
    format = Keyword.get(opts, :format, :msgpack)
    mode = Keyword.get(opts, :mode, resolve_test_mode())

    # Start pool adapter that connects Bridge <-> SessionPool.
    {:ok, adapter_pid, session_id} = PoolAdapter.start_link(pool: pool, format: format)
    Process.monitor(adapter_pid)

    # Generate a unique name for this test session's Plushie supervisor.
    tag = :erlang.unique_integer([:positive])
    plushie_name = :"plushie_test_#{tag}"

    # Start the full Plushie supervisor tree with iostream transport.
    {:ok, sup} =
      Plushie.start_link(app,
        name: plushie_name,
        transport: {:iostream, adapter_pid},
        format: format,
        session_id: session_id,
        app_opts: Keyword.get(opts, :init_arg) |> List.wrap()
      )

    runtime = Plushie.runtime_for(plushie_name)

    Plushie.Runtime.sync(runtime)

    {:ok,
     %__MODULE__{
       pool: pool,
       session_id: session_id,
       mode: mode,
       sup: sup,
       plushie_name: plushie_name,
       runtime: runtime,
       app: app,
       format: format
     }}
  end

  @impl GenServer
  def handle_call(:runtime, _from, state) do
    {:reply, state.runtime, state}
  end

  def handle_call({:advance_frame, timestamp}, _from, state) do
    bridge = Plushie.Runtime.get_bridge(state.runtime)

    if bridge do
      Plushie.Bridge.send_advance_frame(bridge, timestamp)
    end

    # Sync to process any events the renderer sends back
    Plushie.Runtime.sync(state.runtime)
    {:reply, :ok, state}
  end

  def handle_call(:model, _from, state) do
    model = Plushie.Runtime.get_model(state.runtime)
    {:reply, model, state}
  end

  def handle_call(:tree, _from, state) do
    tree = Plushie.Runtime.get_tree(state.runtime)
    {:reply, resolve_animation_descriptors(tree), state}
  end

  def handle_call({:tree_hash, name}, _from, state) do
    current_state = wait_for_draw(state)
    tree = Plushie.Runtime.get_tree(current_state.runtime) |> resolve_animation_descriptors()
    {:reply, TreeHash.from_tree(name, tree, current_state.mode), state}
  end

  def handle_call({:screenshot, name, opts}, _from, state) do
    bridge = Plushie.bridge_for(state.plushie_name)
    response = Plushie.Bridge.screenshot(bridge, name, opts)
    {:reply, Screenshot.from_response(response, state.format, state.mode), state}
  end

  def handle_call({:find, selector}, _from, state) do
    tree = Plushie.Runtime.get_tree(state.runtime) |> resolve_animation_descriptors()
    element = Selector.find(tree, selector)
    {:reply, element, state}
  end

  def handle_call({:read_prop, selector, :toggle_value}, _from, state) do
    tree = Plushie.Runtime.get_tree(state.runtime)
    node = Selector.find_node(tree, selector)
    props = (node && node[:props]) || %{}

    value =
      props[:is_toggled] || props["is_toggled"] ||
        props[:checked] || props["checked"] || false

    {:reply, value, state}
  end

  def handle_call({:read_prop, selector, :submit_value}, _from, state) do
    tree = Plushie.Runtime.get_tree(state.runtime)
    node = Selector.find_node(tree, selector)
    props = (node && node[:props]) || %{}
    value = props[:value] || props["value"] || ""
    {:reply, value, state}
  end

  def handle_call({:interact, action, selector, payload, window_id}, _from, state) do
    tree = Plushie.Runtime.get_tree(state.runtime)
    sel = Selector.encode(selector, tree, window_id)
    result = Plushie.Runtime.interact(state.runtime, action, sel, payload)
    wait_for_draw(state)
    {:reply, result, state}
  end

  # Backwards compat: interact without window_id
  def handle_call({:interact, action, selector, payload}, from, state) do
    handle_call({:interact, action, selector, payload, nil}, from, state)
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
    :ok = Plushie.Test.SessionPool.unregister(state.pool, state.session_id)

    {:ok, adapter_pid, session_id} =
      PoolAdapter.start_link(pool: state.pool, format: state.format)

    Process.monitor(adapter_pid)

    tag = :erlang.unique_integer([:positive])
    plushie_name = :"plushie_test_#{tag}"

    {:ok, sup} =
      Plushie.start_link(state.app,
        name: plushie_name,
        transport: {:iostream, adapter_pid},
        format: state.format,
        session_id: session_id
      )

    runtime = Plushie.runtime_for(plushie_name)
    Plushie.Runtime.sync(runtime)

    {:reply, :ok,
     %{state | session_id: session_id, sup: sup, plushie_name: plushie_name, runtime: runtime}}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    Logger.error("plushie test backend: pool adapter crashed: #{inspect(reason)}")
    {:stop, {:adapter_crashed, reason}, state}
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

  @valid_modifiers %{
    "shift" => :shift,
    "ctrl" => :ctrl,
    "alt" => :alt,
    "logo" => :logo,
    "command" => :command
  }

  # Case-insensitive lookup for named keys. Maps downcased input to
  # PascalCase wire format (matching what the renderer sends back in
  # events). Built from Protocol.Keys which is the source of truth
  # for all named key strings.
  @named_key_lookup Plushie.Protocol.Keys.named_key_names()
                    |> Enum.map(fn name -> {String.downcase(name), name} end)
                    |> Map.new()

  defp parse_key(key) when is_binary(key) do
    parts = String.split(key, "+")
    {mods, [key_name]} = Enum.split(parts, -1)

    modifiers =
      for mod <- mods, into: %{} do
        case Map.get(@valid_modifiers, String.downcase(mod)) do
          nil ->
            raise ArgumentError,
                  "unknown modifier #{inspect(mod)} in key #{inspect(key)}. " <>
                    "Valid: shift, ctrl, alt, logo, command"

          atom ->
            {atom, true}
        end
      end

    # Single characters are sent as-is (lowercased for iced's logical key).
    # Named keys are normalized to PascalCase (same format the renderer
    # sends back in events, so widget handle_event patterns match).
    key_name =
      cond do
        String.length(key_name) == 1 ->
          String.downcase(key_name)

        resolved = Map.get(@named_key_lookup, String.downcase(key_name)) ->
          resolved

        true ->
          raise ArgumentError,
                "unknown key #{inspect(key_name)} in #{inspect(key)}. " <>
                  "Examples: Tab, ArrowRight, PageUp, Escape, Enter. " <>
                  "See Plushie.Protocol.Keys for the full list"
      end

    {key_name, modifiers}
  end

  @spec wait_for_draw(t()) :: t()
  defp wait_for_draw(state) do
    wait_for_draw(Plushie.bridge_for(state.plushie_name), state.mode, state.plushie_name)
    state
  end

  @spec wait_for_draw(GenServer.server(), mode(), atom()) :: :ok
  defp wait_for_draw(_bridge, mode, _plushie_name) when mode in [:mock, :headless], do: :ok

  defp wait_for_draw(bridge, :windowed, plushie_name) do
    case Plushie.Bridge.screenshot(bridge, "__sync__", width: 1, height: 1) do
      %{"type" => "screenshot_response"} ->
        :ok

      other ->
        raise RuntimeError,
              "windowed renderer returned unexpected sync response for #{inspect(plushie_name)}: #{inspect(other)}"
    end
  end

  @spec resolve_test_mode() :: mode()
  defp resolve_test_mode do
    case System.get_env("PLUSHIE_TEST_BACKEND") do
      "headless" -> :headless
      "windowed" -> :windowed
      _ -> :mock
    end
  end

  # Resolves animation descriptors in tree props to their target values.
  # In mock mode, transitions resolve instantly. This ensures tests see
  # concrete prop values instead of descriptor maps.
  defp resolve_animation_descriptors(nil), do: nil

  defp resolve_animation_descriptors(%{props: props, children: children} = node) do
    resolved_props =
      Map.new(props, fn
        {k, %{"type" => t, "to" => to}} when t in ["transition", "spring"] ->
          {k, to}

        {k, %{"type" => "sequence", "steps" => steps}} when is_list(steps) and steps != [] ->
          last_to = steps |> List.last() |> Map.get("to")
          {k, last_to}

        # Resolve nested descriptors inside exit prop
        {k, %{} = map} when k in [:exit, "exit"] ->
          resolved =
            Map.new(map, fn
              {sk, %{"type" => t, "to" => to}} when t in ["transition", "spring"] ->
                {sk, to}

              {sk, %{"type" => "sequence", "steps" => steps}}
              when is_list(steps) and steps != [] ->
                {sk, steps |> List.last() |> Map.get("to")}

              other ->
                other
            end)

          {k, resolved}

        pair ->
          pair
      end)

    %{
      node
      | props: resolved_props,
        children: Enum.map(children, &resolve_animation_descriptors/1)
    }
  end

  defp resolve_animation_descriptors(other), do: other
end
