defmodule Plushie.Widget.Container.Extras do
  @moduledoc false

  # Injects convenience alignment methods and setter overrides into Container.
  # Runs after Plushie.Widget's @before_compile, so the struct exists.
  defmacro __before_compile__(_env) do
    quote do
      # Override background/2 to cast colors while passing gradients through.
      # Override center/2 to support center/1 (defaults to true).
      defoverridable background: 2, center: 2

      @doc "Centers the child in both axes. Defaults to true when called with no argument."
      def center(%__MODULE__{} = c), do: %{c | center: true}
      def center(%__MODULE__{} = c, val) when is_boolean(val), do: %{c | center: val}

      @doc "Sets the background fill (color or gradient)."
      def background(%__MODULE__{} = c, %{type: "linear"} = gradient),
        do: %{c | background: gradient}

      def background(%__MODULE__{} = c, background) do
        {:ok, casted} = Plushie.Type.Color.cast(background)
        %{c | background: casted}
      end

      @doc "Centers content horizontally. Sets width and align_x: :center."
      @spec center_x(container :: t(), width :: Plushie.Type.Length.t()) :: t()
      def center_x(%__MODULE__{} = container, width \\ :fill),
        do: %{container | width: width, align_x: :center}

      @doc "Centers content vertically. Sets height and align_y: :center."
      @spec center_y(container :: t(), height :: Plushie.Type.Length.t()) :: t()
      def center_y(%__MODULE__{} = container, height \\ :fill),
        do: %{container | height: height, align_y: :center}

      @doc "Aligns content to the left. Sets width and align_x: :left."
      @spec align_left(container :: t(), width :: Plushie.Type.Length.t()) :: t()
      def align_left(%__MODULE__{} = container, width \\ :fill),
        do: %{container | width: width, align_x: :left}

      @doc "Aligns content to the right. Sets width and align_x: :right."
      @spec align_right(container :: t(), width :: Plushie.Type.Length.t()) :: t()
      def align_right(%__MODULE__{} = container, width \\ :fill),
        do: %{container | width: width, align_x: :right}

      @doc "Aligns content to the top. Sets height and align_y: :top."
      @spec align_top(container :: t(), height :: Plushie.Type.Length.t()) :: t()
      def align_top(%__MODULE__{} = container, height \\ :fill),
        do: %{container | height: height, align_y: :top}

      @doc "Aligns content to the bottom. Sets height and align_y: :bottom."
      @spec align_bottom(container :: t(), height :: Plushie.Type.Length.t()) :: t()
      def align_bottom(%__MODULE__{} = container, height \\ :fill),
        do: %{container | height: height, align_y: :bottom}
    end
  end
end

defmodule Plushie.Widget.Container do
  @moduledoc """
  Container layout, wraps a single child with padding, sizing, and styling.
  """

  use Plushie.Widget

  @before_compile Plushie.Widget.Container.Extras

  @a11y_defaults %{role: :generic_container}

  widget :container, container: true do
    field :padding, Plushie.Type.Padding, doc: "Padding inside the container."
    field :width, Plushie.Type.Length, doc: "Container width. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Container height. Default: shrink."
    field :max_width, :float, doc: "Maximum width in pixels."
    field :max_height, :float, doc: "Maximum height in pixels."
    field :center, :boolean, doc: "Center child in both axes. Default: false."
    field :clip, :boolean, doc: "Clip child that overflows. Default: false."

    field :align_x, Plushie.Type.Alignment,
      doc: "Horizontal alignment: `:left`, `:center`, `:right`."

    field :align_y, Plushie.Type.Alignment,
      doc: "Vertical alignment: `:top`, `:center`, `:bottom`."

    field :background, :any, doc: "Background fill. Accepts a color or gradient."
    field :color, Plushie.Type.Color, doc: "Text color override."
    field :border, Plushie.Type.Border, doc: "Border specification: `%{color, width, radius}`."

    field :shadow, Plushie.Type.Shadow,
      doc: "Shadow specification: `%{color, offset, blur_radius}`."

    field :style, Plushie.Type.Style, doc: "Named preset or custom `StyleMap`."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."
  end

  @presets [
    :transparent,
    :rounded_box,
    :bordered_box,
    :dark,
    :primary,
    :secondary,
    :success,
    :danger,
    :warning
  ]

  @type preset :: unquote(Enum.reduce(@presets, &{:|, [], [&1, &2]}))

  @doc false
  def style_presets, do: @presets
end
