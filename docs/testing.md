# Testing

## Philosophy

Tests are documentation. They tell the next person how the feature works.

The Elm architecture makes julep apps unusually easy to test. `update/2` is
a pure function: model in, model out. `view/1` returns plain maps. No
mocks, no processes, no infrastructure needed for the core loop. Most of
your app logic can be tested with nothing but ExUnit.

When you need to go deeper -- clicking buttons, verifying widgets appear,
catching rendering regressions -- julep ships a test framework with
progressive fidelity:

1. **Sim** (pure Elixir) -- millisecond tests for logic and tree structure.
2. **Headless** (Rust renderer, no display) -- protocol round-trips and
   tree-hash snapshots, powered by iced's
   [iced_test](https://docs.rs/iced_test) crate and
   [tiny-skia](https://github.com/linebender/tiny-skia) software renderer.
3. **Full** (real iced windows) -- GPU pixels, effects, subscriptions.

Write your tests once; swap backends with a single line. Most tests should
be sim tests. Headless and full exist for the things sim cannot catch.


## Unit testing

The Elm architecture means you can test most of your app with plain
ExUnit -- no test framework needed.

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

Commands are data. Inspect their type, target, and tag without executing
them.

```elixir
test "submitting todo refocuses the input" do
  model = %{todos: [], input: "Buy milk"}
  {model, cmd} = MyApp.update(model, {:submit, "todo_input", "Buy milk"})

  assert [%{text: "Buy milk"}] = model.todos
  assert %Julep.Command{type: :focus, target: "todo_input"} = cmd
end
```

### Testing `view/1`

```elixir
test "view shows todo count" do
  model = %{todos: [%{id: 1, text: "Buy milk", done: false}], input: "", filter: :all}
  tree = MyApp.view(model)

  # Julep.UI.find/2 walks the tree by ID (see "Tree query helpers" below)
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


## The test framework

Unit tests cover logic. But they can't click a button, verify a widget
appears after an interaction, or catch a rendering regression when you bump
iced. That's what the test framework is for.

```elixir
defmodule MyApp.CounterTest do
  use Julep.Test.Case, app: MyApp.Counter

  test "clicking increment updates counter" do
    click("#increment")
    assert find!("#count") |> text() == "1"
  end
end
```

`Julep.Test.Case` starts a session, imports all helper functions, and tears
down on exit. The default backend is `:sim` -- no Rust binary, no display
server, no setup.

### What you get

- **`find/1`** and **`find!/1`** -- locate widgets by selector, get back an
  `Element` struct with id, type, props, and children.
- **`click/1`**, **`type_text/2`**, **`submit/1`**, **`toggle/1`**,
  **`select/2`**, **`slide/2`** -- interact with widgets.
- **`assert_text/2`**, **`assert_exists/1`**, **`assert_not_exists/1`** --
  scoped assertions.
- **`model/0`** and **`tree/0`** -- inspect current state directly.
- **`snapshot/1`** and **`assert_snapshot/1`** -- pixel regression.
- **`await_async/2`** -- wait for a tagged async task to complete.
- **`reset/0`** -- return to initial state without creating a new session.


## Selectors, interactions, and assertions

### Selectors

Two selector forms:

- **`"#id"`** -- find by widget ID. The `#` prefix is required.
- **`"text content"`** -- find by text content (checks `content`, `label`,
  `value`, `placeholder` props in that order).

A third form for rendered backends:

- **`{:point, x, y}`** -- find by pixel coordinates (headless/full only).

### Element handles

`find/1` returns nil if not found. `find!/1` raises.

```elixir
element = find!("#my-button")
element.id       # => "my-button"
element.type     # => "button"
element.props    # => %{"label" => "Click me", ...}
element.children # => [...]
```

Use `text/1` to extract display text:

```elixir
assert find!("#count") |> text() == "42"
```

`text/1` checks props in order: `content`, `label`, `value`, `placeholder`.

### Interaction functions

All interaction functions accept a selector string. They are imported
automatically by `Julep.Test.Case`.

| Function | Widget types | Event produced |
|---|---|---|
| `click(selector)` | `button` | `{:click, id}` |
| `type_text(selector, text)` | `text_input`, `text_editor` | `{:input, id, text}` |
| `submit(selector)` | `text_input` | `{:submit, id, value}` |
| `toggle(selector)` | `checkbox`, `toggler` | `{:toggle, id, !current}` |
| `select(selector, value)` | `pick_list`, `combo_box`, `radio` | `{:select, id_or_group, value}` |
| `slide(selector, value)` | `slider`, `vertical_slider` | `{:slide, id, value}` |

Interacting with the wrong widget type raises with a clear message. See
[Debugging](#debugging-and-error-messages) for examples.

### Assertions

```elixir
# Text content
assert find!("#count") |> text() == "42"
assert_text "#count", "42"

# Existence
assert_exists "#my-button"
assert_not_exists "#admin-panel"

# Model state
assert model().count == 5

# Full tree
tree = tree()
assert tree["type"] == "column"
```


## Choosing a backend

**What are you testing?**

- **App logic and tree structure?** Use `:sim`. It's the default, runs in
  milliseconds, and needs nothing beyond Elixir. This covers the vast
  majority of app testing.

- **Bumping iced or changing the renderer?** Use `:headless`. It runs
  your tree through the real Rust renderer, catching protocol mismatches
  and structural drift that sim can't see. Tree-hash snapshots give you
  a baseline to diff against.

- **Platform effects, subscriptions, or pixel accuracy?** Use `:full`. Real
  iced windows with GPU rendering. File dialogs work, timers fire,
  screenshots capture exactly what a user would see. Use sparingly -- it's
  the slowest backend and needs a display server.

### Capabilities

| | `:sim` | `:headless` | `:full` |
|---|---|---|---|
| **Speed** | ~ms | ~100ms | ~seconds |
| **Rust binary** | No | Yes (`--headless`) | Yes (`--test`) |
| **Display server** | No | No | Yes (Xvfb in CI) |
| **Tests logic** | Yes | Yes | Yes |
| **Tests tree structure** | Yes | Yes | Yes |
| **Protocol round-trip** | No | Yes | Yes |
| **Pixel snapshots** | No | Tree-hash only | Real GPU pixels |
| **Effects** | Collected, not executed | Not executed | Executed |
| **Subscriptions** | Not active | Not active | Active |
| **Real windows** | No | No | Yes |

### Backend selection

The backend is resolved through a priority chain:

| Priority | Source | Example |
|---|---|---|
| 1 | Per-test tag | `@tag backend: :headless` |
| 2 | Module option | `use Julep.Test.Case, app: MyApp, backend: :headless` |
| 3 | Environment variable | `JULEP_TEST_BACKEND=headless mix test` |
| 4 | Application config | `config :julep, :test_backend, :sim` |
| 5 | Default | `:sim` |

Atom shorthands (`:sim`, `:headless`, `:full`) and full module names
(`Julep.Test.Backend.Sim`, etc.) both work.

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


## Pixel regression

Pixel snapshots catch visual regressions that tree-level assertions miss.
They are most valuable when bumping iced versions or changing the renderer.

### Golden file workflow

```elixir
@tag backend: :headless
test "counter renders correctly" do
  click("#increment")
  assert_snapshot("counter-at-1")
end
```

`assert_snapshot/1`:

1. Captures the current rendered state via `snapshot/1`.
2. Looks for a golden file at `test/snapshots/<name>.sha256`.
3. **First run:** Creates the golden file. Test passes.
4. **Subsequent runs:** Compares hashes. Mismatch fails the test with both
   hashes shown.

### Updating golden files

When the change is intentional:

```bash
JULEP_UPDATE_SNAPSHOTS=1 mix test
```

### What gets hashed

- **Headless:** SHA-256 of the serialized tree JSON. Catches structural
  changes but not pixel-level rendering differences.
- **Full:** SHA-256 of actual RGBA pixel data from the GPU. Catches any
  visual change, including fonts, spacing, and anti-aliasing.

### When to use pixel regression

- After bumping the iced dependency.
- When changing widget rendering code in the renderer.
- When modifying the theme system or color handling.
- When you need absolute confidence that "it looks the same."


## Script-based testing

`.julep` scripts provide a declarative format for describing interaction
sequences. The format is a superset of iced's
[`.ice` test scripts](https://docs.rs/iced_test/latest/iced_test/ice/) --
the core instructions (`click`, `type`, `expect`, `snapshot`) use the same
syntax. Julep adds `assert_text`, `wait`, and a header section for app
configuration.

### The `.julep` format

A `.julep` file has a header and an instruction section separated by
`-----`:

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
| `type` (key) | `type enter` | Send a special key (`enter`, `escape`, `tab`, `backspace`) |
| `expect` | `expect "text"` | Assert text appears somewhere in the tree |
| `snapshot` | `snapshot "name"` | Capture and assert a pixel snapshot |
| `assert_text` | `assert_text "selector" "text"` | Assert widget has specific text |
| `wait` | `wait 500` | Pause N milliseconds (respected in replay mode) |

### Running scripts

```bash
# Run all scripts in test/scripts/
mix julep.script

# Run specific scripts
mix julep.script test/scripts/counter.julep test/scripts/todo.julep
```

### Replaying scripts

```bash
mix julep.replay test/scripts/counter.julep
```

Replay mode forces the `:full` backend and respects `wait` timings, so you
see interactions happen in real time with real windows. Use cases:

- **Debugging visual issues.** See exactly what the user sees, step by step.
- **Demos.** Walk through a feature for stakeholders without writing a
  separate demo app.
- **Onboarding.** New team members can replay scripts to understand user
  flows visually.
- **Documentation.** Record a replay to capture screenshots or screen
  recordings for docs.


## Backend reference

### Simulated (`:sim`)

Runs your app's `init/update/view` loop entirely in Elixir. No Rust, no
Port, no external process.

On interaction (e.g., `click("#increment")`), the sim backend finds the
element in the tree, uses `Julep.Test.EventMap` to infer the correct event
from the widget type, dispatches it through `update/2`, and re-renders.

#### EventMap inference

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

#### What sim can test

- App logic (model transitions).
- Tree structure (which widgets appear, their props, nesting).
- Event flow (interact -> update -> re-render -> assert).
- Commands returned from `update/2` (type, target, tag -- not execution).

#### What sim cannot test

- Wire protocol encoding/decoding (no Rust involvement).
- Pixel rendering.
- Platform effects (file dialogs, clipboard, notifications).
- Subscriptions (timers, keyboard, window events).

### Headless (`:headless`)

Spawns the Rust renderer in headless mode and communicates via JSONL with
correlation IDs for request/response matching.

**Requirements:**

```bash
cd native/julep_gui && cargo build --features headless
```

No display server needed.

**What it adds over sim:**

- **Protocol verification.** The tree is serialized, sent to Rust, parsed,
  and queried back -- proving the wire format works end-to-end.
- **Tree-hash snapshots.** SHA-256 hashes of the tree JSON provide
  structural regression detection.

### Full (`:full`)

Runs a real `iced::daemon` with GPU rendering, while also accepting test
protocol messages.

**Requirements:**

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

**What it adds over headless:**

- **Real GPU pixels.** wgpu rendering with font rasterization and compositing.
- **Platform effects.** File dialogs, clipboard, and notifications work.
- **Subscriptions.** Timers, keyboard, and window events fire normally.
- **Real window lifecycle.** Windows open, close, resize, and focus.
- **Pixel-accurate snapshots.** Screenshots capture exactly what a user sees.


## Debugging and error messages

### Element not found

```elixir
find!("#nonexistent")
# ** (RuntimeError) Element not found: "#nonexistent"
```

**Fix:** Check the selector. Use `tree()` to inspect the current tree and
verify the widget's ID or text content:

```elixir
tree() |> IO.inspect(label: "current tree")
```

### Wrong interaction type

```elixir
click("#my-checkbox")
# ** (RuntimeError) cannot click a checkbox widget -- use toggle/1 instead
```

**Fix:** Use the correct interaction function. Checkboxes respond to
`toggle/1`, not `click/1`. See the
[interaction table](#interaction-functions) for the mapping.

### Snapshot on sim backend

```elixir
assert_snapshot("my-snapshot")
# ** (RuntimeError) pixel snapshots require the :headless or :full backend --
#    the :sim backend only tests logic and tree structure
```

**Fix:** Tag the test with `@tag backend: :headless` or `:full`.

### Headless binary not built

```
** (EXIT) {:renderer_exited, 1}
```

**Fix:** Build the renderer with the headless feature:

```bash
cd native/julep_gui && cargo build --features headless
```

### Inspecting state when a test fails

When an assertion fails and you need to understand why, `model/0` and
`tree/0` are your best tools:

```elixir
test "debugging a failing test" do
  click("#increment")

  # What does the model look like?
  IO.inspect(model(), label: "model after click")

  # What's in the tree?
  IO.inspect(tree(), label: "tree after click")

  assert find!("#count") |> text() == "1"
end
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

When `update/2` returns an async command, use `await_async/2` to wait for
completion:

```elixir
test "fetching data loads results" do
  click("#fetch")
  assert model().loading == true

  await_async(:data_loaded)
  assert model().loading == false
  assert length(model().results) > 0
end
```

In the sim backend, `await_async` returns immediately (async commands are
collected but not executed). Test the command shape instead:

```elixir
test "clicking fetch starts async load" do
  model = %{loading: false, data: nil}
  {model, cmd} = MyApp.update(model, {:click, "fetch"})

  assert model.loading == true
  assert %Julep.Command{type: :async, tag: :data_loaded} = cmd
end
```

### Multi-window testing

The sim backend tracks the full tree including window nodes:

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

For cases where `#id` and text selectors aren't enough, access the session
directly:

```elixir
test "custom query" do
  tree = tree()

  # Julep.UI.find_all/2 walks the tree depth-first with a predicate
  buttons = Julep.UI.find_all(tree, fn n -> n.type == "button" end)
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
