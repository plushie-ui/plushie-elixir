defmodule Plushie.Canvas.Circle do
  @moduledoc "Canvas circle element with center, radius, and optional styling."

  use Plushie.Canvas.Element

  element :circle do
    positional [:x, :y, :r]

    field :x, :float
    field :y, :float
    field :r, :float
    field :fill, :any
    field :stroke, Plushie.Canvas.Stroke
    field :opacity, :float
    field :fill_rule, :string
  end
end
