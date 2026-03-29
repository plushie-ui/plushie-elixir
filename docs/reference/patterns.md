# Composition Patterns

Recipes for common UI patterns built from Plushie's built-in widgets. Each
pattern shows a brief description, when to use it, and complete code. These
are not special framework features -- they are compositions of existing
widgets.

## Navigation

### Tabs

Buttons in a row with conditional content. Track the active tab in the model.

```elixir
def view(model) do
  tabs = [:overview, :details, :settings]

  window "main", title: "Tabs" do
    column width: :fill do
      row spacing: 0 do
        for tab <- tabs do
          button(
            "tab:#{tab}",
            tab |> Atom.to_string() |> String.capitalize(),
            style: if(model.active_tab == tab, do: :primary, else: :text)
          )
        end
      end

      rule()

      case model.active_tab do
        :overview -> overview_content(model)
        :details -> details_content(model)
        :settings -> settings_content(model)
      end
    end
  end
end
```

Match tab clicks: `%WidgetEvent{type: :click, id: "tab:" <> tab_name}`.

### Sidebar navigation

A fixed-width column alongside the main content:

```elixir
row width: :fill, height: :fill do
  column width: 200, height: :fill, padding: 8, spacing: 4 do
    for item <- nav_items do
      button(item.id, item.label,
        width: :fill,
        style: if(item.id == model.active, do: :primary, else: :text)
      )
    end
  end

  container "content", width: :fill, height: :fill, padding: 16 do
    render_active_page(model)
  end
end
```

### Breadcrumbs

Interleaved buttons and separators:

```elixir
row spacing: 4 do
  for {segment, i} <- Enum.with_index(model.breadcrumbs) do
    if i > 0 do
      text("sep-#{i}", "/", size: 12, color: "#999")
    end

    if i == length(model.breadcrumbs) - 1 do
      text("crumb-#{i}", segment, size: 12)
    else
      button("crumb-#{i}", segment, style: :text)
    end
  end
end
```

The last segment is plain text (current location); earlier segments are
clickable buttons.

## Overlays

### Modal dialog

A `stack` layers a semi-transparent overlay behind a centred dialog:

```elixir
stack width: :fill, height: :fill do
  # Layer 0: main content (always visible)
  main_content(model)

  # Layer 1: modal (conditionally rendered)
  if model.show_modal do
    container "overlay",
      width: :fill, height: :fill,
      background: "#00000088",
      center: true do

      container "dialog", padding: 24, background: "#ffffff",
        border: Border.new() |> Border.rounded(8) do
        column spacing: 12 do
          text("modal-title", "Confirm", size: 18)
          text("modal-body", "Are you sure?")
          row spacing: 8 do
            button("modal-cancel", "Cancel")
            button("modal-confirm", "Confirm", style: :primary)
          end
        end
      end
    end
  end
end
```

The `if` without `else` returns `nil`, which `stack` filters out. The hex
colour `"#00000088"` is black at about 53% opacity (the last two hex digits
control alpha).

### Popover

The `overlay` widget positions floating content relative to an anchor:

```elixir
overlay "menu", position: :below, gap: 4, flip: true do
  button("trigger", "Options")

  container "dropdown", padding: 8, background: "#fff",
    border: Border.new() |> Border.width(1) |> Border.color("#ddd") |> Border.rounded(4) do
    column spacing: 2 do
      button("opt-edit", "Edit", style: :text, width: :fill)
      button("opt-delete", "Delete", style: :text, width: :fill)
    end
  end
end
```

The first child is the anchor (rendered inline). The second is the overlay
(floated above). `flip: true` auto-repositions when the overlay would go
off-screen.

## Layout patterns

### Toolbar

A row with button groups, separators, and trailing alignment:

```elixir
row spacing: 4, padding: {4, 8} do
  button("bold", "B")
  button("italic", "I")

  rule(direction: :vertical, height: 20)

  button("align-left", "Left")
  button("align-center", "Center")

  space(width: :fill)

  button("settings", "Settings")
end
```

`rule(direction: :vertical)` draws a vertical separator.
`space(width: :fill)` pushes everything after it to the right.

### Cards

A container with border, shadow, and padding:

```elixir
defp card(id, do: block) do
  container id,
    padding: 16,
    background: "#ffffff",
    border: Border.new() |> Border.color("#e5e7eb") |> Border.width(1) |> Border.rounded(8),
    shadow: Shadow.new() |> Shadow.color("#0000001a") |> Shadow.offset(0, 2) |> Shadow.blur_radius(4) do
    block
  end
end
```

### Split panel

A resizable divider between two panes. Use `mouse_area` for drag tracking:

```elixir
row width: :fill, height: :fill do
  container "left", width: model.split_width, height: :fill do
    left_content(model)
  end

  mouse_area "divider",
    cursor: :resizing_horizontally,
    on_press: "drag-start",
    on_release: "drag-end" do
    container width: 4, height: :fill, background: "#ddd" do
    end
  end

  container "right", width: :fill, height: :fill do
    right_content(model)
  end
end
```

Track the drag state in your model and update `split_width` on mouse move
events.

### Badges and chips

Pills with large border radius:

```elixir
container "badge",
  padding: {2, 8},
  background: "#3b82f6",
  border: Border.new() |> Border.rounded(999) do
  text("count", "#{model.unread}", color: "#fff", size: 12)
end
```

`rounded(999)` is clamped to the maximum radius, creating a pill shape.
For selectable chips, toggle between solid fill (selected) and outline
(unselected).

## Canvas patterns

### Toggle switch

An interactive group with state-driven position:

```elixir
canvas "switch", width: 64, height: 32 do
  layer "track" do
    group "toggle", on_click: true, cursor: :pointer,
      a11y: %{role: :switch, label: "Dark mode", toggled: model.dark} do
      rect(0, 0, 64, 32, fill: if(model.dark, do: "#3b82f6", else: "#ddd"), radius: 16)
      circle(if(model.dark, do: 44, else: 20), 16, 12, fill: "#fff")
    end
  end
end
```

### Bar chart

Focusable bars with accessibility annotations:

```elixir
canvas "chart", width: 300, height: 200 do
  layer "bars" do
    for {value, i} <- Enum.with_index(model.data) do
      x = i * 40 + 10
      h = value * 2

      group "bar-#{i}", x: x, y: 200 - h, focusable: true,
        tooltip: "#{value}",
        a11y: %{role: :image, label: "Value: #{value}",
               position_in_set: i + 1, size_of_set: length(model.data)} do
        rect(0, 0, 30, h, fill: "#3b82f6")
      end
    end
  end
end
```

### Canvas with widget overlay

Layer a canvas (visuals) under a text_input (editing) using `stack`:

```elixir
stack width: 200, height: 40 do
  canvas "bg", width: 200, height: 40 do
    layer "decor" do
      rect(0, 0, 200, 40, fill: "#f5f5f5", radius: 8)
    end
  end

  text_input("input", model.value,
    placeholder: "Search...",
    style: StyleMap.new() |> StyleMap.background(:transparent)
  )
end
```

## State helper patterns

### Route-based view dispatch

```elixir
def view(model) do
  window "main", title: "App" do
    case Route.current(model.route) do
      :list -> list_view(model)
      :detail -> detail_view(model, Route.params(model.route))
      :settings -> settings_view(model)
    end
  end
end
```

### Selection with highlighting

```elixir
for item <- model.items do
  container item.id,
    style: if(Selection.selected?(model.selection, item.id),
      do: :primary, else: :transparent) do
    text(item.id, item.name)
  end
end
```

### Undo with coalesced keystrokes

```elixir
Undo.apply(model.undo, %{
  apply: fn _ -> new_text end,
  undo: fn _ -> old_text end,
  label: "Edit",
  coalesce: :typing,
  coalesce_window_ms: 500
})
```

## See also

- [Built-in Widgets reference](built-in-widgets.md) -- widget catalog with module links
- [Canvas reference](canvas.md) -- shapes, transforms, interactive groups
- [Types reference](types.md) -- Border, Shadow, StyleMap, Theme
- Guide chapters 3-13 -- patterns demonstrated in context
