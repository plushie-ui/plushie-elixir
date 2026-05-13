defmodule Plushie.Widget.Markdown do
  @moduledoc """
  Markdown display, renders parsed markdown content.

  The renderer manages an internal `markdown::Items` cache keyed by node ID.
  """

  use Plushie.Widget

  @a11y_defaults %{role: :document}

  widget :markdown do
    field :content, :string,
      option: false,
      doc: "Raw markdown text (used to seed the parser cache)."

    field :width, Plushie.Type.Length, doc: "Container width."
    field :text_size, :float, doc: "Base text size in pixels."
    field :h1_size, :float, doc: "Heading 1 size in pixels."
    field :h2_size, :float, doc: "Heading 2 size in pixels."
    field :h3_size, :float, doc: "Heading 3 size in pixels."
    field :code_size, :float, doc: "Code block text size in pixels."
    field :spacing, :float, doc: "Spacing between markdown elements in pixels."
    field :link_color, Plushie.Type.Color, doc: "Color to override the default link color."
    field :code_theme, :string, doc: "Syntax highlighting theme for code blocks."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."

    positional [:content]
  end

  event :link_click, value: :string, doc: "Emitted when a markdown link is clicked."
end
