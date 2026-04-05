# Testing

Plushie tests exercise the real renderer binary. Every test starts a full
application instance (Runtime, Bridge, and renderer) and interacts with
it through the same wire protocol that a real user session uses. This catches
bugs that live at the boundary between the SDK and the renderer: wire format
drift, startup ordering, codec issues.

This chapter covers the testing framework and applies it to the pad.

## Setting up

In `test/test_helper.exs`:

```elixir
Plushie.Test.setup!()
ExUnit.start()
```

`Plushie.Test.setup!/0` configures the test environment: starts the renderer
session pool, sets up ExUnit exclusions for backend-specific tests, and
registers cleanup hooks.

Tests run against the mock backend by default. This is the fastest option --
it uses the real binary with the real wire protocol, but skips GPU rendering.

## Plushie.Test.Case

`Plushie.Test.Case` is an ExUnit case template that starts a real app
instance for each test:

```elixir
defmodule PlushiePad.PadTest do
  use Plushie.Test.Case, app: PlushiePad

  test "initial state has empty event log" do
    assert model().event_log == []
  end

  test "save button compiles the preview" do
    click("#save")
    assert_exists("#preview")
  end
end
```

`use Plushie.Test.Case, app: PlushiePad` starts a fresh PlushiePad instance
before each test, connected to the renderer session pool. All test helper
functions are imported automatically. Tests are synchronous by default
(`async: false`) because each test gets its own renderer session.

## Selectors

Most helper functions take a selector to identify widgets:

| Selector | Matches |
|---|---|
| `"#save"` | Widget with local ID `"save"` |
| `"#sidebar/hello.ex/delete"` | Widget at exact scoped path |
| `"main#save"` | Widget `"save"` in window `"main"` |
| `"main#form/save"` | Scoped path `"form/save"` in window `"main"` |
| `{:text, "Save"}` | Widget displaying the text "Save" |
| `{:role, :button}` | Widget with accessibility role `:button` |
| `{:label, "Email"}` | Widget with accessibility label "Email" |
| `:focused` | Currently focused widget |

The `#` prefix marks ID selectors. The `window_id#path` form scopes
the selector to a specific window. Useful for multi-window apps
where the same widget ID may appear in different windows. Text content
matching uses the `{:text, "..."}` tuple form. Bare strings without a
`#` prefix are not valid selectors and will raise an `ArgumentError`.

## Finding elements

```elixir
element = find!("#save")        # returns element or raises
element = find("#save")         # returns element or nil
element = find_by_role(:button) # by accessibility role
element = find_by_label("Save") # by accessibility label
element = find_focused()        # currently focused element

text(element)                   # extract display text
```

## Interactions

```elixir
click("#save")                         # click a button
type_text("#editor", "hello")          # type into a text input/editor
submit("#search")                      # press Enter on a text_input
toggle("#auto-save")                   # toggle a checkbox
toggle("#auto-save", true)             # set specific value
select("#theme", "dark")               # select from pick_list/combo_box
slide("#volume", 75)                   # move a slider

# Canvas
canvas_press("#drawing", 100.0, 50.0)  # press at coordinates
canvas_release("#drawing", 100.0, 50.0)
canvas_move("#drawing", 120.0, 60.0)

# Keyboard
press("ctrl+s")                        # key down (supports modifiers)
release("ctrl+s")                      # key up
type_key("escape")                     # press + release
```

In multi-window apps, target a specific window using the `window_id#path`
selector syntax or the `window:` option:

```elixir
click("settings#save")                  # window qualifier in selector
click("#save", window: "settings")      # explicit window: option
type_text("settings#name", "hello")     # works with all interactions
```

Without either, an ambiguous ID that exists in multiple windows raises an
error.

All interactions are synchronous. They wait for the full update cycle
(event -> update -> view -> patch) to complete before returning.

## Assertions

```elixir
assert_text("#count", "Count: 3")       # widget displays expected text
assert_exists("#save")                   # widget is in the tree
assert_not_exists("#error")              # widget is not in the tree
assert_model(%{count: 3})               # model matches pattern
assert_role("#save", :button)            # accessibility role
assert_a11y("#email", %{required: true}) # accessibility properties
assert_no_diagnostics()                  # no prop validation warnings
```

## State inspection

```elixir
model()        # returns the current app model
tree()         # returns the normalized UI tree
```

`model()` is useful for asserting on internal state after interactions:

```elixir
click("#increment")
click("#increment")
assert model().count == 2
```

### Applying it: test the pad

```elixir
defmodule PlushiePad.PadTest do
  use Plushie.Test.Case, app: PlushiePad

  test "starter code renders on init" do
    assert_exists("#preview")
    assert_not_exists("#error")
  end

  test "save compiles and updates preview" do
    type_text("#editor", """
    defmodule Pad.Experiments.Test do
      import Plushie.UI
      def view do
        text("t", "Test passed")
      end
    end
    """)
    click("#save")
    assert_not_exists("#error")
  end

  test "invalid code shows error" do
    type_text("#editor", "defmodule Bad do")
    click("#save")
    assert_exists("#error")
  end

  test "keyboard shortcut saves" do
    press("ctrl+s")
    # Should compile without error if starter code is valid
    assert_not_exists("#error")
  end
end
```

## Async testing and effect stubs

For async commands, `await_async/2` waits for a tagged task to complete:

```elixir
click("#fetch")
await_async(:data_loaded, 5000)
assert_text("#result", "Success")
```

For platform effects (file dialogs, clipboard), use stubs to avoid opening
real OS dialogs in tests:

```elixir
register_effect_stub(:file_open, {:ok, %{path: "/tmp/test.ex"}})
click("#import")
# The effect stub returns immediately with the configured response
assert model().active_file != nil
```

Effect stubs register by **kind** (the operation type atom like
`:file_open`), not by tag. This means the stub applies to all effects of
that kind regardless of which tag they use. Stubs are scoped to the test
process and cleaned up automatically on teardown.

### Applying it: test import/export

```elixir
test "import loads an experiment from file" do
  register_effect_stub(:file_open, {:ok, %{path: "/tmp/hello.ex"}})
  # Ensure the file exists for File.read!
  File.write!("/tmp/hello.ex", @valid_experiment_source)

  click("#import")
  assert String.contains?(model().source, "Hello")
end
```

## Three backends

Tests run against one of three backends. The mock backend is the default and
the fastest. You can run against other backends using the
`PLUSHIE_TEST_BACKEND` environment variable:

```bash
mix test                                     # mock (default)
PLUSHIE_TEST_BACKEND=headless mix test       # real rendering, no display
PLUSHIE_TEST_BACKEND=windowed mix test       # real windows
```

| Backend | Speed | Rendering | Screenshots | Effects |
|---|---|---|---|---|
| `:mock` | ~ms | Protocol only | Hash only | Stubs |
| `:headless` | ~100ms | Software (tiny-skia) | Pixel-accurate | Stubs |
| `:windowed` | ~seconds | GPU | Pixel-accurate | Real |

Tests are backend-agnostic by default. The same test code works on all
three. Write tests once, run them at different fidelity levels.

See the [Testing reference](../reference/testing.md) for backend setup
details, CI configuration, and the full helper API.

## Screenshots and tree hashes

For structural and visual regression testing:

```elixir
# Capture a structural hash of the UI tree
assert_tree_hash("pad-initial")

# Capture a pixel screenshot (headless/windowed only)
assert_screenshot("pad-styled")
```

On first run, these create golden files in `test/snapshots/` and
`test/screenshots/`. Subsequent runs compare against the golden files.

To update golden files when the UI intentionally changes:

```bash
PLUSHIE_UPDATE_SNAPSHOTS=1 mix test    # update tree hashes
PLUSHIE_UPDATE_SCREENSHOTS=1 mix test  # update pixel screenshots
```

These are separate environment variables because you may want to update one
without the other.

## Testing custom widgets

`Plushie.Test.WidgetCase` hosts a single widget in a test harness:

```elixir
defmodule PlushiePad.EventLogTest do
  use Plushie.Test.WidgetCase, widget: PlushiePad.EventLog

  setup do
    init_widget("log", events: ["click on btn", "input on name"])
  end

  test "displays event entries" do
    assert_text("#log-0", "click on btn")
    assert_text("#log-1", "input on name")
  end

  test "toggle hides the log" do
    click("#toggle-log")
    assert_not_exists("#log-scroll")
  end
end
```

`init_widget/2` creates the widget with the given ID and props. The harness
app wraps it in a window and records emitted events.

Two helpers are specific to WidgetCase:

- `last_event/0` - the most recently emitted `WidgetEvent`, or nil
- `events/0` - all emitted events, newest first

## Automation scripts

The `.plushie` scripting format provides declarative test scripts:

```
app: PlushiePad
viewport: 1024x768
theme: dark
-----
click "#save"
expect "Hello, Plushie!"
screenshot "pad-saved"
```

Run scripts:

```bash
mix plushie.script                  # all scripts in test/scripts/
mix plushie.script path/to/test.plushie  # specific script
mix plushie.replay path/to/test.plushie  # with real windows
```

See the [Testing reference](../reference/testing.md) for the complete
instruction set.

## Try it

- Write tests for the counter from chapter 2: click increment three times,
  assert the model and display text.
- Test a file operation with an effect stub: register a stub for
  `:clipboard_write`, click copy, verify the stub was used.
- Test a custom widget with WidgetCase: create a simple toggle widget,
  click it, verify the emitted event.
- Run the same tests with `PLUSHIE_TEST_BACKEND=headless` and compare speed.

In the next chapter, we cover the development workflow: mix tasks, debugging,
and deployment.

---

Next: [Shared State](16-shared-state.md)
