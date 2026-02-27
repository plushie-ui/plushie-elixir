defmodule Julep.Iced.Widget.Canvas do
  @moduledoc """
  Canvas for drawing shapes.

  Shapes are rendered via an iced `canvas::Program`. The canvas supports
  rect, circle, line, and text shape primitives.

  ## Props

  - `shapes` (list of maps) -- shape descriptors. Each shape has a `type` field:
    - `%{type: "rect", x, y, w, h, fill}` -- filled rectangle.
    - `%{type: "circle", x, y, r, fill}` -- filled circle.
    - `%{type: "line", x1, y1, x2, y2, fill, width}` -- stroked line.
    - `%{type: "text", x, y, content, fill}` -- drawn text.
    Colors are hex strings for the `fill` field.
  - `width` (length) -- canvas width. Default: fill. See `Julep.Iced.Length`.
  - `height` (length) -- canvas height. Default: 200px.
  - `background` (color) -- canvas background color. See `Julep.Iced.Color`.
  - `interactive` (boolean) -- enables all mouse event handlers. Default: false.
  - `on_press` (boolean) -- enable mouse press events. Default: false.
  - `on_release` (boolean) -- enable mouse release events. Default: false.
  - `on_move` (boolean) -- enable mouse move events. Default: false.
  - `on_scroll` (boolean) -- enable mouse scroll events. Default: false.

  ## Events

  - `{:canvas_press, id, x, y, button}` -- mouse button pressed on canvas.
  - `{:canvas_release, id, x, y, button}` -- mouse button released on canvas.
  - `{:canvas_move, id, x, y}` -- mouse moved over canvas.
  - `{:canvas_scroll, id, x, y, delta_x, delta_y}` -- mouse scrolled on canvas.
  """

  alias Julep.Iced.Widget.Build

  @type option ::
          {:shapes, [map()]}
          | {:width, Julep.Iced.Length.t()}
          | {:height, Julep.Iced.Length.t()}
          | {:background, Julep.Iced.Color.t()}
          | {:interactive, boolean()}
          | {:on_press, boolean()}
          | {:on_release, boolean()}
          | {:on_move, boolean()}
          | {:on_scroll, boolean()}

  @type t :: %__MODULE__{
          id: String.t(),
          shapes: [map()] | nil,
          width: Julep.Iced.Length.t() | nil,
          height: Julep.Iced.Length.t() | nil,
          background: Julep.Iced.Color.t() | nil,
          interactive: boolean() | nil,
          on_press: boolean() | nil,
          on_release: boolean() | nil,
          on_move: boolean() | nil,
          on_scroll: boolean() | nil
        }

  defstruct [
    :id,
    :shapes,
    :width,
    :height,
    :background,
    :interactive,
    :on_press,
    :on_release,
    :on_move,
    :on_scroll
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
      {:shapes, v}, acc -> shapes(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:background, v}, acc -> background(acc, v)
      {:interactive, v}, acc -> interactive(acc, v)
      {:on_press, v}, acc -> on_press(acc, v)
      {:on_release, v}, acc -> on_release(acc, v)
      {:on_move, v}, acc -> on_move(acc, v)
      {:on_scroll, v}, acc -> on_scroll(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the list of shape descriptors."
  @spec shapes(canvas :: t(), shapes :: [map()]) :: t()
  def shapes(%__MODULE__{} = canvas, shapes), do: %{canvas | shapes: shapes}

  @doc "Sets the canvas width."
  @spec width(canvas :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = canvas, width), do: %{canvas | width: width}

  @doc "Sets the canvas height."
  @spec height(canvas :: t(), height :: Julep.Iced.Length.t()) :: t()
  def height(%__MODULE__{} = canvas, height), do: %{canvas | height: height}

  @doc "Sets the canvas background color."
  @spec background(canvas :: t(), background :: Julep.Iced.Color.t()) :: t()
  def background(%__MODULE__{} = canvas, background), do: %{canvas | background: background}

  @doc "Sets whether all mouse event handlers are enabled."
  @spec interactive(canvas :: t(), interactive :: boolean()) :: t()
  def interactive(%__MODULE__{} = canvas, interactive), do: %{canvas | interactive: interactive}

  @doc "Sets whether mouse press events are enabled."
  @spec on_press(canvas :: t(), on_press :: boolean()) :: t()
  def on_press(%__MODULE__{} = canvas, on_press), do: %{canvas | on_press: on_press}

  @doc "Sets whether mouse release events are enabled."
  @spec on_release(canvas :: t(), on_release :: boolean()) :: t()
  def on_release(%__MODULE__{} = canvas, on_release), do: %{canvas | on_release: on_release}

  @doc "Sets whether mouse move events are enabled."
  @spec on_move(canvas :: t(), on_move :: boolean()) :: t()
  def on_move(%__MODULE__{} = canvas, on_move), do: %{canvas | on_move: on_move}

  @doc "Sets whether mouse scroll events are enabled."
  @spec on_scroll(canvas :: t(), on_scroll :: boolean()) :: t()
  def on_scroll(%__MODULE__{} = canvas, on_scroll), do: %{canvas | on_scroll: on_scroll}

  @doc "Converts this canvas struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(canvas :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = canvas), do: Julep.Iced.Widget.to_node(canvas)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(canvas) do
      props =
        %{}
        |> put_if(canvas.shapes, "shapes")
        |> put_if(canvas.width, "width")
        |> put_if(canvas.height, "height")
        |> put_if(canvas.background, "background")
        |> put_if(canvas.interactive, "interactive")
        |> put_if(canvas.on_press, "on_press")
        |> put_if(canvas.on_release, "on_release")
        |> put_if(canvas.on_move, "on_move")
        |> put_if(canvas.on_scroll, "on_scroll")

      %{id: canvas.id, type: "canvas", props: props, children: []}
    end
  end
end
