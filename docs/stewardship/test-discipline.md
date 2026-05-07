# Test discipline

How tests are written, what they cost, and what they commit to.
The discipline below shows up in plushie-elixir's own test suite,
in widget integration tests, and in parallel form across every
host SDK. It is one of the project's load-bearing conventions.

## The integration spine

Tests exercise the real renderer. The default test backend
(`:mock`) runs `plushie-renderer --mock`: real binary, real wire
protocol, real codec, real Core engine. The only thing the
default backend strips is the GPU rendering step. Tests dispatch
events, read model and tree state, and assert on observable
behavior through the same API user apps use.

A test that passes against a pure-Elixir mock and would fail
against the binary is worse than no test. It gives confidence on
the exact class of bugs the integration is meant to catch: wire
format drift between encoder and renderer, startup handshake
ordering, codec edge cases, lifecycle on bridge restart, the
small protocol-level details that pure-language mocks have no
mechanism to diverge on.

This is not about coverage as a metric. It is about catching
the bugs that matter where they actually live, which is at
boundaries.

## Three test modes

The renderer offers three runtime modes; the test backends
follow them by name. The naming is a cross-SDK contract.

- **mock**: microseconds to milliseconds per test. Protocol-only.
  Real binary, real wire, real Core, no rendering. The default
  for most tests; fast enough that a full suite runs through the
  binary without flinching. `mix test` uses this.
- **headless**: tens to low hundreds of milliseconds per test.
  Real rendering via tiny-skia, no display server. Used when the
  test cares about pixels: screenshot golden files
  (`Plushie.Test.Screenshot`), tree-hash assertions, layout-
  affecting bugs. `PLUSHIE_TEST_BACKEND=headless mix test`.
- **windowed**: seconds per test. Full iced rendering with a
  real display (headless weston on Linux, native display
  elsewhere). Used when the test cares about full window
  lifecycle, focus events, or platform-specific behavior.

The names mean the same thing in plushie-rust, plushie-gleam,
plushie-typescript, plushie-python, plushie-ruby. Findings about
naming or behavior drift between the three modes route through
the parity workflow.

## Pooled mock backend

`Plushie.Test.SessionPool` starts a single `plushie-renderer
--mock --max-sessions N` process and multiplexes tests over it.
Each test gets isolated state via session IDs in every wire
message. This keeps mock-mode startup amortized across the suite
rather than paid per test. Windowed mode does not pool: each test
gets its own renderer.

Tests use `Plushie.Test.Case`, which sets up a session, gives the
test a runtime to talk to, and tears down at the end of the
test. The DSL (`click/1`, `find!/1`, `model/0`, `tree/0`,
`assert_text/2`, `assert_exists/1`) runs through the session
and exercises the real wire path.

## Synchronous test API

Tests synchronize with the runtime through production APIs:

- `Plushie.Runtime.sync/1` waits for the runtime to reach idle.
- `Plushie.Runtime.get_model/1` reads the current model.
- `Plushie.Runtime.get_tree/1` reads the current tree.

`:sys.get_state/1`, `:sys.replace_state/2`, and other `:sys`
debug functions are not used. They bypass the GenServer API and
are explicitly marked debug-only in the Erlang docs. Reading
state through the public API ensures tests exercise the real
code path and that the synchronization barriers tests rely on
also exist for production callers.

## When stubs are acceptable

A pure-Elixir stub that does not go through the renderer is
acceptable only for failure modes the binary cannot exhibit
cleanly:

- Forced renderer crash simulation (the binary cannot be told
  "panic now" via the protocol).
- Malformed wire bytes the codec rejects before any typed
  delivery path runs.
- Direct `update/2` calls to test pure return-shape behavior
  where no runtime context is needed.
- Test infrastructure that wraps the integration primitives
  themselves.

If a test can run against the binary, it does. The bar for
adding a non-binary stub is "what failure mode does this expose
that nothing else can," answered concretely.

## Tests as documentation

Tests should read as a story for the next person who opens the
file. A clear setup, an explicit action, an assertion that
names what is being verified. Behavior-driven shape: the test
framework is incidental; what is being verified should be
obvious from the test name and the body.

Use `describe` blocks for organization. The describe string
serves as a section header; comment-based section headers
(`# --- new/1 ---`) before describe blocks are noise.

The corollary: tests are not allowed to be slow. If a test is
slow, the underlying code path is usually slow in production
too. Speed up the code; do not accept the slow test. mock-mode
exists to skip the GPU step, not to hide a slow code path
behind a faster harness.

## Failing test before fix

For a bug fix, write the failing test first when possible. A
test added alongside the fix that would have passed without the
fix proves nothing about the bug. The failing test is the
definition of done.

Exceptions: refactors with no behavior change (the existing
suite is the regression net), and new features where the test
and the implementation arrive together.

## Capturing logs

Test apps must return `window` nodes from `view/1`. A bare
`column` or `row` triggers `validate_root_windows!` errors that
leak to stdout.

Tests that intentionally trigger errors (crash recovery, view
failures, renderer restarts) wrap in `capture_log/1` or use
`@describetag capture_log: true` on the describe block. Plain
`capture_log/1` only captures logs from the calling process's
group leader; for logs from GenServer processes, the describe
tag is required.

Preflight output must be clean. Any `[error]` or `[warning]` log
lines in test output are bugs. They indicate log output leaking
from tests that should be capturing it.

## Implications

- A feature has to be testable through the renderer. If a
  feature cannot be exercised through the integration spine,
  that is a design problem with the feature, not a problem with
  the test discipline.
- "Let's mock the renderer for speed" proposals are declined.
  Speed comes from mock-mode in the real binary, which is
  already fast; the cost of a pure-Elixir mock is the bug class
  it hides.
- Coverage as a percentage is a non-goal (see
  `goals-and-non-goals.md`). Coverage of real surfaces is what
  matters; the integration spine is what produces it.
- `:sys` debug functions in tests are a regression and get
  rewritten to use `Runtime.sync/get_model/get_tree` whenever
  encountered.
