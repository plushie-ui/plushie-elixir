defmodule Toddy.Protocol.Parsers do
  @moduledoc false

  # Shared string-to-atom parsers used by the decode layer.

  @mouse_buttons %{
    "left" => :left,
    "right" => :right,
    "middle" => :middle,
    "back" => :back,
    "forward" => :forward
  }

  @doc "Parses a mouse button string to an atom."
  @spec parse_mouse_button(String.t() | nil) :: atom() | String.t() | nil
  def parse_mouse_button(nil), do: nil
  def parse_mouse_button(str) when is_binary(str), do: Map.get(@mouse_buttons, str, str)

  @doc "Parses a scroll unit string to an atom."
  @spec parse_scroll_unit(String.t() | nil) :: :line | :pixel | nil
  def parse_scroll_unit(nil), do: nil
  def parse_scroll_unit("line"), do: :line
  def parse_scroll_unit("lines"), do: :line
  def parse_scroll_unit("pixel"), do: :pixel
  def parse_scroll_unit("pixels"), do: :pixel
  def parse_scroll_unit(_), do: nil

  @doc "Parses a pane action string to an atom."
  @spec parse_pane_action(String.t() | nil) :: :picked | :dropped | :canceled | nil
  def parse_pane_action(nil), do: nil
  def parse_pane_action("picked"), do: :picked
  def parse_pane_action("dropped"), do: :dropped
  def parse_pane_action("canceled"), do: :canceled
  def parse_pane_action(_), do: nil

  @doc "Parses a pane region/edge string to an atom."
  @spec parse_pane_region(String.t() | nil) :: :center | :top | :bottom | :left | :right | nil
  def parse_pane_region(nil), do: nil
  def parse_pane_region("center"), do: :center
  def parse_pane_region("top"), do: :top
  def parse_pane_region("bottom"), do: :bottom
  def parse_pane_region("left"), do: :left
  def parse_pane_region("right"), do: :right
  def parse_pane_region(_), do: nil

  @doc """
  Converts an event family string to an existing atom, falling back to the
  raw string if the atom doesn't already exist.
  """
  @spec safe_event_type(String.t()) :: atom() | String.t()
  def safe_event_type(family) do
    String.to_existing_atom(family)
  rescue
    ArgumentError -> family
  end
end
