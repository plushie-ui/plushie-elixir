# Plushie Examples

Example apps demonstrating Plushie's features from minimal to complex.
Run any example with:

```sh
mix plushie.gui <Name>
```

With hot reload enabled (`--watch` flag or `config :plushie,
code_reloader: true`), you can edit an example while the GUI is
running and the window updates instantly.

## DSL styles

The examples deliberately use different DSL styles so you can compare:

- **Keyword opts on the call line** -- `column(spacing: 8, padding: 16, children: [...])`
  Used by: Counter, Clock, Shortcuts, AsyncFetch, and most widget calls.
- **Container inline props** -- options declared inside the do-block, mixed with children.
  Used by: Todo, Notes, Catalog (Layout tab), RatePlushie.
- **Nested struct do-blocks** -- `border do width 1; rounded 8 end` for complex options.
  Used by: RatePlushie, ColorPicker app.
- **Canvas widget modules** -- reusable canvas components in `widgets/`.
  Used by: ColorPicker (ColorPickerWidget), RatePlushie (StarRating, ThemeToggle).

All styles are interchangeable. Pick whichever reads best for your use case.

## Examples

### Counter

**File:** `counter.ex`

Minimal Elm-architecture example. Two buttons increment and decrement a count.
Start here to understand `init/1`, `update/2`, and `view/1`.

```sh
mix plushie.gui Counter
```

### Todo

**File:** `todo.ex`

Todo list with text input, checkboxes, filtering (all/active/completed), and
delete. Demonstrates `text_input` with `on_submit`, `checkbox` with dynamic
IDs, `scrollable` layout, and pattern matching on parameterized event IDs
like `"todo:#{id}"`.

```sh
mix plushie.gui Todo
```

### Notes

**File:** `notes.ex`

Notes app combining all five state helpers: `Plushie.State` (change tracking),
`Plushie.Undo` (undo/redo for title and body editing), `Plushie.Selection`
(multi-select in list view), `Plushie.Route` (stack-based `/list` and `/edit`
navigation), and `Plushie.Data` (search/query across note fields). Shows how
to compose multiple state helpers in a single model.

```sh
mix plushie.gui Notes
```

### Clock

**File:** `clock.ex`

Displays the current UTC time, updated every second. Demonstrates
`Plushie.Subscription.every/2` for timer-based subscriptions. The `subscribe/1`
callback returns a timer that delivers `{:tick, timestamp}` events.

```sh
mix plushie.gui Clock
```

### Shortcuts

**File:** `shortcuts.ex`

Logs keyboard events to a scrollable list. Demonstrates
`Plushie.Subscription.on_key_press/1` for global keyboard handling. Shows
modifier key detection (Ctrl, Alt, Shift, Super) and the `Plushie.Event.Key`
struct.

```sh
mix plushie.gui Shortcuts
```

### AsyncFetch

**File:** `async_fetch.ex`

Button that triggers simulated background work. Demonstrates
`Plushie.Command.async/2` for running expensive operations off the main update
loop. Shows the `{model, command}` return form from `update/2` and how async
results are delivered back as events.

```sh
mix plushie.gui AsyncFetch
```

### ColorPicker

**Files:** `color_picker.ex`, `widgets/color_picker.ex`

HSV color picker using a custom canvas widget. A hue ring surrounds a
saturation/value square with drag interaction. The canvas drawing is
extracted into a reusable widget module (`widgets/color_picker.ex`), showing the
widget composition pattern. Demonstrates canvas layers with the do-block
DSL, path commands, linear gradients with alpha, layer caching, and
coordinate-based canvas events (press/move/release for continuous drag).

```sh
mix plushie.gui ColorPicker
```

### Gallery

**File:** `gallery.ex`

Interactive widget gallery demonstrating common widget types: buttons
(default, primary, danger, text styles), text input (with on_submit),
checkbox, toggler, slider, pick list, radio buttons, progress bar, and
styled text. A good starting point for exploring what widgets are
available and what events they produce.

```sh
mix plushie.gui Gallery
```

### Catalog

**File:** `catalog.ex`

Comprehensive widget catalog exercising every widget type across four
tabbed sections:

- **Layout:** column, row, container, scrollable, stack, grid, pin, float,
  responsive, keyed_column, themer, space
- **Input:** button, text_input, checkbox, toggler, radio, slider,
  vertical_slider, pick_list, combo_box, text_editor
- **Display:** text, rule, progress_bar, tooltip, image, svg, markdown,
  rich_text, canvas
- **Composite:** mouse_area, sensor, pane_grid, table, simulated tabs,
  modal, collapsible panel

Use this as a reference for widget props and event patterns.

```sh
mix plushie.gui Catalog
```

### RatePlushie

**Files:** `rate_plushie.ex`, `widgets/star_rating.ex`, `widgets/theme_toggle.ex`

App rating page with custom canvas-drawn widgets composed into a styled UI.
Features a 5-star rating built from path-drawn star geometry and an animated
emoji theme toggle -- a smiley that slides, rotates upside down, and becomes
a smiling imp when "Dark humor" is enabled. The entire page theme flips at
the animation midpoint.

Demonstrates: custom canvas widgets as reusable modules, the interactive
shape directive, canvas transforms for rotation, timer-based animation via
subscriptions, container inline props with nested do-blocks (border, padding),
theme-aware rendering, keyboard interaction (arrow keys adjust rating).

```sh
mix plushie.gui RatePlushie
```

## Multi-file demos

The [plushie-demos](https://github.com/plushie-ui/plushie-demos/tree/main/elixir)
repo has larger self-contained projects with their own mix.exs, tests,
and build configuration:

- [**gauge-demo**](https://github.com/plushie-ui/plushie-demos/tree/main/elixir/gauge-demo)
  -- native Rust widget with commands, widget events, and
  optimistic updates (Tier C)
- [**sparkline-dashboard**](https://github.com/plushie-ui/plushie-demos/tree/main/elixir/sparkline-dashboard)
  -- render-only Rust canvas widget with timer subscriptions and
  multiple widget instances (Tier A)
- [**notes**](https://github.com/plushie-ui/plushie-demos/tree/main/elixir/notes)
  -- pure Elixir widgets + state helpers (Route, Selection, Undo, Data)
  with keyboard shortcuts -- no Rust required
- [**collab**](https://github.com/plushie-ui/plushie-demos/tree/main/elixir/collab)
  -- collaborative scratchpad over native, WebSocket, and SSH transports
