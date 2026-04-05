defmodule Plushie.Widget.Button.EnabledAlias do
  @moduledoc false

  # Injects the `enabled:` virtual option alias into Button.with_options/2.
  # Registered as a @before_compile hook AFTER Plushie.Widget's hook,
  # so the base with_options/2 is already defined when this runs.
  defmacro __before_compile__(_env) do
    quote do
      defoverridable with_options: 2

      def with_options(%__MODULE__{} = widget, opts) do
        opts =
          case Keyword.pop(opts, :enabled) do
            {nil, rest} -> rest
            {val, rest} -> [{:disabled, !val} | rest]
          end

        super(widget, opts)
      end
    end
  end
end

defmodule Plushie.Widget.Button do
  @moduledoc """
  Button, clickable widget that emits `%WidgetEvent{type: :click}` events.

  The button can contain either a text label (via the `label` prop)
  or arbitrary child content (if children are provided, the first child is rendered).
  """

  use Plushie.Widget

  @before_compile Plushie.Widget.Button.EnabledAlias

  widget :button do
    field :label, :string, option: false, doc: "Text label displayed on the button."
    field :width, Plushie.Type.Length, doc: "Button width. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Button height. Default: shrink."
    field :padding, Plushie.Type.Padding, doc: "Internal padding."
    field :clip, :boolean, doc: "Clip child content that overflows. Default: false."
    field :style, Plushie.Type.Style, doc: "Named preset or custom `StyleMap`."
    field :disabled, :boolean, doc: "Disable the button (no click events). Default: false."

    positional [:label]
  end

  event :click, doc: "Emitted on press (unless disabled)."
end
