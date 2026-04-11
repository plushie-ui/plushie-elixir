defmodule Plushie.Canvas.Line do
  @moduledoc "Canvas line element between two points with optional stroke and opacity."

  use Plushie.Canvas.Element

  element :line do
    positional [:x1, :y1, :x2, :y2]

    field :x1, :float
    field :y1, :float
    field :x2, :float
    field :y2, :float
    field :stroke, Plushie.Canvas.Stroke
    field :opacity, :float
  end
end
