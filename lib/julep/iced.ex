defmodule Julep.Iced do
  @moduledoc """
  Strict parity layer for iced widgets.

  Every function maps 1:1 to an iced widget and returns a plain node map:

      %{id: id, type: type_string, props: %{...}, children: [...]}

  No macro sugar, no auto-IDs -- just data. Props are accepted as atom-keyed
  maps for ergonomics and normalised to string keys in the output.
  """

  # ---------------------------------------------------------------------------
  # Internal helpers
  # ---------------------------------------------------------------------------

  defp node(id, type, props, children) do
    %{id: id, type: type, props: stringify_keys(props), children: children}
  end

  defp node(id, type, props) do
    node(id, type, props, [])
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  # ---------------------------------------------------------------------------
  # Layout widgets
  # ---------------------------------------------------------------------------

  @doc "Column layout. Props: spacing, padding, width, height, align_x."
  @spec column(String.t(), map(), list()) :: map()
  def column(id, props \\ %{}, children \\ []), do: node(id, "column", props, children)

  @doc "Row layout. Props: spacing, padding, width, height, align_y."
  @spec row(String.t(), map(), list()) :: map()
  def row(id, props \\ %{}, children \\ []), do: node(id, "row", props, children)

  @doc "Container layout. Props: padding, width, height, center, style."
  @spec container(String.t(), map(), list()) :: map()
  def container(id, props \\ %{}, children \\ []), do: node(id, "container", props, children)

  @doc "Scrollable container. Props: width, height, direction."
  @spec scrollable(String.t(), map(), list()) :: map()
  def scrollable(id, props \\ %{}, children \\ []), do: node(id, "scrollable", props, children)

  @doc "Stack layout. Props: width, height."
  @spec stack(String.t(), map(), list()) :: map()
  def stack(id, props \\ %{}, children \\ []), do: node(id, "stack", props, children)

  @doc "Empty space. Props: width, height."
  @spec space(String.t(), map()) :: map()
  def space(id, props \\ %{}), do: node(id, "space", props)

  @doc "Grid layout. Props: column_count, column_width, row_height, spacing, padding, width, height."
  @spec grid(String.t(), map(), list()) :: map()
  def grid(id, props \\ %{}, children \\ []), do: node(id, "grid", props, children)

  @doc "Pin layout for absolute positioning. Props: width, height."
  @spec pin(String.t(), map(), list()) :: map()
  def pin(id, props \\ %{}, children \\ []), do: node(id, "pin", props, children)

  @doc "Floating overlay layout. Props: width, height."
  @spec float_widget(String.t(), map(), list()) :: map()
  def float_widget(id, props \\ %{}, children \\ []), do: node(id, "float", props, children)

  @doc "Responsive layout that adapts to available size. Props: width, height."
  @spec responsive(String.t(), map(), list()) :: map()
  def responsive(id, props \\ %{}, children \\ []), do: node(id, "responsive", props, children)

  @doc "Per-subtree theme override. Props: theme (name string or custom palette map)."
  @spec themer(String.t(), map(), list()) :: map()
  def themer(id, props \\ %{}, children \\ []), do: node(id, "themer", props, children)

  @doc "Keyed column for efficient list diffing. Props: spacing, padding, width, height, align_x."
  @spec keyed_column(String.t(), map(), list()) :: map()
  def keyed_column(id, props \\ %{}, children \\ []), do: node(id, "keyed_column", props, children)

  # ---------------------------------------------------------------------------
  # Input widgets
  # ---------------------------------------------------------------------------

  @doc "Button. Props: label, style, width, height."
  @spec button(String.t(), map()) :: map()
  def button(id, props \\ %{}), do: node(id, "button", props)

  @doc "Text input field. Props: value, placeholder, padding, width, size, on_submit."
  @spec text_input(String.t(), map()) :: map()
  def text_input(id, props \\ %{}), do: node(id, "text_input", props)

  @doc "Checkbox. Props: checked/is_checked, label, spacing, width."
  @spec checkbox(String.t(), map()) :: map()
  def checkbox(id, props \\ %{}), do: node(id, "checkbox", props)

  @doc "Toggler. Props: is_toggled, label, spacing, width."
  @spec toggler(String.t(), map()) :: map()
  def toggler(id, props \\ %{}), do: node(id, "toggler", props)

  @doc "Radio button. Props: value, selected, label, group, spacing, width."
  @spec radio(String.t(), map()) :: map()
  def radio(id, props \\ %{}), do: node(id, "radio", props)

  @doc "Slider. Props: range, value, step, width."
  @spec slider(String.t(), map()) :: map()
  def slider(id, props \\ %{}), do: node(id, "slider", props)

  @doc "Vertical slider. Props: range, value, step, height."
  @spec vertical_slider(String.t(), map()) :: map()
  def vertical_slider(id, props \\ %{}), do: node(id, "vertical_slider", props)

  @doc "Pick list (dropdown). Props: options, selected, placeholder, width."
  @spec pick_list(String.t(), map()) :: map()
  def pick_list(id, props \\ %{}), do: node(id, "pick_list", props)

  @doc "Combo box. Props: options, value, placeholder, width."
  @spec combo_box(String.t(), map()) :: map()
  def combo_box(id, props \\ %{}), do: node(id, "combo_box", props)

  @doc "Text editor. Props: content, width, height."
  @spec text_editor(String.t(), map()) :: map()
  def text_editor(id, props \\ %{}), do: node(id, "text_editor", props)

  # ---------------------------------------------------------------------------
  # Interactive widgets
  # ---------------------------------------------------------------------------

  @doc "Mouse area for capturing mouse events on children. Props: on_press, on_release, on_right_press, on_middle_press, on_enter, on_exit."
  @spec mouse_area(String.t(), map(), list()) :: map()
  def mouse_area(id, props \\ %{}, children \\ []), do: node(id, "mouse_area", props, children)

  @doc "Sensor for detecting layout changes. Props: on_resize, on_appear."
  @spec sensor(String.t(), map(), list()) :: map()
  def sensor(id, props \\ %{}, children \\ []), do: node(id, "sensor", props, children)

  @doc "Pane grid for resizable tiled panes. Props: spacing, min_size, on_resize, on_drag, on_click. Children are pane content keyed by ID."
  @spec pane_grid(String.t(), map(), list()) :: map()
  def pane_grid(id, props \\ %{}, children \\ []), do: node(id, "pane_grid", props, children)

  # ---------------------------------------------------------------------------
  # Display widgets
  # ---------------------------------------------------------------------------

  @doc "Text display. Props: content, size, color, font."
  @spec text(String.t(), map()) :: map()
  def text(id, props \\ %{}), do: node(id, "text", props)

  @doc "Horizontal or vertical rule. Props: height, direction."
  @spec rule(String.t(), map()) :: map()
  def rule(id, props \\ %{}), do: node(id, "rule", props)

  @doc "Progress bar. Props: range, value, width, height."
  @spec progress_bar(String.t(), map()) :: map()
  def progress_bar(id, props \\ %{}), do: node(id, "progress_bar", props)

  @doc """
  Tooltip wrapping child content. The `tip` argument becomes the `tip`
  prop. Additional props: position, gap.
  """
  @spec tooltip(String.t(), map(), list(), String.t()) :: map()
  def tooltip(id, props \\ %{}, children \\ [], tip) do
    merged = Map.put(props, :tip, tip)
    node(id, "tooltip", merged, children)
  end

  @doc "Image display. Props: source, width, height, content_fit."
  @spec image(String.t(), map()) :: map()
  def image(id, props \\ %{}), do: node(id, "image", props)

  @doc "SVG display. Props: source, width, height, content_fit."
  @spec svg(String.t(), map()) :: map()
  def svg(id, props \\ %{}), do: node(id, "svg", props)

  @doc "Markdown display. Props: content, width, text_size, h1_size, h2_size, h3_size, code_size, spacing."
  @spec markdown(String.t(), map()) :: map()
  def markdown(id, props \\ %{}), do: node(id, "markdown", props)

  @doc "Rich text display with styled spans. Props: spans (list of span descriptors), width."
  @spec rich_text(String.t(), map()) :: map()
  def rich_text(id, props \\ %{}), do: node(id, "rich_text", props)

  # ---------------------------------------------------------------------------
  # Canvas & data widgets
  # ---------------------------------------------------------------------------

  @doc "Canvas for drawing shapes. Props: shapes (list), width, height, background, interactive (bool), on_press, on_release, on_move, on_scroll."
  @spec canvas(String.t(), map()) :: map()
  def canvas(id, props \\ %{}), do: node(id, "canvas", props)

  @doc "Data table. Props: columns (list of %{key, label, width}), rows (list of maps), header (bool), sortable (bool)."
  @spec table(String.t(), map()) :: map()
  def table(id, props \\ %{}), do: node(id, "table", props)
end
