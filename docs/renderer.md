# Renderer

`julep` is a standalone Rust binary (in the sibling `julep`
repository) that renders julep UI trees using the
[julep-iced](https://github.com/julep-ui/julep-iced) toolkit (v0.6.0).

## What it does

1. Reads messages from stdin (MessagePack by default, or JSONL) (snapshots and patches).
2. Maintains a retained tree of UI nodes.
3. Maps each node type to an iced widget.
4. Renders the widget tree using iced's reactive rendering.
5. Captures user interactions (clicks, input, etc.).
6. Writes events to stdout (MessagePack by default, or JSONL).
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

A dedicated thread reads from stdin, parses messages (MessagePack by default, or JSONL), and sends parsed
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
triggered by `effect` messages from Elixir. The renderer executes
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
| `rich_text` | `rich_text` |
| `pane_grid` | `pane_grid` |
| `keyed_column` | `keyed_column` |
| `mouse_area` | `mouse_area` |
| `sensor` | `sensor` |
| `pin` | `pin` |
| `float` | `float` |
| `themer` | `Themer` |

### Composite widgets

The renderer assembles these from iced primitives:

| Node type | Built from | Description |
|---|---|---|
| `window` | Container + window management | Top-level window |
| `qr_code` | `canvas` + `qrcode` crate | QR rendered via `canvas::Program` |
| `overlay` | Custom `OverlayWrapper` widget impl | Positions child as floating overlay |
| `responsive` | `sensor` + `container` | Wraps children in a sensor so Elixir receives resize events |

Note: The UI-only composites (tabs, nav, modal, card, panel, form,
split_pane) were removed. Apps build these patterns directly using iced
primitives via `Julep.UI` or the widget layer.

## Theming

The renderer supports iced's built-in theme system. Themes can be set at
the window level or overridden per-subtree using the `theme` prop.

Built-in themes include Light, Dark, and ~30 community palettes (Dracula,
Catppuccin, Nord, Tokyo Night, etc.). Custom themes can be defined via a
palette prop.

## Multi-window

Iced supports multiple windows natively. The renderer can manage
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

## Feature flags

Widget features can be toggled at compile time via Cargo features. By
default all built-in widgets are enabled via the `builtin-all` feature.

| Feature | Iced feature | Widget |
|---|---|---|
| `widget-image` | `iced/image` | `image` |
| `widget-svg` | `iced/svg` | `svg` |
| `widget-canvas` | `iced/canvas` | `canvas` |
| `widget-markdown` | `iced/markdown` | `markdown` |
| `widget-highlighter` | `iced/highlighter` | TextEditor syntax highlighting |
| `widget-sysinfo` | `iced/sysinfo` | `get_system_info` command |
| `widget-qr-code` | `iced/canvas` + `qrcode` crate | `qr_code` |

When a feature is disabled, the renderer renders a placeholder error text
for that widget type. Platform features (`dialogs`, `clipboard`,
`notifications`) are always included in the default build.

On the Elixir side, `Julep.Features` resolves the configured feature set
from the renderer's Cargo feature flags. Widget features are controlled
at compile time via the Cargo.toml `[features]` table.

## Building

```bash
# Debug build (all features)
cd ../julep && cargo build

# Release build
cd ../julep && cargo build --release

```

The binary can also be built automatically by `mix julep.gui --build`.

## Testing the renderer in isolation

Since the renderer speaks MessagePack (or JSONL), it can be tested without Elixir:

```bash
echo '{"type":"snapshot","tree":{"id":"root","type":"column","props":{},"children":[{"id":"hello","type":"text","props":{"content":"Hello, world!"},"children":[]}]}}' | ./julep
```

Pipe JSON fixtures in, observe the window. Useful for visual regression
testing and renderer development.

## Debugging the renderer

The renderer uses the standard Rust `log` + `env_logger` crate pair. All log
output goes to stderr (stdout is reserved for the wire protocol). When
launched by Julep, the default log level is `error` (set via the `:log_level`
option). The renderer's own built-in default is `warn`.

### RUST_LOG environment variable

Set `RUST_LOG` to control verbosity. The renderer's crate name is `julep`:

```bash
# Show everything at debug level and above
RUST_LOG=julep=debug mix julep.gui MyApp

# Show only errors
RUST_LOG=julep=error mix julep.gui MyApp

# Per-module filtering
RUST_LOG=julep_core::widgets=debug,julep_core::engine=debug mix julep.gui MyApp

# Trace level (most verbose -- future use)
RUST_LOG=julep=trace mix julep.gui MyApp
```

### Elixir :log_level option

Set the renderer log level from Elixir without touching environment variables:

```elixir
# In your app startup
Julep.start(MyApp, log_level: :debug)

# Or via the mix task (always uses the default :error level)
```

The `:log_level` option translates to a `RUST_LOG` env var on the spawned
renderer Port. If `RUST_LOG` is already set in the environment, it takes
precedence.

### Log levels

| Level | What you see |
|-------|-------------|
| `error` | Decode failures, I/O errors, protocol violations, invariant breaks |
| `warn` | Unknown ops, cache misses, unexpected-but-recoverable state |
| `info` | Lifecycle events: codec negotiated, settings received, window open/close, fonts loaded |
| `debug` | Protocol traffic: snapshot/patch received, effect requests, widget ops, subscriptions |

### Output format

Log lines include a UTC timestamp, level, and module target:

```
[2026-02-28T12:34:56Z INFO  julep] wire codec: MsgPack
[2026-02-28T12:34:56Z INFO  julep] initial settings received
[2026-02-28T12:34:56Z DEBUG julep_core::engine] snapshot received (root id=main)
```

The module target (`julep_core::engine`, `julep_core::widgets`, etc.)
enables per-module filtering via `RUST_LOG`.
