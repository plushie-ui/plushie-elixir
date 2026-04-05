defmodule Plushie.Widget.Rule do
  @moduledoc """
  Horizontal or vertical rule (divider line).
  """

  use Plushie.Widget

  widget :rule do
    field :height, :float, doc: "Line thickness in pixels (for horizontal rules)."
    field :width, :float, doc: "Line thickness in pixels (for vertical rules)."
    field :direction, :atom, doc: "`:horizontal` (default) or `:vertical`."
    field :style, Plushie.Type.Style, doc: "Named preset or custom `StyleMap`."
  end
end
