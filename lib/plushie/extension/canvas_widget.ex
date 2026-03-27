defmodule Plushie.Extension.CanvasWidget do
  @moduledoc """
  Runtime support for `:canvas_widget` extensions.

  Canvas widgets are pure-Elixir widgets that render via canvas shapes,
  manage internal state (hover, focus, animation), and transform raw
  canvas events into semantic widget events via `handle_event/2`.

  ## Widget lifecycle

  Canvas widgets follow the standard Widget protocol pipeline:

  1. `new/2` returns a struct (like all other widgets)
  2. `Widget.to_node/1` produces a placeholder node tagged with the
     module and props as metadata
  3. During `Tree.normalize`, the placeholder is detected and rendered
     with the best available state (stored from a previous cycle, or
     initial defaults for new widgets)
  4. The rendered output is normalized in place -- no post-processing

  The tree carries widget state in `:meta` (`__canvas_widget_state__`),
  making it the single source of truth. The runtime derives a registry
  from the tree after each render for O(1) event dispatch lookups.

  ## Event dispatch (captured/ignored model)

  `invoke_handler/4` is called by the runtime when an event arrives
  for a widget inside a canvas_widget's scope. It calls the module's
  `handle_event/2` and interprets the return value using iced's
  captured/ignored model:

  - `{:emit, family, data}` -- captured, emit semantic event
  - `{:emit, family, data, new_state}` -- captured, emit + update state
  - `{:update_state, new_state}` -- captured, internal state change only
  - `:consumed` -- captured, suppress event
  - `:ignored` -- not captured, continue to next handler in scope chain

  Events are dispatched through the scope chain (innermost to outermost).
  `:ignored` continues to the next canvas_widget in the chain. Captured
  events stop propagation (or, for `:emit`, replace the event and
  continue). If no handler captures, the event reaches `app.update/2`.
  """

  @widget_states_key :__plushie_canvas_widget_states__

  @doc "Process dictionary key used to pass canvas widget states during normalization."
  @spec widget_states_key() :: atom()
  def widget_states_key, do: @widget_states_key

  @typedoc "Valid return values from `handle_event/2`."
  @type handle_event_result ::
          {:emit, atom(), term()}
          | {:emit, atom(), term(), map()}
          | {:update_state, map()}
          | :consumed
          | :ignored

  @doc "Transforms a raw event into a semantic widget event (or ignores it)."
  @callback handle_event(event :: struct(), state :: map()) :: handle_event_result()

  @doc "Renders the canvas widget given its id, resolved props, and internal state."
  @callback render(id :: String.t(), props :: map(), state :: map()) :: map()

  @doc "Returns subscription specs for this widget (optional)."
  @callback subscribe(props :: map(), state :: map()) :: [Plushie.Subscription.t()]

  @optional_callbacks [subscribe: 2]

  @doc """
  Invokes a canvas_widget's handle_event/2 and interprets the result.

  Returns `{action, new_state}` where action is one of:
  - `{:emit, %WidgetEvent{}}` -- captured with transformed event
  - `:consumed` -- captured, no output
  - `:ignored` -- not captured, continue to next handler
  """
  @spec invoke_handler(
          module :: module(),
          event :: struct(),
          state :: map(),
          widget_id :: String.t(),
          window_id :: String.t() | nil
        ) :: {{:emit, struct()} | :consumed | :ignored, map()}
  def invoke_handler(module, event, state, widget_id \\ "", window_id \\ nil) do
    case module.handle_event(event, state) do
      {:emit, family, data} ->
        {id, scope, emit_window_id} = resolve_emit_identity(event, widget_id, window_id)

        widget_event = %Plushie.Event.WidgetEvent{
          type: normalize_emit_family(module, family),
          id: id,
          scope: scope,
          window_id: emit_window_id,
          data: normalize_emit_data(data)
        }

        {{:emit, widget_event}, state}

      {:emit, family, data, new_state} when is_map(new_state) ->
        {id, scope, emit_window_id} = resolve_emit_identity(event, widget_id, window_id)

        widget_event = %Plushie.Event.WidgetEvent{
          type: normalize_emit_family(module, family),
          id: id,
          scope: scope,
          window_id: emit_window_id,
          data: normalize_emit_data(data)
        }

        {{:emit, widget_event}, new_state}

      {:update_state, new_state} when is_map(new_state) ->
        {:consumed, new_state}

      :ignored ->
        {:ignored, state}

      :consumed ->
        {:consumed, state}
    end
  end

  # Resolve the ID and scope for emitted events. For widget events
  # (which carry scope), the canvas widget's ID is the first scope
  # element and the remaining scope becomes the parent scope. For
  # non-widget events (Timer, etc.) that lack scope, fall back to
  # splitting the explicit widget_id.
  @spec resolve_emit_identity(struct() | map(), String.t(), String.t() | nil) ::
          {String.t(), [String.t()], String.t() | nil}
  defp resolve_emit_identity(
         %Plushie.Event.CanvasEvent{id: id, scope: scope, window_id: window_id},
         _widget_id,
         _fallback_window_id
       ) do
    {id, scope, window_id}
  end

  defp resolve_emit_identity(
         %{scope: [canvas_id | parent_scope], window_id: window_id},
         _widget_id,
         _fallback_window_id
       ) do
    {canvas_id, parent_scope, window_id}
  end

  defp resolve_emit_identity(
         %{scope: [], id: id, window_id: window_id},
         _widget_id,
         _fallback_window_id
       ) do
    {id, [], window_id}
  end

  defp resolve_emit_identity(_event, widget_id, fallback_window_id) do
    # Timer or other non-widget event -- use the registered widget ID.
    # Split scoped ID: "form/stars" -> {id: "stars", scope: ["form"]}
    case String.split(widget_id, "/") do
      [single] ->
        {single, [], fallback_window_id}

      parts ->
        {List.last(parts), parts |> List.delete_at(-1) |> Enum.reverse(), fallback_window_id}
    end
  end

  # Ensure emitted data uses string keys (wire-compatible).
  # Maps get their keys stringified; bare values are wrapped.
  @spec normalize_emit_family(module(), atom()) :: Plushie.Event.WidgetEvent.event_type()
  defp normalize_emit_family(module, family) when is_atom(family) do
    cond do
      family in module.__events__() ->
        {module.__widget_type__(), family}

      Plushie.Event.WidgetEvent.builtin_event_type?(family) ->
        family

      true ->
        raise ArgumentError,
              "#{inspect(module)} emitted undeclared widget event #{inspect(family)}. " <>
                "Declare it with events/1 or emit a built-in widget family."
    end
  end

  @spec normalize_emit_data(term()) :: map()
  defp normalize_emit_data(data) when is_map(data) do
    Map.new(data, fn {k, v} -> {to_string(k), v} end)
  end

  defp normalize_emit_data(value), do: %{"value" => value}
end
