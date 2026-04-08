defmodule Plushie.Widget.Rule do
  @moduledoc """
  Horizontal or vertical rule (divider line).
  """

  use Plushie.Widget

  @a11y_defaults %{role: :splitter}

  widget :rule do
    field :height, :float, doc: "Line thickness in pixels (for horizontal rules)."
    field :width, :float, doc: "Line thickness in pixels (for vertical rules)."
    field :direction, Plushie.Type.Direction, doc: "`:horizontal` (default) or `:vertical`."
    field :style, Plushie.Type.Style, doc: "Named preset or custom `StyleMap`."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."
  end
end
