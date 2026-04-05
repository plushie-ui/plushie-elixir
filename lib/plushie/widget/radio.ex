defmodule Plushie.Widget.Radio do
  @moduledoc """
  Radio button, one-of-many selection.

  All radios in a group should share the same `group` prop value. The
  `selected` prop should be set to the currently selected value across
  all radios in the group.
  """

  use Plushie.Widget

  widget :radio do
    field :value, :string, option: false, doc: "The value this radio represents."

    field :selected, :string,
      option: false,
      default: nil,
      doc: "Currently selected value in the group."

    field :label, :string, doc: "Label text. Defaults to `value` if omitted."
    field :group, :string, doc: "Group identifier for event routing."
    field :spacing, :float, doc: "Space between radio and label in pixels."
    field :width, Plushie.Type.Length, doc: "Widget width. Default: shrink."
    field :size, :float, doc: "Radio button size in pixels."
    field :text_size, :float, doc: "Label text size in pixels."
    field :font, Plushie.Type.Font, doc: "Label font."
    field :line_height, :any, doc: "Label line height."
    field :shaping, Plushie.Type.Shaping, doc: "Text shaping strategy."
    field :wrapping, Plushie.Type.Wrapping, doc: "Text wrapping mode."
    field :style, Plushie.Type.Style, doc: "Named preset or custom `StyleMap`."

    positional [:value, :selected]
  end

  event :select, value: :string, doc: "Emitted when this radio is selected."
end
