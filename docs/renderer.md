# Renderer

`julep_gui` is a standalone Rust binary that renders julep UI trees using the
[iced](https://github.com/iced-rs/iced) toolkit (currently v0.14).

## What it does

1. Reads JSONL messages from stdin (snapshots and patches).
2. Maintains a retained tree of UI nodes.
3. Maps each node type to an iced widget.
4. Renders the widget tree using iced's reactive rendering.
5. Captures user interactions (clicks, input, etc.).
6. Writes events to stdout as JSONL.
7. Handles native effect requests (file dialogs, clipboard, etc.).

## What it does not do

- Contain any app-specific logic.
- Validate business rules.
- Make decisions about state.
- Communicate with anything other than stdin/stdout.

The renderer is a generic display server. Give it a tree, it paints it.
Give it events, it forwards them. That is the contract.

## Architecture

The renderer is a single iced application with these responsibilities:

### stdin reader (background thread)

A dedicated thread reads lines from stdin, parses JSON, and sends parsed
messages to the main iced application via an `mpsc` channel. This keeps
stdin I/O off the main thread.

### tree store

A retained copy of the current UI tree. Updated by snapshot (full replace)
or patch (incremental ops). The tree is the single source of truth for
what gets rendered.

### widget mapper

A dispatch layer that walks the tree and maps each node's `type` to the
corresponding iced widget. For example:

- `"text"` -> `iced::widget::text`
- `"button"` -> `iced::widget::button`
- `"column"` -> `iced::widget::column`
- `"table"` -> `iced::widget::table`

Props are read from the node and passed to the widget constructor. Unknown
props are ignored. Unknown types render as empty containers with a debug
label.

### event emitter

When a user interacts with a widget, the renderer constructs a JSON event
object and writes it to stdout. The event includes the node ID, event
family, and any relevant data (input value, toggle state, etc.).

### effect handler

Native platform operations (file dialogs, clipboard, notifications) are
triggered by `effect_request` messages from Elixir. The renderer executes
them using platform APIs and sends `effect_response` messages back.

## Widget type mapping

### Direct iced widgets

These map 1:1 to iced built-in widgets:

| Node type | Iced widget |
|---|---|
| `text` | `text` |
| `text_input` | `text_input` |
| `text_editor` | `text_editor` |
| `button` | `button` |
| `checkbox` | `checkbox` |
| `toggler` | `toggler` |
| `radio` | `radio` |
| `slider` | `slider` |
| `vertical_slider` | `vertical_slider` |
| `pick_list` | `pick_list` |
| `combo_box` | `combo_box` |
| `container` | `container` |
| `column` | `column` |
| `row` | `row` |
| `scrollable` | `scrollable` |
| `space` | `space` |
| `rule` | `rule` |
| `progress_bar` | `progress_bar` |
| `tooltip` | `tooltip` |
| `image` | `image` |
| `svg` | `svg` |
| `markdown` | `markdown` |
| `canvas` | `canvas` |
| `table` | `table` |
| `stack` | `stack` |
| `grid` | `grid` |

### Composite widgets

These are assembled from iced primitives by the renderer. They encode
common desktop UI patterns:

| Node type | Built from | Description |
|---|---|---|
| `window` | Container + window management | Top-level window |
| `tabs` | Row of buttons + content swap | Tab bar |
| `nav` | Column of buttons | Navigation sidebar |
| `modal` | Float/overlay + container | Modal dialog |
| `card` | Container with header/body | Content card |
| `panel` | Collapsible container | Expandable section |
| `form` | Column + labeled fields | Form layout |
| `split_pane` | Row with drag handle | Resizable panes |

Composite widgets exist to save app developers from manually assembling
common patterns. They are convenience, not magic -- the same result can
always be achieved with direct iced widgets.

## Theming

The renderer supports iced's built-in theme system. Themes can be set at
the window level or overridden per-subtree using the `theme` prop.

Built-in themes include Light, Dark, and ~30 community palettes (Dracula,
Catppuccin, Nord, Tokyo Night, etc.). Custom themes can be defined via a
palette prop.

## Multi-window

Iced 0.14 supports multiple windows natively. The renderer can manage
multiple windows, each driven by a separate window node in the tree.
Window open/close/configure operations are driven by the tree: if a window
node appears in the tree, it opens; if it disappears, it closes.

## Widget state continuity

The renderer maintains local state for stateful widgets:

- Text input cursor position and selection
- Combo box filter text
- Text editor content and cursor
- Scroll positions
- Focus state

This state is keyed by node ID. As long as the ID stays stable across
renders, widget state persists. If the ID changes, state is reset.

## Building

```bash
# Debug build
cargo build --manifest-path native/julep_gui/Cargo.toml

# Release build
cargo build --manifest-path native/julep_gui/Cargo.toml --release
```

The binary can also be built automatically by `mix julep.gui --build`.

## Testing the renderer in isolation

Since the renderer speaks JSONL, it can be tested without Elixir:

```bash
echo '{"type":"snapshot","tree":{"id":"root","type":"column","props":{},"children":[{"id":"hello","type":"text","props":{"content":"Hello, world!"},"children":[]}]}}' | ./julep_gui
```

Pipe JSON fixtures in, observe the window. Useful for visual regression
testing and renderer development.
