# Layout

Toddy's layout model mirrors iced's. Understanding it is essential for
building UIs that size and position correctly.

## Length

Length controls how a widget claims space along an axis.

| Toddy value | Iced equivalent | Meaning |
|---|---|---|
| `:fill` | `Length::Fill` | Take all remaining space |
| `{:fill_portion, n}` | `Length::FillPortion(n)` | Proportional share of remaining space |
| `:shrink` | `Length::Shrink` | Use minimum/intrinsic size |
| `200` or `200.0` | `Length::Fixed(200.0)` | Exact pixel size |

```elixir
# Fill available width
column width: :fill do ... end

# Fixed width
container "sidebar", width: 250 do ... end

# Proportional: left takes 2/3, right takes 1/3
row do
  container "left", width: {:fill_portion, 2} do ... end
  container "right", width: {:fill_portion, 1} do ... end
end

# Shrink to content
button("save", "Save", width: :shrink)
```

### Default lengths

Most widgets default to `:shrink` for both width and height. Layout
containers (`column`, `row`) typically default to `:shrink` but grow to
accommodate their children.

## Padding

Padding is the space between a widget's boundary and its content.

| Toddy value | Meaning |
|---|---|
| `10` | Uniform: 10px on all sides |
| `{10, 20}` | Axis: 10px vertical, 20px horizontal |
| `%{top: 5, right: 10, bottom: 5, left: 10}` | Per-side |
| `0` | No padding |

```elixir
container "box", padding: 16 do ... end
container "box", padding: {8, 16} do ... end
container "box", padding: %{top: 0, right: 16, bottom: 8, left: 16} do ... end
```

Padding is accepted by `container`, `column`, `row`, `scrollable`,
`button`, `text_input`, and `text_editor`.

## Spacing

Spacing is the gap between children in a layout container.

```elixir
column spacing: 8 do
  text("First")
  text("Second")   # 8px gap between First and Second
  text("Third")    # 8px gap between Second and Third
end
```

Spacing is accepted by `column`, `row`, and `scrollable`.

## Alignment

Alignment controls how children are positioned within their parent along
the cross axis.

### align_x (horizontal alignment in a column)

| Value | Meaning |
|---|---|
| `:start` or `:left` | Left-aligned |
| `:center` | Centered |
| `:end` or `:right` | Right-aligned |

### align_y (vertical alignment in a row)

| Value | Meaning |
|---|---|
| `:start` or `:top` | Top-aligned |
| `:center` | Centered |
| `:end` or `:bottom` | Bottom-aligned |

```elixir
# Center children horizontally in a column
column align_x: :center do
  text("Centered")
  button("ok", "OK")
end

# Center a single child in a container
container "page", width: :fill, height: :fill, center: true do
  text("Dead center")
end
```

The `center: true` shorthand on `container` sets both `align_x: :center`
and `align_y: :center`.

## Layout containers

### column

Arranges children vertically (top to bottom).

```elixir
column id: "main", spacing: 16, padding: 20, width: :fill, align_x: :center do
  text("title", "Title", size: 24)
  text("subtitle", "Subtitle", size: 14)
end
```

Props: `spacing`, `padding`, `width`, `height`, `align_x`.

### row

Arranges children horizontally (left to right).

```elixir
row spacing: 8, align_y: :center do
  button("back", "<")
  text("Page 1 of 5")
  button("next", ">")
end
```

Props: `spacing`, `padding`, `width`, `height`, `align_y`, `wrap` (new
in toddy-iced -- wraps children to next line when they overflow).

### container

Wraps a single child with padding, alignment, and styling.

```elixir
container "card", padding: 16, style: :rounded_box, width: :fill do
  column do
    text("Card title")
    text("Card content")
  end
end
```

Props: `padding`, `width`, `height`, `align_x`, `align_y`, `center`,
`style`, `clip`.

### scrollable

Wraps content in a scrollable region.

```elixir
scrollable "list", height: 400, width: :fill do
  column spacing: 4 do
    for item <- items do
      text("item:#{item.id}", item.name)
    end
  end
end
```

Props: `width`, `height`, `direction` (`:vertical`, `:horizontal`,
`:both`), `spacing`.

### stack

Overlays children on top of each other (z-stacking). Later children
are on top.

```elixir
stack do
  image("bg", "background.png", width: :fill, height: :fill)
  container "overlay", width: :fill, height: :fill, center: true do
    text("overlay_text", "Overlaid text", size: 48)
  end
end
```

### space

Empty spacer. Takes up space without rendering anything.

```elixir
row do
  text("Left")
  space(width: :fill)  # pushes Right to the far right
  text("Right")
end
```

### grid

Arranges children in a grid layout (new in toddy-iced).

```elixir
grid "gallery", columns: 3, spacing: 8 do
  for item <- items do
    image("img:#{item.id}", item.url, width: :fill)
  end
end
```

## Common layout patterns

### Centered page

```elixir
container "page", width: :fill, height: :fill, center: true do
  column spacing: 16, align_x: :center do
    text("welcome", "Welcome", size: 32)
    button("start", "Get Started")
  end
end
```

### Sidebar + content

```elixir
row width: :fill, height: :fill do
  container "sidebar", width: 250, height: :fill, padding: 16 do
    nav_items(model)
  end
  container "content", width: :fill, height: :fill, padding: 16 do
    main_content(model)
  end
end
```

### Header + body + footer

```elixir
column width: :fill, height: :fill do
  container "header", width: :fill, padding: {8, 16} do
    header(model)
  end
  scrollable "body", width: :fill, height: :fill do
    body_content(model)
  end
  container "footer", width: :fill, padding: {8, 16} do
    footer(model)
  end
end
```
