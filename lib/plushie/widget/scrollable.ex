defmodule Plushie.Widget.Scrollable do
  @moduledoc """
  Scrollable container, wraps child content in a scrollable viewport.
  """

  use Plushie.Widget

  widget :scrollable, container: :single do
    field :width, Plushie.Type.Length, doc: "Width of the scrollable area. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Height of the scrollable area. Default: shrink."

    field :direction, Plushie.Type.Direction,
      doc: "Scroll direction: `:vertical` (default), `:horizontal`, or `:both`."

    field :spacing, :float, doc: "Spacing between scrollbar and content."
    field :scrollbar_width, :float, doc: "Scrollbar track width in pixels."
    field :scrollbar_margin, :float, doc: "Margin around the scrollbar in pixels."
    field :scroller_width, :float, doc: "Scroller handle width in pixels."
    field :anchor, Plushie.Type.Anchor, doc: "Scroll anchor: `:start` (default) or `:end`."
    field :on_scroll, :boolean, doc: "When true, emits scroll viewport events."
    field :auto_scroll, :boolean, doc: "When true, auto-scrolls to show new content."
    field :scrollbar_color, Plushie.Type.Color, doc: "Scrollbar track color."
    field :scroller_color, Plushie.Type.Color, doc: "Scroller handle color."
  end
end
