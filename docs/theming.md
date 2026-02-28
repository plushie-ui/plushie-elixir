# Theming

Julep exposes iced's theming system directly. No additional abstraction
layer, no token system, no design system framework. If you need those,
build them in your app.

## Setting a theme

Themes are set at the window level:

```elixir
def view(model) do
  import Julep.UI

  window "main", title: "My App", theme: "catppuccin_mocha" do
    column do
      text("Themed content")
    end
  end
end
```

## Built-in themes

Iced 0.14 ships with 30+ themes. Julep passes the theme name string
directly to the renderer, which resolves it to an iced `Theme` variant.

Common themes:

| Name | Description |
|---|---|
| `light` | Default light theme |
| `dark` | Default dark theme |
| `dracula` | Dracula color scheme |
| `nord` | Nord color scheme |
| `solarized_light` | Solarized Light |
| `solarized_dark` | Solarized Dark |
| `gruvbox_light` | Gruvbox Light |
| `gruvbox_dark` | Gruvbox Dark |
| `catppuccin_latte` | Catppuccin Latte (light) |
| `catppuccin_mocha` | Catppuccin Mocha (dark) |
| `tokyo_night` | Tokyo Night |
| `kanagawa_wave` | Kanagawa Wave |
| `oxocarbon` | Oxocarbon |

The full list is whatever iced's `Theme` enum provides. Unknown names fall
back to `dark`.

## Custom themes

Custom themes are defined by providing a palette:

```elixir
window "main", theme: %{
  background: "#1e1e2e",
  text: "#cdd6f4",
  primary: "#89b4fa",
  success: "#a6e3a1",
  danger: "#f38ba8",
  warning: "#f9e2af"
} do
  # ...
end
```

The palette map is passed to iced's `Theme::custom()` with Oklch-based
palette generation (iced 0.14). Only the colors you specify are overridden;
the rest are derived automatically.

## Per-subtree theme override

Themes can be overridden for a subtree:

```elixir
column do
  text("Uses window theme")
  container "sidebar", theme: "nord" do
    text("Uses Nord theme")
  end
end
```

This is useful for panels, modals, or sections that need a different
visual treatment.

## Widget-level styling

Individual widgets accept a `style` prop. This can be a named preset atom
or a `Julep.Iced.StyleMap` struct for per-instance visual customization.

### Named presets

```elixir
button("save", "Save", style: :primary)
button("cancel", "Cancel", style: :secondary)
button("delete", "Delete", style: :danger)
```

Style atoms (`:primary`, `:secondary`, `:danger`, etc.) map to iced's
built-in style functions. Available presets vary by widget.

### Style maps

Style maps let you fully customize widget appearance from Elixir without
writing Rust. They work on all 13 styleable widgets: button, container,
text_input, text_editor, checkbox, radio, toggler, pick_list, progress_bar,
rule, slider, vertical_slider, and tooltip.

```elixir
alias Julep.Iced.StyleMap

# Build a style map with the builder pattern
card_style =
  StyleMap.new()
  |> StyleMap.background("#ffffff")
  |> StyleMap.text_color("#1a1a1a")
  |> StyleMap.border(Julep.Iced.Border.new() |> Julep.Iced.Border.rounded(8) |> Julep.Iced.Border.width(1) |> Julep.Iced.Border.color("#e0e0e0"))
  |> StyleMap.shadow(Julep.Iced.Shadow.new() |> Julep.Iced.Shadow.color("#00000020") |> Julep.Iced.Shadow.offset(0, 2) |> Julep.Iced.Shadow.blur_radius(8))

container "card", style: card_style do
  text("Card content")
end
```

### Style map fields

- `background` -- hex color for the widget background
- `text_color` -- hex color for text
- `border` -- a `Julep.Iced.Border` struct (color, width, radius)
- `shadow` -- a `Julep.Iced.Shadow` struct (color, offset, blur_radius)

### Status overrides

Style maps support interaction state overrides. Each override is a
partial style map that is merged on top of the base when the widget
enters that state:

```elixir
nav_item_style =
  StyleMap.new()
  |> StyleMap.background("#00000000")
  |> StyleMap.text_color("#cccccc")
  |> StyleMap.hovered(%{background: "#333333", text_color: "#ffffff"})
  |> StyleMap.pressed(%{background: "#222222"})
  |> StyleMap.disabled(%{text_color: "#666666"})
```

Supported statuses: `hovered`, `pressed`, `disabled`, `focused`.

If you don't specify an override for a status, the renderer auto-derives:

- **hovered**: darkens background by 10%
- **pressed**: uses the base style (matching iced's own pattern)
- **disabled**: applies 50% alpha to background and text_color

This means hover and disabled states "just work" without explicit
overrides in most cases. You only need explicit overrides when you want
a specific look.

### Presets and style maps together

Style maps don't replace presets -- they complement them. Use presets
for standard looks and style maps when you need custom appearance:

```elixir
# Standard danger button
button("delete", "Delete", style: :danger)

# Custom branded button
button("cta", "Get Started", style:
  StyleMap.new()
  |> StyleMap.background("#7c3aed")
  |> StyleMap.text_color("#ffffff")
  |> StyleMap.border(Julep.Iced.Border.new() |> Julep.Iced.Border.rounded(24))
)
```

See `docs/composition-patterns.md` for concrete examples of building
polished UI patterns with style maps.

## System theme detection

The renderer detects the OS light/dark preference and sends a window event:

```elixir
def update(model, {:window, "system_theme_changed", theme}) do
  %{model | preferred_theme: theme}
end
```

Your app can use this to follow the system theme or ignore it entirely.

## Density

For apps that need density-aware spacing (compact, comfortable, roomy),
julep provides a simple `Julep.Layout` helper:

```elixir
density = :compact
spacing = Julep.Layout.token(:spacing_md, density)
# => 4 (compact) vs 8 (comfortable) vs 12 (roomy)

column spacing: spacing do
  # ...
end
```

This is a pure function that maps token names to numeric values based on
density. There is no global density setting -- your app decides how to use
it.
