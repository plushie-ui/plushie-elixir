defmodule Plushie.Runtime.CanvasWidgets do
  @moduledoc """
  Runtime support for canvas_widget event dispatch and state management.

  Maintains a registry of active canvas_widgets (keyed by scoped ID)
  derived from the normalized tree. Routes events through the scope
  chain of canvas_widget handlers, following iced's captured/ignored
  model.

  ## Event dispatch

  When an event arrives with a scope that contains one or more
  registered canvas_widgets, the runtime builds a handler chain
  (innermost to outermost) and walks it:

  - `:ignored` -- handler didn't capture; continue to next handler
  - `:consumed` / `{:update_state, ...}` -- captured, no output; stop
  - `{:emit, ...}` -- captured with output; replace event and continue

  If no handler captures, the event reaches `app.update/2` unchanged.
  This mirrors iced's `Status::Captured` / `Status::Ignored` model.

  ## Scoped ID reconstruction

  Events carry a reversed ancestor scope list (e.g., `["picker", "form"]`
  for a widget at `form/picker`). Registry keys are forward-order scoped
  IDs. The dispatch logic reconstructs scoped IDs from the scope array
  to build the handler chain.
  """

  alias Plushie.Extension.CanvasWidget

  @doc """
  Collects subscription specs from all registered canvas_widgets.

  Each widget's `subscribe/2` callback (if defined) is called with
  props and state from the registry. The returned specs are namespaced
  with the widget ID so they don't collide with app subscriptions or
  other widgets.
  """
  @spec collect_subscriptions(registry :: map()) :: [Plushie.Subscription.t()]
  def collect_subscriptions(registry) do
    Enum.flat_map(registry, fn {widget_id, entry} ->
      %{module: module, state: widget_state} = entry
      props = Map.get(entry, :props, %{})

      if function_exported?(module, :subscribe, 2) do
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
  the result. Timer-triggered emits are dispatched through the
  scope chain of parent canvas_widgets.

  Returns:
  - `{:handled, event_or_nil, new_registry}` -- timer was for a canvas_widget
  - `:not_routed` -- not a canvas_widget timer
  """
  @spec maybe_handle_timer(registry :: map(), tag :: term()) ::
          {:handled, struct() | nil, map()} | :not_routed
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
            # Dispatch the emitted event through the scope chain
            # so parent canvas_widgets can intercept it.
            {result_event, final_registry} = dispatch_event(new_registry, transformed)
            {:handled, result_event, final_registry}

          :consumed ->
            {:handled, nil, new_registry}

          :ignored ->
            {:handled, nil, new_registry}
        end

      nil ->
        :not_routed
    end
  end

  def maybe_handle_timer(_registry, _tag), do: :not_routed

  defp namespace_subscription(spec, widget_id) do
    Plushie.Subscription.map_tag(spec, fn tag ->
      {:__canvas_widget__, widget_id, tag}
    end)
  end

  @doc """
  Derives the canvas_widget registry from the normalized tree.

  The tree carries widget metadata (module, state, props) in each
  canvas_widget node's `:meta` field. This function extracts that
  metadata into a flat map keyed by scoped ID for O(1) event
  dispatch lookups.

  Called after each render. The tree is the single source of truth --
  new widgets appear with their initial state (set during normalization),
  existing widgets carry their updated state, and removed widgets are
  simply absent.
  """
  @spec derive_registry(tree :: map() | nil) :: map()
  def derive_registry(nil), do: %{}

  def derive_registry(tree) do
    collect_widget_entries(tree, %{})
  end

  defp collect_widget_entries(%{id: id, children: children} = node, acc) do
    meta = Map.get(node, :meta, %{})

    acc =
      case meta do
        %{__canvas_widget__: module, __canvas_widget_state__: state} when is_atom(module) ->
          props = Map.get(meta, :__canvas_widget_props__, %{})
          Map.put(acc, id, %{module: module, state: state, props: props})

        _ ->
          acc
      end

    Enum.reduce(children, acc, &collect_widget_entries/2)
  end

  defp collect_widget_entries(%{children: children}, acc) do
    Enum.reduce(children, acc, &collect_widget_entries/2)
  end

  defp collect_widget_entries(_, acc), do: acc

  @doc """
  Dispatches an event through the canvas_widget handler chain.

  Builds an ordered list of canvas_widget handlers from the event's
  scope (innermost to outermost), then walks the chain:

  - `:ignored` -- not captured, continue to next handler
  - `:consumed` / `{:update_state, ...}` -- captured, stop
  - `{:emit, family, data}` -- captured, replace event, continue

  Returns `{event_or_nil, updated_registry}`. If no handler captures,
  returns the original event unchanged. If a handler consumes, returns
  nil. This follows iced's captured/ignored model.
  """
  @spec dispatch_event(registry :: map(), event :: struct()) ::
          {struct() | nil, map()}
  def dispatch_event(registry, event) when is_map(event) do
    scope = Map.get(event, :scope, [])
    chain = build_handler_chain(registry, scope)

    # If the scope chain is empty but the event's ID directly matches
    # a registered canvas_widget, include it as a handler. This covers
    # events directed AT the widget (Canvas press/move/release) vs
    # events from INSIDE the widget (element clicks, key presses).
    chain =
      if chain == [] do
        id = Map.get(event, :id, "")

        case Map.get(registry, id) do
          nil -> []
          entry -> [{id, entry}]
        end
      else
        chain
      end

    walk_chain(registry, event, chain)
  end

  # Non-map events (tuples, atoms) can't have scope -- pass through.
  def dispatch_event(registry, event), do: {event, registry}

  # Build an ordered list of {scoped_id, registry_entry} for all
  # canvas_widgets in the scope chain, from innermost to outermost.
  #
  # For scope ["picker", "form", "page"]:
  #   candidates: "page/form/picker", "page/form", "page"
  #   returns only those present in the registry, in inner-to-outer order
  @spec build_handler_chain(map(), [String.t()]) :: [{String.t(), map()}]
  defp build_handler_chain(_registry, []), do: []

  defp build_handler_chain(registry, scope) do
    forward = Enum.reverse(scope)
    len = length(forward)

    # Generate candidate scoped IDs from innermost to outermost
    for n <- len..1//-1,
        scoped_id = forward |> Enum.take(n) |> Enum.join("/"),
        entry = Map.get(registry, scoped_id),
        entry != nil do
      {scoped_id, entry}
    end
  end

  # Walk the handler chain, dispatching the event to each handler
  # until one captures it or the chain is exhausted.
  @spec walk_chain(map(), struct(), [{String.t(), map()}]) :: {struct() | nil, map()}
  defp walk_chain(registry, event, []) do
    # No handler captured -- event reaches app.update/2.
    {event, registry}
  end

  defp walk_chain(registry, event, [{scoped_id, %{module: module, state: widget_state}} | rest]) do
    {action, new_state} =
      CanvasWidget.dispatch_event(module, event, widget_state, scoped_id)

    new_registry = put_in(registry, [scoped_id, :state], new_state)

    case action do
      {:emit, transformed} ->
        # Captured with output. The transformed event continues
        # through remaining handlers in the chain.
        walk_chain(new_registry, transformed, rest)

      :consumed ->
        # Captured, no output. Stop.
        {nil, new_registry}

      :ignored ->
        # Not captured. Continue to next handler with original event.
        walk_chain(new_registry, event, rest)
    end
  end
end
