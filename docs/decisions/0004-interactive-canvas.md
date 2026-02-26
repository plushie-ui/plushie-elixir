# 0004: Interactive canvas via Program trait

## Status

Accepted.

## Context

Canvas currently renders shapes from props (stateless). Users need mouse and
touch interaction for custom drawing -- charts, diagrams, games, and similar.
iced's `canvas::Program` trait provides an `update()` method for event
handling within the canvas widget, which is the natural extension point.

## Decision

Implement `canvas::Program::update()` in the renderer. Canvas gets a
`CanvasState` for interaction tracking. Events are opt-in via props:
`interactive`, `on_press`, `on_release`, `on_move`, `on_scroll`. All
coordinates are canvas-relative.

Canvas serves as the Tier 1 custom widget escape hatch -- the primary
mechanism for users to build arbitrary interactive visuals without writing
Rust.

## Consequences

- Users can build arbitrary interactive visuals (charts, diagrams, custom
  controls) without writing Rust.
- The renderer owns ephemeral interaction state (cursor position, drag
  tracking). Elixir owns semantic state (what shapes to draw, what events
  mean).
- Event props are opt-in, so non-interactive canvases carry no overhead.
- This establishes canvas as the first tier in the custom widget strategy
  (see ADR 0007).
