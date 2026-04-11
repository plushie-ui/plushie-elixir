defmodule Plushie.Canvas.Line do
  @moduledoc "Canvas line element between two points with optional stroke and opacity."

  use Plushie.Canvas.Element

  element :line do
    positional [:x1, :y1, :x2, :y2]

    field :x1, :float, doc: "Start X in pixels."
    field :y1, :float, doc: "Start Y in pixels."
    field :x2, :float, doc: "End X in pixels."
    field :y2, :float, doc: "End Y in pixels."
    field :stroke, Plushie.Canvas.Stroke, doc: "Stroke descriptor."
    field :opacity, :float, doc: "Opacity from 0.0 to 1.0."
  end
end
