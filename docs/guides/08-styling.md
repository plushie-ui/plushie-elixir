# Styling

With the layout in place, it is time to make the pad look good. Plushie has a
layered styling system: themes set the overall palette, per-widget styles
override individual elements, and type modules like `Plushie.Type.Border` and
`Plushie.Type.Shadow` handle the details.

This chapter covers the parts you will use most often. The full theme palette,
shade override keys, and every type option are in the
[Types reference](../reference/types.md).

## Themes

Every window has a `theme:` prop that sets the colour palette for all widgets
inside it. Plushie ships with a set of built-in themes:

```elixir
window "main", title: "Plushie Pad", theme: :dark do
  # All widgets inside use the dark palette
end
```

Some popular options: `:dark`, `:light`, `:nord`, `:dracula`,
`:catppuccin_mocha`, `:tokyo_night`, `:gruvbox_dark`. See
`Plushie.Type.Theme` for the complete list.

Use `:system` to follow the operating system's light/dark preference:

```elixir
window "main", title: "Plushie Pad", theme: :system do
  # Follows OS theme
end
```

Try a few themes on the pad's window to see how the entire UI adapts --
buttons, text inputs, scrollbars, and the editor all respond.

## Custom themes

You can create a custom theme by providing a handful of seed colours.
`Plushie.Type.Theme.custom/2` generates a full palette from them:

```elixir
my_theme = Plushie.Type.Theme.custom("My Theme",
  primary: "#3b82f6",
  danger: "#ef4444",
  background: "#1a1a2e",
  text: "#e0e0e8"
)

window "main", title: "Plushie Pad", theme: my_theme do
  # ...
end
```

You can also extend a built-in theme, overriding only the colours you want
to change:

```elixir
my_theme = Plushie.Type.Theme.custom("Nord+",
  base: :nord,
  primary: "#88c0d0"
)
```

For fine-grained control, the theme system supports shade overrides -- keys
like `primary_strong`, `background_weakest`, `danger_base_text` that target
specific shade levels in the generated palette. See `Plushie.Type.Theme` for
the full list of shade keys.

## Subtree theming

The `themer` widget applies a different theme to its children without
affecting the rest of the window:

```elixir
window "main", title: "App", theme: :light do
  column do
    text("light-text", "This is light themed")

    themer "dark-section", theme: :dark do
      container "sidebar", padding: 12 do
        text("dark-text", "This section is dark")
      end
    end
  end
end
```

This is useful for dark sidebars in a light app, brand-specific sections, or
any case where part of the UI needs a different palette. No prop threading
needed -- `themer` changes the theme context for everything inside it.

You can give the preview pane a different theme from the rest of the pad
using `themer`, so experiments render in a distinct palette:

```elixir
themer "preview-theme", theme: :light do
  container "preview", width: {:fill_portion, 1}, height: :fill, padding: 8 do
    # preview content
  end
end
```

## Per-widget styling with StyleMap

Themes set the baseline palette. `Plushie.Type.StyleMap` overrides the
appearance of individual widget instances.

Build a style with the builder pattern:

```elixir
alias Plushie.Type.{StyleMap, Border, Shadow}

save_style =
  StyleMap.new()
  |> StyleMap.background("#3b82f6")
  |> StyleMap.text_color("#ffffff")
  |> StyleMap.hovered(%{background: "#2563eb"})
  |> StyleMap.pressed(%{background: "#1d4ed8"})

button("save", "Save", style: save_style)
```

The properties you can set: `background` (colour or gradient), `text_color`,
`border` (`Plushie.Type.Border` struct), `shadow` (`Plushie.Type.Shadow`
struct).

### Status overrides

`hovered`, `pressed`, `disabled`, and `focused` set property overrides for
those interaction states. Each accepts the same properties as the base style:

```elixir
StyleMap.new()
|> StyleMap.background("#ffffff")
|> StyleMap.border(Border.new() |> Border.color("#e5e7eb") |> Border.width(1))
|> StyleMap.hovered(%{border: Border.new() |> Border.color("#3b82f6") |> Border.width(2)})
|> StyleMap.focused(%{border: Border.new() |> Border.color("#3b82f6") |> Border.width(2)})
```

### Named presets

Instead of building from scratch, you can extend a named preset:

```elixir
StyleMap.new()
|> StyleMap.base(:primary)
|> StyleMap.hovered(%{background: "#2563eb"})
```

Available presets vary by widget -- `:primary`, `:secondary`, `:success`,
`:danger`, `:warning`, `:text` are common. Check each widget's module docs
for its supported presets.

You can also use the preset atom directly on the `:style` prop:

```elixir
button("save", "Save", style: :primary)
button("cancel", "Cancel", style: :text)
```

## Borders and shadows

`Plushie.Type.Border` and `Plushie.Type.Shadow` are struct types used
in container styling and StyleMap:

```elixir
alias Plushie.Type.{Border, Shadow}

card_border =
  Border.new()
  |> Border.color("#e5e7eb")
  |> Border.width(1)
  |> Border.rounded(8)

card_shadow =
  Shadow.new()
  |> Shadow.color("#0000001a")
  |> Shadow.offset(0, 2)
  |> Shadow.blur_radius(4)

container "card", border: card_border, shadow: card_shadow, padding: 16 do
  text("content", "Card content")
end
```

Border supports per-corner radius:

```elixir
Border.new()
|> Border.width(1)
|> Border.color("#ccc")
|> Border.rounded(Border.radius(8, 8, 0, 0))  # rounded top, square bottom
```

These types also work in do-block syntax:

```elixir
container "card" do
  border do
    color "#e5e7eb"
    width 1
    rounded 8
  end
  shadow do
    color "#0000001a"
    offset 0, 2
    blur_radius 4
  end
  padding 16
  text("content", "Card content")
end
```

## Design tokens

Plushie does not have a built-in design system framework. Instead, you use
plain Elixir modules to define consistent values. This pattern works well:

```elixir
defmodule PlushiePad.Design do
  alias Plushie.Type.{StyleMap, Border, Shadow}

  # Spacing scale
  def spacing(:xs), do: 4
  def spacing(:sm), do: 8
  def spacing(:md), do: 12
  def spacing(:lg), do: 16
  def spacing(:xl), do: 24

  # Font sizes
  def font_size(:sm), do: 12
  def font_size(:md), do: 14
  def font_size(:lg), do: 18
  def font_size(:xl), do: 24

  # Border radius
  def radius(:sm), do: 4
  def radius(:md), do: 8
  def radius(:lg), do: 12

  # Reusable styles
  def card_style do
    StyleMap.new()
    |> StyleMap.background("#ffffff")
    |> StyleMap.border(
      Border.new() |> Border.color("#e5e7eb") |> Border.width(1) |> Border.rounded(radius(:md))
    )
    |> StyleMap.shadow(
      Shadow.new() |> Shadow.color("#0000001a") |> Shadow.offset(0, 2) |> Shadow.blur_radius(4)
    )
  end
end
```

Then use it in your views:

```elixir
import PlushiePad.Design

column spacing: spacing(:md), padding: spacing(:lg) do
  text("title", "Experiments", size: font_size(:lg))
  # ...
end
```

This is just Elixir module design -- no Plushie magic. But it keeps spacing,
sizes, and styles consistent across your app. As the pad grows, a design
module prevents the gradual drift toward inconsistent values.

## Fonts

Plushie supports three font forms:

- `:default` -- the system default proportional font
- `:monospace` -- the system monospace font
- `"Family Name"` -- a specific font family by name

App-level font defaults are set via the `c:Plushie.App.settings/0` callback:

```elixir
def settings do
  [
    default_text_size: 14,
    fonts: ["/path/to/custom-font.ttf"]
  ]
end
```

Fonts loaded in `settings/0` are available by family name in any widget's
`font:` prop.

## Applying it: the styled pad

Put it all together. Set a dark theme on the window, style the save button
as primary, highlight errors in red, and add a border between the sidebar
and editor:

```elixir
window "main", title: "Plushie Pad", theme: :dark do
  column width: :fill, height: :fill, spacing: 0 do
    row width: :fill, height: :fill, spacing: 0 do
      # Sidebar with a right border
      container "sidebar-wrap",
        border: Border.new() |> Border.width(1) |> Border.color("#333") do
        file_list(model)
      end

      text_editor "editor", model.source do
        width {:fill_portion, 1}
        height :fill
        highlight_syntax "ex"
        font :monospace
      end

      container "preview", width: {:fill_portion, 1}, height: :fill, padding: 12 do
        if model.error do
          text("error", model.error, color: "#ef4444", size: 13)
        else
          # ...
        end
      end
    end

    row padding: {4, 8}, spacing: 8 do
      button("save", "Save", style: :primary)
      checkbox("auto-save", model.auto_save)
      text("auto-label", "Auto-save", size: 12)
    end

    # ...event log...
  end
end
```

The dark theme transforms the entire pad. The primary save button stands
out. The sidebar border creates visual separation. Error text uses an
explicit red colour for contrast. Small adjustments, dramatic result.

## Verify it

Test that the styled pad still works end-to-end:

```elixir
test "styled pad compiles and previews correctly" do
  click("#save")
  assert_text("#preview/greeting", "Hello, Plushie!")
  assert_not_exists("#error")
end
```

Styling is visual, but this confirms the theme, borders, and style changes
did not break the compilation and preview flow.

## Try it

Write a styling experiment in your pad:

- Create a card: container with border, shadow, rounded corners, and padding.
- Try `StyleMap` with status overrides: build a button that changes colour
  on hover and press.
- Try the do-block syntax for border and shadow -- nest them inside a
  container block.
- Apply different themes to nested `themer` widgets to see how palettes
  compose.
- Build a design token module for your experiments with a spacing scale and
  reusable styles.

In the next chapter, we will add animations and transitions to make the pad
feel alive.

---

Next: [Animation and Transitions](09-animation.md)
