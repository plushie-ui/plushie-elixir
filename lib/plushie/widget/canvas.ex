defmodule Plushie.Widget.Canvas do
  @moduledoc """
  Canvas for drawing shapes, organized into named layers.

  Layers are a map of layer names to shape lists. Each layer maps to an iced
  `Cache` on the Rust side -- only changed layers are re-tessellated. This
  prevents performance footguns when rendering thousands of shapes in a stable
  layer.

  Shape descriptors are plain maps with string keys. Use `Plushie.Canvas.Shape`
  for convenience builders, or construct maps directly.

  ## Do-block form

  The `canvas` macro in `Plushie.UI` supports a do-block form that collects
  layers declaratively:

      import Plushie.UI

      canvas "chart", width: 400, height: 300 do
        layer "grid" do
          rect(0, 0, 400, 300, stroke: "#eee")
        end
        layer "data" do
          for bar <- bars do
            rect(bar.x, bar.y, bar.w, bar.h, fill: bar.color)
          end
        end
      end

  ## Props

  - `layers` (map of string => list of maps) -- named layers of shape
    descriptors. Each layer is independently cached. Shapes within a layer
    are drawn in order. Layers are drawn in alphabetical order by name.
  - `shapes` (list of maps) -- flat list of shape descriptors. Convenience
    alternative to `layers` for canvases that don't need named layers.
  - `width` (length) -- canvas width. Default: fill. See `Plushie.Type.Length`.
  - `height` (length) -- canvas height. Default: 200px.
  - `background` (color) -- canvas background color. See `Plushie.Type.Color`.
  - `interactive` (boolean) -- enables all mouse event handlers. Default: false.
  - `on_press` (boolean) -- enable mouse press events. Default: false.
  - `on_release` (boolean) -- enable mouse release events. Default: false.
  - `on_move` (boolean) -- enable mouse move events. Default: false.
  - `on_scroll` (boolean) -- enable mouse scroll events. Default: false.
  - `alt` (string) -- accessible label for the canvas. Sits outside the
    `a11y` object. See "Widget-specific accessibility props" in
    `docs/accessibility.md`.
  - `description` (string) -- extended accessible description for the
    canvas. Sits outside the `a11y` object.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.

  ## Shape types

  Shapes are plain maps. See `Plushie.Canvas.Shape` for builder functions.

  - `%{type: "rect", x: x, y: y, w: w, h: h}` -- rectangle.
  - `%{type: "circle", x: x, y: y, r: r}` -- circle.
  - `%{type: "line", x1: x1, y1: y1, x2: x2, y2: y2}` -- line.
  - `%{type: "text", x: x, y: y, content: text}` -- text.
  - `%{type: "path", commands: [...]}` -- arbitrary path.
  - `%{type: "image", source: path, x: x, y: y, w: w, h: h}` -- image.
  - `%{type: "svg", source: path, x: x, y: y, w: w, h: h}` -- SVG.

  All shapes accept optional `fill` (hex color or gradient) and `stroke` fields.

  ## Events

  Raw canvas events (coordinate-level):

  - `%Canvas{type: :press, id: id, x: x, y: y, button: button}`
  - `%Canvas{type: :release, id: id, x: x, y: y, button: button}`
  - `%Canvas{type: :move, id: id, x: x, y: y}`
  - `%Canvas{type: :scroll, id: id, x: x, y: y, delta_x: dx, delta_y: dy}`

  Interactive shape events (semantic, from shapes with `interactive` field):

  - `%WidgetEvent{type: :canvas_element_enter, id: id, data: %{"element_id" => element_id, ...}}`
  - `%WidgetEvent{type: :canvas_element_leave, id: id, data: %{"element_id" => element_id}}`
  - `%WidgetEvent{type: :canvas_element_click, id: id, data: %{"element_id" => element_id, ...}}`
  - `%WidgetEvent{type: :canvas_element_drag, id: id, data: %{"element_id" => element_id, ...}}`
  - `%WidgetEvent{type: :canvas_element_drag_end, id: id, data: %{"element_id" => element_id, ...}}`
  - `%WidgetEvent{type: :canvas_element_focused, id: id, data: %{"element_id" => element_id}}`

  Shape events are delivered as `%WidgetEvent{}` structs (not `%Canvas{}`). The `id`
  field is the canvas widget ID; `data.element_id` identifies which shape.
  """

  alias Plushie.Widget.Build

  @typedoc "A canvas shape descriptor (struct or plain map)."
  @type canvas_shape ::
          Plushie.Canvas.Shape.Rect.t()
          | Plushie.Canvas.Shape.Circle.t()
          | Plushie.Canvas.Shape.Line.t()
          | Plushie.Canvas.Shape.CanvasText.t()
          | Plushie.Canvas.Shape.Path.t()
          | Plushie.Canvas.Shape.CanvasImage.t()
          | Plushie.Canvas.Shape.CanvasSvg.t()
          | Plushie.Canvas.Shape.Group.t()
          | Plushie.Canvas.Shape.Translate.t()
          | Plushie.Canvas.Shape.Rotate.t()
          | Plushie.Canvas.Shape.Scale.t()
          | Plushie.Canvas.Shape.Clip.t()
          | map()

  @type option ::
          {:layers, %{String.t() => [canvas_shape()]}}
          | {:shapes, [canvas_shape()]}
          | {:width, Plushie.Type.Length.t()}
          | {:height, Plushie.Type.Length.t()}
          | {:background, Plushie.Type.Color.input()}
          | {:interactive, boolean()}
          | {:on_press, boolean()}
          | {:on_release, boolean()}
          | {:on_move, boolean()}
          | {:on_scroll, boolean()}
          | {:alt, String.t()}
          | {:description, String.t()}
          | {:event_rate, pos_integer()}
          | {:a11y, Plushie.Type.A11y.t() | map() | keyword()}

  @type t :: %__MODULE__{
          id: String.t(),
          layers: %{String.t() => [canvas_shape()]} | nil,
          shapes: [canvas_shape()] | nil,
          width: Plushie.Type.Length.t() | nil,
          height: Plushie.Type.Length.t() | nil,
          background: Plushie.Type.Color.t() | nil,
          interactive: boolean() | nil,
          on_press: boolean() | nil,
          on_release: boolean() | nil,
          on_move: boolean() | nil,
          on_scroll: boolean() | nil,
          alt: String.t() | nil,
          description: String.t() | nil,
          role: String.t() | nil,
          arrow_mode: String.t() | nil,
          event_rate: pos_integer() | nil,
          a11y: Plushie.Type.A11y.t() | nil
        }

  defstruct [
    :id,
    :layers,
    :shapes,
    :width,
    :height,
    :background,
    :interactive,
    :on_press,
    :on_release,
    :on_move,
    :on_scroll,
    :alt,
    :description,
    :role,
    :arrow_mode,
    :event_rate,
    :a11y
  ]

  @valid_option_keys ~w(width height background interactive on_press on_release
    on_move on_scroll alt description role arrow_mode event_rate a11y)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__ do
    %{a11y: Plushie.Type.A11y}
  end

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
      {:shapes, v}, acc -> shapes(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:background, v}, acc -> background(acc, v)
      {:interactive, v}, acc -> interactive(acc, v)
      {:on_press, v}, acc -> on_press(acc, v)
      {:on_release, v}, acc -> on_release(acc, v)
      {:on_move, v}, acc -> on_move(acc, v)
      {:on_scroll, v}, acc -> on_scroll(acc, v)
      {:alt, v}, acc -> alt(acc, v)
      {:description, v}, acc -> description(acc, v)
      {:role, v}, acc -> role(acc, v)
      {:arrow_mode, v}, acc -> arrow_mode(acc, v)
      {:event_rate, v}, acc -> event_rate(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the layers map (layer name => list of shape descriptors)."
  @spec layers(canvas :: t(), layers :: %{String.t() => [canvas_shape()]}) :: t()
  def layers(%__MODULE__{} = canvas, layers), do: %{canvas | layers: layers}

  @doc "Sets a flat list of shapes (convenience shorthand for unlayered canvases)."
  @spec shapes(canvas :: t(), shapes :: [canvas_shape()]) :: t()
  def shapes(%__MODULE__{} = canvas, shapes) when is_list(shapes), do: %{canvas | shapes: shapes}

  @doc "Adds a single named layer to the canvas. Merges with existing layers."
  @spec layer(canvas :: t(), name :: String.t(), shapes :: [canvas_shape()]) :: t()
  def layer(%__MODULE__{} = canvas, name, shapes) do
    current = canvas.layers || %{}
    %{canvas | layers: Map.put(current, name, shapes)}
  end

  @doc "Sets the canvas width."
  @spec width(canvas :: t(), width :: Plushie.Type.Length.t()) :: t()
  def width(%__MODULE__{} = canvas, width), do: %{canvas | width: width}

  @doc "Sets the canvas height."
  @spec height(canvas :: t(), height :: Plushie.Type.Length.t()) :: t()
  def height(%__MODULE__{} = canvas, height), do: %{canvas | height: height}

  @doc "Sets the canvas background color. Accepts a hex string or named color atom."
  @spec background(canvas :: t(), background :: Plushie.Type.Color.input()) :: t()
  def background(%__MODULE__{} = canvas, background),
    do: %{canvas | background: Plushie.Type.Color.cast(background)}

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

  @doc "Sets the accessible label for the canvas."
  @spec alt(canvas :: t(), alt :: String.t()) :: t()
  def alt(%__MODULE__{} = canvas, alt) when is_binary(alt), do: %{canvas | alt: alt}

  @doc "Sets an extended accessible description for the canvas."
  @spec description(canvas :: t(), description :: String.t()) :: t()
  def description(%__MODULE__{} = canvas, description) when is_binary(description),
    do: %{canvas | description: description}

  @doc ~S[Sets the accessible role for the canvas (e.g. "radiogroup", "toolbar").]
  @spec role(canvas :: t(), role :: String.t()) :: t()
  def role(%__MODULE__{} = canvas, role) when is_binary(role),
    do: %{canvas | role: role}

  def role(%__MODULE__{} = canvas, role) when is_atom(role),
    do: %{canvas | role: Atom.to_string(role)}

  @doc ~S[Sets the arrow key navigation mode ("wrap", "clamp", "linear", "none").]
  @spec arrow_mode(canvas :: t(), mode :: String.t()) :: t()
  def arrow_mode(%__MODULE__{} = canvas, mode) when is_binary(mode),
    do: %{canvas | arrow_mode: mode}

  def arrow_mode(%__MODULE__{} = canvas, mode) when is_atom(mode),
    do: %{canvas | arrow_mode: Atom.to_string(mode)}

  @doc "Sets the maximum event rate (events per second) for this widget's coalescable events."
  @spec event_rate(canvas :: t(), rate :: pos_integer()) :: t()
  def event_rate(%__MODULE__{} = canvas, rate) when is_integer(rate) and rate >= 0,
    do: %{canvas | event_rate: rate}

  @doc "Sets accessibility annotations."
  @spec a11y(canvas :: t(), a11y :: Plushie.Type.A11y.t() | map() | keyword()) :: t()
  def a11y(%__MODULE__{} = canvas, a11y), do: %{canvas | a11y: Plushie.Type.A11y.cast(a11y)}

  @doc "Converts this canvas struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(canvas :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = canvas), do: Plushie.Widget.Plushie.Widget.Canvas.to_node(canvas)

  defimpl Plushie.Widget do
    import Plushie.Widget.Build

    def to_node(canvas) do
      props =
        %{}
        |> put_if(canvas.layers, :layers)
        |> put_if(canvas.shapes, :shapes)
        |> put_if(canvas.width, :width)
        |> put_if(canvas.height, :height)
        |> put_if(canvas.background, :background)
        |> put_if(canvas.interactive, :interactive)
        |> put_if(canvas.on_press, :on_press)
        |> put_if(canvas.on_release, :on_release)
        |> put_if(canvas.on_move, :on_move)
        |> put_if(canvas.on_scroll, :on_scroll)
        |> put_if(canvas.alt, :alt)
        |> put_if(canvas.description, :description)
        |> put_if(canvas.role, :role)
        |> put_if(canvas.arrow_mode, :arrow_mode)
        |> put_if(canvas.event_rate, :event_rate)
        |> put_if(canvas.a11y, :a11y)

      %{id: canvas.id, type: "canvas", props: props, children: []}
    end
  end
end
