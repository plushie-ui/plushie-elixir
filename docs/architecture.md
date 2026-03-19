# Architecture

Julep has three pieces. Everything else is optional layering on top of these.

## The three pieces

### 1. julep (Elixir library)

A Hex package that provides:

- `Julep.App` behaviour (init, update, view callbacks)
- `Julep.UI` module for building UI trees
- A runtime that manages app state and communicates with the renderer
- A `Port`-based bridge that spawns the renderer and speaks MessagePack (or JSONL)
- Mix tasks for development (`mix julep.gui`)
- Test helpers for asserting on UI trees without the renderer

Apps can optionally implement `settings/0` to configure renderer defaults
(default_font, default_text_size, antialiasing). Settings are sent once at
startup before the first snapshot.

This is the only piece app developers interact with directly.

### 2. julep (Rust binary)

A standalone executable that:

- Reads messages from stdin (MessagePack or JSONL) (snapshots and patches)
- Renders iced widgets based on the UI tree
- Writes user events to stdout (MessagePack or JSONL)
- Manages window lifecycle, theming, and input handling

The binary has no app-specific logic. It is a generic "display server" for
julep UI trees. It ships as a precompiled binary or can be built from source
via `cargo build`.

### 3. Consumer app (Mix project)

A normal Mix project that depends on `:julep` and implements `Julep.App`.
The demo app (`julep_demo`) is one such consumer.

## Data flow

```
+------------------+  msgpack/stdio (default) +------------------+
|                  |  --- snapshots/patches ->|                  |
|  Elixir runtime  |                         |  julep            |
|  (Julep.App)     |  <--- events ---------- |  (iced renderer) |
|                  |                         |                  |
+------------------+                         +------------------+
       |                                            |
  owns: state,                                 owns: event loop,
  logic, UI trees,                             rendering, input,
  effects requests                             window management
```

1. Elixir runtime calls `view(model)` to produce a UI tree (plain maps).
2. Runtime diffs the tree against the previous version.
3. Diff is encoded (MessagePack by default, or JSONL) and sent to the renderer via Port stdin.
4. Renderer applies the diff to its retained tree and repaints.
5. User interacts with the UI (clicks, types, etc.).
6. Renderer encodes the interaction as an event (MessagePack by default, or JSONL) and writes it to stdout.
7. Elixir runtime receives the event, calls `update(model, event)`.
8. Cycle repeats from step 1.

On first render (or after reconnect), a full snapshot is sent instead of a
diff. The renderer handles both transparently.

## Process model

Elixir is the primary process. It spawns the Rust renderer as a child via
`Port.open/2`. If the renderer crashes, Elixir detects the exit and can
restart it with bounded backoff, replaying the current snapshot.

This model supports:

- **mix task launch:** `mix julep.gui MyApp` compiles and runs the app.
- **IEx launch:** `Julep.start(MyApp)` from a running shell.
- **Library embedding:** start the runtime under your own supervisor for
  use cases like observability consoles or admin panels.
- **Testing without GUI:** run the app runtime with no renderer attached;
  assert on UI trees and event handling directly.

## What this is not

This is not a client-server architecture. There are no sockets, no
handshakes, no authentication between the processes. The renderer is a
child process that speaks stdio. The protocol is intentionally simple
because the trust boundary is the OS process -- not a network.

## Dev mode

Julep includes live code reloading. `Julep.DevServer` watches `lib/` via
`:file_system`, debounces rapid saves, recompiles via `Code.compile_file/1`,
and sends `:force_rerender` to the Runtime. The model is preserved; only
`view/1` is re-evaluated with the new code. See `docs/dev-mode.md`.

## Glossary

- **ui_node** -- A plain map with keys `id`, `type`, `props`, and `children` representing a single widget in the UI tree.
- **patch** -- A diff operation (replace_node, update_props, insert_child, remove_child) sent to the renderer to update the displayed tree incrementally.
- **snapshot** -- A complete UI tree sent to the renderer, used on initial render and after renderer restart.
- **command** -- A side-effect descriptor returned from `update/2` that the runtime executes asynchronously (e.g. async work, widget ops, window management).
- **subscription** -- A declarative specification of ongoing event sources (timers, keyboard, window events) that the runtime manages based on model state.
- **effect** -- A platform I/O operation (file dialog, clipboard, notification) requested via `Julep.Effects` and executed by the renderer.
- **event_tag** -- An atom or string identifier embedded in commands and returned in result events, used to correlate requests with responses.
- **widget_op** -- A command targeting a specific widget instance (focus, scroll_to, select_all) identified by widget ID.
- **session** -- A `Julep.Test.Session` struct wrapping a test backend module and process, providing the unified test interaction API.
- **backend** -- One of three `Julep.Test.Backend` implementations (mock, headless, full) that execute test interactions at different fidelity levels.
