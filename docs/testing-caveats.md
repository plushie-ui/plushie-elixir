# Testing caveats

Known limitations of julep's test framework, with workarounds and paths to
resolution. Each entry documents what the limitation is, why it exists, how
to work around it, and what a real fix would look like.


## ~~`await_async` is a no-op on headless and full backends~~ (resolved)

**Fixed.** All three backends now use the shared `CommandProcessor` module
to execute async/stream/done/batch commands synchronously. Commands returned
by `init/1` and `update/2` are processed immediately, so `await_async`
correctly returns `:ok` -- the commands have already completed by the time
it is called.

The `CommandProcessor` was extracted from the sim backend's private
implementation and is shared by sim, headless, and full backends.


## ~~Script instructions `press`, `release`, `move`, `move_to` are no-ops~~ (mostly resolved)

**Fixed.** `press/1`, `release/1`, `type_key/1`, and `move_to/2` are now
implemented as backend callbacks, session delegates, and importable helpers.
Key strings support modifier prefixes: `"ctrl+s"`, `"shift+enter"`,
`"ctrl+shift+z"`. Named keys are mapped to atoms: `"enter"` -> `:enter`,
`"escape"` -> `:escape`, etc.

All three backends support these operations:
- **sim:** Dispatches `{:key_press, %KeyEvent{}}` / `{:key_release, ...}` /
  `{:cursor_moved, x, y}` directly through `update/2`.
- **headless/full:** Sends interact messages over the wire protocol. Rust
  side parses the key string and emits event JSON.

**Remaining limitation:** `move` (move cursor to a widget by selector)
remains a no-op. It requires widget bounds from layout, which only the
renderer knows. `move_to/2` (move to absolute coordinates) works on all
backends, but on sim it has no spatial layout info -- mouse area enter/exit
events won't fire because there's no hit testing against widget bounds.


## ~~`type_key` is a no-op on all backends~~ (resolved)

**Fixed.** `type_key/1` dispatches both a `key_press` and `key_release`
event. Supports modifier prefixes like `"ctrl+c"` and named keys like
`"enter"`, `"escape"`, `"tab"`.


## ~~Screenshots are stubs on sim and headless backends~~ (partially resolved)

**What:** `screenshot/1` and `assert_screenshot/1` now return real RGBA pixel
data on both the `:full` and `:headless` backends. Only the `:sim` backend
returns a stub (empty hash, no pixel data).

**Why this changed:** The headless backend now uses tiny-skia software
rendering to produce real RGBA screenshots without a display server. The
`screenshot_capture` message includes viewport dimensions (`width`, `height`)
which the Rust headless renderer uses to size the tiny-skia surface.

**Remaining caveat:** Headless screenshots use software rendering (tiny-skia),
so pixels will not match GPU-rendered output (`:full` backend) exactly. Use
headless screenshots for catching layout regressions and verifying the
rendering pipeline; use full screenshots for pixel-perfect visual regression
against GPU output.

The sim backend still returns an empty `Screenshot` struct because it has no
renderer at all. `assert_match` silently accepts empty hashes.

`save_png/2` and the `save_screenshot/1` helper can write RGBA data to disk
as valid PNG files for manual inspection or archival:

```elixir
test "renders correctly" do
  click("#increment")
  assert_snapshot("counter-at-1")       # always works
  assert_screenshot("counter-pixels")   # checks on :headless and :full
  save_screenshot("counter-debug")      # writes PNG to test/screenshots/
end
```


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
