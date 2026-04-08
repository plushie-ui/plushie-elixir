defmodule Plushie.Widget.Space do
  @moduledoc """
  Empty space, invisible spacer widget.
  """

  use Plushie.Widget

  # No a11y defaults: layout containers are transparent to AT

  widget :space do
    field :width, Plushie.Type.Length, doc: "Space width. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Space height. Default: shrink."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, doc: "Accessibility annotations."
  end
end
