defmodule Plushie.Widget.Toggler do
  @moduledoc """
  Toggler, on/off switch.
  """

  use Plushie.Widget

  widget :toggler do
    field :is_toggled, :boolean, option: false, doc: "Whether the toggler is on."
    field :label, :string, doc: "Text label next to the toggler."
    field :spacing, :float, doc: "Space between toggler and label in pixels."
    field :width, Plushie.Type.Length, doc: "Widget width. Default: shrink."
    field :size, :float, doc: "Toggler size in pixels."
    field :text_size, :float, doc: "Label text size in pixels."
    field :font, Plushie.Type.Font, doc: "Label font."
    field :line_height, :any, doc: "Label line height."
    field :shaping, :atom, doc: "Text shaping strategy."
    field :wrapping, :atom, doc: "Text wrapping mode."
    field :text_alignment, :atom, doc: "Horizontal label alignment."
    field :style, Plushie.Type.Style, doc: "Named style preset."
    field :disabled, :boolean, doc: "When true, cannot be toggled."

    positional [:is_toggled]
  end

  event :toggle, value: :boolean, doc: "Emitted when toggled. Value is the new boolean state."
end
