# 0006: Responsive layout via sensor widget

## Status

Accepted.

## Context

iced's `Responsive` widget takes a closure that is called mid-frame with the
available `Size`, allowing the widget tree to adapt to the container's
dimensions. Julep's architecture cannot call back to Elixir mid-frame --
the UI tree is built entirely in Elixir before being sent to the renderer.

## Decision

Use a `sensor` widget to measure available size and emit it as an event.
Elixir stores the size in its model and branches in `view/1` on the next
render cycle. This is one frame behind -- the first frame renders without
size data, and layout changes take effect on the following frame.

The `responsive` widget type becomes an alias for `sensor` in the builder
layer, providing a familiar name for the pattern.

## Consequences

- No new widget type needed in the renderer. Sensor handles both explicit
  size detection and responsive layout use cases.
- Responsive patterns follow idiomatic Elm architecture: measure, store in
  model, react in view. No special-casing.
- Trade-off: the first frame renders without size data. For most responsive
  layouts (sidebar collapse, grid column count), this is imperceptible.
- Elixir code is explicit about what happens at each size, making responsive
  behavior easy to test without the renderer.
