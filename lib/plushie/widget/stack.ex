defmodule Plushie.Widget.Stack do
  @moduledoc """
  Stack layout, layers children on top of each other.
  """

  use Plushie.Widget

  # No a11y defaults: layout containers are transparent to AT

  widget :stack, container: true do
    field :width, Plushie.Type.Length, doc: "Stack width. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Stack height. Default: shrink."
    field :clip, :boolean, doc: "Clip children that overflow. Default: false."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, doc: "Accessibility annotations."
  end
end
