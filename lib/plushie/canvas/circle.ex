defmodule Plushie.Canvas.Circle do
  @moduledoc "Canvas circle element with center, radius, and optional styling."

  use Plushie.Canvas.Element

  element :circle do
    positional [:x, :y, :r]

    field :x, :float, doc: "Center X in pixels."
    field :y, :float, doc: "Center Y in pixels."
    field :r, :float, doc: "Radius in pixels."
    field :fill, :any, doc: "Fill color or gradient."
    field :stroke, Plushie.Canvas.Stroke, doc: "Stroke descriptor."
    field :opacity, :float, doc: "Opacity from 0.0 to 1.0."
    field :fill_rule, :string, doc: "Fill rule: \"non_zero\" or \"even_odd\"."
  end
end
