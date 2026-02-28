# 0009: Style maps for per-instance widget customization

## Status

Accepted.

## Context

Julep currently only supports named style presets (atoms like `:primary`,
`:danger`) for widget styling. iced's full `StyleFn` closures cannot cross
the IPC boundary -- they are Rust closures, not data. Users need per-instance
visual customization to build polished UIs (custom colors, borders, shadows
per widget). The gap between "it works" and "it looks good" is entirely about
styling.

## Decision

Introduce style maps -- plain data maps that describe widget visual
properties. The `style` prop on widgets accepts either a preset atom
(existing behavior) or a `StyleMap` struct. The Rust renderer constructs a
closure from the map fields at render time.

**Wire format.** A JSON object (serializes naturally in both JSON and
msgpack) with optional fields:

- `background` -- hex color
- `text_color` -- hex color
- `border` -- object with `color`, `width`, `radius`
- `shadow` -- object with `color`, `offset`, `blur_radius`

**Status overrides.** Optional `hovered`, `pressed`, `disabled`, `focused`
keys containing partial style maps. Only the fields that differ from the base
need to be specified.

**Auto-derivation.** When status overrides are not explicitly provided:

- `hovered` -- darken background slightly
- `pressed` -- same as active (matching iced's built-in pattern)
- `disabled` -- 50% alpha on background and text_color

Unspecified base fields fall through to the theme defaults for that widget.

**Elixir side.** `Julep.Iced.StyleMap` type module with builder functions,
following the same pattern as `Border` and `Shadow`. The Encode protocol
handles serialization.

**Rust side.** A `parse_style_map` helper that takes the deserialized map and
returns `Box<dyn Fn(&Theme, Status) -> Style>`, which slots directly into
iced's style function API.

**Affected widgets (13).** Button, Container, TextInput, TextEditor,
Checkbox, Radio, Toggler, PickList, ProgressBar, Rule, Slider,
VerticalSlider, Tooltip.

## Consequences

- Users can fully customize widget appearance from Elixir without writing
  Rust.
- No IPC protocol changes needed -- maps already serialize naturally in both
  wire formats.
- Preset atoms continue to work unchanged (backwards compatible).
- Unlocks composition patterns that require visual differentiation (tabs,
  cards, nav items) without dedicated composite widgets.
- Auto-derivation means hover, press, and disabled states "just work" without
  explicit overrides, while remaining overridable when needed.
