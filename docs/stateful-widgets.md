# Stateful widgets

Most iced widgets are stateless -- the Elixir side owns all data and the
renderer just paints it. But a few widgets maintain renderer-side state
that cannot be driven purely from the tree. These need special handling.

## The problem

Iced's `text_editor`, `combo_box`, and `pane_grid` each hold internal
state:

- **text_editor** has a `Content` buffer with cursor position, selection,
  undo history, and the actual text. Edits are applied via `Action` values
  in the update function.
- **combo_box** has a `State` that holds the option list and current filter
  text.
- **pane_grid** has a `State` that tracks pane layout, sizes, and focus.

In native iced, these live in your app's state struct and are passed by
reference to the widget. In julep, the Elixir side cannot hold Rust
structs. The state lives in the renderer process.

## How julep handles it

### text_editor

The renderer maintains the `Content` buffer. Elixir provides initial
content via the `content` prop and receives the full text on every edit:

```elixir
# In view:
text_editor("notes",
  content: model.notes_text,
  placeholder: "Write something...",
  height: 300
)
```

When the user types, the renderer applies the edit action internally,
then sends the entire text back as a `%Widget{type: :input, id: id, value: text}` event --
the same family as `text_input`:

```elixir
def update(model, %Widget{type: :input, id: "notes", value: text}) do
  %{model | notes_text: text}
end
```

The renderer owns the cursor position, selection, and undo stack. Elixir
owns the logical text content. The `content` prop seeds the `Content`
buffer on first render; subsequent prop changes do not overwrite an
existing buffer (the renderer keeps its own state for the lifetime of
the widget).

Additional text_editor props supported by the renderer: `font`, `size`,
`line_height`, `padding` (uniform), `min_height`, `max_height`,
`wrapping`, `width` (in pixels), `style`.

### combo_box

The renderer maintains `combo_box::State<String>` with the option list
and filter text:

```elixir
# In view:
combo_box("language",
  options: ["Elixir", "Rust", "Python", "Go", "Ruby"],
  selected: model.language,
  placeholder: "Search languages..."
)
```

Elixir provides the full option list and the selected value. The renderer
handles filtering as the user types. Two event families fire:

- `%Widget{type: :input, id: "language", value: filter_text}` -- as the user types in the search
  field (only if the renderer wires `on_input`, which it does by default).
- `%Widget{type: :select, id: "language", value: value}` -- when an option is selected.

```elixir
def update(model, %Widget{type: :select, id: "language", value: value}) do
  %{model | language: value}
end
```

Additional combo_box props: `width`, `padding`, `size`, `font`,
`line_height`, `menu_height`.

Option changes are detected and applied dynamically. The renderer
compares the incoming `options` prop against the current State on each
render pass and updates the option list when changes are found.

### pane_grid

The renderer maintains `pane_grid::State<String>` for pane layout and
sizes. Children define the initial pane configuration:

```elixir
# In view:
pane_grid("editor_panes", spacing: 4) do
  container("left", padding: 8) do
    editor_panel(model, :left)
  end
  container("right", padding: 8) do
    editor_panel(model, :right)
  end
end
```

Each child's ID becomes a pane identifier in the State. On first render,
the renderer creates an initial layout by splitting panes vertically in
order.

Three event families fire:

- `{:pane_clicked, "editor_panes", pane_id}` -- a pane was clicked.
- `{:pane_resized, "editor_panes", split_id, ratio}` -- a split divider
  was dragged; `ratio` is the new split position (0.0-1.0).
- `{:pane_dragged, "editor_panes", source_pane, target_pane}` -- a pane
  was drag-and-dropped onto another.

```elixir
def update(model, {:pane_resized, "editor_panes", _split, _ratio}) do
  # Layout is managed by the renderer; acknowledge or ignore
  model
end
```

Pane operations are available as commands:

```elixir
Julep.Command.pane_split("editor_panes", "left", :horizontal, "bottom")
Julep.Command.pane_close("editor_panes", "left")
Julep.Command.pane_swap("editor_panes", "left", "right")
Julep.Command.pane_maximize("editor_panes", "left")
Julep.Command.pane_restore("editor_panes")
```

Additional pane_grid props: `width`, `height`.

## Design principle

For stateful widgets, the split is:

- **Elixir owns the semantic state.** The text content, the selected
  option, the pane contents. This is what gets saved, serialized, and
  tested.
- **The renderer owns the interaction state.** Cursor position, filter
  text, pane sizes, undo stacks. This is ephemeral -- it resets on
  renderer restart and is not part of the app model.

This means:

1. Tests work without the renderer. You test the text content, the
   selected value, the pane configuration -- not cursor positions.
2. Renderer restart is graceful. Elixir resends the semantic state via
   props. The renderer rebuilds its interaction state from there.
3. The boundary is clear. If you need to persist something, it goes in
   the Elixir model. If it is ephemeral UI state, the renderer owns it.

## When state ownership is ambiguous

Sometimes it is unclear whether state is "semantic" or "interaction."
Scroll position is a good example -- is it part of the app state (restore
it on navigation) or ephemeral (let it reset)?

The answer depends on the app. Julep provides both options:

```elixir
# Ephemeral: renderer manages scroll, resets on navigation.
# Just use scrollable normally.
scrollable "list" do ... end

# Preserved: track scroll position in model via a future on_scroll callback.
# For now, use commands to restore position:
def update(model, %Widget{type: :click, id: "back_to_list"}) do
  {%{model | screen: :list},
   Julep.Command.scroll_to("list", model.list_scroll)}
end
```

The default is ephemeral (renderer owns it). Opt in to preservation by
storing scroll offsets in the model and restoring them via commands when
navigating back.
