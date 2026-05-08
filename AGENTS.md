# plushie-elixir

This file is not version controlled. Do not reference it in commit
messages, pull requests, or documentation.

Native desktop GUI framework for Elixir, powered by iced. Implements
the Elm architecture (init/update/view) with commands and subscriptions.
Communicates with the Rust binary over stdin/stdout using MessagePack
(default) or JSONL.

## Stewardship

Direction, trust posture, goals, and explicit non-goals are captured
in `docs/stewardship/`. That directory is the authority on what work
the project takes on and what it declines. The summary below is enough
for routine work; pull the relevant doc when an axis is in play. Use
`docs/stewardship/triage.md` as the routing tool when the answer is
not self-evident.

Pre-1.0: no backcompat, right design wins, rename across SDKs is fine.
Post-1.0: stability obligations begin (Hyrum's Law). plushie-rust =
protocol authority. plushie-elixir = canonical API-shape reference
(rename here = six-SDK change). Cross-SDK parity audited in sibling
`plushie-sdk-parity/`. Hex package is a library, not an OTP application.

### Disciplines (non-negotiable)

Tests through real renderer; cross-SDK claims verified by reading
source on each side; design before code at boundaries (public API,
DSL surface, wire codec, type behaviour); clarity is the bar; no
half-built features; local cleanup not scope creep; no legacy shims
pre-1.0.

### Goals

Wire codec fidelity on host side; cross-SDK concept parity (semantics
converge, syntax diverges per language); Elm-architecture purity
(`init/update/view`, return-shape validation, commands as pure data,
pure view, declarative subs); lightweight runtime (no idle work, no
polling, minimal tree diff via LIS); fault tolerance (renderer crash
auto-recovers + state re-syncs, app exception reverts to last good
model, view-error tracking with frozen-UI overlay, neither side takes
the other down); macro DSL clarity.

### Non-goals (declined, not deprioritized)

Backcompat before 1.0; per-Elixir API ergonomics that diverge from
cross-SDK shape; API stability hardening pre-1.0 (single 1.0 sweep,
not piecemeal); coverage targets as a metric; mocking renderer for
speed; micro-optimization at cost of readability; refactoring without
a forcing function; DSL extensions for hypothetical future widgets;
defending against speculative deployment shapes.

### Trust model

Asymmetric. Renderer-to-host = closed and typed; host structurally
protected today (typed event decoding, no opaque-blob path, effect/
query response correlation by wire ID, no host-side eval, atoms only
from closed enumeration). Host-to-renderer = broad by design (file
paths, fonts, images, screenshots, effects, `--exec`); bounding it
is the capability-manifest roadmap in plushie-rust. Wire = byte-stream
agnostic; confidentiality + integrity delegated to outer transport.
Same-access (user attacking themselves) out of scope.

### Resilience

Things-go-wrong axis, not adversary axis. App exception revert in
`init/update/view`; view-error tracking with frozen-UI overlay after
warn threshold; renderer crash auto-recovery with fresh snapshot
re-sync; rest_for_one supervision (Bridge crash -> Runtime restart;
Runtime crash alone -> Runtime re-syncs to running Bridge); defensive
parsing on the wire (reject + structured error); return-shape
validation in `unwrap_result/1` raises immediately; subscription
failure isolated. Fail-fast on programming-error invariant violations
and unrecoverable bridge startup. Degrade gracefully on user-facing
input. Log suppression after 100 consecutive errors.

### Performance

Lightweight = baseline, not optimization-after-fact. Don't do
unnecessary work in the first place; cost compounds. Worth doing
without benchmark (readability preserved/improved): consolidate
redundant traversals, right data structure, avoid unnecessary `Enum`
passes, move per-frame work that doesn't depend on per-frame inputs
to the edge. Need benchmark first (readability cost real): clever
encoding, big-O without realistic N, ETS over GenServer state without
measured contention, optimization on idle paths. Numeric direction:
16.67ms frame budget at a few hundred to ~1000 nodes; idle CPU = no
measurable work; tree diff is the load-bearing piece (LIS-based child
reorder, memo cache, widget view cache).

### Test discipline

Integration spine: tests exercise real renderer (default `:mock`
backend = real binary, real wire, real Core, no GPU). Three modes
(cross-SDK contract): mock (default, fastest), headless (tiny-skia,
pixels), windowed (full iced, real display). Pooled mock backend
multiplexes via `--max-sessions N`. Stubs acceptable only for forced
crash sim, malformed wire bytes, direct `update/2` shape tests, test
infra. Sync via `Runtime.sync/1`/`get_model`/`get_tree`, never `:sys`.
Tests as documentation; slow tests = slow code; failing test before
fix. Test apps must return `window` nodes from `view/1`. Capture logs
on intentional-error tests with `@describetag capture_log: true`.

### Simplicity

Clarity = constraint, not aspiration. Reader-cost compounds.
Readability wins ties. Abstraction earns its place: 3 similar lines
> premature abstraction; 3rd use earns consideration not commitment;
single-user abstraction = costume; "we might need this someday" =
reason not to extract. Local complexity > global. Cohesion across
file > brevity of any one file. Functional flavor (Elixir's natural
fit): pure where possible, immutable, pattern matching over
branching, sum types over flag-state-machines, errors-as-values,
composition over inheritance. Comments answer why-not-what.
Typespecs use verbose `name :: type()`; no dialyzer suppression for
mismatches.

### Elm invariants

`init/1`, `update/2` return: bare model | `{model, %Command{}}` |
`{model, [%Command{}]}`. Anything else raises `ArgumentError` from
`unwrap_result/1`. Commands are pure data; runtime executes. `view/1`
is pure function of model; top level must be window nodes
(`validate_root_windows!`). Subs declarative; runtime diffs each cycle.
Widget event flow walks scope chain innermost-first; handlers return
`:ignored`/`:consumed`/`{:update_state, _}`/`{:emit, family, data}`.
Canvas-internal events auto-consumed if not captured. Wire IDs:
`window#scope/path/id`; events split into `id`/`scope`/`window_id`
fields; commands use forward-order path strings.

### DSL discipline

Largest user-facing surface; held to same readability bar as runtime.
New macro form earns its place when: 2+ real users, replaces harder-
to-read runtime construct, real bug class detectable at compile time,
generated code reads as cleanly as hand-written, error messages point
at user's call site (not macro source). Compile-time work isn't free
(every dependent project pays the seconds). `Plushie.Type` is the
single behaviour for all types (no parallel hierarchies). Generated
code is what users read in stack traces; stable predictable structure,
named functions match expectations, errors name macro context.

### Concurrency shape

Bridge owns Port + wire framing; Runtime owns app loop + model + tree.
Two GenServers, one supervisor. `:rest_for_one`: Task.Supervisor first
(async commands need parent), Bridge before Runtime (initial Settings
cast hangs renderer if Bridge missing), Runtime last. `:transient` +
`:auto_shutdown: :any_significant` so clean window close shuts down.
Bridge crash -> Runtime restart (fresh snapshot). Runtime crash alone
-> only Runtime restarts, re-syncs to running Bridge. GenServer over
Task for sync reads (`get_model`/`get_tree`/`sync`). Transport behaviour
with Port and Iostream impls. SessionPool: multiplexed for mock/
headless, per-session for windowed. No `:sys` debug, no GenStage in
event path, no Phoenix.PubSub, library not OTP application.

### Common shapes -> outcomes

- "mock the renderer for speed" -> decline
- "use `:sys.get_state` in this test" -> rewrite to `Runtime.get_model`
- "add `@deprecated` / API hardening" -> decline; 1.0 sweep
- "this is O(n) on a hot path" -> need realistic N
- "split this large module" -> need forcing function
- "harden against malicious renderer" -> structurally protected; check
  if proposal loosens that, otherwise misframed
- "harden against malicious host" -> defer to capability-manifest
  (plushie-rust roadmap)
- "wire should encrypt / sign" -> outer transport's job
- "consolidate N redundant traversals" -> do
- "extract this single-use helper" -> decline; costume
- "this exception should propagate up" -> usually no; revert + log
- "let users return `{:noreply, model}`" -> no, bare model is no-change
- "rename field across SDKs" -> route through parity workflow
- "add new macro form for X" -> run dsl-discipline criteria; default no

## Before committing

Run `mix preflight`. It mirrors CI: format, compile (warnings as
errors), credo, test, dialyzer.

When `PLUSHIE_RUST_SOURCE_PATH` is set, preflight first rebuilds
`plushie-renderer` from that checkout via plain
`cargo build --release -p plushie-renderer` and exports
`PLUSHIE_BINARY_PATH` for the rest of the run. This guarantees tests
exercise the current source rather than a stale `_build/` artifact.
The cargo-plushie workspace machinery (used by `mix plushie.build`
for native widgets) is not needed here because the SDK's own tests
do not declare native widgets.

Preflight output must be clean. Any `[error]` or `[warning]` log
lines in the test output are bugs. They indicate log output
leaking from tests that should be capturing it. Fix the source:

- Test apps must return `window` nodes from `view/1`. A bare
  `column` or `row` without a window wrapper triggers
  `validate_root_windows!` errors that leak to stdout.
- Tests that intentionally trigger errors (crash recovery, view
  failures, renderer restarts) must wrap in `capture_log/1` or
  use `@describetag capture_log: true` to suppress expected output.
- For logs from GenServer processes (not the test process), use
  `@describetag capture_log: true` on the describe block. Plain
  `capture_log/1` only captures logs from the calling process's
  group leader.

Ignore these environment-level messages (not within our control):
- `warning: the VM is running with native name encoding of latin1`
- `Create event loop: Os(OsError ...)` (headless, no display)
- `thread 'main' panicked` from winit (headless renderer crash)

## Commit hygiene

Every commit should be self-contained and functional. Preflight
should pass at each commit, not just at the tip.

Commits after `origin/main` are unpublished and can be freely
amended, squashed, or reordered to keep the history clean. Run
`git fetch origin` first to ensure the boundary is current. Use
`--amend` to fold small fixes into the commit they belong to
rather than creating "fix the fix" commits. If a later commit
fixes a bug introduced by an earlier unpublished commit, squash
them together.

Never amend or rebase commits that are already on `origin/main`.

## Commit messages

Commit messages should describe what changed and why. Do not include:
- Counts of any kind (findings, files, tests, items). If the
  content is listed, the reader can count. Counts add noise.
- Ticket, review, or tracking IDs (R-001, PROJ-123, etc.)
- References to this file

More broadly, think carefully before including counts anywhere
(code comments, docs, log messages). If the count is derivable
from the surrounding content, it doesn't add value.

## Writing style

Do not use `--` (double dash) as a separator or em-dash substitute
in prose, docs, comments, or bullet lists. Use a single `-` for
list item separators and reword sentences to avoid inline dashes
(use commas, periods, colons, or parentheses instead). `--` should
only appear as part of CLI flag names (e.g. `--watch`, `--release`).

## Building the renderer binary

`mix plushie.build` delegates workspace generation to `cargo-plushie`,
a Cargo subcommand that lives in the plushie-rust workspace. The Mix
task's own job is narrow:

1. Discover native widgets via `Plushie.Widget` protocol consolidation.
2. Write a "renderer spec" Cargo.toml to
   `_build/<env>/plushie-renderer-spec/` listing each widget crate
   as a path dependency.
3. Shell out to `cargo plushie build --manifest-path <spec>/Cargo.toml`.
4. Copy the resulting binary to `_build/plushie/bin/`.

cargo-plushie walks the spec manifest's `cargo metadata` output to
find `[package.metadata.plushie.widget]` tables on each widget crate,
runs the collision checks, generates the actual renderer workspace
under `target/plushie-renderer/`, and drives `cargo build`.

### cargo-plushie resolution

`Mix.PlushieHelpers.resolve_cargo_plushie/0` decides how to invoke the
tool:

- **Local source** (development): when `PLUSHIE_RUST_SOURCE_PATH` is
  set, run the tool straight from the checkout with
  `cargo run -p cargo-plushie --release`. Dependencies resolve to the
  local plushie-rust crates via `[patch.crates-io]`.
- **crates.io**: otherwise expect `cargo-plushie` on PATH at the exact
  version this SDK targets (`Plushie.Binary.plushie_rust_version/0`).
  Install with `cargo install cargo-plushie --version X.Y.Z --locked`.
  If missing or mismatched, the task raises with an install hint.

Versioning: the SDK's own crate version (hex.pm) is independent of the
plushie-rust version it targets. `PLUSHIE_RUST_VERSION` pins the
plushie-rust release, `mix.exs` carries the SDK's semver. See
`docs/versioning.md`.

```
PLUSHIE_RUST_SOURCE_PATH=../plushie-rust mix plushie.build
mix plushie.build              # uses crates.io if no source path
mix plushie.build --release    # optimized build
```

Native widgets are auto-detected via `Plushie.Widget` protocol
consolidation (`Plushie.WidgetRegistry`). No explicit config
needed. Each widget crate must declare
`[package.metadata.plushie.widget] { type_name, constructor }` in its
own Cargo.toml so cargo-plushie can discover it during build.

`mix plushie.download` downloads a precompiled release binary
(only for released packages, not local development). It refuses to
download when native widgets are detected (they require a custom
build).

## Quick reference

```
mix preflight                   # run all CI checks locally
mix test                        # run tests (mock backend)
mix format                      # auto-format
mix format --check-formatted    # check formatting (CI mode)
mix credo --strict              # lint
mix dialyzer                    # type checking
mix plushie.gui MyApp             # run a plushie app
mix plushie.gui MyApp --build     # build binary first, then run
mix plushie.gui MyApp --watch     # enable hot reload (or config :plushie, code_reloader: true)
mix plushie.build                 # build renderer (auto-detects native widgets)
mix plushie.build --wasm          # build WASM renderer via wasm-pack
mix plushie.download              # download precompiled binary
mix plushie.download --wasm       # download WASM renderer
mix plushie.connect MyApp         # connect to renderer (for plushie --listen --exec)
mix plushie.script                # run .plushie automation scripts
mix plushie.replay FILE           # replay a script with real windows
```

## Testing

### Philosophy

Tests must exercise the real renderer binary. The default backend
is `mock` which runs `plushie-renderer --mock` (real binary, real
wire protocol, real Core engine, just no GPU rendering). This
catches bugs that live at the boundary between the SDK and the
renderer: wire format drift, startup handshake ordering, codec
issues. A test that passes against a pure-Elixir mock but fails
against the real binary is worse than no test. It hides the exact
class of bugs that matter most.

Stubs and direct `update/2` calls are appropriate only for edge
cases that can't be triggered through the binary: renderer crash
simulation, malformed wire data. If a test can run against the
binary, it should.

### Debug functions

Do not use `:sys.get_state`, `:sys.replace_state`, or other
`:sys` debug functions. These bypass the GenServer API and are
explicitly marked as debug-only in the Erlang docs.

Use instead:
- `Plushie.Runtime.sync(runtime)` - wait for idle (sync barrier)
- `Plushie.Runtime.get_model(runtime)` - read current model
- `Plushie.Runtime.get_tree(runtime)` - read current tree

For test synchronization after dispatching events, use `sync/1`
rather than `:sys.get_state/1`.

### Test structure

Use `describe` blocks for organization. Do not add comment-based
section headers (e.g. `# --- new/1 ---`) before `describe` blocks
because the describe string already serves that purpose. Comment headers
are only appropriate before groups of `defmodule` definitions at
the top of a test file (separating test module setup from the tests
themselves).

### Backend selection

Tests run against the real renderer binary by default. The binary
must be built before running tests (see "Building the renderer
binary" above).

```
mix test                                      # mock (default, fastest)
PLUSHIE_TEST_BACKEND=headless mix test          # real rendering, no display
```

For windowed tests (real GPU rendering), start headless weston:

```
export XDG_RUNTIME_DIR=$(mktemp -d)
weston -B headless --socket=plushie-test &
WAYLAND_DISPLAY=plushie-test XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR \
  PLUSHIE_TEST_BACKEND=windowed mix test
```

Backend names match the Gleam SDK: `mock`, `headless`, `windowed`.

## Configuration

Environment variables:
- `PLUSHIE_BINARY_PATH` - path to the plushie binary (overrides all resolution)
- `PLUSHIE_RUST_SOURCE_PATH` - path to the plushie-rust source checkout

Application config (config/*.exs):
- `config :plushie, :binary_path` - explicit binary path (deployment-specific)
- `config :plushie, :source_path` - path to Rust source checkout
- `config :plushie, :build_name` - custom binary name (default: `app-renderer`)
- `config :plushie, :build_profile` - `:release` or `:debug` (default: `:debug`)
- `config :plushie, artifacts: [:bin]` - which artifacts download/build installs
- `config :plushie, :bin_file` - override binary output path
- `config :plushie, :wasm_dir` - override WASM output directory
- `config :plushie, :code_reloader` - dev reload: `false | true | keyword()`
- `config :plushie, :test_backend` - test mode: `:mock | :headless | :windowed`

SDK-owned (not user-configurable):
- `PLUSHIE_RUST_VERSION` file at package root - plushie-rust release the SDK
  targets, read by `Plushie.Binary.plushie_rust_version/0`

Widget discovery:
- Native widgets are auto-detected via `Plushie.Tree.Node`
  consolidation. No config needed. See `Plushie.WidgetRegistry`.

## Project layout

```
lib/
  mix/
    compilers/
      plushie_binary.ex           # Mix compiler: checks for the plushie binary
    plushie_helpers.ex            # shared helpers for Mix tasks (source_path, etc.)
    tasks/
      plushie.build.ex            # mix plushie.build (Cargo workspace generation + build)
      plushie.connect.ex          # mix plushie.connect (attach to renderer via --exec)
      plushie.download.ex         # mix plushie.download (precompiled binary fetcher)
      plushie.gui.ex              # mix plushie.gui (run a Plushie app)
      plushie.inspect.ex          # mix plushie.inspect (debug tree/protocol inspection)
      plushie.replay.ex           # mix plushie.replay (replay .plushie scripts with real windows)
      plushie.script.ex           # mix plushie.script (run .plushie automation scripts)
      preflight.ex                # mix preflight (CI checks: format, compile, credo, test, dialyzer)
  plushie.ex                      # top-level Supervisor, start_link/stop API
  plushie/
    app.ex                        # Plushie.App behaviour (init/update/view/subscribe)
    ui.ex                         # single DSL layer: all macros, canvas_scope, container_scope
    ui/
      widget_set.ex               # macro for custom widget set modules (override built-in macros)
    command.ex                    # Command structs (side effects from update/2)
    command/                      # command builder modules
      image.ex                    # image load/unload commands
      scroll.ex                   # scroll-to commands
      text.ex                     # text editor commands (insert, undo, select)
      window.ex                   # window commands (close, minimize, maximize)
      window_query.ex             # window query commands (position, size)
    subscription.ex               # declarative subscription specs (timers, events)
    tree.ex                       # tree normalization, diffing (LIS-based patch generation)
    tree/
      diff.ex                     # tree diffing engine (produces patch ops)
      node.ex                     # Tree.Node protocol (struct -> node map)
      normalize_ctx.ex            # NormalizeCtx struct threaded through tree normalization
      search.ex                   # tree search by ID (single/multi-window)
    bridge.ex                     # GenServer: Port to Rust binary, wire framing, restart_renderer
    widget_registry.ex            # widget discovery via protocol consolidation
    dev/
      dev_server.ex               # file watcher + recompiler (Elixir + Rust + WASM)
      rebuilding_overlay.ex       # dev overlay bar (build status injection into tree)
    protocol.ex                   # wire protocol encode/decode (JSON/MessagePack)
    protocol/
      encode.ex                   # wire encoding, key stringification
      decode.ex                   # wire decoding, event parsing
      error.ex                    # Protocol.Error exception (malformed wire data)
      keys.ex                     # named keyboard key mappings (wire PascalCase -> atom)
      parsers.ex                  # strict enum parsers (mouse buttons, etc.)
    runtime.ex                    # core GenServer: Elm update loop, event dispatch
    runtime/
      coalescable.ex              # deferred high-frequency event coalescing
      commands.ex                 # command execution engine
      dev_overlay.ex              # dev overlay event interception
      interact.ex                 # headless interact_step event application
      subscriptions.ex            # subscription lifecycle diffing
      view_errors.ex              # consecutive view error tracking + frozen-UI overlay
      widget_handlers.ex          # widget handler registry, event interception, bubbling
      windows.ex                  # window node detection, open/close sync
    event.ex                      # union type for all events
    event/                        # event struct types (@enforce_keys)
      widget_event.ex key_event.ex ime_event.ex
      window_event.ex modifiers_event.ex
      async_event.ex stream_event.ex timer_event.ex
      effect_event.ex system_event.ex
      command_error.ex            # command error event
      builtin_specs.ex            # canonical event specs for all built-in events
    effect.ex                     # platform effects (file dialogs, clipboard, notifications)
    key_modifiers.ex              # KeyModifiers struct (ctrl/shift/alt/logo/command booleans)
    renderer_env.ex               # whitelisted environment builder for renderer subprocess
    renderer_exit.ex              # renderer exit reason struct
    scoped_id.ex                  # structured scoped ID parser (window#scope/path/id)
    socket_adapter.ex             # Unix domain socket to iostream transport bridge
    widget.ex                     # macro DSL (use Plushie.Widget) + delegated protocol API
    widget/
      build.ex                    # internal helpers for widget to_node/1 implementations
      handler.ex                  # widget event handler behaviour + dispatch
      meta.ex                     # widget metadata structs (Composite, Native)
      node.ex                     # node builder (id, type, props, children map)
      # per-widget typed builder modules:
      button.ex canvas.ex checkbox.ex column.ex combo_box.ex
      container.ex floating.ex grid.ex image.ex keyed_column.ex
      markdown.ex overlay.ex pane_grid.ex pick_list.ex pin.ex
      pointer_area.ex progress_bar.ex qr_code.ex radio.ex
      responsive.ex rich_text.ex row.ex rule.ex scrollable.ex
      sensor.ex slider.ex space.ex stack.ex svg.ex table.ex
      text.ex text_editor.ex text_input.ex themer.ex toggler.ex
      tooltip.ex vertical_slider.ex window.ex
    type.ex                       # unified Plushie.Type behaviour (cast, encode, field keys/types)
    type/                         # property, event field, and primitive types
      # primitives
      any.ex boolean.ex integer.ex float.ex string.ex atom.ex
      # widget property types
      a11y.ex alignment.ex anchor.ex border.ex color.ex content_fit.ex
      direction.ex filter_method.ex font.ex gradient.ex length.ex
      line_height.ex map.ex padding.ex pointer.ex position.ex range.ex
      shadow.ex shaping.ex style.ex style_map.ex theme.ex wrapping.ex
      # event field types
      key.ex key_modifiers.ex mouse_button.ex
      # composite type system
      composite.ex                # Composite behaviour (parameterized types)
      composite/
        enum.ex list.ex map.ex tuple.ex union.ex
    dsl/                          # shared DSL infrastructure
      fields.ex                   # field/event/state declaration processing
      validation.ex               # compile-time validation helpers
      widget/                     # widget-specific codegen
        codegen.ex macro.ex validation.ex
      element/                    # canvas element codegen
        codegen.ex macro.ex
    canvas/
      element.ex                  # Plushie.Canvas.Element behaviour (use Plushie.Canvas.Element)
      shape.ex                    # builder functions re-exporting all shapes
      # shape element structs
      angle.ex circle.ex line.ex path.ex rect.ex text.ex
      # composite element structs
      group.ex image.ex interactive.ex layer.ex svg.ex
      # property types
      clip.ex dash.ex drag_bounds.ex gradient.ex hit_rect.ex
      shape_style.ex stroke.ex
      transform/                  # transform structs
        rotate.ex scale.ex translate.ex
    table/                        # table structural elements
      element.ex                  # Table.Element behaviour (use Plushie.Table.Element)
      row.ex                      # table row container
      cell.ex                     # table cell (column-keyed child container)
    transport.ex                  # Plushie.Transport behaviour (init/send/close/handle_info)
    transport/
      port.ex                     # Transport.Port: Erlang Port for :spawn and :stdio modes
      iostream.ex                 # Transport.Iostream: message-based adapter for {:iostream, pid}
      framing.ex                  # frame encode/decode for raw byte streams
    state.ex                      # path-based state with revision tracking
    animation.ex                  # animation namespace module
    animation/
      easing.ex                   # named easing curves + cubic bezier
      sequence.ex                 # renderer-side sequential chain
      spring.ex                   # renderer-side spring descriptor
      transition.ex               # renderer-side timed transition descriptor
      tween.ex                    # SDK-side stateful interpolator
    route.ex                      # client-side navigation routing
    selection.ex                  # selection state (single/multi/range)
    undo.ex                       # undo/redo stack with coalescing
    data.ex                       # query pipeline (filter, search, sort, paginate)
    binary.ex                     # plushie binary path resolution
    automation.ex                 # automation namespace (session, replay, scripting)
    automation/
      element.ex                  # inspected tree element wrapper
      file.ex                     # .plushie file parser
      runner.ex                   # .plushie executor for real apps
      screenshot.ex               # screenshot data and PNG writing
      selector.ex                 # selector resolution for scripting and tests
      session.ex                  # automation client (key combos pass through to renderer)
    test.ex                       # Plushie.Test setup (session pool, backend config)
    test/
      case.ex                     # ExUnit case template (use Plushie.Test.Case)
      widget_case.ex              # case template for widget integration tests
      helpers.ex                  # test DSL: click/find/assert_text/model etc.
      session.ex                  # test session wrapper
      session_pool.ex             # shared process pool for renderer sessions
      session_pool/
        multiplexed.ex            # mock/headless pool: one renderer, many sessions
        transport.ex              # renderer process startup and wire write helpers
        windowed.ex               # windowed pool: one renderer per session
      screenshot.ex               # screenshot golden-file assertions
      tree_hash.ex                # tree-hash golden-file assertions
      pool_adapter.ex             # adapter from pooled sessions to runtime iostream
      diagnostic_collector.ex     # telemetry event collector for test assertions
      backend/
        runtime.ex                # pooled test backend over the real runtime/bridge
examples/                         # example apps (compiled in dev/test only)
  counter.ex clock.ex todo.ex notes.ex shortcuts.ex
  async_fetch.ex color_picker.ex gallery.ex rate_plushie.ex
  widgets/                        # custom widget examples
    color_picker.ex               # canvas-based HSV color picker widget
    star_rating.ex                # canvas-based star rating widget
    theme_toggle.ex               # animated theme toggle with face on thumb
  tests/                          # example app tests
    counter_test.exs clock_test.exs todo_test.exs notes_test.exs
    shortcuts_test.exs async_fetch_test.exs color_picker_test.exs
    color_picker_widget_test.exs rate_plushie_test.exs
    test_helper.exs
```

## Architecture

- **Elm architecture.** `init/1` produces the initial model.
  `update/2` handles events and returns model + commands.
  `view/1` returns a UI tree. The runtime diffs trees and sends
  patches to the binary.
- **Bridge/Runtime split.** Bridge owns the Port (OS process) and
  wire framing. Runtime owns the app state and update loop.
  Bridge starts first; Runtime's `handle_continue` immediately
  sends Settings + Snapshot to the already-registered Bridge.
  Supervised with `:rest_for_one`.
- **Single DSL layer.** `Plushie.UI` is the one import for the full
  DSL. Widget macros, canvas shape macros, path commands, transforms,
  clips, gradients, all available via `import Plushie.UI`.
  `Plushie.Widget.*` modules provide typed structs for programmatic
  use. `Plushie.Canvas.Shape` re-exports builder functions for
  programmatic use outside canvas blocks.
- **Block-form options.** All leaf widgets and canvas shapes support
  do-block syntax for declaring options. Container widgets support
  inline option declarations mixed with children. Struct-typed
  options support nested do-blocks at any depth.
- **Context-aware validation.** `canvas_scope` validates calls inside
  canvas/layer/group blocks (rewrites text/image/svg, errors on
  widget macros or wrong-context shapes). `container_scope` validates
  container options at compile time (wrong-container errors list which
  containers support the option).
- **Canvas elements.** Canvas shapes use `use Plushie.Canvas.Element`
  with `element :name do field ... end` declarations, sharing the same
  field/type infrastructure as widgets. Element builders return typed
  structs (`Plushie.Canvas.Rect`, `Plushie.Canvas.Circle`, etc.) with
  `Plushie.Type.encode_value/1` impls for wire conversion. Shapes are
  children (not props) of canvas nodes. Tree normalizer detects
  element structs in the widget tree.
- **Unified type system.** `Plushie.Type` replaces the former
  `Plushie.DSL.Buildable`, `Plushie.Encode`, and
  `Plushie.Event.EventType` modules. All types implement a single
  behaviour with required callbacks (`cast/1`, `encode/1`,
  `fields/0`, etc.) for value coercion, wire encoding, and
  compile-time field introspection. Type identifiers are `:integer`, `:float`,
  `:string`, `:boolean`, `:atom`, or modules implementing
  `Plushie.Type`.
- **Widget declarations.** All widgets (pure Elixir and native) use
  `use Plushie.Widget` with block-form declarations:
  `widget :name do field ... end`. The `field` macro declares typed
  fields (replacing the former `prop` macro). Events use `value:`
  for scalar data or `fields:` for structured data.
- **Render optimization.** `memo/2` wraps a widget view to skip
  re-rendering when the `cache_key` has not changed. Useful for
  expensive subtrees.
- **LIS-based children diff.** Tree diffing uses a longest increasing
  subsequence algorithm for minimal move operations when children
  are reordered.
- **NormalizeCtx.** Tree normalization threads a `NormalizeCtx`
  struct through the traversal. This carries widget state, scope
  chain, caches, and accumulates widget handler/event registries
  and window IDs. The tree is a pure wire representation with no
  runtime bookkeeping. `normalize_with_caches` returns
  `{tree, ctx}` where the ctx carries all accumulated data.
- **Three test backends.** `:mock` (~ms), `:headless`
  (real rendering, no display, ~100ms), `:windowed` (real iced
  windows via headless weston, ~seconds). Tests are backend-agnostic.
  Preflight runs both mock and headless backends.
- **Transport behaviour.** `Plushie.Transport` defines callbacks for
  init/send_data/close/handle_info. Two implementations:
  `Transport.Port` (Erlang Port for `:spawn` and `:stdio` modes) and
  `Transport.Iostream` (message-based adapter for `{:iostream, pid}`).
  The Bridge delegates all transport I/O through the behaviour.
- **Widget system.** Two kinds: `:widget` (pure Elixir, default) and
  `:native_widget` (Rust-backed). `use Plushie.Widget` generates
  structs, setters, types, `Tree.Node` protocol, command functions,
  and DSL support from `widget`, `field`, `event`, `command`
  declarations.
  The `event` macro declares typed events with explicit `value:` or
  `fields:` routing. See `Plushie.Type` for the type system.
  Widgets are auto-detected via `Plushie.Tree.Node`
  consolidation (`Plushie.WidgetRegistry`). No config needed.
- **Widget lifecycle.** All widgets follow the Tree.Node
  pipeline: struct -> `to_node` -> normalize. `new/2` returns a
  struct. `Widget.to_node/1` returns a placeholder tagged with
  the module and props. During `Tree.normalize`, the placeholder
  is detected and rendered via `view/3` with stored internal state
  (or initial defaults for new widgets). Widget handler and event
  registry entries are accumulated into NormalizeCtx during
  normalization for O(1) event dispatch lookups (only widgets with
  events/state participate; view-only widgets are skipped). Events
  bubble hierarchically through parent widgets.
- **Dev overlay.** In dev mode, the runtime injects a build status
  bar into each window's tree via `Plushie.Dev.RebuildingOverlay`. The bar uses
  the `__plushie_dev__/` ID prefix; events with that prefix are
  intercepted by the runtime before reaching `update/2`. The overlay
  shows "Rebuilding... (elixir)" or "Rebuilding... (rust)" with a
  collapsible drawer for build output. It auto-dismisses on success
  (unless expanded) and persists on failure with a dismiss button.
  For Rust rebuilds, `Bridge.restart_renderer/1` triggers a clean
  renderer restart (no backoff/retry) and the overlay survives the
  restart to show "Restarted (rust)" before auto-dismissing.

## Widget ID convention

If a function accepts an id, it is always the first argument.
Display widgets that rarely need explicit IDs have auto-id sugar
forms (e.g. `text("Hello")` auto-generates an id). The canonical
forms are always id-first:

    text("greeting", "Hello", size: 18)     # id, content, opts
    button("save", "Save")                  # id, label
    markdown("docs", "# Title")             # id, content
    progress_bar("loading", {0, 100}, 50)   # id, range, value

The `Plushie.Widget.*` typed builder modules use `new(id, opts)`
uniformly for all widgets (no positional content args).

## Scoped IDs

Named containers (explicit non-auto IDs) scope their children's
IDs automatically. `button("save")` inside `container "form"` gets
the wire ID `"form/save"`. Events split this into `id: "save"` and
`scope: ["form"]` (reversed ancestor chain, immediate parent first).

Pattern matching uses the reversed scope:
- `%Widget{id: "save"}` - any save button
- `%Widget{id: "save", scope: ["form" | _]}` - save in a form
- `%Widget{id: "done", scope: [item_id | _]}` - dynamic list binding

Commands use forward-order path strings: `Command.focus("form/email")`.
`Plushie.Event.target(event)` reconstructs the full path from an event.

Auto-ID containers and window nodes don't create scopes.
`"/"` is forbidden in user-provided IDs. See `docs/reference/scoped-ids.md`.

## Non-obvious patterns

**Return validation.** `unwrap_result/1` in `runtime.ex` validates
that `init/1` and `update/2` return either a bare model, `{model,
%Command{}}`, or `{model, [%Command{}]}`. Invalid shapes raise
`ArgumentError` immediately rather than silently corrupting state.

**Window sync.** The runtime detects window nodes in the view tree
and sends open/close/update ops to the bridge. Window props
(title, size, position, theme) are extracted and diffed separately
from the widget tree.

**Subscription diffing.** `subscribe/1` returns a list of active
subscriptions. The runtime diffs this list each cycle, starting
new subscriptions and stopping removed ones. Timer subs run in
the runtime process; other subs (key/mouse/window events) are
forwarded to the bridge.

**Tree normalization.** `Plushie.Tree.normalize/2` converts typed
widget structs (via the `Plushie.Widget` protocol) into plain
`%{id, type, props, children}` maps for wire transport. A
`NormalizeCtx` struct is threaded through the traversal, carrying
widget state, scope chain, caches, and accumulating widget handler/event
registries and window IDs. The output tree is a pure wire
representation with no runtime bookkeeping. Canvas shape structs in the
widget tree raise clear errors. Leaked DSL metadata tuples
(`{:__widget_prop__}`, `{:__canvas_meta__}`) are detected and reported.

**Effect request tracking.** Effect commands (file dialogs, clipboard)
take a user-provided atom tag and get an internal wire ID and a
timeout timer. The runtime maps wire IDs to tags and tracks pending
effects. One effect per tag: starting a new effect with the same
tag discards the previous one. Responses arrive as
`%EffectEvent{tag: tag, result: result}` in `update/2`.

**Pooled test backend.** The `SessionPool` starts a single
`plushie --mock` process with `--max-sessions N` and multiplexes
test sessions over it. Each test gets isolated state via session
IDs in every wire message.

**Multi-expression control flow.** Inside DSL blocks (containers,
canvas layers, groups), multi-expression if/case/for bodies are
wrapped in list literals so all values contribute to the parent's
items list. Without this, Elixir's standard block semantics would
discard all but the last expression.

**Prop partitioning.** Container do-blocks can mix option declarations
with children. `__build_container__` partitions `{:__widget_prop__}`
tuples from children at runtime, merges with keyword opts from the
call line (block wins on conflict).

## Event system

Event struct types under `Plushie.Event.*`:
- WidgetEvent, KeyEvent, ModifiersEvent, ImeEvent, WindowEvent
- EffectEvent, SystemEvent, TimerEvent, AsyncEvent, StreamEvent
- CommandError

All structs use `@enforce_keys`. The `Plushie.Event` module provides
the `t()` union type covering all event types.

## Command system

Commands are pure data (`%Plushie.Command{type, payload}`). Categories:
- Async work: `:async`, `:stream`, `:cancel`, `:done`
- Widget ops: `:focus`, `:scroll`, `:select`, `:cursor`, `:widget_op`
- Window ops: `:close_window`, `:window_op`, `:window_query`
- Effects: `:effect` (file dialogs, clipboard, notifications)
- Lifecycle: `:send_after`, `:exit`, `:batch`
- Widget commands: `:widget_command`, `:widget_commands`
- Images: `:image_op`
- Animation: `:advance_frame`

## Custom widget development

Two kinds:

**Pure Elixir** (`use Plushie.Widget`): compose existing widgets
or draw custom visuals with canvas/SVG via a `view/2` (stateless)
or `view/3` (stateful) callback. No Rust, no binary rebuild. Works
with precompiled binaries. Add `state` declarations for internal
state, `handle_event/2` for event interception, `subscribe/2`
for widget-scoped subscriptions. Features are detected at compile
time. Declare what you need, the macro generates the rest.

**Native** (`use Plushie.Widget, :native_widget`): Rust-backed
widgets. Declares `widget`, `field`, `rust_crate`, `rust_constructor`,
and optional `event` and `command` fields. Generates the struct,
setters, types, Tree.Node implementation, command functions,
and DSL support.

Events are declared with typed specs: `event :select, value: :integer`
or `event :change, fields: [hue: :float]`. The spec determines the shape of
`WidgetEvent.value`: a scalar for `value:` events, an atom-keyed
map for `fields:` events. Built-in event types
(`:click`, `:toggle`, etc.) use the built-in spec automatically.
Type identifiers can be built-in atoms (`:integer`, `:float`,
`:string`, `:boolean`, `:atom`) or modules implementing
`Plushie.Type`.

Widget events flow: renderer -> Bridge -> Runtime ->
`intercept_event` (walks scope chain for registered handlers)
-> `handle_event/2` -> bubble emitted events through parent
widgets -> deliver to `app.update/2`. Canvas-internal events
(`:canvas_element_*`) that are not intercepted are auto-consumed
by the runtime and never reach `update/2`. View-only widgets
(no events, no state) are transparent, so events pass through to
the app. The `handle_event/2` callback returns:
- `{:emit, family, data}` or `{:emit, family, data, new_state}`
- `{:update_state, new_state}` (no event to app)
- `:ignored` (not captured, continue to next handler)
- `:consumed` (captured, suppress)

Test widgets with `Plushie.Test.WidgetCase`:

    use Plushie.Test.WidgetCase, widget: ColorPickerWidget
    setup do: init_widget("picker")

Rust side: implement `PlushieWidget` from `plushie_widget_sdk::prelude::*`.
Three required methods: `type_names()`, `render()`,
`clone_for_session()`. Optional: `namespace()`, `init()`,
`prepare()`, `handle_message()`, `handle_widget_op()`, `cleanup()`,
`infer_a11y()`.

Build: `mix plushie.build` auto-detects native widgets via the
`Plushie.Tree.Node` protocol consolidation and shells out to
`cargo plushie build` for the actual workspace + binary generation.
See "Building the renderer binary" above.

Test: use `Plushie.Test.Case` to run app tests through the actual
renderer binary. Tests use `click/1`, `find!/1`, `model/0`,
`assert_text/2`, `assert_exists/1` etc. which go through the wire
protocol. Widget struct/command tests can be pure ExUnit since
they test macro-generated code. See the demo repos for examples.

## Headless screenshots

Take headless screenshots for visual verification without a display:

```elixir
PLUSHIE_BINARY_PATH=/path/to/binary mix run -e '
renderer = Plushie.Binary.path!()
session = Plushie.Test.Session.start(MyApp, backend: Plushie.Test.Backend.Headless, renderer: renderer)
screenshot = Plushie.Test.Session.screenshot(session, "verify")
File.mkdir_p!("/tmp/screenshots")
Plushie.Test.Screenshot.save_png(screenshot, "/tmp/screenshots/verify.png")
Plushie.Test.Session.stop(session)
'
```

Read the PNG file to view it. Renders at 1024x768 via tiny-skia.

## Related repositories

These are expected as sibling directories (e.g. `../plushie-rust/`):

- plushie-rust - Rust workspace (SDK, widget SDK, renderer)
- plushie-iced - vendored iced fork
- plushie-demos - demo apps for all SDKs (Elixir demos in elixir/)
