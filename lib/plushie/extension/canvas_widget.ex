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
  @canvas_widget_props_key :__canvas_widget_props__

  @doc """
  Creates a marker node that the runtime expands during rendering.

  The marker carries the module and props. During tree normalization
  or the render cycle, the runtime calls `expand/3` with stored
  state to produce the actual canvas output.
  """
  @spec marker_node(id :: String.t(), module :: module(), props :: map()) :: map()
  def marker_node(id, module, props) when is_atom(module) and is_binary(id) do
    # Render immediately with initial state. The runtime will
    # re-render with stored state on subsequent cycles.
    state = module.__initial_state__()
    node = module.render(id, props, state)

    # Tag the node for runtime detection.
    node_props = node[:props] || node["props"] || %{}

    tagged_props =
      node_props
      |> Map.put(@canvas_widget_key, module)
      |> Map.put(@canvas_widget_props_key, props)

    Map.put(node, :props, tagged_props)
  end

  @doc """
  Re-renders a canvas_widget with its current state from the registry.

  Called by the runtime when it detects a canvas_widget node during
  tree normalization or when widget state has changed.
  """
  @spec expand(node :: map(), module :: module(), widget_state :: map()) :: map()
  def expand(%{} = node, module, widget_state) do
    id = node[:id] || node["id"]

    # After tree normalization, runtime metadata keys (__canvas_widget_props__)
    # are moved from :props to :meta. Check meta first, fall back to props
    # for pre-normalization nodes.
    meta = Map.get(node, :meta, %{})
    node_props = node[:props] || node["props"] || %{}

    props =
      Map.get(meta, @canvas_widget_props_key) ||
        Map.get(node_props, @canvas_widget_props_key, %{})
    rendered = module.render(id, props, widget_state)

    # Preserve the canvas_widget tags on the re-rendered output.
    rendered_props = rendered[:props] || rendered["props"] || %{}

    tagged_props =
      rendered_props
      |> Map.put(@canvas_widget_key, module)
      |> Map.put(@canvas_widget_props_key, props)

    Map.put(rendered, :props, tagged_props)
  end

  @doc """
  Extracts the canvas_widget module from a node's metadata, if present.
  """
  @spec module_from_node(node :: map()) :: module() | nil
  def module_from_node(%{meta: %{__canvas_widget__: module}}) when is_atom(module), do: module
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
          state :: map(),
          widget_id :: String.t()
        ) :: {{:emit, struct()} | :consumed | :passthrough, map()}
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

      :passthrough ->
        {:passthrough, state}

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
