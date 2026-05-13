defmodule Plushie.Widget.TextEditor do
  @moduledoc """
  Text editor, multi-line editable text area.

  The renderer manages an internal `text_editor::Content` cache keyed by
  node ID. The `content` prop seeds the initial content.
  """

  use Plushie.Widget

  @a11y_defaults %{role: :multiline_text_input, label_from: :placeholder}

  widget :text_editor do
    field :content, :string, doc: "Initial text content (seeds the editor cache)."
    field :placeholder, :string, doc: "Placeholder text shown when editor is empty."
    field :width, Plushie.Type.Length, doc: "Editor width. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Editor height. Default: shrink."
    field :min_height, :float, doc: "Minimum height in pixels."
    field :max_height, :float, doc: "Maximum height in pixels."
    field :font, Plushie.Type.Font, doc: "Font specification."
    field :size, :float, doc: "Font size in pixels."

    field :line_height, Plushie.Type.LineHeight,
      doc: "Line height. Number is relative; map for explicit control."

    field :padding, :float, doc: "Uniform padding in pixels."
    field :wrapping, Plushie.Type.Wrapping, doc: "Text wrapping mode."

    field :text_direction, Plushie.Type.TextDirection,
      doc: "Text direction hint: `:auto`, `:ltr`, or `:rtl`."

    field :input_purpose,
          {:enum,
           [:normal, :secure, :terminal, :number, :decimal, :phone, :email, :url, :search]},
          doc:
            "Input purpose: `:normal`, `:secure`, `:terminal`, `:number`, `:decimal`, `:phone`, `:email`, `:url`, `:search`."

    field :highlight_syntax, :string,
      doc: "Language extension for syntax highlighting (e.g. \"rs\", \"py\", \"ex\")."

    field :highlight_theme, :string, doc: "Highlighter theme name."
    field :style, Plushie.Type.Style, doc: "Named preset or custom `StyleMap`."
    field :key_bindings, {:list, :map}, doc: "Declarative key binding rules for the editor."
    field :placeholder_color, Plushie.Type.Color, doc: "Placeholder text color."
    field :selection_color, Plushie.Type.Color, doc: "Text selection highlight color."
    field :on_paste, :boolean, doc: "When true, emits paste events. Default: false."

    field :required, :boolean,
      doc: "Marks the field as required. Flows into `a11y.required` automatically."

    field :validation, Plushie.Type.Validation,
      doc:
        "Form validation state. Accepts `:valid`, `:pending`, or `{:invalid, message}`. " <>
          "Flows into `a11y.invalid` and `a11y.error_message` automatically."

    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."
  end

  event :edit, value: :string, doc: "Emitted on content changes."
  event :paste, value: :string, doc: "Emitted on paste (requires `on_paste` prop)."
  event :focused, doc: "Emitted when the editor gains focus."
  event :blurred, doc: "Emitted when the editor loses focus."
end
