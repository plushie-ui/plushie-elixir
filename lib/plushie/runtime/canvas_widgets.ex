defmodule Plushie.Runtime.CanvasWidgets do
  @moduledoc """
  Runtime support for canvas_widget event interception and state management.

  Maintains a registry of active canvas_widgets (keyed by scoped ID) and
  their internal state. Intercepts events whose scope matches a registered
  canvas_widget, routes them through the widget's `handle_event/2`, and
  returns either a transformed event or a suppression signal.

  ## Hierarchical bubbling

  Canvas_widgets compose hierarchically. When a child canvas_widget emits
  a semantic event, the runtime checks whether the emitted event's scope
  contains a parent canvas_widget. If so, the parent's `handle_event/2`
  receives the child's semantic event and can transform, consume, or pass
  it through. Bubbling continues until no more parent canvas_widgets
  remain in the scope chain, at which point the final event reaches
  `app.update/2`.

  ## Scoped ID reconstruction

  Events carry a reversed ancestor scope list (e.g., `["picker", "form"]`
  for a widget at `form/picker`). Registry keys are forward-order scoped
  IDs. The interception logic reconstructs scoped IDs from the scope
  array to find matching registry entries.
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
  the result. Timer-triggered emits bubble through parent canvas_widgets.

  Returns:
  - `{:handled, event_or_nil, new_registry}` -- timer was for a canvas_widget
  - `:passthrough` -- not a canvas_widget timer
  """
  @spec maybe_handle_timer(registry :: map(), tag :: term()) ::
          {:handled, struct() | nil, map()} | :passthrough
  def maybe_handle_timer(registry, {:__canvas_widget__, widget_id, inner_tag}) do
    case Map.get(registry, widget_id) do
      %{module: module, state: widget_state} ->
        timer_event = %Plushie.Event.Timer{
          tag: inner_tag,
          timestamp: System.monotonic_time(:millisecond)
        }

        {action, new_state} =
          CanvasWidget.dispatch_event(module, timer_event, widget_state, widget_id)

        new_registry = put_in(registry, [widget_id, :state], new_state)

        case action do
          {:emit, transformed} ->
            bubble(new_registry, transformed)

          :consumed ->
            {:handled, nil, new_registry}

          :passthrough ->
            {:handled, nil, new_registry}
        end

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

  Walks the event's scope from innermost to outermost, looking for
  the first registered canvas_widget. If found, dispatches through
  the widget's `handle_event/2`. Emitted events bubble up through
  parent canvas_widgets in the scope chain.

  Returns:
  - `{:intercepted, transformed_event_or_nil, new_registry}` -- event was handled
  - `:passthrough` -- no canvas_widget in scope
  """
  @spec maybe_intercept(registry :: map(), event :: struct()) ::
          {:intercepted, struct() | nil, map()} | :passthrough
  def maybe_intercept(registry, event) when is_map(event) do
    case Map.get(event, :scope, []) do
      [] ->
        :passthrough

      scope ->
        case find_innermost_widget(registry, scope) do
          nil ->
            :passthrough

          {scoped_id, %{module: module, state: widget_state}} ->
            {action, new_state} =
              CanvasWidget.dispatch_event(module, event, widget_state, scoped_id)

            new_registry = put_in(registry, [scoped_id, :state], new_state)

            case action do
              {:emit, transformed} ->
                bubble(new_registry, transformed)

              :consumed ->
                {:intercepted, nil, new_registry}

              :passthrough ->
                {:intercepted, event, new_registry}
            end
        end
    end
  end

  def maybe_intercept(_registry, _event), do: :passthrough

  # Bubble an emitted event up through parent canvas_widgets.
  # Stops when no more canvas_widgets are found in scope, or when
  # a parent consumes or passes through. Returns the same shape
  # as maybe_intercept: {:intercepted, event_or_nil, registry}.
  @spec bubble(map(), struct()) :: {:intercepted, struct() | nil, map()}
  defp bubble(registry, event) do
    case Map.get(event, :scope, []) do
      [] ->
        {:intercepted, event, registry}

      scope ->
        case find_innermost_widget(registry, scope) do
          nil ->
            {:intercepted, event, registry}

          {scoped_id, %{module: module, state: widget_state}} ->
            {action, new_state} =
              CanvasWidget.dispatch_event(module, event, widget_state, scoped_id)

            new_registry = put_in(registry, [scoped_id, :state], new_state)

            case action do
              {:emit, transformed} ->
                bubble(new_registry, transformed)

              :consumed ->
                {:intercepted, nil, new_registry}

              :passthrough ->
                {:intercepted, event, new_registry}
            end
        end
    end
  end

  # Find the innermost canvas_widget in a scope chain.
  # The scope is a reversed ancestor list: ["picker", "form", "page"].
  # We reconstruct scoped IDs starting from the innermost ancestor
  # and work outward until we find one in the registry.
  #
  # For scope ["picker", "form", "page"]:
  #   try "page/form/picker", then "page/form", then "page"
  defp find_innermost_widget(registry, scope) do
    forward = Enum.reverse(scope)
    find_innermost_widget(registry, forward, length(forward))
  end

  defp find_innermost_widget(_registry, _forward, 0), do: nil

  defp find_innermost_widget(registry, forward, n) do
    scoped_id = forward |> Enum.take(n) |> Enum.join("/")

    case Map.get(registry, scoped_id) do
      nil -> find_innermost_widget(registry, forward, n - 1)
      entry -> {scoped_id, entry}
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
