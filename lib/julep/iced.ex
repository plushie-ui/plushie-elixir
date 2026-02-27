defmodule Julep.Iced do
  @moduledoc """
  Strict parity layer for iced widgets.

  Every function maps 1:1 to an iced widget and returns a plain node map:

      %{id: id, type: type_string, props: %{...}, children: [...]}

  No macro sugar, no auto-IDs -- just data. Props are accepted as atom-keyed
  maps for ergonomics and normalised to string keys in the output.

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

  @doc """
  Column layout -- arranges children vertically.

  ## Props

  - `spacing` (number) -- vertical space between children in pixels. Default: 0.
  - `padding` (number | map) -- padding inside the column. Accepts a uniform number
    or `%{top, right, bottom, left}` map. See `Julep.Iced.Padding`.
  - `width` (length) -- width of the column. Default: shrink. See `Julep.Iced.Length`.
  - `height` (length) -- height of the column. Default: shrink.
  - `max_width` (number) -- maximum width in pixels.
  - `align_x` (string) -- horizontal alignment of children: `"left"`, `"center"`, `"right"`.
  - `clip` (boolean) -- clip children that overflow. Default: false.
  - `wrap` (boolean) -- wrap children to next column when they overflow. Default: false.
  """
  @spec column(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def column(id, props \\ %{}, children \\ []), do: node(id, "column", props, children)

  @doc """
  Row layout -- arranges children horizontally.

  ## Props

  - `spacing` (number) -- horizontal space between children in pixels. Default: 0.
  - `padding` (number | map) -- padding inside the row. See `Julep.Iced.Padding`.
  - `width` (length) -- width of the row. Default: shrink. See `Julep.Iced.Length`.
  - `height` (length) -- height of the row. Default: shrink.
  - `align_y` (string) -- vertical alignment of children: `"top"`, `"center"`, `"bottom"`.
  - `clip` (boolean) -- clip children that overflow. Default: false.
  - `wrap` (boolean) -- wrap children to next row when they overflow. Default: false.
  """
  @spec row(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def row(id, props \\ %{}, children \\ []), do: node(id, "row", props, children)

  @doc """
  Container layout -- wraps a single child with padding, sizing, and styling.

  ## Props

  - `padding` (number | map) -- padding inside the container. See `Julep.Iced.Padding`.
  - `width` (length) -- container width. Default: shrink. See `Julep.Iced.Length`.
  - `height` (length) -- container height. Default: shrink.
  - `max_width` (number) -- maximum width in pixels.
  - `max_height` (number) -- maximum height in pixels.
  - `center` (boolean) -- center child in both axes. Default: false.
  - `clip` (boolean) -- clip child that overflows. Default: false.
  - `align_x` (string) -- horizontal alignment: `"left"`, `"center"`, `"right"`.
  - `align_y` (string) -- vertical alignment: `"top"`, `"center"`, `"bottom"`.
  - `background` (color | gradient) -- background fill. Accepts a hex color string,
    `%{r, g, b, a}` map, or a gradient map. See `Julep.Iced.Color`, `Julep.Iced.Gradient`.
  - `color` (color) -- text color override. See `Julep.Iced.Color`.
  - `border` (map) -- border specification: `%{color, width, radius}`. See `Julep.Iced.Border`.
  - `shadow` (map) -- shadow specification: `%{color, offset, blur_radius}`. See `Julep.Iced.Shadow`.
  - `style` (string) -- named style. One of: `"transparent"`, `"rounded_box"`,
    `"bordered_box"`, `"dark"`, `"primary"`, `"secondary"`, `"success"`,
    `"danger"`, `"warning"`. Overrides inline style props if both are set.
  """
  @spec container(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def container(id, props \\ %{}, children \\ []), do: node(id, "container", props, children)

  @doc """
  Scrollable container -- wraps child content in a scrollable viewport.

  ## Props

  - `width` (length) -- width of the scrollable area. Default: shrink. See `Julep.Iced.Length`.
  - `height` (length) -- height of the scrollable area. Default: shrink.
  - `direction` (string) -- scroll direction: `"vertical"` (default), `"horizontal"`, or `"both"`.
  - `spacing` (number) -- spacing between scrollbar and content.
  - `scrollbar_width` (number) -- width of the scrollbar track in pixels.
  - `scrollbar_margin` (number) -- margin around the scrollbar in pixels.
  - `scroller_width` (number) -- width of the scroller handle in pixels.
  - `id` (string) -- widget ID for programmatic scroll control via `Julep.Command`.
  - `anchor` (string) -- scroll anchor: `"start"` (default) or `"end"` / `"bottom"` / `"right"`.
  """
  @spec scrollable(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def scrollable(id, props \\ %{}, children \\ []), do: node(id, "scrollable", props, children)

  @doc """
  Stack layout -- layers children on top of each other.

  ## Props

  - `width` (length) -- stack width. Default: shrink. See `Julep.Iced.Length`.
  - `height` (length) -- stack height. Default: shrink.
  """
  @spec stack(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def stack(id, props \\ %{}, children \\ []), do: node(id, "stack", props, children)

  @doc """
  Empty space -- invisible spacer widget.

  ## Props

  - `width` (length) -- space width. Default: shrink. See `Julep.Iced.Length`.
  - `height` (length) -- space height. Default: shrink.
  """
  @spec space(id :: String.t(), props :: props()) :: ui_node()
  def space(id, props \\ %{}), do: node(id, "space", props)

  @doc """
  Grid layout -- arranges children in a fixed-column grid.

  ## Props

  - `columns` (integer) -- number of columns. Default: 1.
  - `spacing` (number) -- spacing between grid cells in pixels. Default: 0.
  - `width` (number) -- grid width in pixels.
  - `height` (number) -- grid height in pixels.
  """
  @spec grid(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def grid(id, props \\ %{}, children \\ []), do: node(id, "grid", props, children)

  @doc """
  Pin layout -- positions child at absolute coordinates.

  ## Props

  - `x` (number) -- x position in pixels. Default: 0.
  - `y` (number) -- y position in pixels. Default: 0.
  - `width` (length) -- pin container width. Default: shrink. See `Julep.Iced.Length`.
  - `height` (length) -- pin container height. Default: shrink.
  """
  @spec pin(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def pin(id, props \\ %{}, children \\ []), do: node(id, "pin", props, children)

  @doc """
  Floating overlay -- positions child with optional translation and scaling.

  ## Props

  - `translate_x` (number) -- horizontal translation in pixels. Default: 0.
  - `translate_y` (number) -- vertical translation in pixels. Default: 0.
  - `scale` (number) -- scale factor for the child content.
  """
  @spec float_widget(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def float_widget(id, props \\ %{}, children \\ []), do: node(id, "float", props, children)

  @doc """
  Responsive layout -- adapts to available size by reporting resize events.

  The renderer wraps child content in a sensor that sends `{:sensor_resize, id, w, h}`
  events so the Elixir app can adjust its view based on the measured size.

  ## Props

  - `width` (length) -- container width. Default: fill. See `Julep.Iced.Length`.
  - `height` (length) -- container height. Default: fill.
  """
  @spec responsive(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def responsive(id, props \\ %{}, children \\ []), do: node(id, "responsive", props, children)

  @doc """
  Per-subtree theme override -- applies a different theme to child widgets.

  ## Props

  - `theme` (string | map) -- a built-in theme name string (e.g. `"Dark"`, `"Nord"`)
    or a custom palette map. See `Julep.Iced.Theme`.
  """
  @spec themer(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def themer(id, props \\ %{}, children \\ []), do: node(id, "themer", props, children)

  @doc """
  Keyed column -- like `column/3` but uses child IDs as keys for efficient
  list diffing by the iced runtime. Use for dynamic lists where items are
  added, removed, or reordered.

  ## Props

  - `spacing` (number) -- vertical space between children in pixels. Default: 0.
  - `padding` (number | map) -- padding inside the column. See `Julep.Iced.Padding`.
  - `width` (length) -- column width. Default: shrink. See `Julep.Iced.Length`.
  - `height` (length) -- column height. Default: shrink.
  - `max_width` (number) -- maximum width in pixels.
  """
  @spec keyed_column(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def keyed_column(id, props \\ %{}, children \\ []),
    do: node(id, "keyed_column", props, children)

  # ---------------------------------------------------------------------------
  # Input widgets
  # ---------------------------------------------------------------------------

  @doc """
  Button -- clickable widget that emits `{:click, id}` events.

  The button can contain either a text label (via the `label` or `content` prop)
  or arbitrary child content (if children are provided, the first child is rendered).

  ## Props

  - `label` (string) -- text label displayed on the button. Also accepts `content` as an alias.
  - `style` (string) -- named style. One of: `"primary"` (default), `"secondary"`,
    `"success"`, `"warning"`, `"danger"`, `"text"`.
  - `width` (length) -- button width. Default: shrink. See `Julep.Iced.Length`.
  - `height` (length) -- button height. Default: shrink.
  - `padding` (number | map) -- internal padding. See `Julep.Iced.Padding`.
  - `clip` (boolean) -- clip child content that overflows. Default: false.
  - `disabled` (boolean) -- disable the button (no click events). Default: false.
  - `enabled` (boolean) -- inverse of disabled. Default: true.

  ## Events

  - `{:click, id}` -- emitted on press (unless disabled).
  """
  @spec button(id :: String.t(), props :: props()) :: ui_node()
  def button(id, props \\ %{}), do: node(id, "button", props)

  @doc """
  Text input field -- single-line editable text.

  Emits `{:input, id, value}` on every keystroke.

  ## Props

  - `value` (string) -- current text content. Required for controlled input.
  - `placeholder` (string) -- placeholder text shown when value is empty.
  - `padding` (number | map) -- internal padding. See `Julep.Iced.Padding`.
  - `width` (length) -- input width. Default: fill. See `Julep.Iced.Length`.
  - `size` (number) -- font size in pixels.
  - `font` (string | map) -- font specification. See `Julep.Iced.Font`.
  - `line_height` (number | map) -- line height. Number is a relative multiplier;
    map with `%{relative: n}` or `%{absolute: n}` for explicit control.
  - `align_x` (string) -- text horizontal alignment: `"left"`, `"center"`, `"right"`.
  - `on_submit` (any) -- when present (any truthy value), enables submit on Enter.
    Emits `{:submit, id, value}`.
  - `id` (string) -- widget ID for programmatic focus via `Julep.Command.focus/1`.
  - `style` (string) -- named style. Currently only `"default"`.
  - `secure` (boolean) -- mask input as password dots. Default: false.

  ## Events

  - `{:input, id, value}` -- emitted on every text change.
  - `{:submit, id, value}` -- emitted on Enter (requires `on_submit` prop).
  """
  @spec text_input(id :: String.t(), props :: props()) :: ui_node()
  def text_input(id, props \\ %{}), do: node(id, "text_input", props)

  @doc """
  Checkbox -- toggleable boolean input.

  ## Props

  - `checked` (boolean) -- whether the checkbox is checked. Default: false.
  - `label` (string) -- text label displayed next to the checkbox.
  - `spacing` (number) -- space between checkbox and label in pixels.
  - `width` (length) -- widget width. Default: shrink. See `Julep.Iced.Length`.
  - `size` (number) -- checkbox size in pixels.
  - `text_size` (number) -- label text size in pixels.
  - `font` (string | map) -- label font. See `Julep.Iced.Font`.
  - `line_height` (number | map) -- label line height.
  - `text_shaping` (string) -- text shaping: `"basic"`, `"advanced"`, or `"auto"`.
  - `wrapping` (string) -- text wrapping: `"none"`, `"word"`, `"glyph"`, `"word_or_glyph"`.
  - `style` (string) -- named style. One of: `"primary"` (default), `"secondary"`,
    `"success"`, `"danger"`.

  ## Events

  - `{:toggle, id, value}` -- emitted on toggle, `value` is the new boolean state.
  """
  @spec checkbox(id :: String.t(), props :: props()) :: ui_node()
  def checkbox(id, props \\ %{}), do: node(id, "checkbox", props)

  @doc """
  Toggler -- on/off switch.

  ## Props

  - `is_toggled` (boolean) -- whether the toggler is on. Default: false.
  - `label` (string) -- text label displayed next to the toggler.
  - `spacing` (number) -- space between toggler and label in pixels.
  - `width` (length) -- widget width. Default: shrink. See `Julep.Iced.Length`.
  - `size` (number) -- toggler size in pixels.
  - `text_size` (number) -- label text size in pixels.
  - `font` (string | map) -- label font. See `Julep.Iced.Font`.
  - `line_height` (number | map) -- label line height.
  - `text_shaping` (string) -- text shaping: `"basic"`, `"advanced"`, or `"auto"`.
  - `wrapping` (string) -- text wrapping: `"none"`, `"word"`, `"glyph"`, `"word_or_glyph"`.
  - `style` (string) -- named style. Currently only `"default"`.

  ## Events

  - `{:toggle, id, value}` -- emitted on toggle, `value` is the new boolean state.
  """
  @spec toggler(id :: String.t(), props :: props()) :: ui_node()
  def toggler(id, props \\ %{}), do: node(id, "toggler", props)

  @doc """
  Radio button -- one-of-many selection.

  All radios in a group should share the same `group` prop value. The
  `selected` prop should be set to the currently selected value across
  all radios in the group.

  ## Props

  - `value` (string) -- the value this radio represents.
  - `selected` (string) -- the currently selected value in the group.
  - `label` (string) -- label text. Defaults to `value` if omitted.
  - `group` (string) -- group identifier. All radios with the same group
    emit events with the group name as the event ID.
  - `spacing` (number) -- space between radio and label in pixels.
  - `width` (length) -- widget width. Default: shrink. See `Julep.Iced.Length`.
  - `size` (number) -- radio button size in pixels.
  - `text_size` (number) -- label text size in pixels.
  - `font` (string | map) -- label font. See `Julep.Iced.Font`.
  - `line_height` (number | map) -- label line height.
  - `text_shaping` (string) -- text shaping: `"basic"`, `"advanced"`, or `"auto"`.
  - `wrapping` (string) -- text wrapping: `"none"`, `"word"`, `"glyph"`, `"word_or_glyph"`.
  - `style` (string) -- named style. Currently only `"default"`.

  ## Events

  - `{:select, group_or_id, value}` -- emitted when this radio is selected.
    The first element is the `group` prop if set, otherwise the node ID.
  """
  @spec radio(id :: String.t(), props :: props()) :: ui_node()
  def radio(id, props \\ %{}), do: node(id, "radio", props)

  @doc """
  Slider -- horizontal range input.

  ## Props

  - `range` (list) -- `[min, max]` range as a two-element list. Default: `[0, 100]`.
  - `value` (number) -- current slider value. Defaults to range minimum.
  - `step` (number) -- step increment.
  - `width` (length) -- slider width. Default: fill. See `Julep.Iced.Length`.
  - `default` (number) -- default value (double-click resets to this).
  - `height` (number) -- slider track height in pixels.
  - `shift_step` (number) -- step increment when Shift is held.
  - `style` (string) -- named style. Currently only `"default"`.

  ## Events

  - `{:slide, id, value}` -- emitted continuously while dragging.
  - `{:slide_release, id, value}` -- emitted when drag ends.
  """
  @spec slider(id :: String.t(), props :: props()) :: ui_node()
  def slider(id, props \\ %{}), do: node(id, "slider", props)

  @doc """
  Vertical slider -- vertical range input.

  ## Props

  - `range` (list) -- `[min, max]` range as a two-element list. Default: `[0, 100]`.
  - `value` (number) -- current slider value. Defaults to range minimum.
  - `step` (number) -- step increment.
  - `height` (length) -- slider height. Default: fill. See `Julep.Iced.Length`.
  - `default` (number) -- default value (double-click resets to this).
  - `shift_step` (number) -- step increment when Shift is held.
  - `style` (string) -- named style. Currently only `"default"`.

  ## Events

  - `{:slide, id, value}` -- emitted continuously while dragging.
  - `{:slide_release, id, value}` -- emitted when drag ends.
  """
  @spec vertical_slider(id :: String.t(), props :: props()) :: ui_node()
  def vertical_slider(id, props \\ %{}), do: node(id, "vertical_slider", props)

  @doc """
  Pick list -- dropdown selection.

  ## Props

  - `options` (list of strings) -- the available choices.
  - `selected` (string | nil) -- the currently selected value.
  - `placeholder` (string) -- placeholder text when nothing is selected.
  - `width` (length) -- widget width. Default: shrink. See `Julep.Iced.Length`.
  - `padding` (number | map) -- internal padding. See `Julep.Iced.Padding`.
  - `text_size` (number) -- text size in pixels.
  - `font` (string | map) -- font specification. See `Julep.Iced.Font`.
  - `line_height` (number | map) -- text line height.
  - `menu_height` (number) -- maximum height of the dropdown menu in pixels.
  - `text_shaping` (string) -- text shaping: `"basic"`, `"advanced"`, or `"auto"`.
  - `style` (string) -- named style. Currently only `"default"`.

  ## Events

  - `{:select, id, value}` -- emitted when an option is selected.
  """
  @spec pick_list(id :: String.t(), props :: props()) :: ui_node()
  def pick_list(id, props \\ %{}), do: node(id, "pick_list", props)

  @doc """
  Combo box -- searchable dropdown with free-form text input.

  The renderer manages an internal `combo_box::State` cache keyed by node ID.
  Options changes trigger a state rebuild.

  ## Props

  - `options` (list of strings) -- the available choices.
  - `selected` (string | nil) -- the currently selected value.
  - `placeholder` (string) -- placeholder text.
  - `width` (length) -- widget width. Default: fill. See `Julep.Iced.Length`.
  - `padding` (number | map) -- internal padding. See `Julep.Iced.Padding`.
  - `size` (number) -- text size in pixels.
  - `font` (string | map) -- font specification. See `Julep.Iced.Font`.
  - `line_height` (number | map) -- text line height.
  - `menu_height` (number) -- maximum height of the dropdown menu in pixels.

  ## Events

  - `{:select, id, value}` -- emitted when an option is selected.
  - `{:input, id, value}` -- emitted on every text input change (for filtering).
  """
  @spec combo_box(id :: String.t(), props :: props()) :: ui_node()
  def combo_box(id, props \\ %{}), do: node(id, "combo_box", props)

  @doc """
  Text editor -- multi-line editable text area.

  The renderer manages an internal `text_editor::Content` cache keyed by
  node ID. The `content` prop seeds the initial content.

  ## Props

  - `content` (string) -- initial text content (used to seed the editor cache).
  - `placeholder` (string) -- placeholder text shown when editor is empty.
  - `width` (number) -- editor width in pixels (note: takes pixels, not length).
  - `height` (length) -- editor height. Default: shrink. See `Julep.Iced.Length`.
  - `min_height` (number) -- minimum height in pixels.
  - `max_height` (number) -- maximum height in pixels.
  - `font` (string | map) -- font specification. See `Julep.Iced.Font`.
  - `size` (number) -- font size in pixels.
  - `line_height` (number | map) -- line height.
  - `padding` (number) -- uniform padding in pixels.
  - `wrapping` (string) -- text wrapping: `"none"`, `"word"`, `"glyph"`, `"word_or_glyph"`.
  - `style` (string) -- named style. Currently only `"default"`.

  ## Events

  The editor emits text action events handled internally by the renderer.
  Content changes are reported back to Elixir via the protocol.
  """
  @spec text_editor(id :: String.t(), props :: props()) :: ui_node()
  def text_editor(id, props \\ %{}), do: node(id, "text_editor", props)

  # ---------------------------------------------------------------------------
  # Interactive widgets
  # ---------------------------------------------------------------------------

  @doc """
  Mouse area -- captures mouse events on child content.

  Wraps child content and emits click events for various mouse buttons.

  ## Props

  No additional props beyond children. Events are derived from the node ID.

  ## Events

  - `{:click, id}` -- left mouse button pressed.
  - `{:click, "id:release"}` -- left mouse button released.
  - `{:click, "id:middle"}` -- middle mouse button pressed.
  """
  @spec mouse_area(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def mouse_area(id, props \\ %{}, children \\ []), do: node(id, "mouse_area", props, children)

  @doc """
  Sensor -- detects visibility and size changes on child content.

  ## Props

  No additional props beyond children. Events are derived from the node ID.

  ## Events

  - `{:sensor_resize, id, width, height}` -- emitted on resize.
  - `{:sensor_resize, "id:show", width, height}` -- emitted when child becomes visible.
  - `{:click, "id:hide"}` -- emitted when child becomes hidden.
  """
  @spec sensor(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def sensor(id, props \\ %{}, children \\ []), do: node(id, "sensor", props, children)

  @doc """
  Pane grid -- resizable tiled panes.

  Children are keyed by their node ID and rendered as individual panes.
  The renderer manages an internal `pane_grid::State` cache.

  ## Props

  - `spacing` (number) -- space between panes in pixels. Default: 2.
  - `width` (length) -- grid width. Default: fill. See `Julep.Iced.Length`.
  - `height` (length) -- grid height. Default: fill.

  ## Events

  - `{:pane_clicked, id, pane}` -- emitted when a pane is clicked.
  - `{:pane_resized, id, split, ratio}` -- emitted when a split is resized.
  - `{:pane_dragged, id, pane, target}` -- emitted when a pane is dragged.
  """
  @spec pane_grid(id :: String.t(), props :: props(), children :: [ui_node()]) :: ui_node()
  def pane_grid(id, props \\ %{}, children \\ []), do: node(id, "pane_grid", props, children)

  # ---------------------------------------------------------------------------
  # Display widgets
  # ---------------------------------------------------------------------------

  @doc """
  Text display -- renders static text.

  ## Props

  - `content` (string) -- the text string to display.
  - `size` (number) -- font size in pixels.
  - `color` (color) -- text color. See `Julep.Iced.Color`.
  - `font` (string | map) -- font specification. See `Julep.Iced.Font`.
  - `width` (length) -- text widget width. See `Julep.Iced.Length`.
  - `height` (length) -- text widget height.
  - `line_height` (number | map) -- line height. Number is a relative multiplier;
    map with `%{relative: n}` or `%{absolute: n}` for explicit control.
  - `align_x` (string) -- horizontal text alignment: `"left"`, `"center"`, `"right"`.
  - `align_y` (string) -- vertical text alignment: `"top"`, `"center"`, `"bottom"`.
  - `wrapping` (string) -- text wrapping: `"none"`, `"word"`, `"glyph"`, `"word_or_glyph"`.
  - `style` (string) -- named style. One of: `"default"`, `"primary"`, `"secondary"`,
    `"success"`, `"danger"`, `"warning"`.
  """
  @spec text(id :: String.t(), props :: props()) :: ui_node()
  def text(id, props \\ %{}), do: node(id, "text", props)

  @doc """
  Horizontal or vertical rule (divider line).

  ## Props

  - `height` (number) -- line thickness in pixels (for horizontal rules). Default: 1.
  - `width` (number) -- line thickness in pixels (for vertical rules). Also accepts `thickness`.
  - `direction` (string) -- `"horizontal"` (default) or `"vertical"`.
  - `style` (string) -- named style: `"default"` or `"weak"`.
  """
  @spec rule(id :: String.t(), props :: props()) :: ui_node()
  def rule(id, props \\ %{}), do: node(id, "rule", props)

  @doc """
  Progress bar -- displays progress within a range.

  ## Props

  - `range` (list) -- `[min, max]` as a two-element list. Default: `[0, 100]`.
  - `value` (number) -- current progress value. Default: 0.
  - `width` (length) -- bar width. Default: fill. See `Julep.Iced.Length`.
  - `height` (length) -- bar height. Default: shrink.
  - `style` (string) -- named style. One of: `"primary"` (default), `"secondary"`,
    `"success"`, `"danger"`, `"warning"`.
  """
  @spec progress_bar(id :: String.t(), props :: props()) :: ui_node()
  def progress_bar(id, props \\ %{}), do: node(id, "progress_bar", props)

  @doc """
  Tooltip -- shows a popup tip over child content on hover.

  The `tip` argument becomes the `tip` prop.

  ## Props

  - `tip` (string) -- tooltip text (set automatically from the `tip` argument).
  - `position` (string) -- tooltip position: `"top"` (default), `"bottom"`,
    `"left"`, `"right"`, `"follow_cursor"` / `"follow"`.
  - `gap` (number) -- gap between tooltip and content in pixels.
  - `padding` (number) -- tooltip padding in pixels (uniform, not per-side).
  - `snap_within_viewport` (boolean) -- keep tooltip within viewport. Default: true.
  - `style` (string) -- named style (uses container styles). One of:
    `"transparent"`, `"rounded_box"`, `"bordered_box"`, `"dark"`, `"primary"`,
    `"secondary"`, `"success"`, `"danger"`, `"warning"`.
  """
  @spec tooltip(id :: String.t(), props :: props(), children :: [ui_node()], tip :: String.t()) ::
          ui_node()
  def tooltip(id, props \\ %{}, children \\ [], tip) do
    merged = Map.put(props, :tip, tip)
    node(id, "tooltip", merged, children)
  end

  @doc """
  Image display -- renders a raster image from a file path.

  ## Props

  - `source` (string) -- path to the image file.
  - `width` (length) -- image width. Default: shrink. See `Julep.Iced.Length`.
  - `height` (length) -- image height. Default: shrink.
  - `content_fit` (string) -- how the image fits its bounds: `"contain"`,
    `"cover"`, `"fill"`, `"none"`, `"scale_down"`.
  - `rotation` (number) -- rotation angle in degrees.
  - `opacity` (number) -- opacity from 0.0 (transparent) to 1.0 (opaque).
  - `border_radius` (number) -- corner radius in pixels.
  - `filter_method` (string) -- image filtering: `"linear"` (default) or `"nearest"`.
  - `expand` (boolean) -- expand image to fill available space.
  - `scale` (number) -- scale factor for the image.
  - `crop` (map) -- crop rectangle: `%{x, y, width, height}` (integer pixel values).
  """
  @spec image(id :: String.t(), props :: props()) :: ui_node()
  def image(id, props \\ %{}), do: node(id, "image", props)

  @doc """
  SVG display -- renders a vector image from a file path.

  ## Props

  - `source` (string) -- path to the SVG file.
  - `width` (length) -- SVG width. Default: shrink. See `Julep.Iced.Length`.
  - `height` (length) -- SVG height. Default: shrink.
  - `content_fit` (string) -- how the SVG fits its bounds: `"contain"`,
    `"cover"`, `"fill"`, `"none"`, `"scale_down"`.
  - `rotation` (number) -- rotation angle in degrees.
  - `opacity` (number) -- opacity from 0.0 (transparent) to 1.0 (opaque).
  """
  @spec svg(id :: String.t(), props :: props()) :: ui_node()
  def svg(id, props \\ %{}), do: node(id, "svg", props)

  @doc """
  Markdown display -- renders parsed markdown content.

  The renderer manages an internal `markdown::Items` cache keyed by node ID.

  ## Props

  - `content` (string) -- raw markdown text (used to seed the parser cache).
  - `width` (length) -- container width. See `Julep.Iced.Length`.
  - `text_size` (number) -- base text size in pixels.
  - `h1_size` (number) -- heading 1 size in pixels.
  - `h2_size` (number) -- heading 2 size in pixels.
  - `h3_size` (number) -- heading 3 size in pixels.
  - `code_size` (number) -- code block text size in pixels.
  - `spacing` (number) -- spacing between markdown elements in pixels.

  ## Events

  - Link clicks are forwarded as `MarkdownUrl` messages by the renderer.
  """
  @spec markdown(id :: String.t(), props :: props()) :: ui_node()
  def markdown(id, props \\ %{}), do: node(id, "markdown", props)

  @doc """
  Rich text display with individually styled spans.

  ## Props

  - `spans` (list of maps) -- list of span descriptors. Each span is a map with:
    - `text` (string) -- the text content.
    - `size` (number) -- font size in pixels.
    - `color` (color) -- text color. See `Julep.Iced.Color`.
    - `font` (string | map) -- font specification. See `Julep.Iced.Font`.
    - `link` (string) -- makes this span a clickable link.
  - `width` (length) -- widget width. Default: shrink. See `Julep.Iced.Length`.
  - `height` (length) -- widget height. Default: shrink.
  - `size` (number) -- default font size for all spans.
  - `font` (string | map) -- default font for all spans.
  - `color` (color) -- default text color for all spans.
  - `line_height` (number | map) -- line height.

  ## Events

  - `{:click, "id:link_value"}` -- emitted when a span link is clicked.
  """
  @spec rich_text(id :: String.t(), props :: props()) :: ui_node()
  def rich_text(id, props \\ %{}), do: node(id, "rich_text", props)

  # ---------------------------------------------------------------------------
  # Canvas & data widgets
  # ---------------------------------------------------------------------------

  @doc """
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
  @spec canvas(id :: String.t(), props :: props()) :: ui_node()
  def canvas(id, props \\ %{}), do: node(id, "canvas", props)

  @doc """
  Data table -- composite widget built from columns, rows, and scrollable containers.

  ## Props

  - `columns` (list of maps) -- column definitions. Each column is
    `%{key: string, label: string}`. The `key` maps to row data fields.
  - `rows` (list of maps) -- data rows. Each row is a map where keys
    correspond to column `key` values.
  - `header` (boolean) -- show header row. Default: true.
  - `separator` (boolean) -- show separator line below header. Default: true.
  - `width` (length) -- table width. Default: fill. See `Julep.Iced.Length`.
  - `padding` (number | map) -- table padding. See `Julep.Iced.Padding`.
  """
  @spec table(id :: String.t(), props :: props()) :: ui_node()
  def table(id, props \\ %{}), do: node(id, "table", props)
end
