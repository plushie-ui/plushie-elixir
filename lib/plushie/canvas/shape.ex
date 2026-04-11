defmodule Plushie.Canvas.Shape do
  @moduledoc """
  Pure builder functions returning typed canvas shape structs.

  Every function returns a struct from `Plushie.Canvas.Shape.*`.
  Each struct module has an `encode/1` function for wire-format
  conversion. These are plain functions, not macros --
  they can be called anywhere.

  Structure macros (`group`, `layer`) live in `Plushie.UI` and are
  available inside canvas do-blocks. Inside
  those blocks, `text`, `image`, and `svg` calls resolve
  automatically to their canvas shape variants. For helper functions
  outside canvas blocks, import this module directly.

  ## When to import this module

  Import `Plushie.Canvas.Shape` when you build shapes in standalone
  helper functions (defp) outside a `Plushie.UI` canvas block:

      import Plushie.Canvas.Shape

      defp draw_indicator(x, y, color) do
        [
          circle(x, y, 6, fill: color),
          circle(x, y, 3, fill: "#fff")
        ]
      end

  Inside `Plushie.UI` canvas/layer/group blocks, all shape functions
  are already in scope via `import Plushie.UI` -- no extra import
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

  Make shapes interactive with the `interactive` macro (requires a
  string id as the first argument):

      interactive "btn", on_click: true, cursor: "pointer" do
        rect(0, 0, 100, 40, fill: "#3498db")
      end
  """

  alias Plushie.Canvas.{Clip, Gradient, Stroke}

  alias Plushie.Canvas.Transform.{Rotate, Scale, Translate}

  alias Plushie.Canvas.Shape.{
    CanvasImage,
    CanvasSvg,
    CanvasText,
    Circle,
    Group,
    Interactive,
    Line,
    Path,
    Rect
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

    # Collect transforms and other metadata from DSL directives.
    transforms =
      meta
      |> Enum.filter(&match?({:__canvas_meta__, :transform, _}, &1))
      |> Enum.map(fn {:__canvas_meta__, :transform, t} -> t end)

    clip =
      Enum.find_value(meta, fn
        {:__canvas_meta__, :clip, c} -> c
        _ -> nil
      end)

    # Desugar x:/y: keyword opts into a leading translate.
    {x, opts} = Keyword.pop(explicit_opts, :x)
    {y, opts} = Keyword.pop(opts, :y)

    transforms =
      if x || y do
        [%Translate{x: x || 0, y: y || 0} | transforms]
      else
        transforms
      end

    shape = %Group{
      children: children,
      transforms: if(transforms == [], do: nil, else: transforms),
      clip: clip
    }

    # Apply remaining keyword opts as group fields.
    Enum.reduce(opts, shape, fn {key, val}, acc ->
      if Map.has_key?(acc, key) do
        Map.put(acc, key, val)
      else
        valid = Map.keys(%Group{children: []}) -- [:__struct__]

        raise ArgumentError,
              "unknown group option #{inspect(key)}. " <>
                "Valid options: #{inspect(valid)}"
      end
    end)
  end

  # -- Interactive shape -------------------------------------------------------

  @doc false
  @spec __build_interactive__(id :: String.t(), children :: [map()], opts :: keyword()) ::
          Interactive.t()
  def __build_interactive__(id, items, explicit_opts)
      when is_binary(id) and is_list(items) and is_list(explicit_opts) do
    {meta, children} = Enum.split_with(items, &match?({:__canvas_meta__, _, _}, &1))

    transforms =
      meta
      |> Enum.filter(&match?({:__canvas_meta__, :transform, _}, &1))
      |> Enum.map(fn {:__canvas_meta__, :transform, t} -> t end)

    clip =
      Enum.find_value(meta, fn
        {:__canvas_meta__, :clip, c} -> c
        _ -> nil
      end)

    {x, opts} = Keyword.pop(explicit_opts, :x)
    {y, opts} = Keyword.pop(opts, :y)

    transforms =
      if x || y do
        [%Translate{x: x || 0, y: y || 0} | transforms]
      else
        transforms
      end

    shape = %Interactive{
      id: id,
      children: children,
      transforms: if(transforms == [], do: nil, else: transforms),
      clip: clip
    }

    Enum.reduce(opts, shape, fn {key, val}, acc ->
      if Map.has_key?(acc, key) do
        Map.put(acc, key, val)
      else
        valid = Map.keys(%Interactive{children: [], id: ""}) -- [:__struct__, :id]

        raise ArgumentError,
              "unknown interactive option #{inspect(key)}. " <>
                "Valid options: #{inspect(valid)}"
      end
    end)
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

  # -- Transform values -------------------------------------------------------

  @doc "Create a translation transform."
  @spec translate(x :: number(), y :: number()) :: Translate.t()
  def translate(x, y), do: %Translate{x: x, y: y}

  @doc """
  Create a rotation transform.

  Accepts degrees by default. Use `degrees:` or `radians:` for
  explicit units.

      rotate(45)              # 45 degrees
      rotate(degrees: 45)     # explicit degrees
      rotate(radians: 0.785)  # explicit radians
  """
  @spec rotate(angle_or_opts :: number() | keyword()) :: Rotate.t()
  def rotate(angle) when is_number(angle) do
    %Rotate{angle: angle * :math.pi() / 180.0}
  end

  def rotate(degrees: d) when is_number(d) do
    %Rotate{angle: d * :math.pi() / 180.0}
  end

  def rotate(radians: r) when is_number(r) do
    %Rotate{angle: r}
  end

  @doc "Create a uniform scale transform."
  @spec scale(factor :: number()) :: Scale.t()
  def scale(factor) when is_number(factor), do: %Scale{factor: factor}

  @doc "Create a non-uniform scale transform."
  @spec scale(x :: number(), y :: number()) :: Scale.t()
  def scale(x, y), do: %Scale{x: x, y: y}

  # -- Clip value -------------------------------------------------------------

  @doc "Create a clip rectangle for a group."
  @spec clip(x :: number(), y :: number(), w :: number(), h :: number()) :: Clip.t()
  def clip(x, y, w, h), do: %Clip{x: x, y: y, w: w, h: h}

  # -- Gradient builder -------------------------------------------------------

  @doc """
  Builds a linear gradient, usable as a `fill` value.

  Stops are `{offset, color}` tuples where offset is 0.0..1.0.
  """
  @spec linear_gradient(
          from :: {number(), number()},
          to :: {number(), number()},
          stops :: [{number(), String.t()}]
        ) :: Gradient.t()
  def linear_gradient({fx, fy}, {tx, ty}, stops) do
    %Gradient{from: {fx, fy}, to: {tx, ty}, stops: stops}
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

  # -- Build helpers for canvas_scope rewrites --------------------------------

  @doc false
  def __build_text__(x, y, content), do: text(x, y, content)
  def __build_text__(x, y, content, opts), do: text(x, y, content, opts)

  @doc false
  def __build_image__(source, x, y, w, h), do: image(source, x, y, w, h)
  def __build_image__(source, x, y, w, h, opts), do: image(source, x, y, w, h, opts)

  @doc false
  def __build_svg__(source, x, y, w, h), do: svg(source, x, y, w, h)

  def __build_svg__(source, x, y, w, h, opts) do
    if opts != [] do
      raise ArgumentError,
            "canvas svg does not accept options (got #{inspect(opts)}). " <>
              "SVG shapes do not support fill, stroke, or opacity."
    end

    %CanvasSvg{source: source, x: x, y: y, w: w, h: h}
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
