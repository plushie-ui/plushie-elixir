defmodule Plushie.Widget.Floating do
  @moduledoc """
  Floating overlay, positions child with optional translation and scaling.
  """

  use Plushie.Widget

  widget :float, container: :single do
    field :translate_x, :float, doc: "Horizontal translation in pixels. Default: 0."
    field :translate_y, :float, doc: "Vertical translation in pixels. Default: 0."
    field :scale, :float, doc: "Scale factor for the child content."
    field :width, Plushie.Type.Length, doc: "Float width."
    field :height, Plushie.Type.Length, doc: "Float height."
  end
end
