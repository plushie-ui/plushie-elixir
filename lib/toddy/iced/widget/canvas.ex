defmodule Toddy.Iced.Widget.Canvas do
  @moduledoc """
  Canvas for drawing shapes, organized into named layers.

  Layers are a map of layer names to shape lists. Each layer maps to an iced
  `Cache` on the Rust side -- only changed layers are re-tessellated. This
  prevents performance footguns when rendering thousands of shapes in a stable
  layer.

  Shape descriptors are plain maps with string keys. Use `Toddy.Canvas.Shape`
  for convenience builders, or construct maps directly.

  ## Props

  - `layers` (map of string => list of maps) -- named layers of shape
    descriptors. Each layer is independently cached. Shapes within a layer
    are drawn in order. Layers are drawn in alphabetical order by name.
  - `width` (length) -- canvas width. Default: fill. See `Toddy.Iced.Length`.
  - `height` (length) -- canvas height. Default: 200px.
  - `background` (color) -- canvas background color. See `Toddy.Iced.Color`.
  - `interactive` (boolean) -- enables all mouse event handlers. Default: false.
  - `on_press` (boolean) -- enable mouse press events. Default: false.
  - `on_release` (boolean) -- enable mouse release events. Default: false.
  - `on_move` (boolean) -- enable mouse move events. Default: false.
  - `on_scroll` (boolean) -- enable mouse scroll events. Default: false.
  - `a11y` (map) -- accessibility overrides. See `Toddy.Iced.A11y`.

  ## Shape types

  Shapes are plain maps. See `Toddy.Canvas.Shape` for builder functions.

  - `%{"type" => "rect", "x" => x, "y" => y, "w" => w, "h" => h}` -- rectangle.
  - `%{"type" => "circle", "x" => x, "y" => y, "r" => r}` -- circle.
  - `%{"type" => "line", "x1" => x1, "y1" => y1, "x2" => x2, "y2" => y2}` -- line.
  - `%{"type" => "text", "x" => x, "y" => y, "content" => text}` -- text.
  - `%{"type" => "path", "commands" => [...]}` -- arbitrary path.
  - `%{"type" => "image", "source" => path, "x" => x, "y" => y, "w" => w, "h" => h}` -- image.
  - `%{"type" => "svg", "source" => path, "x" => x, "y" => y, "w" => w, "h" => h}` -- SVG.

  All shapes accept optional `fill` (hex color or gradient) and `stroke` fields.

  ## Events

  - `%Canvas{type: :press, id: id, x: x, y: y, button: button}`
  - `%Canvas{type: :release, id: id, x: x, y: y, button: button}`
  - `%Canvas{type: :move, id: id, x: x, y: y}`
  - `%Canvas{type: :scroll, id: id, x: x, y: y, delta_x: dx, delta_y: dy}`
  """

  alias Toddy.Iced.A11y
  alias Toddy.Iced.Widget.Build

  @type option ::
          {:layers, %{String.t() => [map()]}}
          | {:width, Toddy.Iced.Length.t()}
          | {:height, Toddy.Iced.Length.t()}
          | {:background, Toddy.Iced.Color.input()}
          | {:interactive, boolean()}
          | {:on_press, boolean()}
          | {:on_release, boolean()}
          | {:on_move, boolean()}
          | {:on_scroll, boolean()}
          | {:a11y, Toddy.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          layers: %{String.t() => [map()]} | nil,
          width: Toddy.Iced.Length.t() | nil,
          height: Toddy.Iced.Length.t() | nil,
          background: Toddy.Iced.Color.t() | nil,
          interactive: boolean() | nil,
          on_press: boolean() | nil,
          on_release: boolean() | nil,
          on_move: boolean() | nil,
          on_scroll: boolean() | nil,
          a11y: Toddy.Iced.A11y.t() | nil
        }

  defstruct [
    :id,
    :layers,
    :width,
    :height,
    :background,
    :interactive,
    :on_press,
    :on_release,
    :on_move,
    :on_scroll,
    :a11y
  ]

  @doc "Creates a new canvas struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing canvas struct."
  @spec with_options(canvas :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = canvas, []), do: canvas

  def with_options(%__MODULE__{} = canvas, opts) do
    Enum.reduce(opts, canvas, fn
      {:layers, v}, acc -> layers(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:background, v}, acc -> background(acc, v)
      {:interactive, v}, acc -> interactive(acc, v)
      {:on_press, v}, acc -> on_press(acc, v)
      {:on_release, v}, acc -> on_release(acc, v)
      {:on_move, v}, acc -> on_move(acc, v)
      {:on_scroll, v}, acc -> on_scroll(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the layers map (layer name => list of shape descriptors)."
  @spec layers(canvas :: t(), layers :: %{String.t() => [map()]}) :: t()
  def layers(%__MODULE__{} = canvas, layers), do: %{canvas | layers: layers}

  @doc "Adds a single named layer to the canvas. Merges with existing layers."
  @spec layer(canvas :: t(), name :: String.t(), shapes :: [map()]) :: t()
  def layer(%__MODULE__{} = canvas, name, shapes) do
    current = canvas.layers || %{}
    %{canvas | layers: Map.put(current, name, shapes)}
  end

  @doc "Sets the canvas width."
  @spec width(canvas :: t(), width :: Toddy.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = canvas, width), do: %{canvas | width: width}

  @doc "Sets the canvas height."
  @spec height(canvas :: t(), height :: Toddy.Iced.Length.t()) :: t()
  def height(%__MODULE__{} = canvas, height), do: %{canvas | height: height}

  @doc "Sets the canvas background color. Accepts a hex string or named color atom."
  @spec background(canvas :: t(), background :: Toddy.Iced.Color.input()) :: t()
  def background(%__MODULE__{} = canvas, background),
    do: %{canvas | background: Toddy.Iced.Color.cast(background)}

  @doc "Sets whether all mouse event handlers are enabled."
  @spec interactive(canvas :: t(), interactive :: boolean()) :: t()
  def interactive(%__MODULE__{} = canvas, v) when is_boolean(v), do: %{canvas | interactive: v}

  @doc "Sets whether mouse press events are enabled."
  @spec on_press(canvas :: t(), on_press :: boolean()) :: t()
  def on_press(%__MODULE__{} = canvas, v) when is_boolean(v), do: %{canvas | on_press: v}

  @doc "Sets whether mouse release events are enabled."
  @spec on_release(canvas :: t(), on_release :: boolean()) :: t()
  def on_release(%__MODULE__{} = canvas, v) when is_boolean(v), do: %{canvas | on_release: v}

  @doc "Sets whether mouse move events are enabled."
  @spec on_move(canvas :: t(), on_move :: boolean()) :: t()
  def on_move(%__MODULE__{} = canvas, v) when is_boolean(v), do: %{canvas | on_move: v}

  @doc "Sets whether mouse scroll events are enabled."
  @spec on_scroll(canvas :: t(), on_scroll :: boolean()) :: t()
  def on_scroll(%__MODULE__{} = canvas, v) when is_boolean(v), do: %{canvas | on_scroll: v}

  @doc "Sets accessibility annotations."
  @spec a11y(canvas :: t(), a11y :: Toddy.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = canvas, a11y), do: %{canvas | a11y: A11y.cast(a11y)}

  @doc "Converts this canvas struct to a `ui_node()` map via the `Toddy.Iced.Widget` protocol."
  @spec build(canvas :: t()) :: Toddy.Iced.ui_node()
  def build(%__MODULE__{} = canvas), do: Toddy.Iced.Widget.to_node(canvas)

  defimpl Toddy.Iced.Widget do
    import Toddy.Iced.Widget.Build

    def to_node(canvas) do
      props =
        %{}
        |> put_if(canvas.layers, "layers")
        |> put_if(canvas.width, "width")
        |> put_if(canvas.height, "height")
        |> put_if(canvas.background, "background")
        |> put_if(canvas.interactive, "interactive")
        |> put_if(canvas.on_press, "on_press")
        |> put_if(canvas.on_release, "on_release")
        |> put_if(canvas.on_move, "on_move")
        |> put_if(canvas.on_scroll, "on_scroll")
        |> put_if(canvas.a11y, "a11y")

      %{id: canvas.id, type: "canvas", props: props, children: []}
    end
  end
end
