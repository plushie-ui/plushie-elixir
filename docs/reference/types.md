# Types Reference

Plushie's type modules define the structured values used in widget props:
colours, lengths, padding, fonts, borders, shadows, gradients, style maps,
and themes. Most have strong module docs -- this page provides the catalog
and fills gaps where the module docs are incomplete.

## Type catalog

| Type | Common use | Module |
|---|---|---|
| Color | Fill, text colour, background | `Plushie.Type.Color` |
| Length | Width, height | `Plushie.Type.Length` |
| Padding | Container padding | `Plushie.Type.Padding` |
| Font | Text font | `Plushie.Type.Font` |
| Border | Container border | `Plushie.Type.Border` |
| Shadow | Container shadow | `Plushie.Type.Shadow` |
| Gradient | Background gradient | `Plushie.Type.Gradient` |
| StyleMap | Per-widget styling | `Plushie.Type.StyleMap` |
| Theme | Window/app theme | `Plushie.Type.Theme` |
| A11y | Accessibility props | `Plushie.Type.A11y` |

## Color

See `Plushie.Type.Color` for the full API.

Accepted input forms: hex string (`"#rgb"`, `"#rrggbb"`, `"#rrggbbaa"`),
named atom (`:red`, `:cornflowerblue`, etc.), or `%{r: f, g: f, b: f, a: f}`
float map.

`Plushie.Type.Color.named_colors/0` returns the complete map of CSS Color
Module Level 4 named colours. `Plushie.Type.Color.cast/1` normalizes any
input form to canonical hex.

## Length

See `Plushie.Type.Length`.

| Value | Behaviour |
|---|---|
| `:fill` | Take all available space |
| `:shrink` | Take only what content needs |
| `{:fill_portion, n}` | Proportional share of available space |
| number | Exact pixels |

## Padding

See `Plushie.Type.Padding`.

Accepted forms:

| Input | Result |
|---|---|
| `16` | 16px on all sides |
| `{8, 16}` | 8px vertical, 16px horizontal |
| `%{top: 16, bottom: 8}` | Per-side (nil fields omitted) |
| `%Padding{top: 16, ...}` | Struct form |
| do-block | `padding do top 16; bottom 8 end` |

## Font

See `Plushie.Type.Font`.

| Input | Meaning |
|---|---|
| `:default` | System default proportional font |
| `:monospace` | System monospace font |
| `"Family Name"` | Specific font family |
| `%Font{family: ..., weight: ..., style: ..., stretch: ...}` | Full spec |

Weights: `:thin`, `:extra_light`, `:light`, `:normal`, `:medium`,
`:semi_bold`, `:bold`, `:extra_bold`, `:black`.

Styles: `:normal`, `:italic`, `:oblique`.

Stretches: `:ultra_condensed` through `:ultra_expanded`.

## Border

See `Plushie.Type.Border`.

Builder API:

```elixir
Border.new()
|> Border.color("#e5e7eb")
|> Border.width(1)
|> Border.rounded(8)          # uniform radius
```

Per-corner radius:

```elixir
Border.radius(8, 8, 0, 0)    # top_left, top_right, bottom_right, bottom_left
```

The module docs for `Plushie.Type.Border` cover `color/2`, `width/2`,
`rounded/2`, and `radius/4`. The `from_opts/1` function accepts keyword
form for do-block syntax.

## Shadow

See `Plushie.Type.Shadow`.

```elixir
Shadow.new()
|> Shadow.color("#0000001a")
|> Shadow.offset(0, 2)
|> Shadow.blur_radius(4)
```

## Gradient

See `Plushie.Type.Gradient`.

```elixir
Plushie.Type.Gradient.linear(90, [{0.0, "#ff0000"}, {1.0, "#0000ff"}])
```

Angle in degrees. Stops are `{offset, colour}` where offset is 0.0--1.0.

## StyleMap

See `Plushie.Type.StyleMap`.

Builder API:

```elixir
StyleMap.new()
|> StyleMap.base(:primary)           # extend a named preset
|> StyleMap.background("#3b82f6")    # colour or gradient
|> StyleMap.text_color("#ffffff")
|> StyleMap.border(%Border{...})
|> StyleMap.shadow(%Shadow{...})
|> StyleMap.hovered(%{background: "#2563eb"})
|> StyleMap.pressed(%{background: "#1d4ed8"})
|> StyleMap.disabled(%{background: "#9ca3af"})
|> StyleMap.focused(%{border: %Border{...}})
```

### Status overrides

Each status override accepts: `background`, `text_color`, `border`,
`shadow`. Only the properties you specify are overridden; others inherit
from the base style.

### Named presets

`StyleMap.base/2` extends from a widget-specific preset. Common presets:
`:primary`, `:secondary`, `:success`, `:danger`, `:warning`, `:text`.
Available presets vary by widget -- check each widget's module docs.

You can also pass a preset atom directly to the `:style` prop:

```elixir
button("save", "Save", style: :primary)
```

## Theme

See `Plushie.Type.Theme`.

### Built-in themes

`Plushie.Type.Theme.builtin_themes/0` returns the list of all built-in
theme atoms (`:light`, `:dark`, `:nord`, `:dracula`, etc.).

Use `:system` to follow the OS light/dark preference.

### Custom themes

```elixir
Plushie.Type.Theme.custom("name",
  primary: "#3b82f6",
  danger: "#ef4444",
  background: "#1a1a2e",
  text: "#e0e0e8"
)
```

Top-level colour keys: `background`, `text`, `primary`, `success`,
`danger`, `warning`.

Extend a built-in theme:

```elixir
Plushie.Type.Theme.custom("name", base: :nord, primary: "#88c0d0")
```

### Shade overrides

For fine-grained control, themes support shade override keys that target
specific levels in the generated palette. See `Plushie.Type.Theme` for the
full list of shade keys.

Shade families: primary, secondary, success, warning, danger (each with
base, weak, strong levels and text variants). Background has eight levels
(weakest through strongest) with text variants.

## Encoding

All type structs implement the `Plushie.Encode` protocol for wire
serialization. Encoding happens during `Plushie.Tree.normalize/1` -- widget
builders work with raw Elixir values, and encoding is deferred to the single
normalization pass.

See `Plushie.Encode` for the protocol definition.

## Buildable

Types that participate in the DSL block-form syntax implement
`Plushie.DSL.Buildable`. This provides `from_opts/1` (construct from keyword
list), `__field_keys__/0` (valid field names for compile-time validation),
and `__field_types__/0` (nested struct types for recursive do-blocks).

See `Plushie.DSL.Buildable` for the behaviour definition.

## See also

- [Styling guide](../guides/08-styling.md) -- themes, StyleMap, design tokens
- [Built-in Widgets reference](built-in-widgets.md) -- which widgets accept :style
- [DSL reference](dsl.md) -- block-form syntax for types
