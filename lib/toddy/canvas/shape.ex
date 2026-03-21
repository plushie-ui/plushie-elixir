defmodule Toddy.Canvas.Shape do
  @moduledoc """
  Convenience builders for canvas shape descriptors.

  Every function produces a plain map with atom keys. The `Protocol.Encode`
  wire boundary handles key stringification before serialization. These are
  optional helpers -- raw maps work identically.

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

  ## Groups

  Groups nest shapes with optional positioning and interactivity.
  The `group` macro supports do-blocks for ergonomic nesting:

      group x: 4, y: 4, interactive: [id: "bold", on_click: true] do
        rect(0, 0, 32, 32, radius: 4)
        text(8, 22, "B", fill: "#333")
      end

  Or the list form:

      group([rect(0, 0, 32, 32), text(8, 22, "B")], x: 4, y: 4)

  ## Layers

  The `layer` macro collects shapes into a named layer for use inside
  a `canvas` do-block:

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

  All shapes accept an `:opacity` option (0.0-1.0) that multiplies into
  the fill and stroke color alpha channels:

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
  """

  # -- Basic shapes -----------------------------------------------------------

  @doc "Builds a rectangle shape descriptor."
  @spec rect(x :: number(), y :: number(), w :: number(), h :: number(), opts :: keyword()) ::
          map()
  def rect(x, y, w, h, opts \\ []) do
    %{type: "rect", x: x, y: y, w: w, h: h}
    |> apply_fill(opts)
    |> apply_stroke(opts)
    |> apply_opacity(opts)
  end

  @doc "Builds a circle shape descriptor."
  @spec circle(x :: number(), y :: number(), r :: number(), opts :: keyword()) :: map()
  def circle(x, y, r, opts \\ []) do
    %{type: "circle", x: x, y: y, r: r}
    |> apply_fill(opts)
    |> apply_stroke(opts)
    |> apply_opacity(opts)
  end

  @doc "Builds a line shape descriptor."
  @spec line(
          x1 :: number(),
          y1 :: number(),
          x2 :: number(),
          y2 :: number(),
          opts :: keyword()
        ) :: map()
  def line(x1, y1, x2, y2, opts \\ []) do
    %{type: "line", x1: x1, y1: y1, x2: x2, y2: y2}
    |> apply_stroke(opts)
    |> apply_opacity(opts)
  end

  @doc "Builds a text shape descriptor."
  @spec text(x :: number(), y :: number(), content :: String.t(), opts :: keyword()) :: map()
  def text(x, y, content, opts \\ []) do
    %{type: "text", x: x, y: y, content: content}
    |> apply_fill(opts)
    |> maybe_put(opts, :size, :size)
    |> maybe_put(opts, :font, :font)
    |> maybe_put(opts, :align_x, :align_x)
    |> maybe_put(opts, :align_y, :align_y)
    |> apply_opacity(opts)
  end

  # -- Group shape ------------------------------------------------------------

  @doc """
  Groups child shapes into a logical unit with optional positioning
  and interaction.

  Groups are the primary way to build interactive canvas components.
  The `:x` and `:y` options offset all child shapes. The `:interactive`
  option attaches click/hover/drag behavior via `Shape.interactive/2`.

  ## Do-block form

      group x: 4, y: 4, interactive: [id: "btn", on_click: true] do
        rect(0, 0, 32, 32, radius: 4)
        text(8, 22, "B", fill: "#333")
      end

  ## List form

      group([
        rect(0, 0, 100, 40, fill: "#3498db"),
        text(50, 25, "Click me", align_x: :center)
      ], x: 10, y: 50)

  ## Options

    * `:x` -- horizontal offset (default 0)
    * `:y` -- vertical offset (default 0)
    * `:interactive` -- keyword list passed to `interactive/2`
  """
  defmacro group(opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.Canvas.Shape.__build_group__(children, [])
        end

      other ->
        quote do
          Toddy.Canvas.Shape.__build_group__(unquote(other), [])
        end
    end
  end

  defmacro group(first, second) do
    case second do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.Canvas.Shape.__build_group__(children, unquote(first))
        end

      opts ->
        quote do
          Toddy.Canvas.Shape.__build_group__(unquote(first), unquote(opts))
        end
    end
  end

  @doc false
  @spec __build_group__(children :: [map()], opts :: keyword()) :: map()
  def __build_group__(children, opts) when is_list(children) and is_list(opts) do
    shape = %{type: "group", children: children}
    shape = if opts[:x], do: Map.put(shape, :x, opts[:x]), else: shape
    shape = if opts[:y], do: Map.put(shape, :y, opts[:y]), else: shape

    case Keyword.get(opts, :interactive) do
      nil -> shape
      interactive_opts -> interactive(shape, interactive_opts)
    end
  end

  # -- Layer helper -----------------------------------------------------------

  @doc """
  Collects shapes into a named layer tuple.

  Use inside a `canvas` do-block. Each layer is cached independently
  by the renderer -- put static content (grids, labels) in one layer
  and dynamic content (data, interactive shapes) in another.

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
  """
  defmacro layer(name, do: block) do
    exprs = block_to_exprs(block)

    quote do
      {unquote(name), [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)}
    end
  end

  # -- Path shape -------------------------------------------------------------

  @doc """
  Builds an arbitrary path shape descriptor.

  Commands are produced by `move_to/2`, `line_to/2`, `bezier_to/6`,
  `quadratic_to/4`, `arc/5`, `arc_to/5`, `ellipse/7`, `rounded_rect/5`,
  and `close/0`.
  """
  @spec path(commands :: [map() | list() | String.t()], opts :: keyword()) :: map()
  def path(commands, opts \\ []) do
    %{type: "path", commands: commands}
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
  @spec push_transform() :: map()
  def push_transform, do: %{type: "push_transform"}

  @doc "Pop (restore) the previously saved transform state from the stack."
  @spec pop_transform() :: map()
  def pop_transform, do: %{type: "pop_transform"}

  @doc "Translate the coordinate origin."
  @spec translate(x :: number(), y :: number()) :: map()
  def translate(x, y), do: %{type: "translate", x: x, y: y}

  @doc "Rotate the coordinate system (angle in radians)."
  @spec rotate(angle :: number()) :: map()
  def rotate(angle), do: %{type: "rotate", angle: angle}

  @doc "Scale the coordinate system."
  @spec scale(x :: number(), y :: number()) :: map()
  def scale(x, y), do: %{type: "scale", x: x, y: y}

  # -- Clipping commands ------------------------------------------------------

  @doc "Pushes a clipping rectangle. All shapes until the matching pop_clip are clipped to this region."
  @spec push_clip(x :: number(), y :: number(), w :: number(), h :: number()) :: map()
  def push_clip(x, y, w, h) do
    %{type: "push_clip", x: x, y: y, w: w, h: h}
  end

  @doc "Pops the most recent clipping rectangle."
  @spec pop_clip() :: map()
  def pop_clip do
    %{type: "pop_clip"}
  end

  # -- Gradient builder -------------------------------------------------------

  @doc """
  Builds a linear gradient descriptor, usable as a `fill` value.

  Stops are `{offset, color}` tuples where offset is 0.0..1.0.
  """
  @spec linear_gradient(
          from :: {number(), number()},
          to :: {number(), number()},
          stops :: [{number(), String.t()}]
        ) :: map()
  def linear_gradient({fx, fy}, {tx, ty}, stops) do
    %{
      type: "linear",
      start: [fx, fy],
      end: [tx, ty],
      stops: Enum.map(stops, fn {offset, color} -> [offset, color] end)
    }
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
        ) :: map()
  def image(source, x, y, w, h, opts \\ []) do
    %{type: "image", source: source, x: x, y: y, w: w, h: h}
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
        ) :: map()
  def svg(source, x, y, w, h),
    do: %{type: "svg", source: source, x: x, y: y, w: w, h: h}

  # -- Stroke helper ----------------------------------------------------------

  @doc """
  Builds a stroke descriptor.

  ## Options

  - `:cap` -- line cap: `"butt"`, `"round"`, or `"square"`. Default: `"butt"`.
  - `:join` -- line join: `"miter"`, `"round"`, or `"bevel"`. Default: `"miter"`.
  - `:dash` -- dash pattern as `{segments, offset}` where segments is a list
    of numbers and offset is the starting offset.
  """
  @spec stroke(color :: String.t(), width :: number(), opts :: keyword()) :: map()
  def stroke(color, width, opts \\ []) do
    base = %{color: color, width: width}

    base
    |> maybe_put(opts, :cap, :cap)
    |> maybe_put(opts, :join, :join)
    |> maybe_put_dash(opts)
  end

  # -- Interactive shapes -----------------------------------------------------

  @doc """
  Marks a shape as interactive by adding an `interactive` field.

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
    interactive_map =
      %{id: Keyword.fetch!(opts, :id)}
      |> maybe_put(opts, :on_click, :on_click)
      |> maybe_put(opts, :on_hover, :on_hover)
      |> maybe_put(opts, :draggable, :draggable)
      |> maybe_put(opts, :drag_axis, :drag_axis)
      |> maybe_put(opts, :drag_bounds, :drag_bounds)
      |> maybe_put(opts, :cursor, :cursor)
      |> maybe_put(opts, :hover_style, :hover_style)
      |> maybe_put(opts, :pressed_style, :pressed_style)
      |> maybe_put(opts, :tooltip, :tooltip)
      |> maybe_put(opts, :a11y, :a11y)
      |> maybe_put(opts, :hit_rect, :hit_rect)

    Map.put(shape, :interactive, interactive_map)
  end

  # -- Private helpers --------------------------------------------------------

  defp apply_fill(shape, opts) do
    shape =
      case Keyword.get(opts, :fill) do
        nil -> shape
        fill -> Map.put(shape, :fill, fill)
      end

    case Keyword.get(opts, :fill_rule) do
      nil -> shape
      :non_zero -> Map.put(shape, :fill_rule, "non_zero")
      :even_odd -> Map.put(shape, :fill_rule, "even_odd")
    end
  end

  defp apply_stroke(shape, opts) do
    case Keyword.get(opts, :stroke) do
      nil -> shape
      stroke_val -> Map.put(shape, :stroke, stroke_val)
    end
  end

  defp maybe_put(map, opts, key, atom_key) do
    case Keyword.get(opts, key) do
      nil -> map
      val -> Map.put(map, atom_key, val)
    end
  end

  defp maybe_put_dash(map, opts) do
    case Keyword.get(opts, :dash) do
      nil -> map
      {segments, offset} -> Map.put(map, :dash, %{segments: segments, offset: offset})
    end
  end

  defp apply_opacity(shape, opts) do
    case Keyword.get(opts, :opacity) do
      nil -> shape
      opacity -> Map.put(shape, :opacity, opacity)
    end
  end

  # -- Private macro helpers --------------------------------------------------

  defp block_to_exprs({:__block__, _, exprs}), do: exprs
  defp block_to_exprs(single_expr), do: [single_expr]
end
