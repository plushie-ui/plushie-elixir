defmodule Plushie.Widget.Pin do
  @moduledoc """
  Pin layout, positions child at absolute coordinates.
  """

  use Plushie.Widget

  widget :pin, container: :single do
    field :x, :float, doc: "X position in pixels. Default: 0."
    field :y, :float, doc: "Y position in pixels. Default: 0."
    field :width, Plushie.Type.Length, doc: "Pin container width. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Pin container height. Default: shrink."
  end
end
