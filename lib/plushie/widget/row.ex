defmodule Plushie.Widget.Row do
  @moduledoc """
  Row layout, arranges children horizontally.
  """

  use Plushie.Widget

  widget :row, container: true do
    field :spacing, :float, doc: "Horizontal space between children in pixels. Default: 0."
    field :padding, Plushie.Type.Padding, doc: "Padding inside the row."
    field :width, Plushie.Type.Length, doc: "Width of the row. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Height of the row. Default: shrink."

    field :align_y, Plushie.Type.Alignment,
      doc: "Vertical alignment of children: `:top`, `:center`, `:bottom`."

    field :max_width, :float, doc: "Maximum width of the row in pixels."
    field :clip, :boolean, doc: "Clip children that overflow. Default: false."
    field :wrap, :boolean, doc: "Wrap children to next row when they overflow. Default: false."
  end
end
