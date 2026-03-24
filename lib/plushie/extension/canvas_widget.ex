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

  `dispatch_event/4` is called by the runtime when an event arrives
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

  @doc """
  Extracts the canvas_widget module from a node's metadata, if present.
  """
  @spec module_from_node(node :: map()) :: module() | nil
  def module_from_node(%{meta: %{__canvas_widget__: module}}) when is_atom(module), do: module
  def module_from_node(_), do: nil

  @doc """
  Dispatches an event through a canvas_widget's handle_event/2.

  Returns `{action, new_state}` where action is one of:
  - `{:emit, %Widget{}}` -- captured with transformed event
  - `:consumed` -- captured, no output
  - `:ignored` -- not captured, continue to next handler
  """
  @spec dispatch_event(
          module :: module(),
          event :: struct(),
          state :: map(),
          widget_id :: String.t()
        ) :: {{:emit, struct()} | :consumed | :ignored, map()}
  def dispatch_event(module, event, state, widget_id \\ "") do
    case module.handle_event(event, state) do
      {:emit, family, data} ->
        {id, scope} = resolve_emit_identity(event, widget_id)

        widget_event = %Plushie.Event.Widget{
          type: family,
          id: id,
          scope: scope,
          data: normalize_emit_data(data)
        }

        {{:emit, widget_event}, state}

      {:emit, family, data, new_state} when is_map(new_state) ->
        {id, scope} = resolve_emit_identity(event, widget_id)

        widget_event = %Plushie.Event.Widget{
          type: family,
          id: id,
          scope: scope,
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
  @spec resolve_emit_identity(struct() | map(), String.t()) :: {String.t(), [String.t()]}
  defp resolve_emit_identity(%{scope: [canvas_id | parent_scope]}, _widget_id) do
    {canvas_id, parent_scope}
  end

  defp resolve_emit_identity(%{scope: [], id: id}, _widget_id) do
    {id, []}
  end

  defp resolve_emit_identity(_event, widget_id) do
    # Timer or other non-widget event -- use the registered widget ID.
    # Split scoped ID: "form/stars" -> {id: "stars", scope: ["form"]}
    case String.split(widget_id, "/") do
      [single] -> {single, []}
      parts -> {List.last(parts), parts |> List.delete_at(-1) |> Enum.reverse()}
    end
  end

  # Ensure emitted data uses string keys (wire-compatible).
  # Maps get their keys stringified; bare values are wrapped.
  @spec normalize_emit_data(term()) :: map()
  defp normalize_emit_data(data) when is_map(data) do
    Map.new(data, fn {k, v} -> {to_string(k), v} end)
  end

  defp normalize_emit_data(value), do: %{"value" => value}
end
