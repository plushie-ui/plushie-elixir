defmodule Plushie.Canvas.Svg do
  @moduledoc "Canvas SVG element with position and size."

  use Plushie.Canvas.Element

  element :svg do
    positional [:source, :x, :y, :w, :h]

    field :source, :string
    field :x, :float
    field :y, :float
    field :w, :float
    field :h, :float
  end
end
