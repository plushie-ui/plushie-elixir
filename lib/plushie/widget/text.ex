defmodule Plushie.Widget.Text do
  @moduledoc """
  Text display, renders static text.
  """

  use Plushie.Widget

  widget :text do
    field :content, :string, option: false, doc: "The text string to display."
    field :size, :float, doc: "Font size in pixels."
    field :color, Plushie.Type.Color, doc: "Text color."
    field :font, Plushie.Type.Font, doc: "Font specification."
    field :width, Plushie.Type.Length, doc: "Text widget width."
    field :height, Plushie.Type.Length, doc: "Text widget height."

    field :line_height, :any,
      doc:
        "Line height. Number is a relative multiplier; map with `%{relative: n}` or `%{absolute: n}` for explicit control."

    field :align_x, Plushie.Type.Alignment,
      doc: "Horizontal text alignment: `:left`, `:center`, `:right`."

    field :align_y, Plushie.Type.Alignment,
      doc: "Vertical text alignment: `:top`, `:center`, `:bottom`."

    field :wrapping, Plushie.Type.Wrapping,
      doc: "Text wrapping: `:none`, `:word`, `:glyph`, `:word_or_glyph`."

    field :ellipsis, :string,
      doc: "Ellipsis mode: `\"none\"`, `\"start\"`, `\"middle\"`, `\"end\"`."

    field :shaping, Plushie.Type.Shaping, doc: "Text shaping strategy: `:basic` or `:advanced`."

    field :style, Plushie.Type.Style,
      doc: "Named style: `:default`, `:primary`, `:secondary`, `:success`, `:danger`, `:warning`."

    positional [:content]
  end
end
