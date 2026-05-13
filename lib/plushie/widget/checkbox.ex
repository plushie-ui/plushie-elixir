defmodule Plushie.Widget.Checkbox do
  @moduledoc """
  Checkbox, toggleable boolean input.
  """

  use Plushie.Widget

  @a11y_defaults %{role: :check_box, label_from: :label}

  widget :checkbox do
    field :label, :string, doc: "Text label next to the checkbox."
    field :is_toggled, :boolean, option: false, wire_name: :checked, doc: "Whether checked."
    field :spacing, :float, doc: "Space between checkbox and label in pixels."
    field :width, Plushie.Type.Length, doc: "Widget width. Default: shrink."
    field :size, :float, doc: "Checkbox size in pixels."
    field :text_size, :float, doc: "Label text size in pixels."
    field :font, Plushie.Type.Font, doc: "Label font."
    field :line_height, Plushie.Type.LineHeight, doc: "Label line height."
    field :shaping, Plushie.Type.Shaping, doc: "Text shaping strategy."
    field :wrapping, Plushie.Type.Wrapping, doc: "Text wrapping mode."
    field :style, Plushie.Type.Style, doc: "Named preset or custom `StyleMap`."
    field :icon, :map, doc: "Custom icon for the check mark."
    field :disabled, :boolean, doc: "When true, cannot be toggled."

    field :required, :boolean,
      doc: "Marks the field as required. Flows into `a11y.required` automatically."

    field :validation, Plushie.Type.Validation,
      doc:
        "Form validation state. Accepts `:valid`, `:pending`, or `{:invalid, message}`. " <>
          "Flows into `a11y.invalid` and `a11y.error_message` automatically."

    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."

    positional [:label, :is_toggled]
  end

  event :toggle, value: :boolean, doc: "Emitted when toggled. Value is the new boolean state."
end
