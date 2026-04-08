defmodule Plushie.Widget.Tooltip.TipNew do
  @moduledoc false

  # Overrides new/2 to support both keyword-style `new(id, tip: "text", ...)`
  # and positional `new(id, "text", opts)` forms.
  defmacro __before_compile__(_env) do
    quote do
      defoverridable new: 2

      @doc """
      Creates a new tooltip.

      Accepts either keyword opts (with `:tip` key) or a positional tip string:

          Tooltip.new("tt", tip: "Help", position: :top)
          Tooltip.new("tt", "Help", position: :top)
      """
      def new(id, opts) when is_binary(id) and is_list(opts) do
        {tip, remaining} = Keyword.pop(opts, :tip, "")
        %__MODULE__{id: id, tip: tip} |> with_options(remaining)
      end

      def new(id, tip) when is_binary(id) and is_binary(tip),
        do: %__MODULE__{id: id, tip: tip}

      @spec new(id :: String.t(), tip :: String.t(), opts :: keyword()) :: t()
      def new(id, tip, opts) when is_binary(id) and is_binary(tip),
        do: %__MODULE__{id: id, tip: tip} |> with_options(opts)
    end
  end
end

defmodule Plushie.Widget.Tooltip do
  @moduledoc """
  Tooltip, shows a popup tip over child content on hover.
  """

  use Plushie.Widget

  @before_compile Plushie.Widget.Tooltip.TipNew

  @a11y_defaults %{role: :tooltip}

  widget :tooltip, container: true do
    field :tip, :string, option: false, doc: "Tooltip text."

    field :position, Plushie.Type.Position,
      doc: "Position: `:top`, `:bottom`, `:left`, `:right`, `:follow_cursor`."

    field :gap, :float, doc: "Gap between tooltip and content in pixels."
    field :padding, :float, doc: "Tooltip padding in pixels (uniform)."

    field :snap_within_viewport, :boolean, doc: "Keep tooltip within viewport. Default: true."

    field :delay, :integer, doc: "Delay in milliseconds before showing."
    field :style, Plushie.Type.Style, doc: "Named style preset or custom `StyleMap`."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."
  end
end
