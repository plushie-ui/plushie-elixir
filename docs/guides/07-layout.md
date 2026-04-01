# Layout

The pad from chapter 6 works, but the layout could use some attention. The
sidebar, editor, and preview panes are functional but not well-proportioned,
and the spacing is inconsistent. In this chapter we will fix that by learning
Plushie's layout system.

We will cover the layout containers you use every day, how sizing works, and
how spacing and alignment give your UI structure. The full container catalog
is in the [Built-in Widgets reference](../reference/built-in-widgets.md) --
here we focus on the ones that matter most.

## Layout containers

Plushie provides several layout containers. These are the workhorses:

### column

Stacks children vertically, top to bottom. Accepts `spacing:` (gap between
children), `padding:` (space inside the container), `width:`, `height:`, and
`align_x:`.

```elixir
column spacing: 12, padding: 16 do
  text("one", "First")
  text("two", "Second")
  text("three", "Third")
end
```

### row

Stacks children horizontally, left to right. Same props as `column`, plus
`align_y:`. Also supports `wrap: true` to flow children to the next line
when they overflow.

```elixir
row spacing: 8 do
  button("a", "Left")
  button("b", "Right")
end
```

### container

A single-child wrapper. Use it for styling (background, border, shadow),
for scoping (gives children a named ID scope), or for alignment and padding.

```elixir
container "card", padding: 16, background: "#f5f5f5" do
  text("content", "Inside the card")
end
```

### scrollable

Adds scroll bars when content overflows. Direction can be `:vertical`
(default), `:horizontal`, or `:both`. Set a fixed height to constrain the
scrollable area.

```elixir
scrollable "list", height: 300, direction: :vertical do
  column spacing: 4 do
    for item <- items do
      text(item.id, item.name)
    end
  end
end
```

`scrollable` supports `auto_scroll: true` for chat-like behaviour where
new content scrolls into view automatically.

## Sizing: fill, shrink, and fixed

Every widget has `width:` and `height:` props. They accept four kinds of
values:

| Value | Behaviour |
|---|---|
| `:fill` | Take all available space |
| `:shrink` | Take only as much as the content needs |
| `{:fill_portion, n}` | Take a proportional share of available space |
| number | Exact pixel size |

Most widgets default to `:shrink`. Layout containers grow to fit their
children.

### fill vs shrink

In a `row`, a `:fill` child takes all remaining space after `:shrink`
children are measured:

```elixir
row width: :fill do
  text_input("search", model.query, width: :fill, placeholder: "Search...")
  button("go", "Go")
end
```

The button shrinks to fit its label. The text input fills the rest.

### fill_portion

When multiple children use `:fill`, they share space equally. Use
`{:fill_portion, n}` for proportional splits:

```elixir
row width: :fill do
  container "sidebar", width: {:fill_portion, 1} do
    text("nav", "Sidebar")
  end
  container "main", width: {:fill_portion, 3} do
    text("content", "Main content")
  end
end
```

The sidebar gets 1/4 of the width, the main area gets 3/4. The numbers are
relative -- `{:fill_portion, 1}` and `{:fill_portion, 3}` is the same ratio
as `{:fill_portion, 2}` and `{:fill_portion, 6}`.

### Fixed size

A plain number means exact pixels:

```elixir
container "icon", width: 48, height: 48 do
  text("x", "X")
end
```

### Applying it: pad pane sizing

Our pad has three horizontal areas: sidebar, editor, and preview. We want
the sidebar to have a fixed width and the editor and preview to share the
remaining space equally:

```elixir
row width: :fill, height: :fill do
  # Fixed-width sidebar
  file_list(model)  # file_list sets width: 200 internally

  # Editor and preview share remaining space
  text_editor "editor", model.source do
    width {:fill_portion, 1}
    height :fill
    # ...
  end

  container "preview", width: {:fill_portion, 1}, height: :fill do
    # ...
  end
end
```

The sidebar takes 200 pixels. The editor and preview each get half of what
remains. Resize the window and they reflow proportionally.

## Spacing and padding

**Spacing** is the gap between sibling children inside a container:

```elixir
column spacing: 12 do
  text("a", "First")    # 12px gap below
  text("b", "Second")   # 12px gap below
  text("c", "Third")    # no gap after last child
end
```

**Padding** is the space between a container's edges and its content.
It accepts several forms:

```elixir
# Uniform: 16px on all sides
column padding: 16 do ... end

# Vertical/horizontal: 8px top/bottom, 16px left/right
column padding: {8, 16} do ... end

# Per-side via do-block:
column do
  padding do
    top 16
    bottom 8
    left 12
    right 12
  end
  text("hello", "Hello")
end
```

### Applying it: consistent pad spacing

Add consistent spacing throughout the pad:

```elixir
def view(model) do
  window "main", title: "Plushie Pad" do
    column width: :fill, height: :fill, spacing: 0 do
      # Main editing area
      row width: :fill, height: :fill, spacing: 0 do
        file_list(model)
        editor_pane(model)
        preview_pane(model)
      end

      # Toolbar
      row padding: {4, 8}, spacing: 8 do
        button("save", "Save")
        checkbox("auto-save", model.auto_save)
        text("auto-label", "Auto-save")
      end

      # Event log
      event_log(model)
    end
  end
end
```

Setting `spacing: 0` on the outer column and row eliminates unwanted gaps
between the main area, toolbar, and event log. Each section manages its own
internal spacing.

## Alignment

`align_x:` and `align_y:` control how children are positioned within a
container:

| `align_x` values | `align_y` values |
|---|---|
| `:left` (default), `:center`, `:right` | `:top` (default), `:center`, `:bottom` |

`:start` and `:end` are aliases for `:left`/`:top` and `:right`/`:bottom`.

```elixir
container width: :fill, height: 200, align_x: :center, align_y: :center do
  text("centered", "I am centred")
end
```

The shorthand `center: true` sets both axes at once:

```elixir
container width: :fill, height: :fill, center: true do
  text("centered", "Centred both ways")
end
```

## Other layout tools

These containers cover specialised needs. We will not use them in the pad
right now, but they are good to know about:

- **stack** -- layers children on top of each other (z-axis). Useful for
  overlays, badges, and loading spinners.
- **grid** -- CSS-like grid layout. Supports fixed column count (`columns: 3`)
  or fluid mode (`fluid: 200`) that auto-wraps.
- **pin** -- positions a child at exact `(x, y)` pixel coordinates.
- **floating** -- applies translate and scale transforms to a child.
- **responsive** -- emits `:sensor_resize` events when its size changes,
  enabling adaptive layouts.
- **space** -- explicit empty space with configurable width and height.

See the [Built-in Widgets reference](../reference/built-in-widgets.md) for
full details on each.

## Applying it: the polished pad layout

With these layout tools, refine the pad into a clean three-pane layout:

```elixir
def view(model) do
  window "main", title: "Plushie Pad" do
    column width: :fill, height: :fill, spacing: 0 do
      # Main area: sidebar + editor + preview
      row width: :fill, height: :fill, spacing: 0 do
        file_list(model)

        text_editor "editor", model.source do
          width {:fill_portion, 1}
          height :fill
          highlight_syntax "ex"
          font :monospace
        end

        container "preview", width: {:fill_portion, 1}, height: :fill, padding: 12 do
          # ...preview content...
        end
      end

      # Toolbar: compact, horizontal
      row padding: {4, 8}, spacing: 8 do
        button("save", "Save")
        checkbox("auto-save", model.auto_save)
        text("auto-label", "Auto-save")
      end

      # Event log: fixed height at the bottom
      scrollable "log", height: 100 do
        column spacing: 2, padding: {2, 8} do
          for {entry, i} <- Enum.with_index(model.event_log) do
            text("log-#{i}", entry, size: 11, font: :monospace)
          end
        end
      end
    end
  end
end
```

Key changes: `spacing: 0` on the outer containers eliminates unwanted gaps.
The toolbar uses `{4, 8}` padding (vertical, horizontal) for a compact look.
The event log has a smaller fixed height and tighter text. Each section
manages its own internal spacing.

## Try it

Write a layout experiment in your pad:

- Build a sidebar + content layout using `row` with a fixed-width `column`
  and a `:fill` container.
- Try different `{:fill_portion, n}` ratios. Give one pane `2` and another
  `1` to see the 2:1 split.
- Nest a `scrollable` inside a fixed-height container. Add enough items to
  trigger scrolling.
- Experiment with `align_x: :center` and `align_y: :bottom` on a container.
- Try `row` with `wrap: true` and enough buttons to overflow the width.

In the next chapter, we will style the pad with themes, colours, and
per-widget styling to make it look polished.
