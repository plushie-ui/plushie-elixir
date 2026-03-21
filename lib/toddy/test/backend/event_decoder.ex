defmodule Toddy.Test.Backend.EventDecoder do
  @moduledoc """
  Decodes wire-format event maps into Elixir event structs.

  Shared between `RendererBase` (headless/full backends) and `Pooled`
  (session pool backend). Keeps event decoding logic in one place so
  new event families don't need to be added in multiple locations.
  """

  alias Toddy.Event.Key, as: KeyEvent
  alias Toddy.Event.Mouse, as: MouseEvent
  alias Toddy.Event.Widget, as: WidgetEvent

  require Logger

  @doc """
  Decode a wire event map into an Elixir event struct.

  Returns `nil` for unrecognised event families (caller should skip).
  """
  @spec decode(family :: String.t(), id :: String.t(), event :: map()) :: struct() | nil
  def decode("click", id, _event) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :click, id: local, scope: scope}
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
    %WidgetEvent{type: :canvas_press, id: local, scope: scope, data: event["data"] || %{}}
  end

  def decode("canvas_release", id, event) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :canvas_release, id: local, scope: scope, data: event["data"] || %{}}
  end

  def decode("canvas_move", id, event) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :canvas_move, id: local, scope: scope, data: event["data"] || %{}}
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

    modifiers = %Toddy.KeyModifiers{
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
