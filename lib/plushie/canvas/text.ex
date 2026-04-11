defmodule Plushie.Canvas.Text do
  @moduledoc "Canvas text element with position, content, and optional font styling."

  use Plushie.Canvas.Element

  element :text do
    positional [:x, :y, :content]

    field :x, :float, doc: "X position in pixels."
    field :y, :float, doc: "Y position in pixels."
    field :content, :string, doc: "Text string to draw."
    field :fill, :any, doc: "Text fill color."
    field :size, :float, doc: "Font size in pixels."
    field :font, :string, doc: "Font specification."
    field :align_x, :string, doc: "Horizontal alignment: \"left\", \"center\", \"right\"."
    field :align_y, :string, doc: "Vertical alignment: \"top\", \"center\", \"bottom\"."
    field :opacity, :float, doc: "Opacity from 0.0 to 1.0."
  end
end
