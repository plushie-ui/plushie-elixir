defmodule Plushie.Widget.TextEditor do
  @moduledoc """
  Text editor, multi-line editable text area.

  The renderer manages an internal `text_editor::Content` cache keyed by
  node ID. The `content` prop seeds the initial content.
  """

  use Plushie.Widget

  widget :text_editor do
    field :content, :string, doc: "Initial text content (seeds the editor cache)."
    field :placeholder, :string, doc: "Placeholder text shown when editor is empty."
    field :width, Plushie.Type.Length, doc: "Editor width. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Editor height. Default: shrink."
    field :min_height, :float, doc: "Minimum height in pixels."
    field :max_height, :float, doc: "Maximum height in pixels."
    field :font, Plushie.Type.Font, doc: "Font specification."
    field :size, :float, doc: "Font size in pixels."
    field :line_height, :any, doc: "Line height. Number is relative; map for explicit control."
    field :padding, :float, doc: "Uniform padding in pixels."
    field :wrapping, Plushie.Type.Wrapping, doc: "Text wrapping mode."
    field :input_purpose, :string, doc: "Input purpose: \"normal\", \"secure\", \"terminal\"."

    field :highlight_syntax, :string,
      doc: "Language extension for syntax highlighting (e.g. \"rs\", \"py\", \"ex\")."

    field :highlight_theme, :string, doc: "Highlighter theme name."
    field :style, Plushie.Type.Style, doc: "Named preset or custom `StyleMap`."
    field :key_bindings, {:list, :map}, doc: "Declarative key binding rules for the editor."
    field :placeholder_color, Plushie.Type.Color, doc: "Placeholder text color."
    field :selection_color, Plushie.Type.Color, doc: "Text selection highlight color."
  end

  event :edit, value: :string, doc: "Emitted on content changes."
  event :focused, doc: "Emitted when the editor gains focus."
  event :blurred, doc: "Emitted when the editor loses focus."
end
