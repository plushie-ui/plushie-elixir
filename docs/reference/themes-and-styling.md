# Themes and Styling

Plushie's visual styling works at three layers: **themes** set the
overall palette, **style maps** override individual widget appearance,
and **type modules** (Color, Border, Shadow, Gradient) provide the
building blocks. This reference covers all of them.

## Color

`Plushie.Type.Color`

Colors appear throughout the styling system: themes, style maps,
borders, shadows, gradients, and widget props like `color:` and
`background:`. Wherever a color is accepted, you can use any of these
input forms:

| Input | Example | Result |
|---|---|---|
| Named atom | `:cornflowerblue` | `"#6495ed"` |
| Hex string | `"#3b82f6"` | `"#3b82f6"` |
| Shorthand hex | `"#f00"` | `"#ff0000"` |
| Hex with alpha | `"#3b82f680"` | `"#3b82f680"` |
| Shorthand with alpha | `"#f008"` | `"#ff000088"` |
| Named string | `"cornflowerblue"` | `"#6495ed"` |
| Float RGB map | `%{r: 0.23, g: 0.51, b: 0.96}` | `"#3b82f5"` |
| Float RGBA map | `%{r: 1.0, g: 0.0, b: 0.0, a: 0.5}` | `"#ff000080"` |

`Color.cast/1` normalises any input to a canonical lowercase hex string
(`"#rrggbb"` or `"#rrggbbaa"`). All type modules that accept colors run
inputs through `cast/1` automatically.

### Named colors

Plushie supports all 148 colors from the
[CSS Color Module Level 4](https://www.w3.org/TR/css-color-4/#named-colors)
specification plus `:transparent`. Named lookups are case-insensitive
(both the atom `:cornflowerblue` and the string `"CornflowerBlue"` work).
`Color.named_colors/0` returns the complete map.

Grey/gray aliases are supported: `:darkgray` and `:darkgrey` both
resolve to the same hex value.

### Convenience functions

```elixir
Color.black()        # "#000000"
Color.white()        # "#ffffff"
Color.transparent()  # "#00000000"
Color.from_rgb(59, 130, 246)           # "#3b82f6"
Color.from_rgba(59, 130, 246, 0.5)     # "#3b82f680"
```

`from_rgb/3` and `from_rgba/4` take 0-255 integer channels. The alpha
in `from_rgba/4` is a 0.0-1.0 float.

Float maps clamp values to the 0.0-1.0 range before converting.

## Theme

`Plushie.Type.Theme`

Every window has a `theme:` prop that sets the colour palette for all
widgets inside it. Themes control button colours, input field
backgrounds, scrollbar tints, text colours. Everything visual adapts
to the active theme.

### Built-in themes

Plushie ships 22 built-in themes. Pass the atom to the window's
`theme:` prop:

```elixir
window "main", title: "App", theme: :dark do
  # ...
end
```

| Theme | Description |
|---|---|
| `:light`, `:dark` | Default light and dark themes |
| `:nord` | [Nord](https://www.nordtheme.com/) palette |
| `:dracula` | [Dracula](https://draculatheme.com/) palette |
| `:solarized_light`, `:solarized_dark` | [Solarized](https://ethanschoonover.com/solarized/) |
| `:gruvbox_light`, `:gruvbox_dark` | [Gruvbox](https://github.com/morhetz/gruvbox) |
| `:catppuccin_latte`, `:catppuccin_frappe`, `:catppuccin_macchiato`, `:catppuccin_mocha` | [Catppuccin](https://catppuccin.com/) |
| `:tokyo_night`, `:tokyo_night_storm`, `:tokyo_night_light` | [Tokyo Night](https://github.com/enkia/tokyo-night-vscode-theme) |
| `:kanagawa_wave`, `:kanagawa_dragon`, `:kanagawa_lotus` | [Kanagawa](https://github.com/rebelot/kanagawa.nvim) |
| `:moonfly`, `:nightfly` | [moonfly](https://github.com/bluz71/vim-moonfly-colors) / [nightfly](https://github.com/bluz71/vim-nightfly-colors) |
| `:oxocarbon` | [Oxocarbon](https://github.com/nyoom-engineering/oxocarbon.nvim) |
| `:ferra` | [Ferra](https://github.com/casperstorm/ferra) |

Use `:system` to follow the operating system's light/dark preference.
`Theme.builtin_themes/0` returns the full list programmatically.

### Custom themes

`Theme.custom/2` creates a custom palette from seed colours:

```elixir
my_theme = Plushie.Type.Theme.custom("My Brand",
  primary: "#3b82f6",
  danger: "#ef4444",
  background: "#1a1a2e",
  text: "#e0e0e8"
)

window "main", theme: my_theme do
  # ...
end
```

| Seed key | Purpose |
|---|---|
| `:background` | Page/window background |
| `:text` | Default text colour |
| `:primary` | Primary accent (buttons, links, focus rings) |
| `:success` | Success indicators |
| `:danger` | Error/destructive actions |
| `:warning` | Warning indicators |

All seed values are passed through `Color.cast/1`, so any colour input
form works.

The secondary palette is auto-derived from `:background` and `:text`
by iced's palette generator. To customize it, use shade overrides
(`secondary_base`, `secondary_weak`, `secondary_strong`, plus `_text`
variants) rather than a core seed.

Custom themes also accept chrome colour tokens:

| Key | Purpose |
|---|---|
| `:cursor_color` | Text cursor colour |
| `:scrollbar_color` | Scrollbar track colour |
| `:scroller_color` | Scrollbar handle colour |

These values are passed through `Color.cast/1` and sent with the custom
theme. Scrollbar tokens become defaults for scrollable widgets, and explicit
widget `scrollbar_color` or `scroller_color` props still win. `cursor_color`
applies to focused text entry widgets through iced's focused text style, so
explicit widget text styling still wins.

### Extending built-in themes

Provide `:base` to start from an existing theme and override only the
colours you want:

```elixir
Plushie.Type.Theme.custom("Nord+", base: :nord, primary: "#88c0d0")
```

### Shade overrides

For fine-grained control, themes support shade override keys that target
specific levels in the generated palette. The renderer generates a full
shade ramp from each seed colour; overrides replace individual shades.

**Colour families** (primary, secondary, success, warning, danger):

Each has three base shades and corresponding text variants:

- `primary_base`, `primary_weak`, `primary_strong`
- `primary_base_text`, `primary_weak_text`, `primary_strong_text`

Same pattern for `secondary_*`, `success_*`, `warning_*`, `danger_*`.

**Background family** (8 levels with text variants):

- `background_base`, `background_weakest`, `background_weaker`,
  `background_weak`, `background_neutral`, `background_strong`,
  `background_stronger`, `background_strongest`
- Each has a `_text` variant (e.g. `background_base_text`)

Pass shade overrides as additional keys to `custom/2`:

```elixir
Plushie.Type.Theme.custom("Custom",
  base: :dark,
  primary: "#3b82f6",
  primary_strong: "#1d4ed8",
  background_weakest: "#0f0f1a",
  cursor_color: "#ffffff",
  scrollbar_color: "#1f2937",
  scroller_color: "#6b7280"
)
```

### Subtree theming

The `themer` widget applies a different theme to a subtree without
affecting the rest of the window:

```elixir
themer "sidebar-theme", theme: :dark do
  column padding: 12 do
    # All widgets here use the dark theme
  end
end
```

## StyleMap

`Plushie.Type.StyleMap`

StyleMap overrides the appearance of individual widget instances.
Themes set the baseline; StyleMap customises specific widgets.

### Builder API

```elixir
alias Plushie.Type.{StyleMap, Border, Shadow}

style =
  StyleMap.new()
  |> StyleMap.base(:primary)
  |> StyleMap.background("#3b82f6")
  |> StyleMap.text_color("#ffffff")
  |> StyleMap.border(Border.new() |> Border.color("#2563eb") |> Border.width(1))
  |> StyleMap.shadow(Shadow.new() |> Shadow.color("#0000001a") |> Shadow.blur_radius(4))
  |> StyleMap.hovered(%{background: "#2563eb"})
  |> StyleMap.pressed(%{background: "#1d4ed8"})
  |> StyleMap.disabled(%{background: "#9ca3af", text_color: "#6b7280"})
  |> StyleMap.focused(%{border: Border.new() |> Border.color("#3b82f6") |> Border.width(2)})

button("save", "Save", style: style)
```

| Function | Accepts | Purpose |
|---|---|---|
| `new/0` | *n/a* | Empty style map |
| `base/2` | atom | Extend a named preset (`:primary`, `:danger`, etc.) |
| `background/2` | `Color.input()` or `Gradient.t()` | Background colour or gradient |
| `text_color/2` | `Color.input()` | Text colour |
| `border/2` | `Border.t()` | Border specification |
| `shadow/2` | `Shadow.t()` | Shadow specification |
| `hovered/2` | map or keyword | Overrides when hovered |
| `pressed/2` | map or keyword | Overrides when pressed |
| `disabled/2` | map or keyword | Overrides when disabled |
| `focused/2` | map or keyword | Overrides when focused |

### Status overrides

Each status override accepts a subset of the base properties:
`background`, `text_color`, `border`, `shadow`. Only the properties you
specify are overridden; others inherit from the base style. Pass a map
or keyword list:

```elixir
StyleMap.hovered(%{background: "#2563eb"})
StyleMap.hovered(background: "#2563eb")  # equivalent
```

### Named presets

Instead of building from scratch, extend a widget's named preset with
`base/2`:

```elixir
StyleMap.new()
|> StyleMap.base(:primary)
|> StyleMap.hovered(%{background: "#2563eb"})
```

Or pass a preset atom directly to the widget's `:style` prop:

```elixir
button("save", "Save", style: :primary)
button("cancel", "Cancel", style: :text)
```

Common presets: `:primary`, `:secondary`, `:success`, `:danger`,
`:warning`, `:text`. Available presets vary by widget. Check each
widget's module docs for its supported values.

### Do-block syntax

StyleMap supports the [do-block](dsl.md#do-block-types) syntax with nested
Border and Shadow blocks:

```elixir
button "save", "Save" do
  style do
    base :primary
    background "#3b82f6"
    border do
      color "#2563eb"
      width 1
      rounded 6
    end
    hovered background: "#2563eb"
  end
end
```

## Gradient

`Plushie.Type.Gradient`

Linear gradients for use as background fills in widgets and style maps.

```elixir
Plushie.Type.Gradient.linear(90, [
  {0.0, "#3b82f6"},
  {1.0, "#1d4ed8"}
])
```

The first argument is the angle in degrees (0 = left to right, 90 = top
to bottom). Stops are `{offset, color}` tuples where offset is 0.0-1.0
and color is any `Color.input()` form.

Use gradients anywhere a background colour is accepted:

```elixir
container "card", background: Gradient.linear(135, [{0.0, "#667eea"}, {1.0, "#764ba2"}]) do
  text("content", "Gradient card")
end
```

## Border

`Plushie.Type.Border`

Border specifications for containers and style maps.

### Builder API

```elixir
alias Plushie.Type.Border

border =
  Border.new()
  |> Border.color("#e5e7eb")
  |> Border.width(1)
  |> Border.rounded(8)
```

| Function | Accepts | Purpose |
|---|---|---|
| `new/0` | *n/a* | Border with defaults (nil colour, 0 width, 0 radius) |
| `color/2` | `Color.input()` | Border colour |
| `width/2` | number | Border width in pixels |
| `rounded/2` | number | Uniform corner radius in pixels |
| `radius/4` | 4 numbers | Per-corner radius (top_left, top_right, bottom_right, bottom_left) |

### Per-corner radius

```elixir
Border.new()
|> Border.width(1)
|> Border.color("#ccc")
|> Border.rounded(Border.radius(8, 8, 0, 0))  # rounded top, square bottom
```

`radius/4` returns a map: `%{top_left: 8, top_right: 8, bottom_right: 0, bottom_left: 0}`.
Pass it to `rounded/2` or use it directly in the `:radius` field.

### Do-block syntax

```elixir
container "card" do
  border do
    color "#e5e7eb"
    width 1
    rounded 8
  end
end
```

## Shadow

`Plushie.Type.Shadow`

Drop shadow specifications for containers and style maps.

### Builder API

```elixir
alias Plushie.Type.Shadow

shadow =
  Shadow.new()
  |> Shadow.color("#0000001a")
  |> Shadow.offset(0, 4)
  |> Shadow.blur_radius(8)
```

| Function | Accepts | Purpose |
|---|---|---|
| `new/0` | *n/a* | Shadow with defaults (black, zero offset, zero blur) |
| `color/2` | `Color.input()` | Shadow colour |
| `offset/3` | x, y numbers | Offset in pixels |
| `blur_radius/2` | number | Blur radius in pixels |

### Do-block syntax

```elixir
container "card" do
  shadow do
    color "#0000001a"
    offset 0, 4
    blur_radius 8
  end
end
```

## Encoding

All styling types implement `encode/1` via the `Plushie.Type` behaviour
for wire serialisation. Encoding happens during tree normalization --
you work with Elixir structs and atoms in your view code, and encoding
is deferred to the single normalisation pass before the tree hits the
wire.

Colours are already hex strings after `cast/1`, so encoding is a no-op.
Border and Shadow encode to maps. Gradients are built as maps
internally. StyleMap encodes its fields recursively (colours cast,
border/shadow encoded, presets converted to strings).

## See also

- [Styling guide](../guides/08-styling.md) - themes, StyleMap, and
  design tokens applied to the pad
- [Built-in Widgets reference](built-in-widgets.md) - which widgets
  accept `:style`, `:border`, `:shadow`, and `:background`
- [DSL reference](dsl.md) - block-form syntax for Border, Shadow,
  and StyleMap
- [Canvas reference](canvas.md) - fill and stroke colours in canvas
  shapes
- `Plushie.Type.Color` - colour module docs
- `Plushie.Type.Theme` - theme module docs with the full shade key
  list
