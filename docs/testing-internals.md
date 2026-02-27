# Testing internals

Contributor guide for people working on the test framework itself. If you
are building an app with julep, see [testing.md](testing.md) instead.


## Architecture

```
                         +--------------------+
                         | Julep.Test.Case     |
                         | (ExUnit template)   |
                         +--------+-----------+
                                  |
                         imports  |
                                  v
                         +--------------------+
                         | Julep.Test.Helpers  |
                         | (find, click, ...)  |
                         +--------+-----------+
                                  |
                         reads    | process dict
                                  v
                         +--------------------+
                         | Julep.Test.Session  |
                         | (backend + pid)     |
                         +--------+-----------+
                                  |
                         delegates|
                                  v
                    +-------------+-------------+
                    |             |              |
           +--------+--+  +------+-----+  +-----+------+
           | Backend.Sim|  |Backend.    |  |Backend.    |
           | (GenServer)|  |Headless    |  |Full        |
           |            |  |(GenServer) |  |(GenServer) |
           +-----+------+  +-----+-----+  +-----+-----+
                 |                |              |
           pure Elixir      Port: julep_gui  Port: julep_gui
           EventMap         --headless       --test
           process_commands  JSONL protocol   JSONL protocol
                                              real iced windows
```

### Data flow

1. `Julep.Test.Case` calls `Session.start(app, backend: mod)` in the
   `setup` block. The session is stored in the process dictionary.

2. `Julep.Test.Helpers` functions (imported into the test module) read the
   session from the process dictionary and delegate to `Session`.

3. `Session` delegates every call to the backend module, passing its `pid`.

4. Each backend is a `GenServer` that manages app state (`model`, `tree`)
   and handles interactions differently:
   - **Sim** runs `init/update/view` locally, uses `EventMap` to infer
     events, and executes commands synchronously.
   - **Headless** spawns `julep_gui --headless` via Port, sends JSONL
     queries, and processes responses asynchronously via correlation IDs.
   - **Full** spawns `julep_gui --test` via Port, same JSONL protocol as
     headless but with real iced windows and GPU rendering.


## Backend behaviour

`Julep.Test.Backend` defines 16 callbacks that every backend must implement:

| Callback | Signature | Purpose |
|---|---|---|
| `start/2` | `(app, opts) -> {:ok, pid}` | Start the backend process |
| `stop/1` | `(pid) -> :ok` | Stop the backend process |
| `find/2` | `(pid, selector) -> Element.t \| nil` | Find element, return nil |
| `find!/2` | `(pid, selector) -> Element.t` | Find element, raise if missing |
| `click/2` | `(pid, selector) -> :ok` | Click a widget |
| `type_text/3` | `(pid, selector, text) -> :ok` | Type text into a widget |
| `submit/2` | `(pid, selector) -> :ok` | Submit a text input |
| `toggle/2` | `(pid, selector) -> :ok` | Toggle checkbox/toggler |
| `select/3` | `(pid, selector, value) -> :ok` | Select from pick_list/radio/combo_box |
| `slide/3` | `(pid, selector, value) -> :ok` | Slide a slider to a value |
| `model/1` | `(pid) -> term` | Get current model |
| `tree/1` | `(pid) -> map` | Get current normalized tree |
| `snapshot/2` | `(pid, name) -> Snapshot.t` | Capture structural snapshot |
| `screenshot/2` | `(pid, name) -> Screenshot.t` | Capture pixel screenshot |
| `reset/1` | `(pid) -> :ok` | Reset to initial state |
| `await_async/3` | `(pid, tag, timeout) -> :ok` | Wait for async task |


## How to add a new widget to EventMap

When a new widget type is added to julep that should support interactions
in the sim backend:

1. Add clauses to the appropriate function in
   `lib/julep/test/event_map.ex`. Each interaction type (`click`, `input`,
   `submit`, `toggle`, `select`, `slide`) is a separate function.

2. The clause should pattern-match on the element's `type` field and
   return `{:ok, event_tuple}` or `{:error, reason}`.

3. For widgets that do not support an interaction, add an error clause
   with a helpful message:

   ```elixir
   def click(%Element{type: "my_widget"}),
     do: {:error, "cannot click a my_widget -- use toggle/1 instead"}
   ```

4. Update the EventMap inference table in the module's `@moduledoc`.

5. The headless and full backends do not use EventMap -- they inject
   interactions via the JSONL protocol and the Rust renderer generates the
   real events. Ensure the Rust side handles the new widget type in
   `headless.rs` and `test_mode.rs`.


## How to add a new interaction type

To add a new kind of user interaction (beyond click, type_text, submit,
toggle, select, slide):

1. Add a callback to `Julep.Test.Backend` behaviour:
   ```elixir
   @callback my_action(session :: pid(), selector :: selector(), ...) :: :ok
   ```

2. Add a delegation function to `Julep.Test.Session`.

3. Add a helper function to `Julep.Test.Helpers` that reads the session
   from the process dictionary and delegates.

4. Implement the callback in all three backends:
   - **Sim:** Add an `EventMap` function and a `handle_call` clause.
   - **Headless:** Add a `handle_call` clause that sends an `interact`
     JSONL message with the new action name.
   - **Full:** Same as headless.

5. On the Rust side, handle the new action in the interact message
   handler in `headless.rs` and `test_mode.rs`.

6. Add a script instruction if it makes sense (see below).


## How to add a new assertion

Assertions live in `Julep.Test.Helpers`. There are two patterns:

**Macro assertions** (for ExUnit-style error messages with file/line info):

```elixir
defmacro assert_foo(selector, expected) do
  quote do
    element = Julep.Test.Helpers.find!(unquote(selector))
    # ... assertion logic ...
    :ok
  end
end
```

**Function assertions** (simpler, for golden-file workflows):

```elixir
@spec assert_foo(name :: String.t()) :: :ok
def assert_foo(name) do
  # capture, compare, fail or pass
end
```

Both patterns should return `:ok` on success and raise
`ExUnit.AssertionError` on failure.


## How to add a new script instruction

1. Add the instruction type to `@type instruction` in
   `lib/julep/test/script.ex`.

2. Add a `parse_instruction/1` clause that tokenizes the line and returns
   `{:ok, {:my_instruction, args...}}`.

3. Add an `execute/3` clause in `lib/julep/test/script/runner.ex` that
   executes the instruction against a session. Return `:ok` or
   `{:error, reason}`.

4. Document the instruction in `docs/testing.md` in the instructions table,
   including whether it works on the sim backend.


## How to add a new backend

1. Create a new module implementing `Julep.Test.Backend` with all 16
   callbacks.

2. Register it in the `@backend_map` in both `Julep.Test.Case` and
   `Julep.Test.Script.Runner` if it should be selectable by atom shorthand.

3. All existing tests should pass on the new backend without modification
   (that is the contract). If they do not, the backend has a bug or the
   behaviour specification needs updating.


## EventMap inference table

The sim backend uses `Julep.Test.EventMap` to infer what event a widget
interaction should produce. This table must stay in sync with the Rust
renderer's actual event generation.

| Widget | `click` | `input` | `submit` | `toggle` | `select` | `slide` |
|---|---|---|---|---|---|---|
| `button` | `{:click, id}` | error | error | error | error | error |
| `checkbox` | error (use toggle) | error | error | `{:toggle, id, !is_checked}` | error | error |
| `toggler` | error (use toggle) | error | error | `{:toggle, id, !is_toggled}` | error | error |
| `radio` | error | error | error | error | `{:select, group, value}` | error |
| `text_input` | error | `{:input, id, text}` | `{:submit, id, props["value"]}` | error | error | error |
| `text_editor` | error | `{:input, id, text}` | error | error | error | error |
| `slider` | error | error | error | error | error | `{:slide, id, value}` |
| `vertical_slider` | error | error | error | error | error | `{:slide, id, value}` |
| `pick_list` | error | error | error | error | `{:select, id, value}` | error |
| `combo_box` | error | error | error | error | `{:select, id, value}` | error |

"error" means the function returns `{:error, message}` with an actionable
hint about which function to use instead (when applicable).


## Sim backend internals

The sim backend (`lib/julep/test/backend/sim.ex`) is a GenServer that
manages the app lifecycle entirely in Elixir.

### Initialization

1. Calls `app.init(opts)` to get the initial model (and optional commands).
2. Processes any init commands via `process_commands/4`.
3. Calls `app.view(model)` and normalizes the tree via `Julep.Tree.normalize/1`.

### Interaction flow

1. `find_in_tree/2` locates the target element by selector (ID or text).
2. The appropriate `EventMap` function infers the event tuple.
3. `dispatch_update/3` calls `app.update(model, event)` and normalizes the
   return value (bare model or `{model, commands}`).
4. `process_commands/4` executes any returned commands:
   - `:async` -- calls the function synchronously, dispatches the result
     as `{tag, result}` through `update/2`.
   - `:stream` -- calls the function synchronously with an `emit` callback,
     drains emitted messages, dispatches each through `update/2`, then
     dispatches the final return value.
   - `:done` -- calls the mapper on the value, dispatches the result.
   - `:batch` -- recursively processes the list of commands.
   - `:none` -- no-op.
   - All other command types (focus, scroll, window ops, timers, cancel) --
     silently skipped.
5. Re-renders the tree via `app.view(model)`.

### Command execution depth limit

`process_commands/4` tracks recursion depth and stops at 100 to prevent
infinite command loops (e.g., an async that triggers another async that
triggers another...).

### Tree search

Two search strategies:

- **By ID** (`"#foo"`) -- strips the `#` prefix and walks the tree
  depth-first, comparing against each node's `:id` or `"id"` key.
- **By text** (`"Click me"`) -- walks depth-first, creates an `Element`
  from each node, and checks `Element.text/1` for a match.


## Headless backend internals

The headless backend (`lib/julep/test/backend/headless.ex`) spawns
`julep_gui --headless` as a Port.

### Protocol

Communication uses JSONL (one JSON object per line) with correlation IDs.
Each request includes an `"id"` field (e.g., `"req_1"`). The renderer
echoes the same `"id"` in its response. The GenServer maintains a `pending`
map from ID to `{type, from}` or `{type, from, extra}` tuples.

### Message types

**Outgoing (Elixir to Rust):**

| Type | Purpose |
|---|---|
| `snapshot` | Send the full tree for rendering |
| `query` (target: `find`) | Find an element by selector |
| `query` (target: `tree`) | Get the full rendered tree |
| `interact` | Simulate a user interaction |
| `snapshot_capture` | Capture a structural snapshot |
| `reset` | Reset renderer state |

**Incoming (Rust to Elixir):**

| Type | Purpose |
|---|---|
| `query_response` | Response to a query |
| `interact_response` | Response with generated events |
| `snapshot_response` | Snapshot hash and optional RGBA data |
| `reset_response` | Acknowledgement of reset |
| `event` | Asynchronous event from the renderer |

### Event dispatching

When an `interact_response` includes events, the headless backend decodes
each event (e.g., `{"event": "click", "id": "my_btn"}` becomes
`{:click, "my_btn"}`), dispatches it through `app.update/2`, re-renders the
tree, and sends the updated tree back to the renderer.

### Screenshot behaviour

The headless backend returns an empty `Screenshot` struct (hash `""`,
size `{0, 0}`, no RGBA data). `Screenshot.assert_match/2` silently accepts
empty hashes, making `assert_screenshot` a no-op on headless.


## Full backend internals

The full backend (`lib/julep/test/backend/full.ex`) is structurally
identical to the headless backend but spawns `julep_gui --test` instead of
`--headless`. The Rust renderer runs a real `iced::daemon` with GPU
rendering alongside the test protocol message handler.

Key differences from headless:

- Real windows open and render via wgpu.
- Effects (file dialogs, clipboard, notifications) actually work.
- Subscriptions fire normally.
- Screenshots could capture real GPU-rendered RGBA pixels (currently returns
  empty screenshots -- this is a known gap to be filled).
- Longer GenServer call timeouts (15s vs 10s) due to GPU initialization.


## How snapshots work

### Structural snapshots (`Snapshot`)

1. The backend serializes the current tree to JSON.
2. SHA-256 hash of the JSON bytes produces the snapshot hash.
3. `Snapshot.assert_match/2` compares against a golden `.sha256` file in
   `test/snapshots/`.
4. First run: writes the golden file.
5. Subsequent runs: reads the golden file and compares hashes.
6. `JULEP_UPDATE_SNAPSHOTS=1`: overwrites the golden file.

The sim backend hashes the tree JSON directly. The headless and full
backends send a `snapshot_capture` message to the renderer and receive the
hash in the response.

### Pixel screenshots (`Screenshot`)

1. The backend captures RGBA pixel data (only meaningful on full backend).
2. SHA-256 hash of the pixel data produces the screenshot hash.
3. `Screenshot.assert_match/2` works the same as `Snapshot.assert_match/2`
   but uses `test/screenshots/` and `JULEP_UPDATE_SCREENSHOTS`.
4. Empty hashes (from sim/headless) are silently accepted without creating
   or checking golden files.

### JSON tree snapshots (`Julep.Test.assert_tree_snapshot/2`)

1. The tree map is normalized (map keys sorted recursively for stable
   output).
2. Encoded to pretty-printed JSON.
3. Compared byte-for-byte against a stored `.json` file.
4. First run or `JULEP_UPDATE_SNAPSHOTS=1`: writes the file.
5. Subsequent runs: fails with a diff showing stored vs current.

This is a standalone function in `Julep.Test` -- it does not use backends,
sessions, or the test framework at all.


## Source file index

| File | Purpose |
|---|---|
| `lib/julep/test.ex` | `assert_tree_snapshot/2` for unit-level JSON tree comparison |
| `lib/julep/test/backend.ex` | `Backend` behaviour (16 callbacks) |
| `lib/julep/test/backend/sim.ex` | Pure Elixir backend, EventMap-based event inference |
| `lib/julep/test/backend/headless.ex` | Rust renderer via `--headless` Port, JSONL protocol |
| `lib/julep/test/backend/full.ex` | Real iced windows via `--test` Port, JSONL protocol |
| `lib/julep/test/case.ex` | ExUnit case template, backend resolution, setup/teardown |
| `lib/julep/test/helpers.ex` | Imported helper functions (find, click, assert_text, ...) |
| `lib/julep/test/session.ex` | Session facade wrapping backend module + pid |
| `lib/julep/test/element.ex` | Element struct (id, type, props, children), text extraction |
| `lib/julep/test/snapshot.ex` | Structural snapshot struct, golden file comparison |
| `lib/julep/test/screenshot.ex` | Pixel screenshot struct, golden file comparison |
| `lib/julep/test/event_map.ex` | Widget type to event inference for sim backend |
| `lib/julep/test/script.ex` | `.julep` script parser |
| `lib/julep/test/script/runner.ex` | Script execution engine |
| `native/julep_gui/src/julep_core.rs` | Core struct (tree, caches, subscriptions) |
| `native/julep_gui/src/headless.rs` | `--headless` mode: Core + JSONL, no iced runtime |
| `native/julep_gui/src/test_mode.rs` | `--test` mode: real iced::daemon + test protocol |
| `test/support/mock_bridge.ex` | Test double tracking bridge calls |
| `test/support/integration_case.ex` | ExUnit case template for integration tests |
