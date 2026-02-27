# Testing

## Philosophy

Tests are documentation. They tell the next person how the feature works.

The Elm architecture makes julep apps unusually easy to test. `update/2` is
a pure function: model in, model out. `view/1` returns plain maps. No
mocks, no processes, no infrastructure needed for the core loop.

**Progressive fidelity.** Start fast, add confidence layers:

1. **Sim** (pure Elixir) -- millisecond tests for logic and tree structure.
2. **Headless** (Rust renderer, no display) -- protocol round-trips and
   tree-hash snapshots.
3. **Full** (real iced windows) -- GPU pixels, effects, subscriptions.

Most tests should be sim tests. Headless and full exist for the things
sim cannot catch: encoding bugs, rendering regressions, platform effects.


## Quick start

```elixir
defmodule MyApp.CounterTest do
  use Julep.Test.Case, app: MyApp.Counter

  test "clicking increment updates counter" do
    click("#increment")
    assert find!("#count") |> text() == "1"
  end
end
```

That is it. `Julep.Test.Case` starts a session, imports all helper
functions, and tears down on exit. The default backend is `:sim` -- no
Rust binary, no display server, no setup.


## Three backends

| | `:sim` | `:headless` | `:full` |
|---|---|---|---|
| **Module** | `Julep.Test.Backend.Sim` | `Julep.Test.Backend.Headless` | `Julep.Test.Backend.Full` |
| **Speed** | ~ms | ~100ms | ~seconds |
| **Rust binary?** | No | Yes (`--headless`) | Yes (`--test`) |
| **Display server?** | No | No | Yes (Xvfb in CI) |
| **Tests logic** | Yes | Yes | Yes |
| **Tests tree structure** | Yes | Yes | Yes |
| **Protocol round-trip** | No | Yes | Yes |
| **Pixel snapshots** | No | Tree-hash only | Real GPU pixels |
| **Effects** | Collected, not executed | Not executed | Executed |
| **Subscriptions** | Not active | Not active | Active |
| **Real windows** | No | No | Yes |
| **Dependencies** | None | `cargo build --features headless` | `cargo build --features test-mode`, Xvfb, mesa-vulkan-drivers |

### When to use each

- **`:sim`** -- Default for everything. Logic, tree assertions, event flow.
  Covers 90% of app testing.
- **`:headless`** -- When you need to verify the JSONL wire protocol
  encodes/decodes correctly, or when you want tree-hash snapshots to detect
  unintended structural changes across iced version bumps.
- **`:full`** -- When you need real GPU-rendered pixels, platform effects
  (file dialogs, clipboard, notifications), or subscription-driven
  behaviour. Use sparingly.


## Backend selection

The backend is resolved through a priority chain:

| Priority | Source | Example |
|---|---|---|
| 1 | Per-test tag | `@tag backend: :headless` |
| 2 | Module option | `use Julep.Test.Case, app: MyApp, backend: :headless` |
| 3 | Environment variable | `JULEP_TEST_BACKEND=headless mix test` |
| 4 | Application config | `config :julep, :test_backend, :sim` |
| 5 | Default | `:sim` |

You can use either the atom shorthand (`:sim`, `:headless`, `:full`) or
the full module name (`Julep.Test.Backend.Sim`, etc.).

```elixir
# Override a single test
@tag backend: :headless
test "protocol round-trip" do
  tree = tree()
  assert is_map(tree)
end

# Override the whole module
use Julep.Test.Case, app: MyApp, backend: :full

# Override via env for CI
# JULEP_TEST_BACKEND=headless mix test
```


## Finding and interacting with widgets

### Selectors

Two selector forms are supported:

- **`"#id"`** -- Find by widget ID. The `#` prefix is required.
- **`"text content"`** -- Find by text content (checks `content`, `label`,
  `value`, `placeholder` props in that order).

A third form exists for rendered backends:

- **`{:point, x, y}`** -- Find by pixel coordinates (headless/full only).

### Element handles

`find/1` and `find!/1` return a `Julep.Test.Element` struct:

```elixir
element = find!("#my-button")
element.id       # => "my-button"
element.type     # => "button"
element.props    # => %{"label" => "Click me", ...}
element.children # => [...]
```

Use `text/1` to extract the display text from an element:

```elixir
assert find!("#count") |> text() == "42"
```

`text/1` checks props in order: `content`, `label`, `value`, `placeholder`.

### Interaction functions

All interaction functions accept a selector (string) as the first argument.
They are imported automatically by `Julep.Test.Case`.

| Function | Widget types | Event produced |
|---|---|---|
| `click(selector)` | `button` | `{:click, id}` |
| `type_text(selector, text)` | `text_input`, `text_editor` | `{:input, id, text}` |
| `submit(selector)` | `text_input` | `{:submit, id, value}` |
| `toggle(selector)` | `checkbox`, `toggler` | `{:toggle, id, !current}` |
| `select(selector, value)` | `pick_list`, `combo_box`, `radio` | `{:select, id_or_group, value}` |
| `slide(selector, value)` | `slider`, `vertical_slider` | `{:slide, id, value}` |

Interacting with the wrong widget type raises an error. For example,
`click("#my-checkbox")` will raise because checkboxes respond to `toggle`,
not `click`.


## Assertions

### Text assertions

```elixir
# Via assert + find! + text()
assert find!("#count") |> text() == "42"

# Via assert_text macro (finds + compares in one step)
assert_text "#count", "42"
```

### Existence assertions

```elixir
# Widget exists
assert_exists "#my-button"

# Widget does not exist (e.g., conditionally rendered)
assert_not_exists "#admin-panel"
```

### Model inspection

```elixir
# Access the current model directly
assert model().count == 5
assert model().loading == false
```

### Tree inspection

```elixir
# Get the full normalized tree
tree = tree()
assert tree["type"] == "column"
```


## Pixel regression testing

Pixel snapshots catch visual regressions that tree-level assertions miss.
They are most valuable when bumping iced versions or changing the renderer.

### Golden file workflow

```elixir
# In a test using :headless or :full backend
@tag backend: :headless
test "counter renders correctly" do
  click("#increment")
  assert_snapshot("counter-at-1")
end
```

`assert_snapshot/1` does the following:

1. Calls `snapshot/1` to capture the current rendered state.
2. Looks for a golden file at `test/snapshots/<name>.sha256`.
3. **First run:** Creates the golden file with the SHA-256 hash. Test passes.
4. **Subsequent runs:** Compares the current hash against the stored hash.
   If they match, the test passes. If they differ, the test fails with a
   diff showing both hashes.

### Updating golden files

When the visual change is intentional:

```bash
JULEP_UPDATE_SNAPSHOTS=1 mix test
```

This overwrites all golden files with current hashes.

### What gets hashed

- **Headless backend:** SHA-256 of the serialized tree JSON. This catches
  structural changes but not pixel-level rendering differences.
- **Full backend:** SHA-256 of the actual RGBA pixel data from the GPU.
  This catches any visual change, including font rendering, spacing, and
  anti-aliasing differences.

### When to use pixel regression

- After bumping the iced dependency version.
- When changing the renderer's widget rendering code.
- When modifying the theme system or color handling.
- When you need absolute confidence that "it looks the same."


## The simulated backend (`:sim`)

The sim backend runs your app's `init/update/view` loop entirely in Elixir.
No Rust, no Port, no external process.

### How it works

1. Calls `app.init(opts)` to get the initial model.
2. Calls `app.view(model)` and normalizes the tree via `Julep.Tree.normalize/1`.
3. On interaction (e.g., `click("#increment")`):
   a. Finds the element in the tree by selector.
   b. Uses `Julep.Test.EventMap` to infer the event from the widget type.
   c. Dispatches the event through `app.update(model, event)`.
   d. Re-renders the tree.
4. State is held in a GenServer for the duration of the test.

### EventMap inference

`Julep.Test.EventMap` maps widget types to the events they would produce.
For example, clicking a `button` with id `"inc"` infers `{:click, "inc"}`.
Toggling a `checkbox` with `is_checked: false` infers `{:toggle, id, true}`.

Full inference table:

| Widget | click | type_text | submit | toggle | select | slide |
|---|---|---|---|---|---|---|
| `button` | `{:click, id}` | -- | -- | -- | -- | -- |
| `checkbox` | -- | -- | -- | `{:toggle, id, !checked}` | -- | -- |
| `toggler` | -- | -- | -- | `{:toggle, id, !toggled}` | -- | -- |
| `radio` | -- | -- | -- | -- | `{:select, group, value}` | -- |
| `text_input` | -- | `{:input, id, text}` | `{:submit, id, val}` | -- | -- | -- |
| `text_editor` | -- | `{:input, id, text}` | -- | -- | -- | -- |
| `slider` | -- | -- | -- | -- | -- | `{:slide, id, val}` |
| `vertical_slider` | -- | -- | -- | -- | -- | `{:slide, id, val}` |
| `pick_list` | -- | -- | -- | -- | `{:select, id, val}` | -- |
| `combo_box` | -- | -- | -- | -- | `{:select, id, val}` | -- |

### What sim can test

- App logic (model transitions via `update/2`).
- Tree structure (which widgets appear, their props, nesting).
- Event flow (click -> update -> re-render -> assert).
- Commands returned from `update/2` (type, target, tag -- not execution).

### What sim cannot test

- Wire protocol encoding/decoding (no Rust involvement).
- Pixel rendering (no renderer).
- Platform effects (file dialogs, clipboard, notifications).
- Subscriptions (timer ticks, keyboard events, window events).
- Interaction edge cases that differ from EventMap's inference.


## The headless backend (`:headless`)

The headless backend spawns the Rust renderer in headless mode and
communicates via JSONL over stdio with a correlation-ID protocol.

### How it works

1. Spawns `julep_gui --headless` as a Port.
2. Calls `app.init(opts)` and `app.view(model)` locally.
3. Sends the initial tree to the renderer as a `snapshot` message.
4. On interactions, sends `interact` messages with correlation IDs.
5. The renderer responds with `interact_response` containing the events
   that would have been generated.
6. Events are dispatched through the local `update/view` loop.
7. Updated trees are sent back to the renderer.

### Correlation-ID protocol

Every request (query, interact, snapshot_capture, reset) includes an `id`
field. The renderer echoes this `id` in its response, allowing the
GenServer to match responses to pending callers. This handles the
asynchronous nature of Port communication.

Example exchange:

```json
{"type":"query","id":"req_1","target":"find","selector":{"by":"id","value":"count"}}
```

```json
{"type":"query_response","id":"req_1","target":"find","data":{"id":"count","type":"text","props":{"content":"0"},"children":[]}}
```

### Requirements

Build the renderer with headless support:

```bash
cd native/julep_gui && cargo build --features headless
```

No display server is needed. The headless binary uses `Core` directly
without creating an `iced::daemon`.

### What headless adds over sim

- **Protocol verification.** Proves the JSONL wire format encodes and
  decodes correctly end-to-end.
- **Tree round-trips.** The tree is serialized to JSON, sent to Rust,
  parsed, and can be queried back -- verifying structural fidelity.
- **Tree-hash snapshots.** SHA-256 hashes of the serialized tree JSON
  provide structural regression detection.


## The full backend (`:full`)

The full backend runs a real `iced::daemon` with GPU rendering, but also
accepts test protocol messages alongside normal snapshot/patch messages.

### How it works

1. Spawns `julep_gui --test` as a Port.
2. Same local init/view loop as headless.
3. Sends the initial tree, which opens real iced windows.
4. Interactions are handled through the test protocol and dispatched
   as real iced Messages.
5. Snapshots capture actual GPU-rendered RGBA pixel data.

### Requirements

Build the renderer with test-mode support:

```bash
cd native/julep_gui && cargo build --features test-mode
```

For CI or headless environments:

```bash
sudo apt-get install -y xvfb mesa-vulkan-drivers
Xvfb :99 -screen 0 1024x768x24 &
export DISPLAY=:99
export WINIT_UNIX_BACKEND=x11
```

### What full adds over headless

- **Real GPU pixels.** Actual wgpu rendering with font rasterization,
  anti-aliasing, and compositing.
- **Platform effects.** File dialogs, clipboard, and notifications work.
- **Subscriptions.** Timer ticks, keyboard events, and window events fire
  normally.
- **Real window lifecycle.** Windows open, close, resize, and focus.
- **Pixel-accurate snapshots.** Screenshots capture exactly what a user
  would see.


## Script-based testing

`.julep` scripts provide a declarative, language-agnostic format for
describing interaction sequences. They are useful for acceptance tests,
demos, and cross-project test sharing.

### The `.julep` format

A `.julep` file has a header section and an instruction section separated
by `-----`:

```
app: MyApp.Counter
viewport: 800x600
theme: dark
backend: sim
-----
click "#increment"
click "#increment"
expect "Count: 2"
snapshot "counter-at-2"
assert_text "#count" "2"
wait 500
```

#### Header fields

| Field | Required | Default | Description |
|---|---|---|---|
| `app` | Yes | -- | Module implementing `Julep.App` |
| `viewport` | No | `800x600` | Viewport size as `WxH` |
| `theme` | No | `dark` | Theme name |
| `backend` | No | `sim` | Backend: `sim`, `headless`, or `full` |

Lines starting with `#` are comments.

#### Instructions

| Instruction | Syntax | Description |
|---|---|---|
| `click` | `click "selector"` | Click a widget |
| `type` | `type "selector" "text"` | Type text into a widget |
| `type` (key) | `type enter` | Type a special key (`enter`, `escape`, `tab`, `backspace`) |
| `expect` | `expect "text"` | Assert that text appears somewhere in the tree |
| `snapshot` | `snapshot "name"` | Capture and assert a pixel snapshot |
| `assert_text` | `assert_text "selector" "text"` | Assert specific widget has specific text |
| `wait` | `wait 500` | Wait N milliseconds (respected in replay mode) |

Quoted strings support the `"selector"` syntax. Selectors follow the same
rules as Elixir tests (`"#id"` for IDs, `"text"` for text content).

### `mix julep.script`

Run `.julep` scripts as tests:

```bash
# Run all scripts in test/scripts/
mix julep.script

# Run specific scripts
mix julep.script test/scripts/counter.julep test/scripts/todo.julep
```

The task starts the application, parses each script, runs it through
`Julep.Test.Script.Runner`, and reports pass/fail results.

### `mix julep.replay`

Replay a script with real windows for demos and debugging:

```bash
mix julep.replay test/scripts/counter.julep
```

Replay mode forces the `:full` backend and respects `wait` timings, so
you see the interactions happen in real time.

### Relationship to iced's `.ice` format

The `.julep` format is a superset of iced's `.ice` test script format.
The core instructions (`click`, `type`, `expect`, `snapshot`) use the
same syntax. Julep adds `assert_text`, `wait`, and the header section
for app configuration.


## Unit testing (pure functions)

The Elm architecture means most of your app logic lives in pure functions.
Test them directly without any test framework infrastructure.

### Testing `update/2`

```elixir
test "adding a todo appends to list and clears input" do
  model = %{todos: [], input: "Buy milk"}
  model = MyApp.update(model, {:click, "add_todo"})

  assert [%{text: "Buy milk", done: false}] = model.todos
  assert model.input == ""
end
```

### Testing commands from `update/2`

```elixir
test "submitting todo refocuses the input" do
  model = %{todos: [], input: "Buy milk"}
  {model, cmd} = MyApp.update(model, {:submit, "todo_input", "Buy milk"})

  assert [%{text: "Buy milk"}] = model.todos
  assert %Julep.Command{type: :focus, target: "todo_input"} = cmd
end
```

Commands are data. Inspect their type, target, and tag without executing
them.

### Testing `view/1`

```elixir
test "view shows todo count" do
  model = %{todos: [%{id: 1, text: "Buy milk", done: false}], input: "", filter: :all}
  tree = MyApp.view(model)

  counter = Julep.UI.find(tree, "todo_count")
  assert counter.props["content"] =~ "1"
end
```

### Testing `subscribe/1`

```elixir
test "timer subscription active when running" do
  model = %{timer_running: true}
  subs = MyApp.subscribe(model)

  assert Enum.any?(subs, fn sub -> sub.type == :every end)
end
```

### Testing `init/1`

```elixir
test "init returns valid initial state" do
  model = MyApp.init([])

  assert is_list(model.todos)
  assert model.input == ""
end
```

### Tree query helpers

`Julep.UI` provides helpers for querying trees outside the test framework:

```elixir
Julep.UI.find(tree, "my_button")
Julep.UI.find(tree, fn node -> node.type == "text" end)
Julep.UI.find_all(tree, fn node -> node.type == "button" end)
Julep.UI.exists?(tree, "my_button")
Julep.UI.ids(tree)
```

### JSON tree snapshots

For complex views, snapshot tests catch unintended structural changes:

```elixir
test "initial view snapshot" do
  model = MyApp.init([])
  tree = MyApp.view(model)

  Julep.Test.assert_snapshot(tree, "test/snapshots/initial_view.json")
end
```

On first run, `assert_snapshot` writes the JSON file. On subsequent runs,
it compares the tree. Update snapshots after intentional changes:

```bash
JULEP_UPDATE_SNAPSHOTS=1 mix test
```


## CI configuration

### Sim-only CI (simplest)

No special setup. Works anywhere Elixir runs.

```yaml
- run: mix test
```

### Headless CI

Requires the Rust toolchain and the headless feature build.

```yaml
- run: |
    cd native/julep_gui
    cargo build --features headless
- run: JULEP_TEST_BACKEND=headless mix test
```

### Full CI

Requires a display server and GPU drivers.

```yaml
- run: |
    sudo apt-get install -y xvfb mesa-vulkan-drivers
    cd native/julep_gui
    cargo build --features test-mode
- run: |
    Xvfb :99 -screen 0 1024x768x24 &
    export DISPLAY=:99
    export WINIT_UNIX_BACKEND=x11
    JULEP_TEST_BACKEND=full mix test
```

### Mixed backend CI

Use tags to run different test subsets with different backends:

```yaml
# Run sim tests (fast, most tests)
- run: mix test --exclude headless --exclude full

# Run headless tests
- run: JULEP_TEST_BACKEND=headless mix test --only headless

# Run full tests
- run: |
    Xvfb :99 -screen 0 1024x768x24 &
    export DISPLAY=:99
    JULEP_TEST_BACKEND=full mix test --only full
```

Tag tests that need a specific backend:

```elixir
@tag :headless
test "protocol round-trip" do
  # ...
end

@tag :full
test "window opens and renders" do
  # ...
end
```


## Advanced patterns

### Testing async workflows

When `update/2` returns an async command, use `await_async/2` to wait
for it to complete:

```elixir
test "fetching data loads results" do
  click("#fetch")
  assert model().loading == true

  await_async(:data_loaded)
  assert model().loading == false
  assert length(model().results) > 0
end
```

In the sim backend, `await_async` returns immediately (async commands
are collected but not executed). Test the command shape instead:

```elixir
test "clicking fetch starts async load" do
  model = %{loading: false, data: nil}
  {model, cmd} = MyApp.update(model, {:click, "fetch"})

  assert model.loading == true
  assert %Julep.Command{type: :async, tag: :data_loaded} = cmd
end
```

### Multi-window testing

Multi-window apps can be tested at any backend level. The sim backend
tracks the full tree including window nodes:

```elixir
test "opening settings window" do
  click("#open-settings")
  assert_exists "#settings-window"
end
```

For real window lifecycle testing, use the full backend:

```elixir
@tag backend: :full
test "settings window opens and renders" do
  click("#open-settings")
  assert_exists "#settings-window"
  assert_snapshot("settings-window-open")
end
```

### Custom selectors

For cases where `#id` and text selectors are not enough, access the
session directly:

```elixir
test "custom query" do
  session = session()
  tree = Julep.Test.Session.tree(session)

  # Manual tree traversal
  buttons = collect_nodes(tree, fn n -> n["type"] == "button" end)
  assert length(buttons) == 3
end
```

### Scenario testing

Chain interactions to test multi-step user flows:

```elixir
test "complete todo flow: add, toggle, filter" do
  type_text("#todo_input", "Buy milk")
  submit("#todo_input")

  assert_text "#todo-count", "1 item"

  toggle("#todo:1")
  click("#filter-active")

  assert_not_exists "#todo:1"
  assert_text "#todo-count", "0 items"
end
```

This reads like a user story. Anyone can understand what it tests.

### Resetting session state

Use `reset/0` to return to the initial state without creating a new
session:

```elixir
test "multiple scenarios in one test" do
  click("#increment")
  assert model().count == 1

  reset()
  assert model().count == 0
end
```
