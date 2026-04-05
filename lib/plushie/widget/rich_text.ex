defmodule Plushie.Widget.RichText do
  @moduledoc """
  Rich text display with individually styled spans.
  """

  use Plushie.Widget

  widget :rich_text do
    field :spans, {:list, :map},
      doc: "List of span descriptors with text, size, color, font, etc."

    field :width, Plushie.Type.Length, doc: "Widget width. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Widget height. Default: shrink."
    field :size, :float, doc: "Default font size for all spans."
    field :font, Plushie.Type.Font, doc: "Default font for all spans."
    field :color, Plushie.Type.Color, doc: "Default text color for all spans."
    field :line_height, :any, doc: "Line height. Number is relative; map for explicit control."
    field :wrapping, Plushie.Type.Wrapping, doc: "Text wrapping mode."
    field :ellipsis, :string, doc: "Text ellipsis mode: \"none\", \"start\", \"middle\", \"end\"."
  end
end
