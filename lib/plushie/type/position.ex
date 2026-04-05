defmodule Plushie.Type.Position do
  @moduledoc """
  Placement value for the tooltip `position` prop.

  Maps to iced's `tooltip::Position` enum.
  """

  use Plushie.Type

  @type t :: :top | :bottom | :left | :right | :follow_cursor

  enum([:top, :bottom, :left, :right, :follow_cursor])
end
