defmodule Plushie.Canvas.Rect do
  @moduledoc "Canvas rectangle element with position, size, and optional styling."

  use Plushie.Canvas.Element

  element :rect do
    positional [:x, :y, :w, :h]

    field :x, :float, doc: "X position in pixels."
    field :y, :float, doc: "Y position in pixels."
    field :w, :float, doc: "Width in pixels."
    field :h, :float, doc: "Height in pixels."
    field :fill, :any, doc: "Fill color or gradient."
    field :stroke, Plushie.Canvas.Stroke, doc: "Stroke descriptor (color, width, cap, join)."
    field :opacity, :float, doc: "Opacity from 0.0 (transparent) to 1.0 (opaque)."
    field :fill_rule, :string, doc: "Fill rule: \"non_zero\" or \"even_odd\"."
    field :radius, :any, doc: "Corner radius. Uniform number or per-corner map."
  end
end
