defmodule Julep.Iced do
  @moduledoc """
  Strict parity layer for iced widgets.

  Every function maps 1:1 to an iced widget and returns a plain node map:

      %{id: id, type: type_string, props: %{...}, children: [...]}

  No macro sugar, no auto-IDs -- just data. Props are accepted as atom-keyed
  maps for ergonomics and normalised to string keys in the output.

  ## Per-widget modules

  Each widget also lives in its own module under `Julep.Iced.Widget.*`,
  matching iced's `iced::widget::*` structure. Those modules provide typed
  structs with builder functions for compile-time safety:

      alias Julep.Iced.Widget.Button

      Button.new("btn", "Click me")
      |> Button.style(:primary)
      |> Button.build()

  This module provides untyped convenience functions that produce raw
  `ui_node()` maps from props maps (matching iced's `iced::widget::button()`
  pattern):

      Julep.Iced.button("btn", %{label: "Click me"})
      Julep.Iced.column("col", %{spacing: 10}, children)

  ## Types

  Several prop values have shared formats across widgets. See the type helper
  modules for constructors and encoding:

  - `Julep.Iced.Length` -- `:fill`, `:shrink`, `{:fill_portion, n}`, or a number
  - `Julep.Iced.Padding` -- uniform number, `{v, h}` tuple, or per-side map
  - `Julep.Iced.Color` -- hex string `"#rrggbb"` / `"#rrggbbaa"`, or `%{r, g, b, a}` map (0.0-1.0 floats)
  - `Julep.Iced.Font` -- `:default`, `:monospace`, or `%{family, weight, style, stretch}` map
  - `Julep.Iced.Alignment` -- `:start` / `:center` / `:end` (encoded as strings)
  - `Julep.Iced.Border` -- `%{color, width, radius}` map
  - `Julep.Iced.Shadow` -- `%{color, offset, blur_radius}` map
  - `Julep.Iced.Theme` -- built-in theme atom or custom palette map
  - `Julep.Iced.Gradient` -- `%{type: "linear", angle, stops}` map

  ## Named styles

  Many widgets accept a `style` prop (string). The available style names
  vary by widget and map to iced's built-in style functions. See each
  widget's documentation for the list of accepted values.
  """

  alias Julep.Iced.Widget.Node

  @typedoc "A UI tree node map. Every widget builder returns this shape."
  @type ui_node :: %{
          id: String.t(),
          type: String.t(),
          props: %{optional(String.t()) => term()},
          children: [ui_node()]
        }

  @typedoc "Props map accepted by widget builders (atom keys, normalised to strings internally)."
  @type props :: %{optional(atom()) => term()}

  # ---------------------------------------------------------------------------
  # Layout widgets
  # ---------------------------------------------------------------------------

  @doc """
  Column layout -- arranges children vertically.

  See `Julep.Iced.Widget.Column` for full props documentation.
  """
  @spec column(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def column(id, props \\ %{}, children \\ []),
    do: Node.build(id, "column", props, children)

  @doc """
  Row layout -- arranges children horizontally.

  See `Julep.Iced.Widget.Row` for full props documentation.
  """
  @spec row(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def row(id, props \\ %{}, children \\ []),
    do: Node.build(id, "row", props, children)

  @doc """
  Container layout -- wraps a single child with padding, sizing, and styling.

  See `Julep.Iced.Widget.Container` for full props documentation.
  """
  @spec container(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def container(id, props \\ %{}, children \\ []),
    do: Node.build(id, "container", props, children)

  @doc """
  Scrollable container -- wraps child content in a scrollable viewport.

  See `Julep.Iced.Widget.Scrollable` for full props documentation.
  """
  @spec scrollable(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def scrollable(id, props \\ %{}, children \\ []),
    do: Node.build(id, "scrollable", props, children)

  @doc """
  Stack layout -- layers children on top of each other.

  See `Julep.Iced.Widget.Stack` for full props documentation.
  """
  @spec stack(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def stack(id, props \\ %{}, children \\ []),
    do: Node.build(id, "stack", props, children)

  @doc """
  Empty space -- invisible spacer widget.

  See `Julep.Iced.Widget.Space` for full props documentation.
  """
  @spec space(id :: String.t(), props :: props()) :: ui_node()
  def space(id, props \\ %{}), do: Node.build(id, "space", props)

  @doc """
  Grid layout -- arranges children in a fixed-column grid.

  See `Julep.Iced.Widget.Grid` for full props documentation.
  """
  @spec grid(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def grid(id, props \\ %{}, children \\ []),
    do: Node.build(id, "grid", props, children)

  @doc """
  Pin layout -- positions child at absolute coordinates.

  See `Julep.Iced.Widget.Pin` for full props documentation.
  """
  @spec pin(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def pin(id, props \\ %{}, children \\ []),
    do: Node.build(id, "pin", props, children)

  @doc """
  Floating overlay -- positions child with optional translation and scaling.

  See `Julep.Iced.Widget.Float` for full props documentation.
  """
  @spec float_widget(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def float_widget(id, props \\ %{}, children \\ []),
    do: Node.build(id, "float", props, children)

  @doc """
  Responsive layout -- adapts to available size by reporting resize events.

  See `Julep.Iced.Widget.Responsive` for full props documentation.
  """
  @spec responsive(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def responsive(id, props \\ %{}, children \\ []),
    do: Node.build(id, "responsive", props, children)

  @doc """
  Per-subtree theme override -- applies a different theme to child widgets.

  See `Julep.Iced.Widget.Themer` for full props documentation.
  """
  @spec themer(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def themer(id, props \\ %{}, children \\ []),
    do: Node.build(id, "themer", props, children)

  @doc """
  Keyed column -- like `column/3` but uses child IDs as keys for efficient
  list diffing.

  See `Julep.Iced.Widget.KeyedColumn` for full props documentation.
  """
  @spec keyed_column(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def keyed_column(id, props \\ %{}, children \\ []),
    do: Node.build(id, "keyed_column", props, children)

  # ---------------------------------------------------------------------------
  # Input widgets
  # ---------------------------------------------------------------------------

  @doc """
  Button -- clickable widget that emits `{:click, id}` events.

  See `Julep.Iced.Widget.Button` for full props documentation.
  """
  @spec button(id :: String.t(), props :: props()) :: ui_node()
  def button(id, props \\ %{}), do: Node.build(id, "button", props)

  @doc """
  Text input field -- single-line editable text.

  See `Julep.Iced.Widget.TextInput` for full props documentation.
  """
  @spec text_input(id :: String.t(), props :: props()) :: ui_node()
  def text_input(id, props \\ %{}), do: Node.build(id, "text_input", props)

  @doc """
  Checkbox -- toggleable boolean input.

  See `Julep.Iced.Widget.Checkbox` for full props documentation.
  """
  @spec checkbox(id :: String.t(), props :: props()) :: ui_node()
  def checkbox(id, props \\ %{}), do: Node.build(id, "checkbox", props)

  @doc """
  Toggler -- on/off switch.

  See `Julep.Iced.Widget.Toggler` for full props documentation.
  """
  @spec toggler(id :: String.t(), props :: props()) :: ui_node()
  def toggler(id, props \\ %{}), do: Node.build(id, "toggler", props)

  @doc """
  Radio button -- one-of-many selection.

  See `Julep.Iced.Widget.Radio` for full props documentation.
  """
  @spec radio(id :: String.t(), props :: props()) :: ui_node()
  def radio(id, props \\ %{}), do: Node.build(id, "radio", props)

  @doc """
  Slider -- horizontal range input.

  See `Julep.Iced.Widget.Slider` for full props documentation.
  """
  @spec slider(id :: String.t(), props :: props()) :: ui_node()
  def slider(id, props \\ %{}), do: Node.build(id, "slider", props)

  @doc """
  Vertical slider -- vertical range input.

  See `Julep.Iced.Widget.VerticalSlider` for full props documentation.
  """
  @spec vertical_slider(id :: String.t(), props :: props()) :: ui_node()
  def vertical_slider(id, props \\ %{}), do: Node.build(id, "vertical_slider", props)

  @doc """
  Pick list -- dropdown selection.

  See `Julep.Iced.Widget.PickList` for full props documentation.
  """
  @spec pick_list(id :: String.t(), props :: props()) :: ui_node()
  def pick_list(id, props \\ %{}), do: Node.build(id, "pick_list", props)

  @doc """
  Combo box -- searchable dropdown with free-form text input.

  See `Julep.Iced.Widget.ComboBox` for full props documentation.
  """
  @spec combo_box(id :: String.t(), props :: props()) :: ui_node()
  def combo_box(id, props \\ %{}), do: Node.build(id, "combo_box", props)

  @doc """
  Text editor -- multi-line editable text area.

  See `Julep.Iced.Widget.TextEditor` for full props documentation.
  """
  @spec text_editor(id :: String.t(), props :: props()) :: ui_node()
  def text_editor(id, props \\ %{}), do: Node.build(id, "text_editor", props)

  # ---------------------------------------------------------------------------
  # Interactive widgets
  # ---------------------------------------------------------------------------

  @doc """
  Mouse area -- captures mouse events on child content.

  See `Julep.Iced.Widget.MouseArea` for full props documentation.
  """
  @spec mouse_area(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def mouse_area(id, props \\ %{}, children \\ []),
    do: Node.build(id, "mouse_area", props, children)

  @doc """
  Sensor -- detects visibility and size changes on child content.

  See `Julep.Iced.Widget.Sensor` for full props documentation.
  """
  @spec sensor(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def sensor(id, props \\ %{}, children \\ []),
    do: Node.build(id, "sensor", props, children)

  @doc """
  Pane grid -- resizable tiled panes.

  See `Julep.Iced.Widget.PaneGrid` for full props documentation.
  """
  @spec pane_grid(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def pane_grid(id, props \\ %{}, children \\ []),
    do: Node.build(id, "pane_grid", props, children)

  # ---------------------------------------------------------------------------
  # Display widgets
  # ---------------------------------------------------------------------------

  @doc """
  Text display -- renders static text.

  See `Julep.Iced.Widget.Text` for full props documentation.
  """
  @spec text(id :: String.t(), props :: props()) :: ui_node()
  def text(id, props \\ %{}), do: Node.build(id, "text", props)

  @doc """
  Horizontal or vertical rule (divider line).

  See `Julep.Iced.Widget.Rule` for full props documentation.
  """
  @spec rule(id :: String.t(), props :: props()) :: ui_node()
  def rule(id, props \\ %{}), do: Node.build(id, "rule", props)

  @doc """
  Progress bar -- displays progress within a range.

  See `Julep.Iced.Widget.ProgressBar` for full props documentation.
  """
  @spec progress_bar(id :: String.t(), props :: props()) :: ui_node()
  def progress_bar(id, props \\ %{}), do: Node.build(id, "progress_bar", props)

  @doc """
  Tooltip -- shows a popup tip over child content on hover.

  See `Julep.Iced.Widget.Tooltip` for full props documentation.
  """
  @spec tooltip(id :: String.t(), props :: props(), children :: [ui_node()], tip :: String.t()) ::
          ui_node()
  def tooltip(id, props \\ %{}, children \\ [], tip) do
    merged = Map.put(props, :tip, tip)
    Node.build(id, "tooltip", merged, children)
  end

  @doc """
  Image display -- renders a raster image from a file path.

  See `Julep.Iced.Widget.Image` for full props documentation.
  """
  @spec image(id :: String.t(), props :: props()) :: ui_node()
  def image(id, props \\ %{}), do: Node.build(id, "image", props)

  @doc """
  SVG display -- renders a vector image from a file path.

  See `Julep.Iced.Widget.Svg` for full props documentation.
  """
  @spec svg(id :: String.t(), props :: props()) :: ui_node()
  def svg(id, props \\ %{}), do: Node.build(id, "svg", props)

  @doc """
  Markdown display -- renders parsed markdown content.

  See `Julep.Iced.Widget.Markdown` for full props documentation.
  """
  @spec markdown(id :: String.t(), props :: props()) :: ui_node()
  def markdown(id, props \\ %{}), do: Node.build(id, "markdown", props)

  @doc """
  Rich text display with individually styled spans.

  See `Julep.Iced.Widget.RichText` for full props documentation.
  """
  @spec rich_text(id :: String.t(), props :: props()) :: ui_node()
  def rich_text(id, props \\ %{}), do: Node.build(id, "rich_text", props)

  # ---------------------------------------------------------------------------
  # Canvas & data widgets
  # ---------------------------------------------------------------------------

  @doc """
  Canvas for drawing shapes.

  See `Julep.Iced.Widget.Canvas` for full props documentation.
  """
  @spec canvas(id :: String.t(), props :: props()) :: ui_node()
  def canvas(id, props \\ %{}), do: Node.build(id, "canvas", props)

  @doc """
  Data table -- composite widget built from columns, rows, and scrollable containers.

  See `Julep.Iced.Widget.Table` for full props documentation.
  """
  @spec table(id :: String.t(), props :: props()) :: ui_node()
  def table(id, props \\ %{}), do: Node.build(id, "table", props)
end
