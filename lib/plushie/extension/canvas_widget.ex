defmodule Plushie.Extension.CanvasWidget do
  @moduledoc """
  Runtime support for `:canvas_widget` extensions.

  Canvas widgets are pure-Elixir widgets that render via canvas shapes,
  manage internal state (hover, focus, animation), and transform raw
  canvas events into semantic widget events via `handle_event/2`.

  ## Node tagging

  When a canvas_widget's `new/2` produces a node, `tag_node/3` wraps it
  in metadata that the runtime can detect during event dispatch. The
  metadata includes the extension module and the widget's props, which
  the runtime uses to route events through the module's `handle_event/2`.

  ## Event transformation

  The `dispatch_event/3` function is called by the runtime when an event
  arrives for a widget inside a canvas_widget's scope. It calls the
  module's `handle_event/2` and interprets the return value:

  - `{:emit, family, data}` -- suppress original, emit semantic event
  - `{:emit, family, data, new_state}` -- emit + update internal state
  - `{:update_state, new_state}` -- update state, no event
  - `:passthrough` -- deliver original event to update/2
  - `:consumed` -- suppress, no event

  ## State management

  Widget internal state is stored in the runtime's `widget_states` map,
  keyed by the widget's scoped ID. State persists across renders and is
  passed to `render/3` and `handle_event/2`. When a canvas_widget leaves
  the tree, its state is cleaned up.
  """

  @canvas_widget_key :__canvas_widget__

  @doc """
  Tags a canvas widget node with extension metadata.

  Adds a `__canvas_widget__` entry to the node's props containing the
  module reference. The tree normalizer preserves this and the runtime
  reads it during event dispatch.
  """
  @spec tag_node(node :: map(), module :: module(), props :: map()) :: map()
  def tag_node(%{} = node, module, _props) when is_atom(module) do
    props = node[:props] || node["props"] || %{}
    tagged_props = Map.put(props, @canvas_widget_key, module)
    Map.put(node, :props, tagged_props)
  end

  @doc """
  Extracts the canvas_widget module from a node's props, if present.
  """
  @spec module_from_node(node :: map()) :: module() | nil
  def module_from_node(%{props: props}) when is_map(props) do
    Map.get(props, @canvas_widget_key)
  end

  def module_from_node(_), do: nil

  @doc """
  Dispatches an event through a canvas_widget's handle_event/2.

  Returns `{action, new_state}` where action is one of:
  - `{:emit, %Widget{}}` -- deliver transformed event to update/2
  - `:consumed` -- suppress event
  - `:passthrough` -- deliver original event to update/2
  """
  @spec dispatch_event(
          module :: module(),
          event :: struct(),
          state :: map()
        ) :: {{:emit, struct()} | :consumed | :passthrough, map()}
  def dispatch_event(module, event, state) do
    case module.handle_event(event, state) do
      {:emit, family, data} ->
        widget_event = %Plushie.Event.Widget{
          type: family,
          id: event_source_id(event),
          scope: event_source_scope(event),
          data: normalize_emit_data(data)
        }

        {{:emit, widget_event}, state}

      {:emit, family, data, new_state} when is_map(new_state) ->
        widget_event = %Plushie.Event.Widget{
          type: family,
          id: event_source_id(event),
          scope: event_source_scope(event),
          data: normalize_emit_data(data)
        }

        {{:emit, widget_event}, new_state}

      {:update_state, new_state} when is_map(new_state) ->
        {:consumed, new_state}

      :passthrough ->
        {:passthrough, state}

      :consumed ->
        {:consumed, state}
    end
  end

  # For emitted events, the ID should be the canvas_widget's own ID
  # (the scope parent), not the element that triggered the event.
  defp event_source_id(event) do
    case event do
      %{scope: [canvas_id | _]} -> canvas_id
      %{id: id} -> id
    end
  end

  # The scope for emitted events is the canvas_widget's parent scope
  # (everything above the canvas in the scope chain).
  defp event_source_scope(event) do
    case event do
      %{scope: [_canvas_id | parent_scope]} -> parent_scope
      _ -> []
    end
  end

  defp normalize_emit_data(data) when is_map(data) do
    Map.new(data, fn {k, v} -> {to_string(k), v} end)
  end

  defp normalize_emit_data(value), do: %{"value" => value}
end
