# Widget packages

How to build and publish reusable widget packages for julep apps.

Two tiers of widget packages exist:

1. **Pure Elixir** -- compose existing primitives (canvas, column, container,
   etc.) into higher-level widgets. Works today. Works with prebuilt
   renderer binaries. No Rust toolchain needed.
2. **Elixir + Rust** -- custom native rendering via a `WidgetExtension`
   trait. Requires a Rust toolchain to compile a custom renderer binary.

This guide covers Tier 1 -- pure Elixir packages.

## When pure Elixir is enough

Canvas + Shape builders cover custom 2D rendering: charts, diagrams,
gauges, sparklines, colour pickers, drawing tools. The overlay widget
enables dropdowns, popovers, and context menus. Style maps provide
per-instance visual customization. Composition of layout primitives
(column, row, container, stack) covers cards, tab bars, sidebars, toolbars,
and other structural patterns.

See [composition-patterns.md](composition-patterns.md) for examples.

Pure Elixir falls short when you need: custom text layout engines, GPU
shaders, platform-native controls (e.g. a native file tree), or
performance-critical rendering that canvas can't handle efficiently. Those
cases need Tier 2.

## Package structure

A julep widget package is a standard Mix project:

```
my_widget/
  lib/
    my_widget.ex              # public API (convenience constructors)
    my_widget/
      donut_chart.ex          # widget struct + Widget protocol impl
  test/
    my_widget/
      donut_chart_test.exs    # struct, builder, and to_node tests
  mix.exs
```

### mix.exs

```elixir
defmodule MyWidget.MixProject do
  use Mix.Project

  def project do
    [
      app: :my_widget,
      version: "0.1.0",
      elixir: "~> 1.16",
      deps: deps()
    ]
  end

  defp deps do
    [
      {:julep, "~> 0.1"}
    ]
  end
end
```

julep is a compile-time dependency. Your package does not need the renderer
binary -- it only uses julep's Elixir modules (`Julep.Iced.Widget`,
`Julep.Iced.Widget.Build`, `Julep.Iced.Encode`, type modules).

## Building a widget

Implement the `Julep.Iced.Widget` protocol on your struct. The `to_node/1`
implementation composes existing built-in node types. The renderer handles
them without modification.

### Example: DonutChart

A ring chart rendered via canvas:

```elixir
defmodule MyWidget.DonutChart do
  @moduledoc """
  A donut chart widget rendered via canvas.

  ## Usage

      DonutChart.new("revenue", [
        {"Product A", 45.0, "#3498db"},
        {"Product B", 30.0, "#e74c3c"},
        {"Product C", 25.0, "#2ecc71"}
      ], size: 200, thickness: 40)
      |> DonutChart.build()
  """

  alias Julep.Iced.Widget.Build
  alias Julep.Canvas.Shape

  @type segment :: {label :: String.t(), value :: number(), color :: String.t()}

  @type option ::
          {:size, number()}
          | {:thickness, number()}
          | {:background, Julep.Iced.Color.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          segments: [segment()],
          size: number(),
          thickness: number(),
          background: Julep.Iced.Color.t() | nil
        }

  defstruct [:id, :segments, size: 200, thickness: 40, background: nil]

  @spec new(id :: String.t(), segments :: [segment()], opts :: [option()]) :: t()
  def new(id, segments, opts \\ []) when is_binary(id) and is_list(segments) do
    %__MODULE__{id: id, segments: segments} |> with_options(opts)
  end

  @spec size(donut_chart :: t(), size :: number()) :: t()
  def size(%__MODULE__{} = chart, size), do: %{chart | size: size}

  @spec thickness(donut_chart :: t(), thickness :: number()) :: t()
  def thickness(%__MODULE__{} = chart, thickness), do: %{chart | thickness: thickness}

  @spec background(donut_chart :: t(), color :: Julep.Iced.Color.t()) :: t()
  def background(%__MODULE__{} = chart, color) do
    %{chart | background: Julep.Iced.Color.cast(color)}
  end

  @spec with_options(donut_chart :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = chart, []), do: chart

  def with_options(%__MODULE__{} = chart, opts) do
    Enum.reduce(opts, chart, fn
      {:size, v}, acc -> size(acc, v)
      {:thickness, v}, acc -> thickness(acc, v)
      {:background, v}, acc -> background(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @spec build(donut_chart :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = chart), do: Julep.Iced.Widget.to_node(chart)

  # -- Widget protocol --

  defimpl Julep.Iced.Widget do
    def to_node(chart) do
      layers = %{"arcs" => build_arc_shapes(chart)}

      props =
        %{"layers" => layers, "width" => chart.size, "height" => chart.size}
        |> Julep.Iced.Widget.Build.put_if(chart.background, "background")

      %{id: chart.id, type: "canvas", props: props, children: []}
    end

    defp build_arc_shapes(chart) do
      total = chart.segments |> Enum.map(&elem(&1, 1)) |> Enum.sum()
      if total == 0, do: throw(:empty)

      r = chart.size / 2
      inner_r = r - chart.thickness

      {shapes, _} =
        Enum.reduce(chart.segments, {[], -:math.pi() / 2}, fn {_label, value, color}, {acc, start} ->
          sweep = value / total * 2 * :math.pi()
          stop = start + sweep

          arc_shape =
            Shape.path(
              [
                Shape.arc(r, r, r, start, stop),
                Shape.line_to(
                  r + inner_r * :math.cos(stop),
                  r + inner_r * :math.sin(stop)
                ),
                Shape.arc(r, r, inner_r, stop, start),
                Shape.close()
              ],
              fill: color
            )

          {[arc_shape | acc], stop}
        end)

      Enum.reverse(shapes)
    catch
      :throw, :empty -> []
    end
  end
end
```

Key points:

- The struct follows julep's builder pattern (see
  [widget-authoring.md](widget-authoring.md) for the full guide).
- `to_node/1` emits a `"canvas"` node with `"layers"` -- a type the stock
  renderer already handles.
- No Rust code. No custom node types. The renderer sees a canvas widget.
- Color builders call `Color.cast/1` to normalize input.

### Providing convenience constructors

For consumer ergonomics, add a top-level module with functions that mirror
the `Julep.UI` / `Julep.Iced` calling conventions:

```elixir
defmodule MyWidget do
  alias MyWidget.DonutChart

  @doc "Creates a donut chart node."
  @spec donut_chart(id :: String.t(), segments :: [DonutChart.segment()], opts :: Keyword.t()) ::
          Julep.Iced.ui_node()
  def donut_chart(id, segments, opts \\ []) do
    DonutChart.new(id, segments, opts) |> DonutChart.build()
  end
end
```

Consumers use it like any other widget:

```elixir
import Julep.UI

column do
  text("Revenue breakdown")
  MyWidget.donut_chart("revenue", model.segments, size: 300)
end
```

The result of `donut_chart/3` is a plain `ui_node()` map. It composes
naturally with `Julep.UI` do-blocks, `Column.push/2`, or any other tree
builder.

## Testing

### Unit tests (no renderer needed)

Test the struct, builders, and `to_node/1` output directly. This is fast
and needs no binary:

```elixir
defmodule MyWidget.DonutChartTest do
  use ExUnit.Case, async: true

  alias MyWidget.DonutChart

  test "new/3 creates struct with defaults" do
    chart = DonutChart.new("c1", [{"A", 50, "#ff0000"}])
    assert chart.id == "c1"
    assert chart.size == 200
    assert chart.thickness == 40
  end

  test "with_options applies size and thickness" do
    chart = DonutChart.new("c1", [{"A", 50, "#ff0000"}], size: 300, thickness: 60)
    assert chart.size == 300
    assert chart.thickness == 60
  end

  test "build/1 produces a canvas node" do
    node = DonutChart.new("c1", [{"A", 50, "#ff0000"}]) |> DonutChart.build()
    assert node.type == "canvas"
    assert node.id == "c1"
    assert is_map(node.props["layers"])
  end

  test "build/1 generates arc shapes for each segment" do
    node =
      DonutChart.new("c1", [
        {"A", 60, "#ff0000"},
        {"B", 40, "#00ff00"}
      ])
      |> DonutChart.build()

    arcs = node.props["layers"]["arcs"]
    assert length(arcs) == 2
  end
end
```

### Integration tests with pooled_mock backend

For testing widget behaviour in a running app (event handling, view
updates), use julep's pooled_mock backend. It runs pure Elixir -- no
renderer binary:

```elixir
defmodule MyWidget.IntegrationTest do
  use Julep.Test.Case, async: true

  defmodule ChartApp do
    @behaviour Julep.App

    def init(_opts), do: %{segments: [{"A", 50, "#ff0000"}, {"B", 50, "#0000ff"}]}
    def update(model, _event), do: model

    def view(model) do
      import Julep.UI
      window "main" do
        MyWidget.donut_chart("chart", model.segments, size: 200)
      end
    end
  end

  test "chart renders in the tree" do
    session = start!(ChartApp)
    element = find!(session, "#chart")
    assert element.type == "canvas"
  end
end
```

### Visual testing with headless or windowed backend

For pixel-level validation, use the headless or windowed test backend.
These require the julep binary. Typically only needed for the package
author's CI, not for consumers:

```elixir
# In test/test_helper.exs or a tagged test module:
use Julep.Test.Case, async: false, backend: :headless
```

## What consumers need to know

Document these in your package README:

1. **Minimum julep version.** Your package depends on julep; specify the
   compatible range.
2. **No renderer changes needed.** Pure Elixir packages work with the stock
   julep binary. Consumers do not need to rebuild anything.
3. **Which built-in features are required.** If your widget uses canvas,
   consumers need the `widget-canvas` feature enabled (it is by default).
   If it uses images, they need `widget-image`. Document this if it matters.

## Limitations of pure Elixir packages

- **No custom node types.** Your `to_node/1` must emit node types the stock
  renderer understands (`canvas`, `column`, `container`, etc.). You cannot
  define new type strings.
- **Canvas performance ceiling.** Complex canvas scenes (thousands of shapes,
  60fps animation) may hit limits. The canvas program re-tessellates when
  layer content changes, and very large shape lists take time to serialize
  over the wire.
- **No access to iced internals.** You cannot customize widget state
  continuity, keyboard focus, accessibility, or rendering internals. Your
  widget is a composition of black-box primitives.
- **Overlay requires the overlay node type.** If your widget needs popover
  behaviour, it depends on the `overlay` node type being available in the
  renderer (shipped in julep 0.x+).

## When to consider Tier 2

If your widget needs any of these, pure Elixir composition is insufficient:

- Custom text rendering (e.g. a rich text editor with inline images)
- GPU shaders or custom rendering pipelines
- Platform-native controls (system file browser, native menus)
- Custom widget state that must persist in the renderer (beyond what canvas
  caching provides)
- Custom hit testing or gesture recognition at the rendering layer

Tier 2 (Elixir + Rust packages) is designed for these cases. The
`WidgetExtension` trait, `Julep.Extension` behaviour, extension
discovery, and build integration are implemented.
