defmodule Plushie.Canvas.Path do
  @moduledoc "Canvas arbitrary path element built from a list of drawing commands."

  use Plushie.Canvas.Element

  element :path do
    field :commands, {:list, :any}
    field :fill, :any
    field :stroke, Plushie.Canvas.Stroke
    field :opacity, :float
    field :fill_rule, :string
  end
end
