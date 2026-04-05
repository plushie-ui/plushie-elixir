defmodule Plushie.Widget.Checkbox do
  @moduledoc """
  Checkbox, toggleable boolean input.
  """

  use Plushie.Widget

  widget :checkbox do
    field :label, :string, doc: "Text label next to the checkbox."
    field :is_toggled, :boolean, option: false, wire_name: :checked, doc: "Whether checked."
    field :spacing, :float, doc: "Space between checkbox and label in pixels."
    field :width, Plushie.Type.Length, doc: "Widget width. Default: shrink."
    field :size, :float, doc: "Checkbox size in pixels."
    field :text_size, :float, doc: "Label text size in pixels."
    field :font, Plushie.Type.Font, doc: "Label font."
    field :line_height, :any, doc: "Label line height."
    field :shaping, :atom, doc: "Text shaping strategy."
    field :wrapping, :atom, doc: "Text wrapping mode."
    field :style, Plushie.Type.Style, doc: "Named preset or custom `StyleMap`."
    field :icon, :map, doc: "Custom icon for the check mark."
    field :disabled, :boolean, doc: "When true, cannot be toggled."

    positional [:label, :is_toggled]
  end

  event :toggle, value: :boolean, doc: "Emitted when toggled. Value is the new boolean state."
end
