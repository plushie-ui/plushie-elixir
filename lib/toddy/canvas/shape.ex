defmodule Toddy.Canvas.Shape do
  @moduledoc """
  Pure builder functions returning typed canvas shape structs.

  Every function returns a struct from `Toddy.Canvas.Shape.*`.
  The `Toddy.Encode` protocol implementations on each struct handle
  wire-format conversion. These are plain functions, not macros --
  they can be called anywhere.

  Structure macros (`group`, `layer`, `interactive` directive) live
  in `Toddy.UI` and are available inside canvas do-blocks. Inside
  those blocks, `text`, `image`, and `svg` calls resolve
  automatically to their canvas shape variants. For helper functions
  outside canvas blocks, import this module directly.

  ## When to import this module

  Import `Toddy.Canvas.Shape` when you build shapes in standalone
  helper functions (defp) outside a `Toddy.UI` canvas block:

      import Toddy.Canvas.Shape

      defp draw_indicator(x, y, color) do
        [
          circle(x, y, 6, fill: color),
          circle(x, y, 3, fill: "#fff")
        ]
      end

  Inside `Toddy.UI` canvas/layer/group blocks, all shape functions
  are already in scope via `import Toddy.UI` -- no extra import
  needed.

  ## Basic shapes

      rect(10, 20, 100, 50, fill: "#ff0000")
      circle(50, 50, 25, stroke: stroke("#000", 2))
      line(0, 0, 100, 100, stroke: stroke("#333", 1, cap: "round"))
      text(10, 10, "Hello", fill: "#000", size: 16)

  ## Paths

      path([move_to(0, 0), line_to(100, 0), line_to(50, 80), close()],
        fill: "#0088ff",
        stroke: stroke("#000", 2)
      )

  ## Transforms

  Transform commands are interleaved with shapes in a layer's shape list:

      [
        push_transform(),
        translate(100, 100),
        rotate(:math.pi() / 4),
        rect(0, 0, 50, 50, fill: "#f00"),
        pop_transform()
      ]

  ## Clipping

  Clip regions restrict drawing to a rectangular area:

      [
        push_clip(10, 10, 100, 80),
        rect(0, 0, 200, 200, fill: "#ff0000"),
        pop_clip()
      ]

  Clip regions nest -- inner clips are intersected with outer clips.

  ## Per-shape opacity

  All shapes (except SVG) accept an `:opacity` option (0.0-1.0) that
  multiplies into the fill and stroke color alpha channels:

      rect(0, 0, 100, 100, fill: "#ff0000", opacity: 0.5)
      circle(50, 50, 25, stroke: stroke("#000", 2), opacity: 0.3)

  ## Text alignment

  The `text/4` builder accepts `:align_x` and `:align_y` options:

      text(100, 50, "Centered", fill: "#000", align_x: "center", align_y: "center")

  Valid values for `:align_x`: `"left"`, `"center"`, `"right"`.
  Valid values for `:align_y`: `"top"`, `"center"`, `"bottom"`.

  ## Gradients

  Use `linear_gradient/3` as a `fill` value:

      rect(0, 0, 200, 100,
        fill: linear_gradient({0, 0}, {200, 0}, [{0.0, "#ff0000"}, {1.0, "#0000ff"}])
      )

  ## Interactive shapes

  Use `interactive/2` to attach click/hover/drag behavior to any shape:

      rect(0, 0, 100, 40, fill: "#3498db")
      |> interactive(id: "btn", on_click: true, cursor: "pointer")

  Inside `Toddy.UI` group blocks, the `interactive` directive provides
  ergonomic do-block and keyword forms -- see `Toddy.UI` moduledoc.
  """

  alias Toddy.Canvas.Shape.{
    CanvasImage,
    CanvasSvg,
    CanvasText,
    Circle,
    Group,
    Interactive,
    Line,
    LinearGradient,
    Path,
    PopClip,
    PopTransform,
    PushClip,
    PushTransform,
    Rect,
    Rotate,
    Scale,
    Stroke,
    Translate
  }

  # -- Basic shapes -----------------------------------------------------------

  @doc "Builds a rectangle shape."
  @spec rect(x :: number(), y :: number(), w :: number(), h :: number(), opts :: keyword()) ::
          Rect.t()
  def rect(x, y, w, h, opts \\ []) do
    %Rect{x: x, y: y, w: w, h: h}
    |> apply_fill(opts)
    |> apply_stroke(opts)
    |> apply_opacity(opts)
    |> maybe_put(opts, :radius, :radius)
  end

  @doc "Builds a circle shape."
  @spec circle(x :: number(), y :: number(), r :: number(), opts :: keyword()) :: Circle.t()
  def circle(x, y, r, opts \\ []) do
    %Circle{x: x, y: y, r: r}
    |> apply_fill(opts)
    |> apply_stroke(opts)
    |> apply_opacity(opts)
  end

  @doc "Builds a line shape."
  @spec line(
          x1 :: number(),
          y1 :: number(),
          x2 :: number(),
          y2 :: number(),
          opts :: keyword()
        ) :: Line.t()
  def line(x1, y1, x2, y2, opts \\ []) do
    %Line{x1: x1, y1: y1, x2: x2, y2: y2}
    |> apply_stroke(opts)
    |> apply_opacity(opts)
  end

  @doc "Builds a text shape."
  @spec text(x :: number(), y :: number(), content :: String.t(), opts :: keyword()) ::
          CanvasText.t()
  def text(x, y, content, opts \\ []) do
    %CanvasText{x: x, y: y, content: content}
    |> apply_fill(opts)
    |> maybe_put(opts, :size, :size)
    |> maybe_put(opts, :font, :font)
    |> maybe_put(opts, :align_x, :align_x)
    |> maybe_put(opts, :align_y, :align_y)
    |> apply_opacity(opts)
  end

  # -- Group shape ------------------------------------------------------------

  @doc false
  @spec __build_group__(children :: [map()], opts :: keyword()) :: Group.t()
  def __build_group__(items, explicit_opts) when is_list(items) and is_list(explicit_opts) do
    {meta, children} = Enum.split_with(items, &match?({:__canvas_meta__, _, _}, &1))

    opts =
      Enum.reduce(meta, explicit_opts, fn
        {:__canvas_meta__, :interactive, v}, acc -> [{:interactive, v} | acc]
      end)

    shape = %Group{children: children}
    shape = if opts[:x], do: %{shape | x: opts[:x]}, else: shape
    shape = if opts[:y], do: %{shape | y: opts[:y]}, else: shape

    case Keyword.get(opts, :interactive) do
      nil ->
        shape

      %Interactive{} = i ->
        %{shape | interactive: i}

      interactive_opts when is_list(interactive_opts) ->
        %{shape | interactive: Interactive.new(interactive_opts)}
    end
  end

  # -- Path shape -------------------------------------------------------------

  @doc """
  Builds an arbitrary path shape.

  Commands are produced by `move_to/2`, `line_to/2`, `bezier_to/6`,
  `quadratic_to/4`, `arc/5`, `arc_to/5`, `ellipse/7`, `rounded_rect/5`,
  and `close/0`.
  """
  @spec path(commands :: [map() | list() | String.t()], opts :: keyword()) :: Path.t()
  def path(commands, opts \\ []) do
    %Path{commands: commands}
    |> apply_fill(opts)
    |> apply_stroke(opts)
    |> apply_opacity(opts)
  end

  # -- Path commands ----------------------------------------------------------

  @doc "Move-to path command."
  @spec move_to(x :: number(), y :: number()) :: list()
  def move_to(x, y), do: ["move_to", x, y]

  @doc "Line-to path command."
  @spec line_to(x :: number(), y :: number()) :: list()
  def line_to(x, y), do: ["line_to", x, y]

  @doc "Cubic bezier curve path command."
  @spec bezier_to(
          cp1x :: number(),
          cp1y :: number(),
          cp2x :: number(),
          cp2y :: number(),
          x :: number(),
          y :: number()
        ) :: list()
  def bezier_to(cp1x, cp1y, cp2x, cp2y, x, y),
    do: ["bezier_to", cp1x, cp1y, cp2x, cp2y, x, y]

  @doc "Quadratic bezier curve path command."
  @spec quadratic_to(cpx :: number(), cpy :: number(), x :: number(), y :: number()) :: list()
  def quadratic_to(cpx, cpy, x, y), do: ["quadratic_to", cpx, cpy, x, y]

  @doc "Arc path command (center, radius, start and end angles in radians)."
  @spec arc(
          cx :: number(),
          cy :: number(),
          r :: number(),
          start_angle :: number(),
          end_angle :: number()
        ) :: list()
  def arc(cx, cy, r, start_angle, end_angle), do: ["arc", cx, cy, r, start_angle, end_angle]

  @doc "Tangent arc path command."
  @spec arc_to(
          x1 :: number(),
          y1 :: number(),
          x2 :: number(),
          y2 :: number(),
          radius :: number()
        ) :: list()
  def arc_to(x1, y1, x2, y2, radius), do: ["arc_to", x1, y1, x2, y2, radius]

  @doc "Ellipse path command."
  @spec ellipse(
          cx :: number(),
          cy :: number(),
          rx :: number(),
          ry :: number(),
          rotation :: number(),
          start_angle :: number(),
          end_angle :: number()
        ) :: list()
  def ellipse(cx, cy, rx, ry, rotation, start_angle, end_angle),
    do: ["ellipse", cx, cy, rx, ry, rotation, start_angle, end_angle]

  @doc "Rounded rectangle path command."
  @spec rounded_rect(
          x :: number(),
          y :: number(),
          w :: number(),
          h :: number(),
          radius :: number()
        ) :: list()
  def rounded_rect(x, y, w, h, radius), do: ["rounded_rect", x, y, w, h, radius]

  @doc "Close path command."
  @spec close() :: String.t()
  def close, do: "close"

  # -- Transform commands -----------------------------------------------------

  @doc "Push (save) the current transform state onto the stack."
  @spec push_transform() :: PushTransform.t()
  def push_transform, do: %PushTransform{}

  @doc "Pop (restore) the previously saved transform state from the stack."
  @spec pop_transform() :: PopTransform.t()
  def pop_transform, do: %PopTransform{}

  @doc "Translate the coordinate origin."
  @spec translate(x :: number(), y :: number()) :: Translate.t()
  def translate(x, y), do: %Translate{x: x, y: y}

  @doc "Rotate the coordinate system (angle in radians)."
  @spec rotate(angle :: number()) :: Rotate.t()
  def rotate(angle), do: %Rotate{angle: angle}

  @doc "Scale the coordinate system."
  @spec scale(x :: number(), y :: number()) :: Scale.t()
  def scale(x, y), do: %Scale{x: x, y: y}

  # -- Clipping commands ------------------------------------------------------

  @doc "Pushes a clipping rectangle. All shapes until the matching pop_clip are clipped to this region."
  @spec push_clip(x :: number(), y :: number(), w :: number(), h :: number()) :: PushClip.t()
  def push_clip(x, y, w, h), do: %PushClip{x: x, y: y, w: w, h: h}

  @doc "Pops the most recent clipping rectangle."
  @spec pop_clip() :: PopClip.t()
  def pop_clip, do: %PopClip{}

  # -- Gradient builder -------------------------------------------------------

  @doc """
  Builds a linear gradient, usable as a `fill` value.

  Stops are `{offset, color}` tuples where offset is 0.0..1.0.
  """
  @spec linear_gradient(
          from :: {number(), number()},
          to :: {number(), number()},
          stops :: [{number(), String.t()}]
        ) :: LinearGradient.t()
  def linear_gradient({fx, fy}, {tx, ty}, stops) do
    %LinearGradient{from: {fx, fy}, to: {tx, ty}, stops: stops}
  end

  # -- Image / SVG on canvas --------------------------------------------------

  @doc """
  Draws a raster image on the canvas at the given position and size.

  ## Options

  - `:rotation` -- rotation angle in radians.
  - `:opacity` -- opacity multiplier (0.0-1.0).
  """
  @spec image(
          source :: String.t(),
          x :: number(),
          y :: number(),
          w :: number(),
          h :: number(),
          opts :: keyword()
        ) :: CanvasImage.t()
  def image(source, x, y, w, h, opts \\ []) do
    %CanvasImage{source: source, x: x, y: y, w: w, h: h}
    |> maybe_put(opts, :rotation, :rotation)
    |> apply_opacity(opts)
  end

  @doc "Draws an SVG on the canvas at the given position and size."
  @spec svg(
          source :: String.t(),
          x :: number(),
          y :: number(),
          w :: number(),
          h :: number()
        ) :: CanvasSvg.t()
  def svg(source, x, y, w, h),
    do: %CanvasSvg{source: source, x: x, y: y, w: w, h: h}

  # -- Stroke helper ----------------------------------------------------------

  @doc """
  Builds a stroke descriptor.

  ## Options

  - `:cap` -- line cap: `"butt"`, `"round"`, or `"square"`. Default: `"butt"`.
  - `:join` -- line join: `"miter"`, `"round"`, or `"bevel"`. Default: `"miter"`.
  - `:dash` -- dash pattern as `{segments, offset}` where segments is a list
    of numbers and offset is the starting offset.
  """
  @spec stroke(color :: String.t(), width :: number(), opts :: keyword()) :: Stroke.t()
  def stroke(color, width, opts \\ []) do
    %Stroke{color: color, width: width}
    |> maybe_put(opts, :cap, :cap)
    |> maybe_put(opts, :join, :join)
    |> maybe_put_dash(opts)
  end

  # -- Interactive shapes -----------------------------------------------------

  @doc """
  Marks a shape as interactive by attaching an `%Interactive{}` struct.

  The canvas renderer uses this field for hit testing, hover/press
  style overrides, drag constraints, cursor changes, tooltips, and
  accessibility annotations.

  ## Required option

  - `:id` -- unique identifier for this interactive shape (used in events).

  ## Optional fields

  - `:on_click` (boolean) -- emit click events for this shape.
  - `:on_hover` (boolean) -- emit hover events for this shape.
  - `:draggable` (boolean) -- allow dragging this shape.
  - `:drag_axis` (string) -- constrain drag to `"x"`, `"y"`, or `"both"`.
  - `:drag_bounds` (map) -- clamp drag to `%{min_x, max_x, min_y, max_y}`.
  - `:cursor` (string) -- CSS cursor name shown on hover.
  - `:hover_style` (map) -- style overrides applied on hover (fill, stroke, opacity).
  - `:pressed_style` (map) -- style overrides applied on press.
  - `:tooltip` (string) -- tooltip text shown on hover.
  - `:a11y` (map) -- accessibility overrides (role, label, etc.).
  - `:hit_rect` (map) -- explicit hit test rectangle `%{x, y, w, h}` override.
  """
  @spec interactive(shape :: map(), opts :: keyword()) :: map()
  def interactive(shape, opts) when is_map(shape) do
    %{shape | interactive: Interactive.new(opts)}
  end

  # -- Build helpers for canvas_scope rewrites --------------------------------

  @doc false
  def __build_text__(x, y, content), do: text(x, y, content)
  def __build_text__(x, y, content, opts), do: text(x, y, content, opts)

  @doc false
  def __build_image__(source, x, y, w, h), do: image(source, x, y, w, h)
  def __build_image__(source, x, y, w, h, opts), do: image(source, x, y, w, h, opts)

  @doc false
  def __build_svg__(source, x, y, w, h), do: svg(source, x, y, w, h)

  def __build_svg__(source, x, y, w, h, _opts) do
    %CanvasSvg{source: source, x: x, y: y, w: w, h: h}
  end

  # -- Interactive descriptor for group blocks --------------------------------

  @doc false
  def interactive_descriptor(id, opts) when is_binary(id) do
    {:__canvas_meta__, :interactive, Interactive.new([{:id, id} | opts])}
  end

  # -- Private helpers --------------------------------------------------------

  defp apply_fill(shape, opts) do
    shape =
      case Keyword.get(opts, :fill) do
        nil -> shape
        fill -> %{shape | fill: fill}
      end

    case Keyword.get(opts, :fill_rule) do
      nil -> shape
      :non_zero -> %{shape | fill_rule: "non_zero"}
      :even_odd -> %{shape | fill_rule: "even_odd"}
    end
  end

  defp apply_stroke(shape, opts) do
    case Keyword.get(opts, :stroke) do
      nil -> shape
      stroke_val -> %{shape | stroke: stroke_val}
    end
  end

  defp maybe_put(shape, opts, key, field) do
    case Keyword.get(opts, key) do
      nil -> shape
      val -> %{shape | field => val}
    end
  end

  defp maybe_put_dash(shape, opts) do
    case Keyword.get(opts, :dash) do
      nil -> shape
      {segments, offset} -> %{shape | dash: %{segments: segments, offset: offset}}
    end
  end

  defp apply_opacity(shape, opts) do
    case Keyword.get(opts, :opacity) do
      nil -> shape
      opacity -> %{shape | opacity: opacity}
    end
  end
end
