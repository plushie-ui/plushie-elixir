# Testing caveats

Known limitations of julep's test framework, with workarounds and paths to
resolution. Each entry documents what the limitation is, why it exists, how
to work around it, and what a real fix would look like.


## `await_async` is a no-op on headless and full backends

**What:** `await_async/2` returns `:ok` immediately on the headless and full
backends without actually waiting for the async task to complete.

**Why:** The headless and full backends dispatch events back through the
wire protocol. Async commands are executed by the sim layer's
`process_commands` on the Elixir side, but the headless/full GenServer
implementations do not track running tasks by tag. The sim backend does not
need `await_async` at all because it executes async commands synchronously.

**Workaround:** On headless/full, use `Process.sleep/1` with a reasonable
timeout after triggering an async action, then assert on the model state.
Alternatively, test async command shapes at the unit test level:

```elixir
# Unit test level -- verify the command is correct
{_model, cmd} = MyApp.update(model, {:click, "fetch"})
assert %Julep.Command{type: :async, payload: %{tag: :data_loaded}} = cmd

# Sim test level -- async executes synchronously, no waiting needed
click("#fetch")
assert length(model().results) > 0
```

**Real fix:** Track async tasks by tag in the headless/full backend
GenServers and implement a polling or message-based wait in `await_async`.


## Script instructions `press`, `release`, `move`, `move_to` are no-ops

**What:** The `press`, `release`, `move`, and `move_to` script instructions
silently do nothing on all backends.

**Why:** These instructions require subscription-level event injection (key
press/release events, mouse movement events) which the interact protocol
does not implement. The interact protocol handles widget-level interactions
(click, type_text, toggle, etc.) but not raw input events.

**Workaround:** For key-driven behavior, test at the unit level by
dispatching the event tuple directly:

```elixir
event = {:key_press, %Julep.KeyEvent{key: :enter, modifiers: %{}}}
model = MyApp.update(model, event)
```

For mouse movement, there is no workaround in the test framework. Test the
`update/2` handler directly with the event tuples your subscriptions
produce.

**Real fix:** Extend the interact protocol to support raw input events.
This requires changes in both the Elixir protocol encoder and the Rust
`headless.rs`/`test_mode.rs` handlers.


## `type_key` is a no-op on all backends

**What:** The `type_key` script instruction (e.g., `type enter`) does
nothing on any backend.

**Why:** Same root cause as `press`/`release`. Special key events are
subscription-level events, not widget interactions. The interact protocol
does not support injecting keyboard events.

**Workaround:** Use `submit/1` for the common case of pressing Enter in a
text input. For other key events, test at the unit level:

```elixir
# Instead of `type_key "escape"` in a script:
event = {:key_press, %Julep.KeyEvent{key: :escape, modifiers: %{}}}
model = MyApp.update(model, event)
```

**Real fix:** Same as `press`/`release` -- extend the interact protocol.


## Screenshots are stubs on sim and headless backends

**What:** `screenshot/1` and `assert_screenshot/1` return real RGBA pixel
data on the full backend but silently no-op on sim and headless. The sim
and headless backends return a `Screenshot` struct with an empty hash, and
`assert_match` accepts empty hashes without creating or checking golden
files.

**Why:** The sim backend has no renderer, so there are no pixels to capture.
The headless backend uses `iced_test` Simulator for tree-level testing but
does not render to a pixel buffer. The full backend runs wgpu and captures
real GPU-rendered RGBA pixels via `iced::window::screenshot()`.

**Workaround:** Include `assert_screenshot` calls freely in your tests.
They will automatically activate when run on the full backend. No
conditional logic needed:

```elixir
test "renders correctly" do
  click("#increment")
  assert_snapshot("counter-at-1")       # always works
  assert_screenshot("counter-pixels")   # only checks on :full
end
```

**Real fix:** The headless backend could potentially render to a pixel
buffer via tiny-skia. This would give screenshot support without a display
server but with software rendering (different from GPU output). Whether this
is desirable depends on the use case -- software-rendered screenshots would
not match GPU-rendered ones pixel-for-pixel.


## Script `assert_model` uses substring matching

**What:** The `assert_model "expression"` script instruction checks whether
the expression string appears anywhere in the `inspect()` output of the
current model. It is not an equality check.

**Why:** Script instructions are strings, not Elixir expressions. Parsing
and evaluating arbitrary Elixir expressions from a script file would
introduce `Code.eval_string/1` and the security/complexity that comes with
it. Substring matching was chosen as a simple, safe approximation.

**Workaround:** Use specific, unambiguous substrings. For example:

```
assert_model "count: 5"
assert_model "loading: false"
```

For precise model assertions, use the ExUnit test framework directly
(`assert_model %{count: 5}` in a test case) rather than scripts.

**Real fix:** If precise model assertions in scripts are needed, implement a
restricted expression parser that supports basic patterns (e.g.,
`field: value` pairs) without full `Code.eval_string`.


## ~~`submit/1` in sim uses tree props, not typed text~~ (resolved)

**Fixed.** The sim backend now tracks text typed via `type_text/2` per
widget and uses it as the submit value. `type_text("#name", "Alice")`
followed by `submit("#name")` submits `"Alice"` regardless of whether
`view/1` echoes the value back into the text_input's `value` prop.

The fallback to `EventMap.submit/1` (which reads the tree prop) still
applies when `submit` is called without a prior `type_text` for that
widget. `reset/0` clears the typed text tracking.
