defmodule Plushie.Canvas.Image do
  @moduledoc "Canvas raster image element with position, size, and optional rotation."

  use Plushie.Canvas.Element

  element :image do
    positional [:source, :x, :y, :w, :h]

    field :source, :string, doc: "Path to the image file."
    field :x, :float, doc: "X position in pixels."
    field :y, :float, doc: "Y position in pixels."
    field :w, :float, doc: "Width in pixels."
    field :h, :float, doc: "Height in pixels."

    field :rotation, Plushie.Canvas.Angle,
      doc: "Rotation angle in degrees. Accepts `{value, :rad}` for radians."

    field :opacity, :float, doc: "Opacity from 0.0 to 1.0."
  end
end
