defmodule Plushie.Widget.Scrollable.SingleChild do
  @moduledoc false

  defmacro __before_compile__(_env) do
    quote do
      defoverridable build: 1

      def build(%__MODULE__{} = w) do
        Plushie.Widget.Build.validate_single_child!(
          w.id,
          "scrollable",
          Enum.reverse(w.children)
        )

        super(w)
      end
    end
  end
end

defmodule Plushie.Widget.Scrollable do
  @moduledoc """
  Scrollable container, wraps child content in a scrollable viewport.
  """

  use Plushie.Widget

  @before_compile Plushie.Widget.Scrollable.SingleChild

  widget :scrollable, container: true do
    field :width, Plushie.Type.Length, doc: "Width of the scrollable area. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Height of the scrollable area. Default: shrink."

    field :direction, :atom,
      doc: "Scroll direction: `:vertical` (default), `:horizontal`, or `:both`."

    field :spacing, :float, doc: "Spacing between scrollbar and content."
    field :scrollbar_width, :float, doc: "Scrollbar track width in pixels."
    field :scrollbar_margin, :float, doc: "Margin around the scrollbar in pixels."
    field :scroller_width, :float, doc: "Scroller handle width in pixels."
    field :anchor, :atom, doc: "Scroll anchor: `:start` (default) or `:end`."
    field :on_scroll, :boolean, doc: "When true, emits scroll viewport events."
    field :auto_scroll, :boolean, doc: "When true, auto-scrolls to show new content."
    field :scrollbar_color, Plushie.Type.Color, doc: "Scrollbar track color."
    field :scroller_color, Plushie.Type.Color, doc: "Scroller handle color."
  end
end
