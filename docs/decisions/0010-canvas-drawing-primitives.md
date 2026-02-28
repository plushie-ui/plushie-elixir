# 0010: Canvas drawing primitives

## Status

Accepted.

## Context

The canvas widget currently supports only four basic shapes (rect, circle, line,
text). iced's canvas Frame API supports arbitrary paths (bezier curves, arcs,
quadratic curves, rounded rects), stroked shapes with full stroke styles (line
cap, join, dash patterns), gradient fills (linear), transforms
(translate/rotate/scale with save/restore stack), and drawing images and SVGs.
All of this is serializable as data. The canvas is the primary custom drawing
escape hatch (ADR 0004) but without these primitives it is limited to toy use
cases.

## Decision

Extend the canvas with full drawing primitives and a layer-based caching system.

**Layers replace shapes.** The `layers` prop is a map of layer names to shape
lists. Each layer maps to an iced `Cache` on the Rust side -- only changed
layers are re-tessellated. The old `shapes` prop is removed entirely (no
external consumers, no backwards compat needed).

**Path commands.** New shape type `"path"` with a `commands` array: `move_to`,
`line_to`, `bezier_to` (cubic), `quadratic_to`, `arc` (center/radius/angles),
`arc_to` (tangent), `ellipse`, `rounded_rect`, `close`. Each command is a JSON
array like `["move_to", x, y]`.

**Stroke styles.** Any shape can have a `stroke` object:
`{color, width, cap (butt/round/square), join (miter/round/bevel), dash: {segments, offset}}`.

**Gradient fills.** The `fill` field accepts either a hex color string or a
gradient object:
`{type: "linear", start: [x, y], end: [x, y], stops: [[offset, color], ...]}`.

**Transform stack.** Shapes in a layer can include transform commands:
`{type: "save"}`, `{type: "translate", x, y}`, `{type: "rotate", angle}`,
`{type: "scale", x, y}`, `{type: "restore"}`. These match iced's Frame API
directly.

**Canvas text improvements.** The text shape gets `font` and `size` fields.

**Image/SVG on canvas.** New shape types `"image"` and `"svg"` for drawing
file-path resources at specific positions and sizes.

**Elixir builder.** New module `Julep.Canvas.Shape` with builder functions that
produce plain maps. Raw maps also work -- the builder is optional convenience.

## Consequences

- Canvas becomes viable for charts, diagrams, drawing apps, and custom controls.
- Layer caching prevents performance footguns -- thousands of shapes in a stable
  layer are tessellated once and reused until the layer changes.
- The builder API is optional convenience; raw maps work identically.
- No backwards compatibility concern (shapes prop had no external consumers).
- Image/SVG on canvas is limited to file paths until an image registry is built
  (separate ADR).
