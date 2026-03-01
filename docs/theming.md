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

Iced 0.14 ships with 22 built-in themes. Julep passes the theme name
string directly to the renderer, which resolves it to an iced `Theme`
variant.

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

## Extended palette shade overrides

When you set a custom theme, iced generates an "extended palette" of shade
variants from your six core colors. These shades (strong, weak, base, etc.)
control how widgets render their backgrounds, borders, and text in different
states. By default the shades are derived automatically using iced's
Oklch-based color math.

If the auto-generated shades don't match your design, you can override
individual shades by adding flat keys to the theme map. Only the shades
you specify are replaced -- the rest keep their generated values.

### Why override shades?

- Pin a specific button hover or pressed color
- Ensure WCAG contrast ratios on specific shade/text pairs
- Match an existing brand color system that doesn't follow iced's derivation

### Key naming convention

For the five color families (primary, secondary, success, warning, danger),
each has three shade levels:

| Key | What it controls |
|-----|------------------|
| `{family}_base` | Base shade background |
| `{family}_weak` | Weak shade background |
| `{family}_strong` | Strong shade background |
| `{family}_base_text` | Text color on the base shade |
| `{family}_weak_text` | Text color on the weak shade |
| `{family}_strong_text` | Text color on the strong shade |

Where `{family}` is one of: `primary`, `secondary`, `success`, `warning`,
`danger`.

The background family has eight levels:

| Key | What it controls |
|-----|------------------|
| `background_base` | Base background |
| `background_weakest` | Weakest background shade |
| `background_weaker` | Weaker background shade |
| `background_weak` | Weak background shade |
| `background_neutral` | Neutral background shade |
| `background_strong` | Strong background shade |
| `background_stronger` | Stronger background shade |
| `background_strongest` | Strongest background shade |

Each background key also supports a `_text` suffix (e.g.
`background_weakest_text`).

### Example

```elixir
window "main", theme: %{
  "name" => "branded",
  "background" => "#1a1a2e",
  "text" => "#e0e0e0",
  "primary" => "#0f3460",
  # Override the strong primary shade and its text color
  "primary_strong" => "#1a5276",
  "primary_strong_text" => "#ffffff",
  # Pin the weakest background for sidebar panels
  "background_weakest" => "#0d0d1a"
} do
  # ...
end
```

Shade overrides only apply to custom themes (map values). Built-in theme
atoms like `:dark` or `:nord` are not affected.

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

The simplest way to follow the OS light/dark preference is to set the
window theme to `"system"`:

```elixir
window "main", title: "My App", theme: "system" do
  # content
end
```

The renderer tracks the current OS mode and applies Light or Dark
automatically. This also works in `settings/0` for the app-level default:

```elixir
def settings, do: [theme: "system"]
```

For manual control, subscribe to theme change events with
`Julep.Subscription.on_theme_change/1`:

```elixir
def subscribe(_model) do
  [Julep.Subscription.on_theme_change(:theme_changed)]
end

def update(model, {:theme_changed, mode}) do
  # mode is "light" or "dark"
  %{model | preferred_theme: mode}
end
```

Your app can use this to follow the system theme or ignore it entirely.

**Note:** The `themer` widget (per-subtree theme override) does not support
`"system"` as a theme value. Setting a themer's theme to `"system"` is
treated as "no override" (the parent theme passes through). Use `"system"`
on window nodes or in `settings/0` instead.

## Density

For apps that need density-aware spacing (compact, comfortable, roomy),
build a simple helper function in your app:

```elixir
defp spacing(density, size) do
  case {density, size} do
    {:compact, :md}      -> 4
    {:comfortable, :md}  -> 8
    {:roomy, :md}        -> 12
    # ... etc.
  end
end

column spacing: spacing(:compact, :md) do
  # ...
end
```

There is no global density setting or built-in density module -- your app
decides how to handle it.
