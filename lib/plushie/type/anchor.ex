defmodule Plushie.Type.Anchor do
  @moduledoc """
  Anchor values for the scrollbar `alignment` prop.

  Maps to iced's `scrollable::Anchor` enum.
  """

  use Plushie.Type

  @type t :: :start | :end

  enum([:start, :end])
end
