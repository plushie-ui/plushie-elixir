defmodule Plushie.Widget.Space do
  @moduledoc """
  Empty space, invisible spacer widget.
  """

  use Plushie.Widget

  widget :space do
    field :width, Plushie.Type.Length, doc: "Space width. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Space height. Default: shrink."
  end
end
