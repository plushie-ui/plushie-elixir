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

Individual widgets accept a `style` prop for fine-grained control:

```elixir
button("save", "Save", style: :primary)
button("cancel", "Cancel", style: :secondary)
button("delete", "Delete", style: :danger)
container("box", style: %{background: "#f0f0f0", border_radius: 8})
```

Style atoms (`:primary`, `:secondary`, `:danger`) map to iced's built-in
style functions. Style maps provide direct CSS-like overrides.

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
