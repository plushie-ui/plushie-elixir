defmodule Plushie.Widget.Stack do
  @moduledoc """
  Stack layout, layers children on top of each other.
  """

  use Plushie.Widget

  @a11y_defaults %{role: :generic_container}

  widget :stack, container: true do
    field :width, Plushie.Type.Length, doc: "Stack width. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Stack height. Default: shrink."
    field :clip, :boolean, doc: "Clip children that overflow. Default: false."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."
  end
end
