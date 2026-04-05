defmodule Plushie.Widget.ComboBox.ValueAlias do
  @moduledoc false

  # Injects the `value:` alias for `selected:` into ComboBox.with_options/2.
  defmacro __before_compile__(_env) do
    quote do
      defoverridable with_options: 2

      def with_options(%__MODULE__{} = cb, opts) do
        opts =
          case Keyword.pop(opts, :value) do
            {nil, rest} -> rest
            {val, rest} -> [{:selected, val} | rest]
          end

        super(cb, opts)
      end
    end
  end
end

defmodule Plushie.Widget.ComboBox do
  @moduledoc """
  Combo box, searchable dropdown with free-form text input.

  The renderer manages an internal `combo_box::State` cache keyed by node ID.
  Options changes trigger a state rebuild.
  """

  use Plushie.Widget

  @before_compile Plushie.Widget.ComboBox.ValueAlias

  widget :combo_box do
    field :options, {:list, :string}, option: false, doc: "Available choices."
    field :selected, :string, doc: "Currently selected value. Also accepts `:value` as alias."
    field :placeholder, :string, doc: "Placeholder text."
    field :width, Plushie.Type.Length, doc: "Widget width. Default: fill."
    field :padding, Plushie.Type.Padding, doc: "Internal padding."
    field :size, :float, doc: "Text size in pixels."
    field :font, Plushie.Type.Font, doc: "Font specification."
    field :line_height, :any, doc: "Text line height."
    field :menu_height, :float, doc: "Maximum dropdown menu height in pixels."
    field :icon, :map, doc: "Icon inside the text input."
    field :on_option_hovered, :boolean, doc: "Emit hover events over dropdown options."
    field :on_open, :boolean, doc: "Emit open event when the dropdown opens."
    field :on_close, :boolean, doc: "Emit close event when the dropdown closes."
    field :shaping, :atom, doc: "Text shaping strategy."
    field :ellipsis, :string, doc: "Text ellipsis: \"none\", \"start\", \"middle\", or \"end\"."
    field :menu_style, :map, doc: "Inline style for the dropdown menu."
    field :style, Plushie.Type.Style, doc: "Named preset or custom `StyleMap`."

    positional [:options]
  end

  event :select, value: :string, doc: "Emitted when an option is selected."
  event :input, value: :string, doc: "Emitted on every text input change (for filtering)."
  event :option_hovered, value: :string, doc: "Emitted on hover (requires `on_option_hovered`)."
  event :open, doc: "Emitted when dropdown opens (requires `on_open: true`)."
  event :close, doc: "Emitted when dropdown closes (requires `on_close: true`)."
end
