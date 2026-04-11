defmodule Plushie.Canvas.Text do
  @moduledoc "Canvas text element with position, content, and optional font styling."

  use Plushie.Canvas.Element

  element :text do
    positional [:x, :y, :content]

    field :x, :float
    field :y, :float
    field :content, :string
    field :fill, :any
    field :size, :float
    field :font, :string
    field :align_x, :string
    field :align_y, :string
    field :opacity, :float
  end
end
