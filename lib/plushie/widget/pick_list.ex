defmodule Plushie.Widget.PickList do
  @moduledoc """
  Pick list, dropdown selection.
  """

  use Plushie.Widget

  @a11y_defaults %{role: :combo_box, has_popup: "listbox", label_from: :placeholder}

  widget :pick_list do
    field :options, {:list, :string}, option: false, doc: "Available choices."
    field :selected, :string, doc: "Currently selected value."
    field :placeholder, :string, doc: "Placeholder text when nothing is selected."
    field :width, Plushie.Type.Length, doc: "Widget width. Default: shrink."
    field :padding, Plushie.Type.Padding, doc: "Internal padding."
    field :text_size, :float, doc: "Text size in pixels."
    field :font, Plushie.Type.Font, doc: "Font specification."
    field :line_height, Plushie.Type.LineHeight, doc: "Text line height."
    field :menu_height, :float, doc: "Maximum dropdown menu height in pixels."
    field :shaping, Plushie.Type.Shaping, doc: "Text shaping strategy."
    field :handle, :map, doc: "Dropdown handle indicator customization."

    field :ellipsis, {:enum, [:none, :start, :middle, :end]},
      doc: "Text ellipsis: `:none`, `:start`, `:middle`, or `:end`."

    field :menu_style, :map, doc: "Inline style for the dropdown menu."
    field :style, Plushie.Type.Style, doc: "Named preset or custom `StyleMap`."
    field :on_open, :boolean, doc: "Emit open event when the dropdown opens."
    field :on_close, :boolean, doc: "Emit close event when the dropdown closes."
    field :required, :boolean,
      doc: "Marks the field as required. Flows into `a11y.required` automatically."

    field :validation, :any,
      doc:
        "Form validation state. Accepts `:valid`, `:pending`, or `{:invalid, message}`. " <>
          "Flows into `a11y.invalid` and `a11y.error_message` automatically."

    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."

    positional [:options]
  end

  event :select, value: :string, doc: "Emitted when an option is selected."
  event :open, doc: "Emitted when dropdown opens (requires `on_open: true`)."
  event :close, doc: "Emitted when dropdown closes (requires `on_close: true`)."
end
