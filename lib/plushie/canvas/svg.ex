defmodule Plushie.Canvas.Svg do
  @moduledoc "Canvas SVG element with position and size."

  use Plushie.Canvas.Element

  element :svg do
    positional [:source, :x, :y, :w, :h]

    field :source, :string, doc: "Path to the SVG file."
    field :x, :float, doc: "X position in pixels."
    field :y, :float, doc: "Y position in pixels."
    field :w, :float, doc: "Width in pixels."
    field :h, :float, doc: "Height in pixels."
  end
end
