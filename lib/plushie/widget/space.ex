defmodule Plushie.Widget.Space do
  @moduledoc """
  Empty space, invisible spacer widget.
  """

  use Plushie.Widget

  @a11y_defaults %{role: :generic_container}

  widget :space do
    field :width, Plushie.Type.Length, doc: "Space width. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Space height. Default: shrink."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."
  end
end
