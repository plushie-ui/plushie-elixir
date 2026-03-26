defmodule Plushie.Protocol.Parsers do
  @moduledoc false

  # Shared strict enum parsers used by the decode layer.

  @type parse_reason :: :unknown | :invalid
  @type parse_result(value) :: {:ok, value} | {:error, parse_reason()}

  @mouse_buttons %{
    "left" => :left,
    "right" => :right,
    "middle" => :middle,
    "back" => :back,
    "forward" => :forward
  }

  @doc "Parses a required mouse button string to an atom."
  @spec parse_mouse_button(term()) :: parse_result(:left | :right | :middle | :back | :forward)
  def parse_mouse_button(str) when is_binary(str) do
    case Map.fetch(@mouse_buttons, str) do
      {:ok, button} -> {:ok, button}
      :error -> {:error, :unknown}
    end
  end

  def parse_mouse_button(_), do: {:error, :invalid}

  @doc "Parses an optional scroll unit string to an atom."
  @spec parse_scroll_unit(term()) :: parse_result(:line | :pixel | nil)
  def parse_scroll_unit(nil), do: {:ok, nil}
  def parse_scroll_unit("line"), do: {:ok, :line}
  def parse_scroll_unit("lines"), do: {:ok, :line}
  def parse_scroll_unit("pixel"), do: {:ok, :pixel}
  def parse_scroll_unit("pixels"), do: {:ok, :pixel}
  def parse_scroll_unit(str) when is_binary(str), do: {:error, :unknown}
  def parse_scroll_unit(_), do: {:error, :invalid}

  @doc "Parses an optional pane action string to an atom."
  @spec parse_pane_action(term()) :: parse_result(:picked | :dropped | :canceled | nil)
  def parse_pane_action(nil), do: {:ok, nil}
  def parse_pane_action("picked"), do: {:ok, :picked}
  def parse_pane_action("dropped"), do: {:ok, :dropped}
  def parse_pane_action("canceled"), do: {:ok, :canceled}
  def parse_pane_action(str) when is_binary(str), do: {:error, :unknown}
  def parse_pane_action(_), do: {:error, :invalid}

  @doc "Parses an optional pane region or edge string to an atom."
  @spec parse_pane_region(term()) :: parse_result(:center | :top | :bottom | :left | :right | nil)
  def parse_pane_region(nil), do: {:ok, nil}
  def parse_pane_region("center"), do: {:ok, :center}
  def parse_pane_region("top"), do: {:ok, :top}
  def parse_pane_region("bottom"), do: {:ok, :bottom}
  def parse_pane_region("left"), do: {:ok, :left}
  def parse_pane_region("right"), do: {:ok, :right}
  def parse_pane_region(str) when is_binary(str), do: {:error, :unknown}
  def parse_pane_region(_), do: {:error, :invalid}

  @doc """
  Returns true when an event family is explicitly namespaced for widget-specific
  extension use as `widget_type:event_name`.
  """
  @spec extension_family?(term()) :: boolean()
  def extension_family?(family) when is_binary(family) do
    case String.split(family, ":", parts: 2) do
      [widget_type, event_name] -> widget_type != "" and event_name != ""
      _ -> false
    end
  end

  def extension_family?(_), do: false
end
