defmodule Julep.Test.Backend.EventDecoder do
  @moduledoc """
  Decodes wire-format event maps into Elixir event structs.

  Shared between `RendererBase` (headless/full backends) and `Pooled`
  (session pool backend). Keeps event decoding logic in one place so
  new event families don't need to be added in multiple locations.
  """

  alias Julep.Event.Key, as: KeyEvent
  alias Julep.Event.Mouse, as: MouseEvent
  alias Julep.Event.Widget, as: WidgetEvent

  require Logger

  @doc """
  Decode a wire event map into an Elixir event struct.

  Returns `nil` for unrecognised event families (caller should skip).
  """
  @spec decode(family :: String.t(), id :: String.t(), event :: map()) :: struct() | nil
  def decode("click", id, _event), do: %WidgetEvent{type: :click, id: id}

  def decode("input", id, event),
    do: %WidgetEvent{type: :input, id: id, value: event["value"] || ""}

  def decode("submit", id, event),
    do: %WidgetEvent{type: :submit, id: id, value: event["value"] || ""}

  def decode("toggle", id, event),
    do: %WidgetEvent{type: :toggle, id: id, value: event["value"] || false}

  def decode("select", id, event),
    do: %WidgetEvent{type: :select, id: id, value: event["value"] || ""}

  def decode("slide", id, event),
    do: %WidgetEvent{type: :slide, id: id, value: event["value"] || 0}

  def decode("slide_release", id, event),
    do: %WidgetEvent{type: :slide_release, id: id, value: event["value"] || 0}

  def decode("paste", id, event),
    do: %WidgetEvent{type: :paste, id: id, value: event["value"] || ""}

  def decode("sort", id, event) do
    data = event["data"] || %{}
    %WidgetEvent{type: :sort, id: id, data: data["column"]}
  end

  def decode("open", id, _event), do: %WidgetEvent{type: :open, id: id}
  def decode("close", id, _event), do: %WidgetEvent{type: :close, id: id}

  def decode("pane_focus_cycle", id, _event),
    do: %WidgetEvent{type: :pane_focus_cycle, id: id}

  def decode("canvas_press", id, event),
    do: %WidgetEvent{type: :canvas_press, id: id, data: event["data"] || %{}}

  def decode("canvas_release", id, event),
    do: %WidgetEvent{type: :canvas_release, id: id, data: event["data"] || %{}}

  def decode("canvas_move", id, event),
    do: %WidgetEvent{type: :canvas_move, id: id, data: event["data"] || %{}}

  def decode("key_press", _id, event), do: decode_key_event(:press, event)
  def decode("key_release", _id, event), do: decode_key_event(:release, event)

  def decode("cursor_moved", _id, event) do
    data = event["data"] || %{}
    %MouseEvent{type: :moved, x: data["x"] || 0, y: data["y"] || 0}
  end

  def decode("scroll", _id, event) do
    data = event["data"] || %{}
    %MouseEvent{type: :scroll, delta_x: data["delta_x"] || 0, delta_y: data["delta_y"] || 0}
  end

  def decode(type, id, _event) do
    # Check for known extension event families.
    known = ~w(extension_event extension_error)
    if type in known do
      %WidgetEvent{type: String.to_existing_atom(type), id: id}
    else
      Logger.debug("unhandled event family #{inspect(type)} for widget #{inspect(id)}")
      nil
    end
  end

  # -- Key event decoding ------------------------------------------------------

  defp decode_key_event(type, event) do
    key_str = event["value"] || ""

    modifiers_map =
      cond do
        is_map(event["modifiers"]) ->
          event["modifiers"]

        is_map(event["data"]) and is_map(event["data"]["modifiers"]) ->
          event["data"]["modifiers"]

        true ->
          %{}
      end

    key = parse_wire_key_name(key_str)

    modifiers = %Julep.KeyModifiers{
      ctrl: modifiers_map["ctrl"] || false,
      shift: modifiers_map["shift"] || false,
      alt: modifiers_map["alt"] || false,
      logo: modifiers_map["logo"] || false,
      command: modifiers_map["ctrl"] || false
    }

    text =
      if is_binary(key) and byte_size(key) == 1,
        do: key,
        else: nil

    %KeyEvent{
      type: type,
      key: key,
      modified_key: key,
      physical_key: nil,
      location: :standard,
      modifiers: modifiers,
      text: text,
      repeat: false
    }
  end

  @wire_key_names %{
    "enter" => :enter,
    "escape" => :escape,
    "tab" => :tab,
    "backspace" => :backspace,
    "space" => :space,
    "delete" => :delete,
    "up" => :up,
    "down" => :down,
    "left" => :left,
    "right" => :right,
    "home" => :home,
    "end" => :end,
    "page_up" => :page_up,
    "page_down" => :page_down,
    "f1" => :f1,
    "f2" => :f2,
    "f3" => :f3,
    "f4" => :f4,
    "f5" => :f5,
    "f6" => :f6,
    "f7" => :f7,
    "f8" => :f8,
    "f9" => :f9,
    "f10" => :f10,
    "f11" => :f11,
    "f12" => :f12
  }

  defp parse_wire_key_name(name), do: Map.get(@wire_key_names, name, name)
end
