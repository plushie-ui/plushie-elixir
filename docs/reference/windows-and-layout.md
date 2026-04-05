# Windows and Layout

Every Plushie app starts with a window. Inside it, you compose layout
containers to arrange widgets on screen. This reference covers windows,
sizing, spacing, alignment, and all layout containers.

## Window

`Plushie.Widget.Window`

The top-level container. Every `view/1` must return one or more window
nodes. Windows map to native OS windows, each with its own title bar,
size, position, and optional theme.

```elixir
window "main", title: "My App", theme: :dark do
  column width: :fill, height: :fill do
    # app content
  end
end
```

### Window props

| Prop | Type | Default | Purpose |
|---|---|---|---|
| `title` | string | *n/a* | Title bar text |
| `size` | `{w, h}` | *n/a* | Initial size in pixels |
| `width` | number | *n/a* | Width (alternative to `size`) |
| `height` | number | *n/a* | Height (alternative to `size`) |
| `position` | `{x, y}` | *n/a* | Initial position |
| `min_size` | `{w, h}` | *n/a* | Minimum dimensions |
| `max_size` | `{w, h}` | *n/a* | Maximum dimensions |
| `maximized` | boolean | `false` | Start maximized |
| `fullscreen` | boolean | `false` | Start fullscreen |
| `visible` | boolean | `true` | Whether window is visible |
| `resizable` | boolean | `true` | Allow resizing |
| `closeable` | boolean | `true` | Show close button |
| `minimizable` | boolean | `true` | Allow minimizing |
| `decorations` | boolean | `true` | Show title bar and borders |
| `transparent` | boolean | `false` | Transparent window background |
| `blur` | boolean | `false` | Blur window background |
| `level` | atom | `:normal` | Stacking level (`:normal`, `:always_on_top`, `:always_on_bottom`) |
| `exit_on_close_request` | boolean | `true` | Whether closing exits the app |
| `scale_factor` | number | *n/a* | DPI scale override |
| `theme` | atom or map | *n/a* | Per-window theme (`:dark`, `:nord`, `:system`, or custom) |
| `a11y` | map | *n/a* | Accessibility overrides |

### Multi-window

Return multiple windows from `view/1`:

```elixir
def view(model) do
  [
    window "main", title: "App" do
      main_content(model)
    end,

    if model.show_settings do
      window "settings", title: "Settings", exit_on_close_request: false do
        settings_content(model)
      end
    end
  ]
end
```

`exit_on_close_request: false` on secondary windows means closing them
removes the window without exiting the app. Window IDs must be stable
strings. A changing ID causes a close and re-open.

See [App Lifecycle](app-lifecycle.md#daemon-mode) for daemon mode
(keep running after all windows close) and
[App Lifecycle](app-lifecycle.md#window-sync) for how the runtime
syncs window state.

## Sizing

Every widget has `width:` and `height:` props that control how much
space it occupies. Four value forms are supported:

| Value | Behaviour |
|---|---|
| `:shrink` | Take only as much space as the content needs. This is the default for most widgets. |
| `:fill` | Take all available space in the parent container. |
| `{:fill_portion, n}` | Take a proportional share of available space relative to siblings. |
| number | Exact pixel size. |

### How fill_portion works

When multiple siblings use `:fill` or `{:fill_portion, n}`, the
available space (after fixed-size and `:shrink` siblings are measured)
is divided proportionally. The numbers are relative ratios:

```elixir
row width: :fill do
  container "sidebar", width: {:fill_portion, 1} do ... end
  container "main", width: {:fill_portion, 3} do ... end
end
```

Sidebar gets 1/4 of the width, main gets 3/4. `{:fill_portion, 1}` and
`{:fill_portion, 3}` is the same ratio as `{:fill_portion, 2}` and
`{:fill_portion, 6}`.

`:fill` is shorthand for `{:fill_portion, 1}`. Two `:fill` siblings
split space equally.

### Sizing resolution order

The layout engine processes siblings in this order:

1. **Fixed-size** children (explicit pixel values) are measured first
2. **`:shrink`** children are measured at their intrinsic content size
3. **`:fill` / `{:fill_portion, n}`** children divide the remaining space

This means a fixed-width sidebar always gets its pixels, a shrink button
takes what it needs, and fill containers expand to use whatever is left.

### Constraints

`max_width:` and `max_height:` set upper bounds. A `:fill` child with
`max_width: 600` expands to fill available space but never exceeds 600
pixels. These are available on `column`, `row`, `container`, and
`keyed_column`.

## Padding

`Plushie.Type.Padding`

Padding is the space between a container's edges and its content.
Multiple input forms are accepted:

| Input | Result |
|---|---|
| `16` | 16px on all sides |
| `{8, 16}` | 8px top/bottom, 16px left/right |
| `%{top: 16, bottom: 8}` | Per-side (unset sides default to 0) |
| Do-block | `padding do top 16; bottom 8 end` |

Padding reduces the space available to children. A 200px-wide container
with `padding: 16` has 168px of content space.

## Spacing

Spacing is the gap between sibling children inside a container. Set via
the `spacing:` prop on `column`, `row`, `grid`, and `keyed_column`:

```elixir
column spacing: 12 do
  text("a", "First")    # 12px gap below
  text("b", "Second")   # 12px gap below
  text("c", "Third")    # no gap after last child
end
```

Spacing applies between children, not before the first or after the
last. It does not interact with padding; they are independent.

## Alignment

`Plushie.Type.Alignment`

Alignment controls how children are positioned within a container's
available space.

| Prop | Container | Values |
|---|---|---|
| `align_x:` | `column`, `container` | `:left` (default), `:center`, `:right` |
| `align_y:` | `row`, `container` | `:top` (default), `:center`, `:bottom` |

`column` aligns children horizontally (they already stack vertically).
`row` aligns children vertically (they already flow horizontally).
`container` supports both axes since it has a single child.

The `center: true` shorthand on `container` sets both `align_x: :center`
and `align_y: :center`.

## Layout containers

### column

Arranges children vertically, top to bottom.

| Prop | Type | Default | Purpose |
|---|---|---|---|
| `spacing` | number | `0` | Vertical gap between children |
| `padding` | Padding | `0` | Inner padding |
| `width` | Length | `:shrink` | Column width |
| `height` | Length | `:shrink` | Column height |
| `max_width` | number | *n/a* | Maximum width in pixels |
| `align_x` | `:left \| :center \| :right` | `:left` | Horizontal alignment of children |
| `clip` | boolean | `false` | Clip children that overflow |
| `wrap` | boolean | `false` | Wrap children to next column on overflow |
| `a11y` | map | *n/a* | Accessibility overrides. See [Accessibility](accessibility.md). |

`wrap: true` enables multi-column flow layout. When children exceed the
column height, they wrap to a new column to the right (like CSS
`flex-wrap`).

### row

Arranges children horizontally, left to right.

| Prop | Type | Default | Purpose |
|---|---|---|---|
| `spacing` | number | `0` | Horizontal gap between children |
| `padding` | Padding | `0` | Inner padding |
| `width` | Length | `:shrink` | Row width |
| `height` | Length | `:shrink` | Row height |
| `max_width` | number | *n/a* | Maximum width in pixels |
| `align_y` | `:top \| :center \| :bottom` | `:top` | Vertical alignment of children |
| `clip` | boolean | `false` | Clip children that overflow |
| `wrap` | boolean | `false` | Wrap children to next row on overflow |
| `a11y` | map | *n/a* | Accessibility overrides. See [Accessibility](accessibility.md). |

`wrap: true` enables multi-row flow layout. Useful for tag clouds,
toolbar buttons, or any content that should reflow at different widths.

### container

Single-child wrapper for styling, scoping, and alignment.

| Prop | Type | Default | Purpose |
|---|---|---|---|
| `padding` | Padding | `0` | Inner padding |
| `width` | Length | `:shrink` | Container width |
| `height` | Length | `:shrink` | Container height |
| `max_width` | number | *n/a* | Maximum width |
| `max_height` | number | *n/a* | Maximum height |
| `align_x` | `:left \| :center \| :right` | `:left` | Horizontal child alignment |
| `align_y` | `:top \| :center \| :bottom` | `:top` | Vertical child alignment |
| `center` | boolean | `false` | Center child in both axes |
| `clip` | boolean | `false` | Clip child that overflows |
| `background` | Color or Gradient | *n/a* | Background fill |
| `color` | Color | *n/a* | Text colour override |
| `border` | Border | *n/a* | Border specification |
| `shadow` | Shadow | *n/a* | Drop shadow |
| `style` | atom or StyleMap | *n/a* | Named preset or full style map |
| `a11y` | map | *n/a* | Accessibility overrides. See [Accessibility](accessibility.md). |

Container style presets: `:transparent`, `:rounded_box`, `:bordered_box`,
`:dark`, `:primary`, `:secondary`, `:success`, `:danger`, `:warning`.

Container serves three roles: **styling** (background, border, shadow),
**scoping** (named containers create ID scopes for their children; see
[Scoped IDs](scoped-ids.md)), and **alignment** (positioning a child
within available space).

### scrollable

Adds scroll bars when content overflows. Requires an explicit string ID
because the renderer tracks scroll position as internal state.

| Prop | Type | Default | Purpose |
|---|---|---|---|
| `width` | Length | `:shrink` | Scrollable area width |
| `height` | Length | `:shrink` | Scrollable area height |
| `direction` | `:vertical \| :horizontal \| :both` | `:vertical` | Scroll direction |
| `spacing` | number | *n/a* | Gap between scrollbar and content |
| `scrollbar_width` | number | *n/a* | Scrollbar track width |
| `scrollbar_margin` | number | *n/a* | Margin around scrollbar |
| `scroller_width` | number | *n/a* | Scroller handle width |
| `scrollbar_color` | Color | *n/a* | Scrollbar track colour |
| `scroller_color` | Color | *n/a* | Scroller thumb colour |
| `anchor` | `:start \| :end` | `:start` | Scroll anchor position |
| `on_scroll` | boolean | `false` | Emit scroll events with viewport data |
| `auto_scroll` | boolean | `false` | Auto-scroll to show new content |
| `a11y` | map | *n/a* | Accessibility overrides. See [Accessibility](accessibility.md). |

`auto_scroll: true` is useful for chat-style interfaces where new
messages should scroll into view. `anchor: :end` starts scrolled to
the bottom.

When `on_scroll: true`, scroll events include viewport metrics:
`absolute_x`, `absolute_y`, `relative_x`, `relative_y`, `bounds`
(visible area as `{width, height}`), and `content_bounds` (full content
as `{width, height}`).

### keyed_column

Like `column`, but uses each child's ID as a diffing key for the
renderer. Same props as column minus `align_x`, `clip`, and `wrap`.

Use `keyed_column` for dynamic lists where items are added, removed,
or reordered. A plain `column` diffs by position index, so adding an
item at the top shifts all widget state down by one. `keyed_column`
matches by ID, preserving widget state (focus, scroll position, cursor)
regardless of position changes.

### stack

Layers children on top of each other (z-axis). First child is at the
back, last child is at the front.

| Prop | Type | Default | Purpose |
|---|---|---|---|
| `width` | Length | `:shrink` | Stack width |
| `height` | Length | `:shrink` | Stack height |
| `clip` | boolean | `false` | Clip children that overflow |
| `a11y` | map | *n/a* | Accessibility overrides. See [Accessibility](accessibility.md). |

Use for overlays, badges, loading spinners, or any situation where
elements need to be layered.

### grid

Arranges children in a grid layout.

| Prop | Type | Default | Purpose |
|---|---|---|---|
| `columns` | pos_integer | `1` | Number of columns |
| `spacing` | number | `0` | Gap between cells |
| `width` | number | *n/a* | Grid width in pixels |
| `height` | number | *n/a* | Grid height in pixels |
| `column_width` | Length | *n/a* | Width of each column |
| `row_height` | Length | *n/a* | Height of each row |
| `fluid` | number | *n/a* | Max cell width for fluid auto-wrap mode |
| `a11y` | map | *n/a* | Accessibility overrides. See [Accessibility](accessibility.md). |

Two modes: **fixed columns** (`columns: 3`) and **fluid** (`fluid: 200`).
In fluid mode, columns auto-wrap based on available width. The number
adjusts to fit as many cells of the specified max width as possible.

### pin

Positions a child at exact pixel coordinates within a container.

| Prop | Type | Default | Purpose |
|---|---|---|---|
| `x` | number | `0` | X position in pixels |
| `y` | number | `0` | Y position in pixels |
| `width` | Length | `:shrink` | Pin container width |
| `height` | Length | `:shrink` | Pin container height |
| `a11y` | map | *n/a* | Accessibility overrides. See [Accessibility](accessibility.md). |

Pin does not participate in flow layout. The child is positioned
absolutely. Useful for tooltips, popovers, or custom positioning.

### floating

Applies translate and scale transforms to a child.

| Prop | Type | Default | Purpose |
|---|---|---|---|
| `translate_x` | number | `0` | Horizontal translation in pixels |
| `translate_y` | number | `0` | Vertical translation in pixels |
| `scale` | number | *n/a* | Scale factor |
| `width` | Length | *n/a* | Container width |
| `height` | Length | *n/a* | Container height |
| `a11y` | map | *n/a* | Accessibility overrides. See [Accessibility](accessibility.md). |

Unlike `pin`, floating applies visual transforms without removing the
child from flow layout. The child still occupies its original space;
the transform is visual only.

### responsive

Adapts layout based on available size by emitting resize events.

| Prop | Type | Default | Purpose |
|---|---|---|---|
| `width` | Length | `:fill` | Container width |
| `height` | Length | `:fill` | Container height |
| `a11y` | map | *n/a* | Accessibility overrides. See [Accessibility](accessibility.md). |

When the responsive container's size changes, it emits
`%WidgetEvent{type: :resize, value: %{width: w, height: h}}`.
Use this in `update/2` to store the measured size and adjust your
`view/1` based on it (for example, switching from a sidebar layout to
a stacked layout below a certain width).

### space

Invisible spacer widget. No children, no visual output.

| Prop | Type | Default | Purpose |
|---|---|---|---|
| `width` | Length | `:shrink` | Space width |
| `height` | Length | `:shrink` | Space height |
| `a11y` | map | *n/a* | Accessibility overrides. See [Accessibility](accessibility.md). |

Use for explicit gaps, alignment tricks, or pushing siblings apart in
a row or column.

### pane_grid

Resizable tiled panes with split, close, swap, and drag. Requires an
explicit ID (holds renderer-side state for pane sizes).

| Prop | Type | Default | Purpose |
|---|---|---|---|
| `spacing` | number | `2` | Space between panes |
| `width` | Length | `:fill` | Grid width |
| `height` | Length | `:fill` | Grid height |
| `min_size` | number | `10` | Minimum pane size in pixels |
| `leeway` | number | `min_size` | Grabbable area around dividers |
| `divider_color` | Color | *n/a* | Divider colour |
| `divider_width` | number | *n/a* | Divider thickness |
| `a11y` | map | *n/a* | Accessibility overrides. See [Accessibility](accessibility.md). |

Pane grid emits these events:

| Event type | Data | Description |
|---|---|---|
| `:pane_clicked` | `pane` | Pane selected |
| `:pane_resized` | `split`, `ratio` | Divider moved |
| `:pane_dragged` | `pane`, `target`, `action`, `region`, `edge` | Pane drag (picked/dropped/canceled) |
| `:pane_focus_cycle` | *n/a* | F6/Shift+F6 focus cycling |

Manage pane layout with commands: `Command.pane_split/4`,
`Command.pane_close/2`, `Command.pane_swap/3`,
`Command.pane_maximize/2`, `Command.pane_restore/1`.

## Composition patterns

### Sidebar + content

```elixir
row width: :fill, height: :fill do
  column width: 200, height: :fill, padding: 8 do
    # Fixed-width sidebar
  end
  container "main", width: :fill, height: :fill, padding: 16 do
    # Content fills remaining space
  end
end
```

### Header / body / footer

```elixir
column width: :fill, height: :fill, spacing: 0 do
  row padding: 8 do
    # Header (shrinks to content)
  end
  container "body", width: :fill, height: :fill do
    # Body (fills remaining space)
  end
  row padding: 8 do
    # Footer (shrinks to content)
  end
end
```

### Centred content

```elixir
container width: :fill, height: :fill, center: true do
  text("msg", "Centred in both axes")
end
```

### Scrollable list

```elixir
scrollable "items", height: 400 do
  keyed_column spacing: 4 do
    for item <- model.items do
      container item.id, padding: 8 do
        text(item.id <> "-name", item.name)
      end
    end
  end
end
```

### Overlay / badge

```elixir
stack do
  container width: :fill, height: :fill do
    # Main content underneath
  end
  pin x: 10, y: 10 do
    text("badge", "NEW", size: 10)
  end
end
```

## See also

- [Layout guide](../guides/07-layout.md) - sizing, spacing, and
  alignment applied to the pad
- [Styling reference](themes-and-styling.md) - Border, Shadow, and background
  for containers
- [Scoped IDs reference](scoped-ids.md) - how named containers create
  ID scopes
- [Built-in Widgets reference](built-in-widgets.md) - full widget
  catalog including non-layout widgets
- `Plushie.Type.Length` - Length type encoding
- `Plushie.Type.Padding` - Padding normalisation and encoding
- `Plushie.Type.Alignment` - alignment value encoding
