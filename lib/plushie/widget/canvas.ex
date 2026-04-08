defmodule Plushie.Widget.Canvas.Extras do
  @moduledoc false

  # Injects the layer/3, shapes/2, and layers/2 setters that bypass
  # the standard option system.
  defmacro __before_compile__(_env) do
    quote do
      @doc "Sets the layers map (layer name => list of shape descriptors)."
      @spec layers(canvas :: t(), layers :: map()) :: t()
      def layers(%__MODULE__{} = canvas, layers), do: %{canvas | layers: layers}

      @doc "Sets a flat list of shapes (convenience for unlayered canvases)."
      @spec shapes(canvas :: t(), shapes :: [map()]) :: t()
      def shapes(%__MODULE__{} = canvas, shapes) when is_list(shapes),
        do: %{canvas | shapes: shapes}

      @doc "Adds a single named layer. Merges with existing layers."
      @spec layer(canvas :: t(), name :: String.t(), shapes :: [map()]) :: t()
      def layer(%__MODULE__{} = canvas, name, shapes) do
        current = canvas.layers || %{}
        %{canvas | layers: Map.put(current, name, shapes)}
      end
    end
  end
end

defmodule Plushie.Widget.Canvas do
  @moduledoc """
  Canvas for drawing shapes, organized into named layers.

  Layers are a map of layer names to shape lists. Each layer maps to an iced
  `Cache` on the Rust side; only changed layers are re-tessellated.
  """

  use Plushie.Widget

  @before_compile Plushie.Widget.Canvas.Extras

  @a11y_defaults %{role: :canvas}

  widget :canvas do
    field :layers, :map, doc: "Named layers of shape descriptors."
    field :shapes, {:list, :map}, doc: "Flat list of shapes (unlayered shorthand)."
    field :width, Plushie.Type.Length, doc: "Canvas width. Default: fill."
    field :height, Plushie.Type.Length, doc: "Canvas height. Default: 200px."
    field :background, Plushie.Type.Color, doc: "Canvas background color."
    field :interactive, :boolean, doc: "Enable all mouse event handlers. Default: false."
    field :on_press, :boolean, doc: "Enable mouse press events. Default: false."
    field :on_release, :boolean, doc: "Enable mouse release events. Default: false."
    field :on_move, :boolean, doc: "Enable mouse move events. Default: false."
    field :on_scroll, :boolean, doc: "Enable mouse scroll events. Default: false."
    field :alt, :string, doc: "Accessible label for the canvas."
    field :description, :string, doc: "Extended accessible description."
    field :role, :string, doc: "Accessible role (e.g. \"radiogroup\", \"toolbar\")."
    field :arrow_mode, :string, doc: "Arrow key navigation mode: \"wrap\", \"clamp\", etc."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."
  end
end
