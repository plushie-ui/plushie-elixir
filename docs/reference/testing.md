# Testing Reference

Complete reference for the Plushie test framework. For a narrative
introduction, see the [Testing guide](../guides/14-testing.md).

## Setup

```elixir
# test/test_helper.exs
Plushie.Test.setup!()
ExUnit.start()
```

See `Plushie.Test` for setup options.

## Test cases

| Module | Purpose |
|---|---|
| `Plushie.Test.Case` | Full app testing -- starts Runtime + Bridge per test |
| `Plushie.Test.WidgetCase` | Single widget testing in a harness app |

### Plushie.Test.Case

```elixir
use Plushie.Test.Case, app: MyApp
```

Starts a fresh app instance before each test. Imports all helpers. Tests run
in parallel (`async: true`). On teardown, checks prop validation diagnostics
and raises if any are found.

### Plushie.Test.WidgetCase

```elixir
use Plushie.Test.WidgetCase, widget: MyWidget

setup do
  init_widget("widget-id", prop1: "value")
end
```

Hosts the widget in a parameterized harness app (window > column > widget).
All standard helpers are available. Additional helpers:

| Function | Description |
|---|---|
| `last_event/0` | Most recently emitted `WidgetEvent`, or nil |
| `events/0` | All emitted events, newest first |

These are the only WidgetCase-specific helpers.

## Helpers by category

All imported automatically by `Plushie.Test.Case` and `Plushie.Test.WidgetCase`.
See `Plushie.Test.Helpers` for full specs.

### Queries

| Function | Description |
|---|---|
| `find(selector)` | Find element, return nil if not found |
| `find!(selector)` | Find element, raise if not found |
| `find_by_role(role)` | Find by accessibility role |
| `find_by_label(label)` | Find by accessibility label |
| `find_focused()` | Currently focused element |
| `text(element)` | Extract display text from an element |

### Interactions

| Function | Widget types | Event produced |
|---|---|---|
| `click(selector, opts)` | button, any clickable | `:click` |
| `type_text(selector, text, opts)` | text_input, text_editor | `:input` |
| `submit(selector, opts)` | text_input | `:submit` |
| `toggle(selector, opts)` | checkbox, toggler | `:toggle` |
| `toggle(selector, value, opts)` | checkbox, toggler | `:toggle` with specific value |
| `select(selector, value, opts)` | pick_list, combo_box, radio | `:select` |
| `slide(selector, value, opts)` | slider, vertical_slider | `:slide` |
| `scroll(selector, dx, dy, opts)` | scrollable | `:scroll` |
| `paste(selector, text, opts)` | text_input, text_editor | `:paste` |
| `canvas_press(selector, x, y, opts)` | canvas | `:canvas_press` |
| `canvas_release(selector, x, y, opts)` | canvas | `:canvas_release` |
| `canvas_move(selector, x, y, opts)` | canvas | `:canvas_move` |
| `press(key)` | -- | `Plushie.Event.Key` |
| `release(key)` | -- | `Plushie.Event.Key` |
| `type_key(key)` | -- | press + release |
| `move_to(x, y)` | -- | cursor position |

All interactions are synchronous -- they wait for the full update cycle to
complete before returning.

### Multi-window interactions

Add `window:` to target a specific window:

```elixir
click("#save", window: "settings")
type_text("#name", "hello", window: "settings")
```

Without `window:`, an ambiguous ID that exists in multiple windows raises
an error.

### Key name parsing

Key names are case-insensitive. Named keys use PascalCase internally:

- Named keys: `"Tab"`, `"ArrowRight"`, `"Escape"`, `"Enter"`, `"Backspace"`,
  `"Delete"`, `"PageUp"`, `"PageDown"`, `"Home"`, `"End"`, `"Space"`
- Single characters: lowercased (`"s"`, `"a"`, `"1"`)
- Modifier combos: `"Ctrl+s"`, `"Shift+ArrowUp"`, `"Alt+F4"`
- Modifiers: `shift`, `ctrl`, `alt`, `logo`, `command`

### Assertions

| Macro | Description |
|---|---|
| `assert_text(selector, expected)` | Widget displays expected text |
| `assert_exists(selector)` | Widget is in the tree |
| `assert_not_exists(selector)` | Widget is not in the tree |
| `assert_model(pattern)` | Model matches pattern |
| `assert_role(selector, role)` | Accessibility role matches |
| `assert_a11y(selector, expected)` | Accessibility props match |
| `assert_no_diagnostics()` | No prop validation warnings |

### State inspection

| Function | Description |
|---|---|
| `model()` | Current app model |
| `tree()` | Normalized UI tree |
| `tree_hash(name)` | Capture structural tree hash |
| `screenshot(name, opts)` | Capture pixel screenshot |
| `save_screenshot(name, opts)` | Save screenshot as PNG |

### Async and effects

| Function | Description |
|---|---|
| `await_async(tag, timeout)` | Wait for tagged async task |
| `register_effect_stub(kind, response)` | Mock a platform effect |
| `unregister_effect_stub(kind)` | Remove effect mock |
| `reset()` | Reset session to initial state |

Effect stubs are scoped to the test process and auto-cleaned on teardown.

## Selector syntax

| Form | Matches |
|---|---|
| `"#widget_id"` | Local widget ID (# prefix required) |
| `"#scope/path/id"` | Exact scoped path |
| `"Visible Text"` | Widget displaying this text (depth-first) |
| `{:role, :button}` | Widget with accessibility role |
| `{:label, "Name"}` | Widget with accessibility label |
| `:focused` | Currently focused widget |

## Backend capabilities

Tests run against one of three backends. Selection:
`PLUSHIE_TEST_BACKEND` env var or `config :plushie, :test_backend`.

| Backend | Speed | Rendering | Screenshots | Effects |
|---|---|---|---|---|
| `:mock` | ~ms | Protocol only | Hash only | Stubs only |
| `:headless` | ~100ms | Software rendering | Pixel-accurate | Stubs only |
| `:windowed` | ~seconds | GPU rendering | Pixel-accurate | Real |

The mock backend uses focus + space for click simulation and synthetic events
for canvas/select. All backends use the real renderer binary and real wire
protocol.

Tests are backend-agnostic -- the same assertions work on all three.

## Screenshots and tree hashes

```elixir
assert_tree_hash("initial-state")     # structural tree comparison
assert_screenshot("styled-view")       # pixel comparison
```

Golden files are stored in `test/snapshots/` (tree hashes) and
`test/screenshots/` (pixel hashes). First run creates the golden file;
subsequent runs compare against it.

Update golden files when the UI intentionally changes:

```bash
PLUSHIE_UPDATE_SNAPSHOTS=1 mix test     # tree hashes
PLUSHIE_UPDATE_SCREENSHOTS=1 mix test   # pixel screenshots
```

These are separate environment variables.

## .plushie scripting format

Declarative test scripts with a header and instruction list:

```
app: MyApp
viewport: 800x600
theme: dark
backend: mock
-----
click "#save"
type_text "#editor" "Hello"
expect "Hello"
screenshot "after-hello"
wait 500
assert_text "#count" "3"
```

**Header fields:** `app:` (required), `viewport:` (default 800x600),
`theme:`, `backend:` (default mock).

**Instructions:**

| Instruction | Description |
|---|---|
| `click SELECTOR` | Click a widget |
| `type_text SELECTOR TEXT` | Type into a widget |
| `type_key KEY` | Press and release a key |
| `press KEY` | Key down |
| `release KEY` | Key up |
| `move_to X Y` | Move cursor |
| `toggle SELECTOR [true\|false]` | Toggle checkbox |
| `select SELECTOR VALUE` | Select from list |
| `slide SELECTOR VALUE` | Move slider |
| `expect TEXT` | Assert text appears in tree |
| `screenshot NAME` | Capture screenshot |
| `assert_text SELECTOR TEXT` | Assert widget text |
| `assert_model EXPR` | Assert model matches |
| `wait MS` | Pause for milliseconds |

```bash
mix plushie.script                           # run all in test/scripts/
mix plushie.script path/to/test.plushie      # run specific script
mix plushie.replay path/to/test.plushie      # replay with real windows
```

## See also

- `Plushie.Test.Case` -- case template docs
- `Plushie.Test.Helpers` -- helper function specs
- `Plushie.Test.WidgetCase` -- widget testing harness
- [Testing guide](../guides/14-testing.md) -- narrative walkthrough
