defmodule Plushie.Widget.Column do
  @moduledoc """
  Column layout, arranges children vertically.
  """

  use Plushie.Widget

  # No a11y defaults: layout containers are transparent to AT

  widget :column, container: true do
    field :spacing, :float, doc: "Vertical space between children in pixels. Default: 0."
    field :padding, Plushie.Type.Padding, doc: "Padding inside the column."
    field :width, Plushie.Type.Length, doc: "Width of the column. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Height of the column. Default: shrink."
    field :max_width, :float, doc: "Maximum width in pixels."

    field :align_x, Plushie.Type.Alignment,
      doc: "Horizontal alignment of children: `:left`, `:center`, `:right`."

    field :clip, :boolean, doc: "Clip children that overflow. Default: false."
    field :wrap, :boolean, doc: "Wrap children to next column when they overflow. Default: false."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, doc: "Accessibility annotations."
  end
end
