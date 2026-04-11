defmodule Plushie.Canvas.Image do
  @moduledoc "Canvas raster image element with position, size, and optional rotation."

  use Plushie.Canvas.Element

  element :image do
    positional [:source, :x, :y, :w, :h]

    field :source, :string
    field :x, :float
    field :y, :float
    field :w, :float
    field :h, :float
    field :rotation, :float
    field :opacity, :float
  end
end
