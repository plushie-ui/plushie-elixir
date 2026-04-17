defmodule Plushie.Widget.TextInput do
  @moduledoc """
  Text input field, single-line editable text.
  """

  use Plushie.Widget

  @a11y_defaults %{role: :text_input, label_from: :placeholder}

  widget :text_input do
    field :value, :string,
      option: false,
      doc: "Current text content. Required for controlled input."

    field :placeholder, :string, doc: "Placeholder text shown when value is empty."
    field :padding, Plushie.Type.Padding, doc: "Internal padding."
    field :width, Plushie.Type.Length, doc: "Input width. Default: fill."
    field :size, :float, doc: "Font size in pixels."
    field :font, Plushie.Type.Font, doc: "Font specification."

    field :line_height, Plushie.Type.LineHeight,
      doc: "Line height. Number is a relative multiplier; map for explicit control."

    field :align_x, Plushie.Type.Alignment,
      doc: "Text horizontal alignment: `:left`, `:center`, `:right`."

    field :icon, :map,
      doc:
        "Icon inside the input field. Map with `code_point`, `size`, `spacing`, `side`, `font` keys."

    field :on_submit, :boolean, doc: "When true, enables submit on Enter."
    field :on_paste, :boolean, doc: "When true, emits paste events. Default: false."
    field :secure, :boolean, doc: "Mask input as password dots. Default: false."

    field :input_purpose, {:enum, [:normal, :secure, :terminal]},
      doc: "Input purpose hint: `:normal`, `:secure`, `:terminal`."

    field :style, Plushie.Type.Style, doc: "Named style preset or custom `StyleMap`."
    field :placeholder_color, Plushie.Type.Color, doc: "Placeholder text color."
    field :selection_color, Plushie.Type.Color, doc: "Text selection highlight color."
    field :required, :boolean,
      doc: "Marks the field as required. Flows into `a11y.required` automatically."

    field :validation, :any,
      doc:
        "Form validation state. Accepts `:valid`, `:pending`, or `{:invalid, message}`. " <>
          "Flows into `a11y.invalid` and `a11y.error_message` automatically."

    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."

    positional [:value]
  end

  event :input, value: :string, doc: "Emitted on every text change."
  event :submit, value: :string, doc: "Emitted on Enter (requires `on_submit` prop)."
  event :paste, value: :string, doc: "Emitted on paste (requires `on_paste` prop)."
  event :focused, doc: "Emitted when the input gains focus."
  event :blurred, doc: "Emitted when the input loses focus."
end
