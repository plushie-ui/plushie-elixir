defmodule Plushie.Runtime.CanvasWidgets do
  @moduledoc """
  Runtime support for canvas_widget event interception and state management.

  Maintains a registry of active canvas_widgets (keyed by scoped ID) and
  their internal state. Intercepts events whose scope matches a registered
  canvas_widget, routes them through the widget's `handle_event/2`, and
  returns either a transformed event or a suppression signal.
  """

  alias Plushie.Extension.CanvasWidget

  @doc """
  Collects subscription specs from all registered canvas_widgets.

  Each widget's `subscribe/2` callback (if defined) is called with
  props and state. The returned specs are namespaced with the widget
  ID so they don't collide with app subscriptions or other widgets.
  """
  @spec collect_subscriptions(registry :: map(), tree :: map() | nil) :: [
          Plushie.Subscription.t()
        ]
  def collect_subscriptions(registry, tree) do
    Enum.flat_map(registry, fn {widget_id, %{module: module, state: widget_state}} ->
      if function_exported?(module, :subscribe, 2) do
        props = extract_props(tree, widget_id)

        module.subscribe(props, widget_state)
        |> List.wrap()
        |> Enum.map(&namespace_subscription(&1, widget_id))
      else
        []
      end
    end)
  end

  @doc """
  Checks if a timer event is for a canvas_widget subscription.
  If so, routes it through the widget's handle_event and returns
  the updated registry. Otherwise returns :passthrough.
  """
  @spec maybe_handle_timer(registry :: map(), tag :: term()) ::
          {:handled, map()} | :passthrough
  def maybe_handle_timer(registry, {:__canvas_widget__, widget_id, inner_tag}) do
    case Map.get(registry, widget_id) do
      %{module: module, state: widget_state} ->
        timer_event = %Plushie.Event.Timer{
          tag: inner_tag,
          timestamp: System.monotonic_time(:millisecond)
        }

        {_action, new_state} =
          CanvasWidget.dispatch_event(module, timer_event, widget_state, widget_id)

        new_registry = put_in(registry, [widget_id, :state], new_state)
        {:handled, new_registry}

      nil ->
        :passthrough
    end
  end

  def maybe_handle_timer(_registry, _tag), do: :passthrough

  # Extract the local (un-scoped) ID from a scoped path.
  # "page/form/stars" → "stars"
  defp raw_id(scoped_id) do
    case String.split(scoped_id, "/") do
      [local] -> local
      parts -> List.last(parts)
    end
  end

  defp namespace_subscription(spec, widget_id) do
    Plushie.Subscription.map_tag(spec, fn tag ->
      {:__canvas_widget__, widget_id, tag}
    end)
  end

  # Extract props for a widget from the tree by its scoped ID.
  defp extract_props(nil, _widget_id), do: %{}

  defp extract_props(tree, widget_id) do
    case find_node_by_id(tree, widget_id) do
      %{props: props} -> props
      _ -> %{}
    end
  end

  defp find_node_by_id(%{id: id} = node, target) when id == target, do: node

  defp find_node_by_id(%{children: children}, target) do
    Enum.find_value(children, fn child -> find_node_by_id(child, target) end)
  end

  defp find_node_by_id(_, _), do: nil

  @doc """
  Scans a normalized tree for canvas_widget nodes and updates the registry.

  Called after each render cycle. Detects new canvas_widgets (initializes
  state), removed canvas_widgets (cleans up state), and preserved ones
  (keeps state).
  """
  @spec sync_registry(registry :: map(), tree :: map() | nil) :: map()
  def sync_registry(registry, nil), do: registry

  def sync_registry(registry, tree) do
    current = collect_canvas_widgets(tree, %{})

    # Initialize state for new widgets
    new_entries =
      for {id, module} <- current, not Map.has_key?(registry, id), into: %{} do
        {id, %{module: module, state: module.__initial_state__(), raw_id: raw_id(id)}}
      end

    # Preserve state for existing widgets
    kept =
      for {id, module} <- current, Map.has_key?(registry, id), into: %{} do
        existing = Map.get(registry, id)
        {id, %{existing | module: module, raw_id: raw_id(id)}}
      end

    Map.merge(new_entries, kept)
  end

  @doc """
  Checks if an event should be intercepted by a canvas_widget.

  If the event's immediate scope parent is a registered canvas_widget,
  dispatches through the widget's handle_event/2. Returns:
  - `{:intercepted, transformed_event_or_nil, new_registry}` -- event was handled
  - `:passthrough` -- event is not for a canvas_widget
  """
  @spec maybe_intercept(registry :: map(), event :: struct()) ::
          {:intercepted, struct() | nil, map()} | :passthrough
  def maybe_intercept(registry, event) do
    with %{scope: [parent_id | _]} <- event,
         %{module: module, state: widget_state} <- Map.get(registry, parent_id) do
      {action, new_state} = CanvasWidget.dispatch_event(module, event, widget_state, parent_id)

      new_registry = put_in(registry, [parent_id, :state], new_state)

      case action do
        {:emit, transformed_event} ->
          {:intercepted, transformed_event, new_registry}

        :consumed ->
          {:intercepted, nil, new_registry}

        :passthrough ->
          {:intercepted, event, new_registry}
      end
    else
      _ -> :passthrough
    end
  end

  # -- Tree scanning ----------------------------------------------------------

  defp collect_canvas_widgets(%{id: id, children: children} = node, acc) do
    meta = Map.get(node, :meta, %{})

    acc =
      case Map.get(meta, :__canvas_widget__) do
        nil -> acc
        module when is_atom(module) -> Map.put(acc, id, module)
      end

    Enum.reduce(children, acc, &collect_canvas_widgets/2)
  end

  defp collect_canvas_widgets(%{children: children}, acc) do
    Enum.reduce(children, acc, &collect_canvas_widgets/2)
  end

  defp collect_canvas_widgets(_, acc), do: acc
end
