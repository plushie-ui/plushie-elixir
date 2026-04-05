defmodule Plushie.Widget.Radio.NilSelected do
  @moduledoc false

  # Overrides new/2 and selected/2 to accept nil for selected.
  # Radio's new/2 becomes a multi-arity constructor that accepts
  # positional (value, selected) args with nil support.
  defmacro __before_compile__(_env) do
    quote do
      defoverridable new: 2, selected: 2

      @doc "Creates a new radio with the given value and selected state."
      @spec new(
              id :: String.t(),
              value :: String.t(),
              selected :: String.t() | nil,
              opts :: keyword()
            ) :: t()
      def new(id, value, selected, opts \\ [])
          when is_binary(id) and is_binary(value) and (is_binary(selected) or is_nil(selected)) do
        struct!(__MODULE__, id: id, value: value, selected: selected) |> with_options(opts)
      end

      @doc "Sets the currently selected value in the group. Accepts nil."
      def selected(%__MODULE__{} = r, nil), do: %{r | selected: nil}
      def selected(%__MODULE__{} = r, s) when is_binary(s), do: %{r | selected: s}
    end
  end
end

defmodule Plushie.Widget.Radio do
  @moduledoc """
  Radio button, one-of-many selection.

  All radios in a group should share the same `group` prop value. The
  `selected` prop should be set to the currently selected value across
  all radios in the group.
  """

  use Plushie.Widget

  @before_compile Plushie.Widget.Radio.NilSelected

  widget :radio do
    field :value, :string, option: false, doc: "The value this radio represents."
    field :selected, :string, option: false, doc: "Currently selected value in the group."
    field :label, :string, doc: "Label text. Defaults to `value` if omitted."
    field :group, :string, doc: "Group identifier for event routing."
    field :spacing, :float, doc: "Space between radio and label in pixels."
    field :width, Plushie.Type.Length, doc: "Widget width. Default: shrink."
    field :size, :float, doc: "Radio button size in pixels."
    field :text_size, :float, doc: "Label text size in pixels."
    field :font, Plushie.Type.Font, doc: "Label font."
    field :line_height, :any, doc: "Label line height."
    field :shaping, :atom, doc: "Text shaping strategy."
    field :wrapping, :atom, doc: "Text wrapping mode."
    field :style, Plushie.Type.Style, doc: "Named preset or custom `StyleMap`."
  end

  event :select, value: :string, doc: "Emitted when this radio is selected."
end
