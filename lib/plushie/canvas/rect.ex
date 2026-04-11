defmodule Plushie.Canvas.Rect do
  @moduledoc "Canvas rectangle element with position, size, and optional styling."

  use Plushie.Canvas.Element

  element :rect do
    positional [:x, :y, :w, :h]

    field :x, :float
    field :y, :float
    field :w, :float
    field :h, :float
    field :fill, :any
    field :stroke, :any
    field :opacity, :float
    field :fill_rule, :string
    field :radius, :any
  end
end
