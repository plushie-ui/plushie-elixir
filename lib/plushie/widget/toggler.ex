defmodule Plushie.Widget.Toggler do
  @moduledoc """
  Toggler, on/off switch.
  """

  use Plushie.Widget

  @a11y_defaults %{role: :switch, label_from: :label}

  widget :toggler do
    field :is_toggled, :boolean, option: false, doc: "Whether the toggler is on."
    field :label, :string, doc: "Text label next to the toggler."
    field :spacing, :float, doc: "Space between toggler and label in pixels."
    field :width, Plushie.Type.Length, doc: "Widget width. Default: shrink."
    field :size, :float, doc: "Toggler size in pixels."
    field :text_size, :float, doc: "Label text size in pixels."
    field :font, Plushie.Type.Font, doc: "Label font."
    field :line_height, Plushie.Type.LineHeight, doc: "Label line height."
    field :shaping, Plushie.Type.Shaping, doc: "Text shaping strategy."
    field :wrapping, Plushie.Type.Wrapping, doc: "Text wrapping mode."
    field :text_alignment, Plushie.Type.Alignment, doc: "Horizontal label alignment."
    field :style, Plushie.Type.Style, doc: "Named style preset."
    field :disabled, :boolean, doc: "When true, cannot be toggled."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."

    positional [:is_toggled]
  end

  event :toggle, value: :boolean, doc: "Emitted when toggled. Value is the new boolean state."
end
