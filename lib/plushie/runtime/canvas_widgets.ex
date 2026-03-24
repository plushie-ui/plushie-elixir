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
        {id, %{module: module, state: module.__initial_state__()}}
      end

    # Preserve state for existing widgets
    kept =
      for {id, module} <- current, Map.has_key?(registry, id), into: %{} do
        existing = Map.get(registry, id)
        # Module might have changed if widget type swapped (rare)
        {id, %{existing | module: module}}
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
      {action, new_state} = CanvasWidget.dispatch_event(module, event, widget_state)

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

  defp collect_canvas_widgets(%{id: id, props: props, children: children}, acc) do
    acc =
      case Map.get(props, :__canvas_widget__) do
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
