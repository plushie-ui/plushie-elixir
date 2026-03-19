# Toddy Examples

Eight example apps demonstrating Toddy's features from minimal to complex.
Run any example with:

```sh
mix toddy.gui <Name>
```

In dev mode, file watching is enabled by default. Edit an example
while the GUI is running and the window updates instantly -- a good
way to experiment with the API.

## Examples

### Counter

**File:** `counter.ex`

Minimal Elm-architecture example. Two buttons increment and decrement a count.
Start here to understand `init/1`, `update/2`, and `view/1`.

```sh
mix toddy.gui Counter
```

### Todo

**File:** `todo.ex`

Todo list with text input, checkboxes, filtering (all/active/completed), and
delete. Demonstrates `text_input` with `on_submit`, `checkbox` with dynamic
IDs, `scrollable` layout, and pattern matching on parameterized event IDs
like `"todo:#{id}"`.

```sh
mix toddy.gui Todo
```

### Notes

**File:** `notes.ex`

Notes app combining all five state helpers: `Toddy.State` (change tracking),
`Toddy.Undo` (undo/redo for title and body editing), `Toddy.Selection`
(multi-select in list view), `Toddy.Route` (stack-based `/list` and `/edit`
navigation), and `Toddy.Data` (search/query across note fields). Shows how
to compose multiple state helpers in a single model.

```sh
mix toddy.gui Notes
```

### Clock

**File:** `clock.ex`

Displays the current UTC time, updated every second. Demonstrates
`Toddy.Subscription.every/2` for timer-based subscriptions. The `subscribe/1`
callback returns a timer that delivers `{:tick, timestamp}` events.

```sh
mix toddy.gui Clock
```

### Shortcuts

**File:** `shortcuts.ex`

Logs keyboard events to a scrollable list. Demonstrates
`Toddy.Subscription.on_key_press/1` for global keyboard handling. Shows
modifier key detection (Ctrl, Alt, Shift, Super) and the `Toddy.Event.Key`
struct.

```sh
mix toddy.gui Shortcuts
```

### AsyncFetch

**File:** `async_fetch.ex`

Button that triggers simulated background work. Demonstrates
`Toddy.Command.async/2` for running expensive operations off the main update
loop. Shows the `{model, command}` return form from `update/2` and how async
results are delivered back as events.

```sh
mix toddy.gui AsyncFetch
```

### ColorPicker

**File:** `color_picker.ex`

HSV color picker built entirely with the canvas widget. A hue ring surrounds
a saturation/value square with drag interaction. Demonstrates canvas layers,
path commands, linear gradients with alpha, layer caching (four layers with
different invalidation patterns), and interactive canvas events
(press/move/release for drag). Uses `Toddy.Canvas.Shape` builder functions
and coordinate math for hit testing.

```sh
mix toddy.gui ColorPicker
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
mix toddy.gui Catalog
```
