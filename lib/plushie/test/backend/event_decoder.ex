defmodule Plushie.Test.Backend.EventDecoder do
  @moduledoc """
  Decodes wire-format event maps into Elixir event structs.

  Decodes wire-format events from the renderer into typed Elixir event
  structs. Used by the Bridge to convert incoming protocol messages.
  """

  alias Plushie.Event.Canvas, as: CanvasEvent
  alias Plushie.Event.Key, as: KeyEvent
  alias Plushie.Event.Mouse, as: MouseEvent
  alias Plushie.Event.Widget, as: WidgetEvent
  alias Plushie.Protocol.Keys

  require Logger

  @doc """
  Decode a wire event map into an Elixir event struct.

  Returns `nil` for unrecognised event families (caller should skip).
  """
  @spec decode(family :: String.t(), id :: String.t(), event :: map()) :: struct() | nil
  def decode("click", id, event) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :click, id: local, scope: scope, data: event["data"]}
  end

  def decode("input", id, event) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :input, id: local, scope: scope, value: event["value"] || ""}
  end

  def decode("submit", id, event) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :submit, id: local, scope: scope, value: event["value"] || ""}
  end

  def decode("toggle", id, event) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :toggle, id: local, scope: scope, value: event["value"] || false}
  end

  def decode("select", id, event) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :select, id: local, scope: scope, value: event["value"] || ""}
  end

  def decode("slide", id, event) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :slide, id: local, scope: scope, value: event["value"] || 0}
  end

  def decode("slide_release", id, event) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :slide_release, id: local, scope: scope, value: event["value"] || 0}
  end

  def decode("paste", id, event) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :paste, id: local, scope: scope, value: event["value"] || ""}
  end

  def decode("sort", id, event) do
    {local, scope} = split_scoped_id(id)
    data = event["data"] || %{}
    %WidgetEvent{type: :sort, id: local, scope: scope, data: data["column"]}
  end

  def decode("open", id, _event) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :open, id: local, scope: scope}
  end

  def decode("close", id, _event) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :close, id: local, scope: scope}
  end

  def decode("pane_focus_cycle", id, _event) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :pane_focus_cycle, id: local, scope: scope}
  end

  def decode("canvas_press", id, event) do
    {local, scope} = split_scoped_id(id)
    data = event["data"] || %{}

    %CanvasEvent{
      type: :press,
      id: local,
      scope: scope,
      x: data["x"] || 0,
      y: data["y"] || 0,
      button: Map.get(data, "button", "left")
    }
  end

  def decode("canvas_release", id, event) do
    {local, scope} = split_scoped_id(id)
    data = event["data"] || %{}

    %CanvasEvent{
      type: :release,
      id: local,
      scope: scope,
      x: data["x"] || 0,
      y: data["y"] || 0,
      button: Map.get(data, "button", "left")
    }
  end

  def decode("canvas_move", id, event) do
    {local, scope} = split_scoped_id(id)
    data = event["data"] || %{}
    %CanvasEvent{type: :move, id: local, scope: scope, x: data["x"] || 0, y: data["y"] || 0}
  end

  def decode("canvas_scroll", id, event) do
    {local, scope} = split_scoped_id(id)
    data = event["data"] || %{}

    %CanvasEvent{
      type: :scroll,
      id: local,
      scope: scope,
      x: data["x"] || 0,
      y: data["y"] || 0,
      delta_x: data["delta_x"] || 0,
      delta_y: data["delta_y"] || 0
    }
  end

  def decode("key_press", _id, event), do: decode_key_event(:press, event)
  def decode("key_release", _id, event), do: decode_key_event(:release, event)

  def decode("cursor_moved", _id, event) do
    data = event["data"] || %{}
    %MouseEvent{type: :moved, x: data["x"] || 0, y: data["y"] || 0}
  end

  def decode("wheel_scrolled", _id, event) do
    data = event["data"] || %{}
    %MouseEvent{type: :scroll, delta_x: data["delta_x"] || 0, delta_y: data["delta_y"] || 0}
  end

  # NOTE: Canvas element events use generic %Widget{} with untyped data
  # maps (string keys, string values) instead of dedicated event structs
  # with parsed fields. This is inconsistent with %Key{} and %Canvas{}
  # which have typed fields and atom key names. When canvas elements are
  # promoted to first-class widget events, these should get proper structs
  # and this dynamic atom construction should become explicit decode clauses
  # like Protocol.Decode uses.
  # canvas_element_click is now emitted as standard "click" by the
  # renderer (handled by the "click" decoder above). Remaining
  # canvas-specific events keep their families but use scoped IDs
  # (canvas_id/element_id) which split_scoped_id handles.
  @canvas_element_families ~w(
    canvas_element_enter canvas_element_leave
    canvas_element_key_press canvas_element_key_release
    canvas_element_drag canvas_element_drag_end
    canvas_element_focused canvas_element_blurred
    canvas_group_focused canvas_group_blurred
  )

  def decode(type, id, event) when type in @canvas_element_families do
    {local, scope} = split_scoped_id(id)
    atom = String.to_atom(type)
    %WidgetEvent{type: atom, id: local, scope: scope, data: event["data"] || %{}}
  end

  def decode("canvas_focused", id, _event) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :canvas_focused, id: local, scope: scope, data: %{}}
  end

  def decode("canvas_blurred", id, _event) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :canvas_blurred, id: local, scope: scope, data: %{}}
  end

  def decode("diagnostic", _id, event) do
    %Plushie.Event.System{type: :diagnostic, data: event["data"] || %{}}
  end

  # Extension event families. Using ~w()a ensures these atoms exist
  # at compile time so String.to_existing_atom won't raise at runtime.
  @extension_families MapSet.new(~w(extension_event extension_error)a)

  def decode(type, id, _event) do
    atom = try_existing_atom(type)

    if atom && MapSet.member?(@extension_families, atom) do
      {local, scope} = split_scoped_id(id)
      %WidgetEvent{type: atom, id: local, scope: scope}
    else
      Logger.debug("unhandled event family #{inspect(type)} for widget #{inspect(id)}")
      nil
    end
  end

  defp try_existing_atom(str) do
    String.to_existing_atom(str)
  rescue
    ArgumentError -> nil
  end

  # -- Scoped ID splitting ----------------------------------------------------

  defp split_scoped_id(id) when is_binary(id) do
    case String.split(id, "/") do
      [local] ->
        {local, []}

      parts ->
        local = List.last(parts)
        scope = parts |> List.delete_at(-1) |> Enum.reverse()
        {local, scope}
    end
  end

  defp split_scoped_id(id), do: {id, []}

  # -- Key event decoding ------------------------------------------------------

  defp decode_key_event(type, event) do
    data = event["data"] || %{}
    key_str = data["key"] || event["value"] || ""
    key = Keys.parse_key(key_str)

    %KeyEvent{
      type: type,
      key: key,
      modified_key: Keys.parse_key(data["modified_key"] || key_str),
      physical_key: Keys.parse_physical_key(data["physical_key"]),
      location: Keys.parse_location(data["location"]),
      modifiers: parse_modifiers(event, data),
      text: if(type == :press, do: data["text"]),
      repeat: data["repeat"] || false,
      captured: event["captured"] || false
    }
  end

  defp parse_modifiers(event, data) do
    m =
      cond do
        is_map(event["modifiers"]) -> event["modifiers"]
        is_map(data["modifiers"]) -> data["modifiers"]
        true -> %{}
      end

    %Plushie.KeyModifiers{
      ctrl: m["ctrl"] || false,
      shift: m["shift"] || false,
      alt: m["alt"] || false,
      logo: m["logo"] || false,
      command: m["ctrl"] || false
    }
  end
end
