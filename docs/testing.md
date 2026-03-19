# Testing

## Philosophy

Progressive fidelity: test your app's logic with fast, pure-Elixir mock tests;
promote to headless or windowed backends when you need wire-protocol verification
or pixel-accurate screenshots.


## Unit testing

`update/2` is pure, `view/1` returns maps. Plain ExUnit -- no framework
needed.

### Testing `update/2`

```elixir
test "adding a todo appends to list and clears input" do
  model = %{todos: [], input: "Buy milk"}
  model = MyApp.update(model, %Widget{type: :click, id: "add_todo"})

  assert [%{text: "Buy milk", done: false}] = model.todos
  assert model.input == ""
end
```

### Testing commands from `update/2`

Commands are plain `%Toddy.Command{}` structs. Pattern-match on `type` and
`payload` to verify what `update/2` asked the runtime to do, without
executing anything.

```elixir
test "submitting todo refocuses the input" do
  model = %{todos: [], input: "Buy milk"}
  {model, cmd} = MyApp.update(model, %Widget{type: :submit, id: "todo_input", value: "Buy milk"})

  assert [%{text: "Buy milk"}] = model.todos
  assert %Toddy.Command{type: :focus, payload: %{target: "todo_input"}} = cmd
end

test "save triggers an async task" do
  model = %{data: "unsaved"}
  {_model, cmd} = MyApp.update(model, %Widget{type: :click, id: "save"})

  assert %Toddy.Command{type: :async, payload: %{tag: :save_result}} = cmd
end
```

### Testing `view/1`

```elixir
test "view shows todo count" do
  model = %{todos: [%{id: 1, text: "Buy milk", done: false}], input: "", filter: :all}
  tree = MyApp.view(model)

  counter = Toddy.Tree.find(tree, "todo_count")
  assert counter.props["content"] =~ "1"
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

`Toddy.Tree` provides helpers for querying view trees directly:

```elixir
Toddy.Tree.find(tree, "my_button")            # find node by ID
Toddy.Tree.exists?(tree, "my_button")         # check existence
Toddy.Tree.ids(tree)                          # all IDs (depth-first)
Toddy.Tree.find_all(tree, fn node ->          # find by predicate
  node.type == "button"
end)
```

These work on the raw `ui_node()` maps returned by `view/1`. No test
session or backend required.

### JSON tree snapshots

For complex views, snapshot the entire tree as JSON to catch unintended
structural changes. `Toddy.Test.assert_tree_snapshot/2` compares a tree
against a stored JSON file at the unit test level -- no backend needed.

```elixir
test "initial view snapshot" do
  model = MyApp.init([])
  tree = MyApp.view(model)

  Toddy.Test.assert_tree_snapshot(tree, "test/snapshots/initial_view.json")
end
```

First run writes the file. Subsequent runs compare and fail with a diff on
mismatch. Update after intentional changes:

```bash
TODDY_UPDATE_SNAPSHOTS=1 mix test
```

This is a pure JSON comparison -- it normalizes map key ordering for stable
output. It is distinct from the framework's `assert_tree_hash/1` (which uses
SHA-256 hashes of the tree via a backend session) and `assert_screenshot/1`
(which compares pixel data).


## The test framework

Unit tests cover logic. But they cannot click a button, verify a widget
appears after an interaction, or catch a rendering regression when you bump
iced. That is what the test framework is for.

```elixir
defmodule MyApp.CounterTest do
  use Toddy.Test.Case, app: MyApp.Counter

  test "clicking increment updates counter" do
    click("#increment")
    assert_text "#count", "1"
  end
end
```

`Toddy.Test.Case` starts a session, imports all helper functions, and tears
down on exit. The default backend is `:pooled_mock` -- a pooled backend
using a shared renderer process. No Rust binary, no display server, no
setup.


## Selectors, interactions, and assertions

### Where do widget IDs come from?

Every widget in toddy gets an ID from the first argument to its builder or
constructor. For example, `Button.new("save_btn", "Save")` creates a button
with ID `"save_btn"`. In `Toddy.UI`, `button("save_btn", "Save")` does the
same thing.

When using selectors in tests, prefix the ID with `#`:

```elixir
click("#save_btn")
find!("#save_btn")
assert_text "#save_btn", "Save"
```

### Selectors

Two selector forms:

- **`"#id"`** -- find by widget ID. The `#` prefix is required.
- **`"text content"`** -- find by text content (checks `content`, `label`,
  `value`, `placeholder` props in that order, depth-first).

```elixir
click("#my_button")         # by ID
find!("Click me")           # by text content
assert_exists "#sidebar"    # by ID
```

### Element handles

`find/1` returns `nil` if not found. `find!/1` raises with a clear message.
Both return an `Element` struct:

```elixir
element = find!("#my-button")
element.id       # => "my-button"
element.type     # => "button"
element.props    # => %{"label" => "Click me", ...}
element.children # => [...]
```

Use `text/1` to extract display text from an element:

```elixir
assert find!("#count") |> text() == "42"
```

`text/1` checks props in order: `content`, `label`, `value`, `placeholder`.
Returns `nil` if no text prop is found.

### Interaction functions

All interaction functions accept a selector string. They are imported
automatically by `Toddy.Test.Case`.

| Function | Widget types | Event produced |
|---|---|---|
| `click(selector)` | `button` | `%Widget{type: :click, id: id}` |
| `type_text(selector, text)` | `text_input`, `text_editor` | `%Widget{type: :input, id: id, value: text}` |
| `submit(selector)` | `text_input` | `%Widget{type: :submit, id: id, value: val}` |
| `toggle(selector)` | `checkbox`, `toggler` | `%Widget{type: :toggle, id: id, value: !current}` |
| `select(selector, value)` | `pick_list`, `combo_box`, `radio` | `%Widget{type: :select, id: id, value: val}` |
| `slide(selector, value)` | `slider`, `vertical_slider` | `%Widget{type: :slide, id: id, value: val}` |

Interacting with the wrong widget type raises with an actionable hint:

```
cannot click a checkbox widget -- use toggle/1 instead
```

### Assertions

```elixir
# Text content
assert_text "#count", "42"

# Existence
assert_exists "#my-button"
assert_not_exists "#admin-panel"

# Full model equality
assert_model %{count: 5, name: "test"}

# Direct model inspection
assert model().count == 5

# Direct element access when you need more control
element = find!("#count")
assert text(element) == "42"
assert element.type == "text"
```


## API reference

All of the following are imported by `use Toddy.Test.Case`:

| Function | Description |
|---|---|
| `find(selector)` | Find element by selector, returns `nil` if not found |
| `find!(selector)` | Find element by selector, raises if not found |
| `click(selector)` | Click a button widget |
| `type_text(selector, text)` | Type text into a text_input or text_editor |
| `submit(selector)` | Submit a text_input (simulates pressing enter) |
| `toggle(selector)` | Toggle a checkbox or toggler |
| `select(selector, value)` | Select a value from pick_list, combo_box, or radio |
| `slide(selector, value)` | Slide a slider to a numeric value |
| `model()` | Returns the current app model |
| `tree()` | Returns the current normalized UI tree |
| `text(element)` | Extract text content from an Element struct |
| `tree_hash(name)` | Capture a structural tree hash |
| `screenshot(name)` | Capture a pixel screenshot (no-op on mock) |
| `save_screenshot(name)` | Capture screenshot and save as PNG to `test/screenshots/` |
| `assert_text(selector, expected)` | Assert widget contains expected text |
| `assert_exists(selector)` | Assert widget exists in the tree |
| `assert_not_exists(selector)` | Assert widget does NOT exist in the tree |
| `assert_model(expected)` | Assert model equals expected (strict equality) |
| `assert_tree_hash(name)` | Capture tree hash and assert it matches golden file |
| `assert_screenshot(name)` | Capture screenshot and assert it matches golden file |
| `await_async(tag, timeout \\ 5000)` | Wait for a tagged async task to complete |
| `press(key)` | Press a key (key down). Supports modifiers: `"ctrl+s"` |
| `release(key)` | Release a key (key up). Supports modifiers: `"ctrl+s"` |
| `move_to(x, y)` | Move the cursor to absolute coordinates |
| `type_key(key)` | Type a key (press + release). Supports modifiers: `"enter"` |
| `reset()` | Reset session to initial state |
| `start(app, opts \\ [])` | Start a session manually (when not using Case) |
| `session()` | Returns the current test session from the process dictionary |


## Backends

All tests work on all backends. Write tests once, swap backends without
changing assertions.

### Three backends

| | `:pooled_mock` | `:headless` | `:windowed` |
|---|---|---|---|
| **Speed** | ~ms | ~100ms | ~seconds |
| **Rust binary** | No | Yes (`--headless`) | Yes (no flag) |
| **Display server** | No | No | Yes (Xvfb in CI) |
| **Tests logic** | Yes | Yes | Yes |
| **Tests tree structure** | Yes | Yes | Yes |
| **Protocol round-trip** | No | Yes | Yes |
| **Structural tree hashes** | Yes | Yes | Yes |
| **Pixel screenshots** | No | Yes (software) | Yes |
| **Effects** | Collected, not executed | Not executed | Executed |
| **Subscriptions** | Not active | Not active | Active |
| **Real windows** | No | No | Yes |

- **`:pooled_mock`** -- pure Elixir via `Backend.Pooled` with a shared
  renderer process. Tests app logic and tree structure. No Rust, no
  display, sub-millisecond. The right default for 90% of tests.

- **`:headless`** -- real Rust renderer with software rendering (no
  display server). Proves the wire protocol works end-to-end (msgpack by
  default). Tree hashes detect structural drift. Pixel screenshots
  capture accurately rendered UI via tiny-skia. Uses the `--headless`
  runtime flag.

- **`:windowed`** -- real `iced::daemon` with GPU rendering. Effects work,
  subscriptions fire, pixel screenshots capture exactly what a user sees.
  Spawns `toddy` with no special flag. Needs a display server
  (Xvfb or headless Weston).

### Backend selection

You never choose a backend in your test code. Backend selection is an
infrastructure decision made via environment variable or application config.
Tests are portable across all three.

| Priority | Source | Example |
|---|---|---|
| 1 | Environment variable | `TODDY_TEST_BACKEND=headless mix test` |
| 2 | Application config | `config :toddy, :test_backend, :pooled_mock` |
| 3 | Default | `:pooled_mock` |

Atom shorthands (`:pooled_mock`, `:headless`, `:windowed`) and full module
names (`Toddy.Test.Backend.Pooled`, etc.) both work in application config.


## Snapshots and screenshots

Toddy has three distinct regression testing mechanisms. Understanding the
difference is important.

### Structural tree hashes (`assert_tree_hash`)

`assert_tree_hash/1` captures a SHA-256 hash of the serialized UI tree and
compares it against a golden file. It works on all three backends because
every backend can produce a tree.

```elixir
test "counter initial state" do
  assert_tree_hash("counter-initial")
end

test "counter after increment" do
  click("#increment")
  assert_tree_hash("counter-at-1")
end
```

Golden files are stored in `test/snapshots/` as `.sha256` files. On first
run, the golden file is created automatically. On subsequent runs, the hash
is compared and the test fails on mismatch.

To update golden files after intentional changes:

```bash
TODDY_UPDATE_SNAPSHOTS=1 mix test
```

### Pixel screenshots (`assert_screenshot`)

`assert_screenshot/1` captures real RGBA pixel data and compares it against
a golden file. It produces meaningful data on both the `:windowed` backend (GPU
rendering via wgpu) and the `:headless` backend (software rendering via
tiny-skia). On `:pooled_mock`, it silently succeeds as a no-op (returns an
empty hash, which is accepted without creating or checking a golden file).

Note that headless screenshots use software rendering, so pixels will not
match GPU output exactly. Maintain separate golden files per backend, or
use headless screenshots for layout regression testing only.

```elixir
test "counter renders correctly" do
  click("#increment")
  assert_screenshot("counter-at-1")
end
```

Golden files are stored in `test/screenshots/` as `.sha256` files. The
workflow is the same as structural snapshots but uses a separate env var:

```bash
TODDY_UPDATE_SCREENSHOTS=1 mix test
```

Because screenshots silently no-op on pooled_mock, you can include
`assert_screenshot` calls in any test without conditional logic. They will
produce assertions when run on the headless or windowed backends.

### JSON tree snapshots (`assert_tree_snapshot`)

`Toddy.Test.assert_tree_snapshot/2` is a unit-test-level tool that compares
a raw tree map against a stored JSON file. No backend or session needed.
See the [Unit testing](#json-tree-snapshots) section above.

### When to use each

- **`assert_tree_hash`** -- always appropriate. Catches structural regressions
  (widgets appearing/disappearing, prop changes, nesting changes). Works on
  every backend. Use liberally.

- **`assert_screenshot`** -- after bumping iced, changing the renderer,
  modifying themes, or any change that affects visual output. Only meaningful
  on the windowed backend. Include alongside `assert_tree_hash` for critical views.

- **`assert_tree_snapshot`** -- for unit tests of `view/1` output. No
  framework overhead. Good for documenting what a view produces for a given
  model state.


## Script-based testing

`.toddy` scripts provide a declarative format for describing interaction
sequences. The format is a superset of iced's `.ice` test scripts -- the
core instructions (`click`, `type`, `expect`, `snapshot`) use the same
syntax. Toddy adds `assert_text`, `assert_model`, `screenshot`, `wait`, and
a header section for app configuration.

### The `.toddy` format

A `.toddy` file has a header and an instruction section separated by
`-----`:

```
app: MyApp.Counter
viewport: 800x600
theme: dark
backend: pooled_mock
-----
click "#increment"
click "#increment"
expect "Count: 2"
tree_hash "counter-at-2"
screenshot "counter-pixels"
assert_text "#count" "2"
wait 500
```

#### Header fields

| Field | Required | Default | Description |
|---|---|---|---|
| `app` | Yes | -- | Module implementing `Toddy.App` |
| `viewport` | No | `800x600` | Viewport size as `WxH` |
| `theme` | No | `dark` | Theme name |
| `backend` | No | `pooled_mock` | Backend: `pooled_mock`, `headless`, or `windowed` |

Lines starting with `#` are comments (in both header and body sections).

#### Instructions

| Instruction | Syntax | Mock support | Description |
|---|---|---|---|
| `click` | `click "selector"` | Yes | Click a widget |
| `type` | `type "selector" "text"` | Yes | Type text into a widget |
| `type` (key) | `type enter` | Yes | Send a special key (press + release). Supports modifiers: `type ctrl+s` |
| `expect` | `expect "text"` | Yes | Assert text appears somewhere in the tree |
| `tree_hash` | `tree_hash "name"` | Yes | Capture and assert a structural tree hash |
| `screenshot` | `screenshot "name"` | No-op on pooled_mock | Capture and assert a pixel screenshot |
| `assert_text` | `assert_text "selector" "text"` | Yes | Assert widget has specific text |
| `assert_model` | `assert_model "expression"` | Yes | Assert expression appears in inspected model (substring match) |
| `press` | `press key` | Yes | Press a key down. Supports modifiers: `press ctrl+s` |
| `release` | `release key` | Yes | Release a key. Supports modifiers: `release ctrl+s` |
| `move` | `move "selector"` | No-op | Move mouse to a widget (requires widget bounds) |
| `move` (coords) | `move "x,y"` | Yes | Move mouse to pixel coordinates |
| `wait` | `wait 500` | Ignored (except replay) | Pause N milliseconds |

### Running scripts

```bash
# Run all scripts in test/scripts/
mix toddy.script

# Run specific scripts
mix toddy.script test/scripts/counter.toddy test/scripts/todo.toddy
```

### Replaying scripts

```bash
mix toddy.replay test/scripts/counter.toddy
```

Replay mode forces the `:windowed` backend and respects `wait` timings, so you
see interactions happen in real time with real windows. Useful for debugging
visual issues, demos, and onboarding.


## Testing async workflows

### On the pooled_mock backend

The pooled_mock backend executes `async`, `stream`, and `done` commands
synchronously. When `update/2` returns a command like
`Command.async(fn -> fetch_data() end, :data_loaded)`, the backend
immediately calls the function, gets the result, and dispatches
`{:data_loaded, result}` through `update/2` -- all within the same call.

This means `await_async/2` returns `:ok` immediately (the work is already
done):

```elixir
test "fetching data loads results" do
  click("#fetch")
  # On pooled_mock, the async command already executed synchronously.
  # await_async is a no-op -- the model is already updated.
  await_async(:data_loaded)
  assert length(model().results) > 0
end
```

Widget ops (focus, scroll), window ops, and timers are silently skipped on
pooled_mock because they require a renderer. Test the command shape at the
unit test level instead:

```elixir
test "clicking fetch starts async load" do
  model = %{loading: false, data: nil}
  {model, cmd} = MyApp.update(model, %Widget{type: :click, id: "fetch"})

  assert model.loading == true
  assert %Toddy.Command{type: :async, payload: %{tag: :data_loaded}} = cmd
end
```

### On headless and windowed backends

All three backends now use the shared `CommandProcessor` to execute async
commands synchronously. `await_async/2` returns `:ok` immediately on all
backends because the commands have already completed.


## Debugging and error messages

### Element not found

```elixir
find!("#nonexistent")
# ** (RuntimeError) Element not found: "#nonexistent"
```

Use `tree()` to inspect the current tree and verify the widget's ID or text
content:

```elixir
tree() |> IO.inspect(label: "current tree")
```

### Wrong interaction type

```elixir
click("#my-checkbox")
# ** (RuntimeError) cannot click a checkbox widget -- use toggle/1 instead
```

Use the correct interaction function for the widget type. See the
[interaction table](#interaction-functions) for the mapping.

### Headless binary not built

```
** (EXIT) {:renderer_exited, 1}
```

Build the renderer with the headless feature:

```bash
mix toddy.build
```

### Inspecting state when a test fails

`model/0` and `tree/0` are your best debugging tools:

```elixir
test "debugging a failing test" do
  click("#increment")

  IO.inspect(model(), label: "model after click")
  IO.inspect(tree(), label: "tree after click")

  assert find!("#count") |> text() == "1"
end
```


## CI configuration

### Pooled mock CI (simplest)

No special setup. Works anywhere Elixir runs.

```yaml
- run: mix test
```

### Headless CI

Requires the toddy binary (download or build from source).

```yaml
- run: mix toddy.download
- run: TODDY_TEST_BACKEND=headless mix test
```

### Windowed CI

Requires a display server and GPU/software rendering. Two options:

**Option A: Xvfb (X11)**

```yaml
- run: mix toddy.download
- run: sudo apt-get install -y xvfb mesa-vulkan-drivers
- run: |
    Xvfb :99 -screen 0 1024x768x24 &
    export DISPLAY=:99
    export WINIT_UNIX_BACKEND=x11
    TODDY_TEST_BACKEND=windowed mix test
```

**Option B: Weston (Wayland)**

Weston's headless backend provides a Wayland compositor without a physical
display. Combined with `vulkan-swrast` (Mesa software rasterizer), this
runs the full rendering pipeline on CPU.

```yaml
- run: mix toddy.download
- run: sudo apt-get install -y weston mesa-vulkan-drivers
- run: |
    export XDG_RUNTIME_DIR=/tmp/toddy-xdg-runtime
    mkdir -p "$XDG_RUNTIME_DIR" && chmod 0700 "$XDG_RUNTIME_DIR"
    weston --backend=headless --width=1024 --height=768 --socket=toddy-test &
    sleep 1
    export WAYLAND_DISPLAY=toddy-test
    TODDY_TEST_BACKEND=windowed mix test
```

On Arch Linux, `weston` and `vulkan-swrast` are available via pacman.

### Progressive CI

Run pooled_mock tests fast, then promote to higher-fidelity backends for subsets:

```yaml
# All tests on pooled_mock (fast, catches logic bugs)
- run: mix test

# Full suite on headless for protocol verification
- run: TODDY_TEST_BACKEND=headless mix test

# Windowed for pixel regression (tagged subset)
- run: |
    Xvfb :99 -screen 0 1024x768x24 &
    export DISPLAY=:99
    TODDY_TEST_BACKEND=windowed mix test --only windowed
```

Tag tests that need a specific backend:

```elixir
@tag :headless
test "protocol round-trip" do
  # ...
end

@tag :windowed
test "window opens and renders" do
  # ...
end
```


## Wire format in test backends

The headless and windowed backends communicate with the renderer using the same
wire protocol as the production Bridge. By default, both use MessagePack
(`{:packet, 4}` framing). JSON is available for debugging:

```elixir
# In test setup or application config
config :toddy, :test_format, :json
```

Or pass `format: :json` in backend opts when starting a session manually:

```elixir
session = Session.start(MyApp, backend: Toddy.Test.Backend.Headless, format: :json)
```

The pooled_mock backend does not use a wire protocol (pure Elixir, no
renderer process), so the format option has no effect on it.


## Testing extensions

Extension widgets have two testing layers: Elixir-side logic (struct
building, command generation, demo app behavior) and Rust-side
rendering (the widget actually renders, handles events, etc.).

### Elixir-side: unit tests (no renderer)

Extension macros generate structs, setters, and protocol
implementations. Test these directly:

```elixir
defmodule MyGauge.MacroTest do
  use ExUnit.Case, async: true

  test "new/2 creates struct with defaults" do
    gauge = MyGauge.new("g1", value: 50)
    assert gauge.id == "g1"
    assert gauge.value == 50
  end

  test "build/1 produces correct node" do
    node = MyGauge.new("g1", value: 75) |> MyGauge.build()
    assert node.type == "gauge"
    assert node.props["value"] == 75
  end

  test "push command" do
    cmd = MyGauge.push("g1", 42.0)
    assert %Toddy.Command{type: :extension_command} = cmd
  end
end
```

Demo apps test the extension in context:

```elixir
defmodule MyGauge.DemoTest do
  use ExUnit.Case, async: true

  test "view produces a gauge widget" do
    model = MyGauge.Demo.init([])
    tree = MyGauge.Demo.view(model) |> Toddy.Tree.normalize()
    gauge = Toddy.Tree.find(tree, "my-gauge")
    assert gauge.type == "gauge"
  end
end
```

### Rust-side: unit tests (no Elixir)

The `toddy_core::testing` module provides `TestEnv` and node factories
for testing `WidgetExtension::render()` in isolation:

```rust
use toddy_core::testing::*;
use toddy_core::prelude::*;

#[test]
fn gauge_renders_without_panic() {
    let ext = MyGaugeExtension::new();
    let test = TestEnv::default();
    let node = node_with_props("g1", "gauge", json!({"value": 75}));
    let env = test.env();
    let _element = ext.render(&node, &env);
}
```

### End-to-end: through the renderer

To verify extension widgets survive the wire protocol round-trip and
render correctly, build a custom renderer binary that includes the
extension's Rust crate:

```bash
# Build the custom renderer with your extension compiled in
mix toddy.build

# Run tests through the real renderer (headless, no display server)
TODDY_TEST_BACKEND=headless mix test
```

`mix toddy.build` reads extensions from application config:

```elixir
# config/config.exs
config :toddy, extensions: [MyGauge]
```

The custom binary is placed at `_build/<env>/toddy/target/debug/<project>-toddy`.
`Toddy.Binary.path!/0` finds it automatically, so the headless
and windowed test backends use it without additional configuration.

Write end-to-end tests with `Toddy.Test.Case`:

```elixir
defmodule MyGauge.EndToEndTest do
  use Toddy.Test.Case, app: MyGauge.Demo

  test "gauge appears in rendered tree" do
    assert_exists "#my-gauge"
  end

  test "gauge responds to push command" do
    click("#push-value")
    assert_text "#value-display", "42"
  end
end
```

These tests run on `:pooled_mock` by default (fast, logic-only). Set
`TODDY_TEST_BACKEND=headless` to exercise the full Rust rendering path
with the extension compiled in.


## Known limitations

Workarounds and details for each limitation are noted inline below.

- Script instruction `move` (move cursor to a widget by selector) is a
  no-op. It requires widget bounds from layout, which only the renderer knows.
- `move_to` on the pooled_mock backend dispatches `%Mouse{type: :moved, x: x, y: y}` but has
  no spatial layout info. Mouse area enter/exit events won't fire.
- Pixel screenshots are only available on the headless and windowed backends (pooled_mock returns stubs).
- Headless screenshots use software rendering (tiny-skia) and may not match
  GPU output pixel-for-pixel.
- Script `assert_model` uses substring matching against the inspected model.
  Use specific substrings (`"count: 5"`) or use ExUnit assertions for precise
  model checks.
- The `CommandProcessor` executes async/stream/batch commands synchronously
  in all test backends. Timing and concurrency bugs will not surface in mock
  tests. Use headless or windowed backends for concurrency-sensitive tests.
- Headless and windowed backends spawn a renderer via `Port`. The `on_exit`
  cleanup handles normal teardown; if a test crashes without triggering it,
  the BEAM's process exit propagation kills the port.
