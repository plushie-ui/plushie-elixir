# 0005: PaneGrid as a stateful widget with renderer-owned layout

## Status

Accepted.

## Context

iced's PaneGrid requires persistent `State<T>` for layout tracking (pane
positions, sizes, splits). Elixir cannot hold Rust structs across the JSONL
boundary. This is the same problem encountered with `text_editor` and
`combo_box`, which was solved by keeping mutable state in the renderer and
syncing via events and widget ops.

## Decision

Follow the established stateful widget pattern. The renderer owns a
`HashMap<String, pane_grid::State<String>>` keyed by widget ID. Pane content
comes from children matched by pane ID. Layout mutations (drag to resize,
drag to reorder) happen in Rust and emit events to Elixir. Structural
operations (split, close, swap) are driven from Elixir via `widget_op`
messages.

## Consequences

- Consistent with the `text_editor` and `combo_box` patterns. One pattern
  for all stateful widgets.
- Layout state is ephemeral -- it resets if the renderer restarts. This is
  acceptable because Elixir replays the current snapshot on reconnect, and
  pane structure (which panes exist) is Elixir-owned.
- Elixir owns pane content and structure; the renderer owns positions and
  sizes. Clear ownership boundary.
