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
content and receives edit actions:

```elixir
# In view:
text_editor("notes",
  initial_content: model.notes_text,
  on_action: "notes_edited",
  placeholder: "Write something...",
  height: 300
)
```

When the user types, the renderer sends the current text back:

```elixir
def update(model, {:editor_action, "notes", %{text: text}}) do
  %{model | notes_text: text}
end
```

The renderer owns the cursor position, selection, and undo stack. Elixir
owns the logical text content. On renderer restart, the initial_content
prop restores the buffer.

For programmatic edits (insert text, move cursor), use commands:

```elixir
Julep.Command.editor_insert("notes", "inserted text")
Julep.Command.editor_move_cursor("notes", :end)
Julep.Command.editor_select_all("notes")
```

### combo_box

The renderer maintains filter text and the filtered option list:

```elixir
# In view:
combo_box("language",
  options: ["Elixir", "Rust", "Python", "Go", "Ruby"],
  selected: model.language,
  on_selected: "language_selected",
  placeholder: "Search languages..."
)
```

Elixir provides the full option list and the selected value. The renderer
handles filtering as the user types. When an option is selected:

```elixir
def update(model, {:select, "language", value}) do
  %{model | language: value}
end
```

If the option list changes (e.g., loaded from an API), update the
`options` prop and the renderer rebuilds its filter state.

### pane_grid

The renderer maintains pane layout and sizes:

```elixir
# In view:
pane_grid("editor_panes",
  panes: %{
    "left" => editor_panel(model, :left),
    "right" => editor_panel(model, :right)
  },
  on_resize: "panes_resized",
  on_drag: "pane_dragged",
  spacing: 4
)
```

Pane content is driven by Elixir (the values in the `panes` map). Pane
layout (which pane is where, relative sizes) is managed by the renderer.

Resize and drag events notify Elixir if you need to react:

```elixir
def update(model, {:pane_resized, "editor_panes", layout}) do
  %{model | pane_layout: layout}
end
```

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

# Preserved: track scroll position in model.
scrollable "list", on_scroll: "list_scrolled" do ... end

def update(model, {:scroll, "list", offset}) do
  %{model | list_scroll: offset}
end

# Restore via command when navigating back:
def update(model, {:click, "back_to_list"}) do
  {%{model | screen: :list},
   Julep.Command.scroll_to("list", model.list_scroll)}
end
```

The default is ephemeral (renderer owns it). Opt in to preservation by
handling the scroll event and storing the value.
