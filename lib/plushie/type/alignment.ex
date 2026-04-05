defmodule Plushie.Type.Alignment do
  @moduledoc """
  Alignment values for `align_x` and `align_y` widget props.

  Horizontal: `:left`, `:center`, `:right`.
  Vertical: `:top`, `:center`, `:bottom`.
  """

  use Plushie.Type

  @type horizontal :: :left | :center | :right
  @type vertical :: :top | :center | :bottom
  @type t :: horizontal() | vertical()

  enum([:left, :center, :right, :top, :bottom])
end
