# Testing

## Philosophy

Progressive fidelity: test your app's logic with fast, pure-Elixir sim tests;
promote to headless or full backends when you need wire-protocol verification
or pixel-accurate screenshots. See
[ADR-0008](decisions/0008-test-framework-architecture.md) for design rationale.


## Unit testing

`update/2` is pure, `view/1` returns maps. Plain ExUnit -- no framework
needed.

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

Commands are plain `%Julep.Command{}` structs. Pattern-match on `type` and
`payload` to verify what `update/2` asked the runtime to do, without
executing anything.

```elixir
test "submitting todo refocuses the input" do
  model = %{todos: [], input: "Buy milk"}
  {model, cmd} = MyApp.update(model, {:submit, "todo_input", "Buy milk"})

  assert [%{text: "Buy milk"}] = model.todos
  assert %Julep.Command{type: :focus, payload: %{target: "todo_input"}} = cmd
end

test "save triggers an async task" do
  model = %{data: "unsaved"}
  {_model, cmd} = MyApp.update(model, {:click, "save"})

  assert %Julep.Command{type: :async, payload: %{tag: :save_result}} = cmd
end
```

### Testing `view/1`

```elixir
test "view shows todo count" do
  model = %{todos: [%{id: 1, text: "Buy milk", done: false}], input: "", filter: :all}
  tree = MyApp.view(model)

  counter = Julep.Tree.find(tree, "todo_count")
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

`Julep.Tree` provides helpers for querying view trees directly:

```elixir
Julep.Tree.find(tree, "my_button")            # find node by ID
Julep.Tree.exists?(tree, "my_button")         # check existence
Julep.Tree.ids(tree)                          # all IDs (depth-first)
Julep.Tree.find_all(tree, fn node ->          # find by predicate
  node.type == "button"
end)
```

These work on the raw `ui_node()` maps returned by `view/1`. No test
session or backend required.

### JSON tree snapshots

For complex views, snapshot the entire tree as JSON to catch unintended
structural changes. `Julep.Test.assert_tree_snapshot/2` compares a tree
against a stored JSON file at the unit test level -- no backend needed.

```elixir
test "initial view snapshot" do
  model = MyApp.init([])
  tree = MyApp.view(model)

  Julep.Test.assert_tree_snapshot(tree, "test/snapshots/initial_view.json")
end
```

First run writes the file. Subsequent runs compare and fail with a diff on
mismatch. Update after intentional changes:

```bash
JULEP_UPDATE_SNAPSHOTS=1 mix test
```

This is a pure JSON comparison -- it normalizes map key ordering for stable
output. It is distinct from the framework's `assert_snapshot/1` (which uses
SHA-256 hashes of the tree via a backend session) and `assert_screenshot/1`
(which compares pixel data).


## The test framework

Unit tests cover logic. But they cannot click a button, verify a widget
appears after an interaction, or catch a rendering regression when you bump
iced. That is what the test framework is for.

```elixir
defmodule MyApp.CounterTest do
  use Julep.Test.Case, app: MyApp.Counter

  test "clicking increment updates counter" do
    click("#increment")
    assert_text "#count", "1"
  end
end
```

`Julep.Test.Case` starts a session, imports all helper functions, and tears
down on exit. The default backend is `:sim` -- no Rust binary, no display
server, no setup.


## Selectors, interactions, and assertions

### Where do widget IDs come from?

Every widget in julep gets an ID from the first argument to its builder or
constructor. For example, `Button.new("save_btn", "Save")` creates a button
with ID `"save_btn"`. In `Julep.UI`, `button("save_btn", "Save")` does the
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
automatically by `Julep.Test.Case`.

| Function | Widget types | Event produced |
|---|---|---|
| `click(selector)` | `button` | `{:click, id}` |
| `type_text(selector, text)` | `text_input`, `text_editor` | `{:input, id, text}` |
| `submit(selector)` | `text_input` | `{:submit, id, value}` |
| `toggle(selector)` | `checkbox`, `toggler` | `{:toggle, id, !current}` |
| `select(selector, value)` | `pick_list`, `combo_box`, `radio` | `{:select, id_or_group, value}` |
| `slide(selector, value)` | `slider`, `vertical_slider` | `{:slide, id, value}` |

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

All of the following are imported by `use Julep.Test.Case`:

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
| `snapshot(name)` | Capture a structural tree snapshot |
| `screenshot(name)` | Capture a pixel screenshot (no-op on sim) |
| `save_screenshot(name)` | Capture screenshot and save as PNG to `test/screenshots/` |
| `assert_text(selector, expected)` | Assert widget contains expected text |
| `assert_exists(selector)` | Assert widget exists in the tree |
| `assert_not_exists(selector)` | Assert widget does NOT exist in the tree |
| `assert_model(expected)` | Assert model equals expected (strict equality) |
| `assert_snapshot(name)` | Capture snapshot and assert it matches golden file |
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

| | `:sim` | `:headless` | `:full` |
|---|---|---|---|
| **Speed** | ~ms | ~100ms | ~seconds |
| **Rust binary** | No | Yes (`--headless`) | Yes (`--test`) |
| **Display server** | No | No | Yes (Xvfb in CI) |
| **Tests logic** | Yes | Yes | Yes |
| **Tests tree structure** | Yes | Yes | Yes |
| **Protocol round-trip** | No | Yes | Yes |
| **Structural snapshots** | Yes | Yes | Yes |
| **Pixel screenshots** | No | Yes (software) | Yes |
| **Effects** | Collected, not executed | Not executed | Executed |
| **Subscriptions** | Not active | Not active | Active |
| **Real windows** | No | No | Yes |

- **`:sim`** -- pure Elixir. Tests app logic and tree structure. No Rust, no
  display, sub-millisecond. The right default for 90% of tests.

- **`:headless`** -- real Rust renderer with `iced_test` Simulator (no
  display server). Proves the wire protocol works end-to-end (msgpack by
  default). Tree-hash snapshots detect structural drift. Build with
  `cargo build --features headless`.

- **`:full`** -- real `iced::daemon` with GPU rendering. Effects work,
  subscriptions fire, pixel screenshots capture exactly what a user sees.
  Build with `cargo build --features test-mode`. Needs a display server
  (Xvfb or headless Weston).

### Backend selection

You never choose a backend in your test code. Backend selection is an
infrastructure decision made via environment variable or application config.
Tests are portable across all three.

| Priority | Source | Example |
|---|---|---|
| 1 | Environment variable | `JULEP_TEST_BACKEND=headless mix test` |
| 2 | Application config | `config :julep, :test_backend, :sim` |
| 3 | Default | `:sim` |

Atom shorthands (`:sim`, `:headless`, `:full`) and full module names
(`Julep.Test.Backend.Sim`, etc.) both work in application config.


## Snapshots and screenshots

Julep has three distinct regression testing mechanisms. Understanding the
difference is important.

### Structural snapshots (`assert_snapshot`)

`assert_snapshot/1` captures a SHA-256 hash of the serialized UI tree and
compares it against a golden file. It works on all three backends because
every backend can produce a tree.

```elixir
test "counter initial state" do
  assert_snapshot("counter-initial")
end

test "counter after increment" do
  click("#increment")
  assert_snapshot("counter-at-1")
end
```

Golden files are stored in `test/snapshots/` as `.sha256` files. On first
run, the golden file is created automatically. On subsequent runs, the hash
is compared and the test fails on mismatch.

To update golden files after intentional changes:

```bash
JULEP_UPDATE_SNAPSHOTS=1 mix test
```

### Pixel screenshots (`assert_screenshot`)

`assert_screenshot/1` captures real RGBA pixel data and compares it against
a golden file. It produces meaningful data on both the `:full` backend (GPU
rendering via wgpu) and the `:headless` backend (software rendering via
tiny-skia). On `:sim`, it silently succeeds as a no-op (returns an empty
hash, which is accepted without creating or checking a golden file).

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
JULEP_UPDATE_SCREENSHOTS=1 mix test
```

Because screenshots silently no-op on sim, you can include
`assert_screenshot` calls in any test without conditional logic. They will
produce assertions when run on the headless or full backends.

### JSON tree snapshots (`assert_tree_snapshot`)

`Julep.Test.assert_tree_snapshot/2` is a unit-test-level tool that compares
a raw tree map against a stored JSON file. No backend or session needed.
See the [Unit testing](#json-tree-snapshots) section above.

### When to use each

- **`assert_snapshot`** -- always appropriate. Catches structural regressions
  (widgets appearing/disappearing, prop changes, nesting changes). Works on
  every backend. Use liberally.

- **`assert_screenshot`** -- after bumping iced, changing the renderer,
  modifying themes, or any change that affects visual output. Only meaningful
  on the full backend. Include alongside `assert_snapshot` for critical views.

- **`assert_tree_snapshot`** -- for unit tests of `view/1` output. No
  framework overhead. Good for documenting what a view produces for a given
  model state.


## Script-based testing

`.julep` scripts provide a declarative format for describing interaction
sequences. The format is a superset of iced's `.ice` test scripts -- the
core instructions (`click`, `type`, `expect`, `snapshot`) use the same
syntax. Julep adds `assert_text`, `assert_model`, `screenshot`, `wait`, and
a header section for app configuration.

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
screenshot "counter-pixels"
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

Lines starting with `#` are comments (in both header and body sections).

#### Instructions

| Instruction | Syntax | Sim support | Description |
|---|---|---|---|
| `click` | `click "selector"` | Yes | Click a widget |
| `type` | `type "selector" "text"` | Yes | Type text into a widget |
| `type` (key) | `type enter` | Yes | Send a special key (press + release). Supports modifiers: `type ctrl+s` |
| `expect` | `expect "text"` | Yes | Assert text appears somewhere in the tree |
| `snapshot` | `snapshot "name"` | Yes | Capture and assert a structural snapshot |
| `screenshot` | `screenshot "name"` | No-op on sim | Capture and assert a pixel screenshot |
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
mix julep.script

# Run specific scripts
mix julep.script test/scripts/counter.julep test/scripts/todo.julep
```

### Replaying scripts

```bash
mix julep.replay test/scripts/counter.julep
```

Replay mode forces the `:full` backend and respects `wait` timings, so you
see interactions happen in real time with real windows. Useful for debugging
visual issues, demos, and onboarding.


## Testing async workflows

### On the sim backend

The sim backend executes `async`, `stream`, and `done` commands
synchronously. When `update/2` returns a command like
`Command.async(fn -> fetch_data() end, :data_loaded)`, the sim backend
immediately calls the function, gets the result, and dispatches
`{:data_loaded, result}` through `update/2` -- all within the same call.

This means `await_async/2` returns `:ok` immediately (the work is already
done):

```elixir
test "fetching data loads results" do
  click("#fetch")
  # On sim, the async command already executed synchronously.
  # await_async is a no-op -- the model is already updated.
  await_async(:data_loaded)
  assert length(model().results) > 0
end
```

Widget ops (focus, scroll), window ops, and timers are silently skipped on
sim because they require a renderer. Test the command shape at the unit test
level instead:

```elixir
test "clicking fetch starts async load" do
  model = %{loading: false, data: nil}
  {model, cmd} = MyApp.update(model, {:click, "fetch"})

  assert model.loading == true
  assert %Julep.Command{type: :async, payload: %{tag: :data_loaded}} = cmd
end
```

### On headless and full backends

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
cd native/julep_gui && cargo build --features headless
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

Requires a display server and GPU/software rendering. Two options:

**Option A: Xvfb (X11)**

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

**Option B: Weston (Wayland)**

Weston's headless backend provides a Wayland compositor without a physical
display. Combined with `vulkan-swrast` (Mesa software rasterizer), this
runs the full rendering pipeline on CPU.

```yaml
- run: |
    sudo apt-get install -y weston mesa-vulkan-drivers
    cd native/julep_gui
    cargo build --features test-mode
- run: |
    export XDG_RUNTIME_DIR=/tmp/julep-xdg-runtime
    mkdir -p "$XDG_RUNTIME_DIR" && chmod 0700 "$XDG_RUNTIME_DIR"
    weston --backend=headless --width=1024 --height=768 --socket=julep-test &
    sleep 1
    export WAYLAND_DISPLAY=julep-test
    JULEP_TEST_BACKEND=full mix test
```

On Arch Linux, `weston` and `vulkan-swrast` are available via pacman.

### Progressive CI

Run sim tests fast, then promote to higher-fidelity backends for subsets:

```yaml
# All tests on sim (fast, catches logic bugs)
- run: mix test

# Full suite on headless for protocol verification
- run: |
    cd native/julep_gui && cargo build --features headless
    JULEP_TEST_BACKEND=headless mix test

# Full for pixel regression (tagged subset)
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


## Wire format in test backends

The headless and full backends communicate with the renderer using the same
wire protocol as the production Bridge. By default, both use MessagePack
(`{:packet, 4}` framing). JSON is available for debugging:

```elixir
# In test setup or application config
config :julep, :test_format, :json
```

Or pass `format: :json` in backend opts when starting a session manually:

```elixir
session = Session.start(MyApp, backend: Julep.Test.Backend.Headless, format: :json)
```

The sim backend does not use a wire protocol (pure Elixir, no renderer
process), so the format option has no effect on it.


## Known limitations

See [testing-caveats.md](testing-caveats.md) for detailed workarounds for
each limitation.

- Script instruction `move` (move cursor to a widget by selector) is a
  no-op. It requires widget bounds from layout, which only the renderer knows.
- `move_to` on the sim backend dispatches `{:cursor_moved, x, y}` but has
  no spatial layout info. Mouse area enter/exit events won't fire.
- Pixel screenshots are only available on the headless and full backends (sim returns stubs).
- Headless screenshots use software rendering (tiny-skia) and may not match
  GPU output pixel-for-pixel.
- Script `assert_model` uses substring matching against the inspected model.
