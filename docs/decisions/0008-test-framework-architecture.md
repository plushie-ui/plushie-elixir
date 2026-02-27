# ADR 0008: Test Framework Architecture

## Status

Accepted

## Context

Julep is an Elixir library that renders native desktop GUIs via a Rust
binary (`julep_gui`) using iced. The Elm architecture makes pure-function
unit testing of `update/2` and `view/1` straightforward, but several
important categories of bugs cannot be caught by unit tests alone:

1. **Wire protocol encoding bugs.** The JSONL protocol between Elixir and
   Rust is a trust boundary. A typo in a prop name, a mismatched type, or
   a missing field will not surface until the renderer processes the tree.
   Unit tests that assert on plain maps cannot catch these.

2. **Iced version bump regressions.** When iced updates (e.g., 0.13 to
   0.14), widget APIs, default styles, and rendering behaviour may change.
   Without cross-boundary tests, these regressions are invisible until a
   human runs the app and notices something looks wrong.

3. **Downstream app confidence.** Apps built on julep need a way to
   integration-test their UI beyond asserting on model state. Clicking a
   button, typing text, and verifying the result should be expressible
   in a test.

4. **Renderer correctness.** The Rust renderer interprets tree nodes into
   iced widgets. Bugs in `widgets.rs` (wrong prop mapping, missing widget
   type) need a test path that exercises the Rust code.

Existing solutions (plain ExUnit tests on pure functions, and the old
`Julep.IntegrationCase` approach) left gaps in all four categories.

## Decision

Introduce a three-backend test framework behind a unified API:

- **`Julep.Test.Backend`** -- behaviour defining the test interface.
- **`Julep.Test.Backend.Sim`** -- pure Elixir, no Rust.
- **`Julep.Test.Backend.Headless`** -- Rust renderer via `julep_gui --headless`.
- **`Julep.Test.Backend.Full`** -- real iced windows via `julep_gui --test`.
- **`Julep.Test.Session`** -- facade wrapping a backend + process pair.
- **`Julep.Test.Case`** -- ExUnit case template with automatic setup/teardown.
- **`Julep.Test.Helpers`** -- convenience functions imported by Case.
- **`Julep.Test.Element`** -- struct representing a found widget.
- **`Julep.Test.Snapshot`** -- structural tree snapshot with golden-file comparison.
- **`Julep.Test.Screenshot`** -- pixel screenshot with golden-file comparison.
- **`Julep.Test.EventMap`** -- widget-type-to-event inference for sim.
- **`Julep.Test.Script`** -- parser for `.julep` test scripts.
- **`Julep.Test.Script.Runner`** -- executor for parsed scripts.

On the Rust side:

- **`julep_core.rs`** -- `Core` struct extracted from `App`, holding tree
  state, caches, and subscriptions. Processes `IncomingMessage`s and
  returns `CoreEffect`s. Decoupled from `iced::daemon`.
- **`headless.rs`** -- `--headless` mode: reads JSONL from stdin, processes
  through `Core`, writes responses to stdout. No iced runtime.
- **`test_mode.rs`** -- `--test` mode helpers: real `iced::daemon` runs
  alongside test protocol message handling.

Mix tasks:

- **`mix julep.script`** -- runs `.julep` test scripts.
- **`mix julep.replay`** -- replays a `.julep` script with real windows.

## Rationale

### Why three backends

Progressive fidelity. Different levels of trust require different levels
of infrastructure:

- **Sim** tests the Elixir layer in isolation. Zero dependencies, sub-ms
  execution, runs in any CI. Covers app logic, tree structure, and event
  flow. This is the right default for 90% of tests.

- **Headless** adds the Rust renderer without a display server. Proves the
  wire protocol works end-to-end and provides tree-hash snapshots. Catches
  the category of bugs where Elixir sends valid-looking JSON that the
  renderer rejects or misinterprets.

- **Full** adds real iced windows with GPU rendering. Proves the complete
  stack works: window lifecycle, platform effects, subscriptions, and
  pixel-accurate rendering. Catches the "it works in headless but looks
  wrong on screen" class of bugs.

A test written against the unified API (`click`, `find!`, `assert_text`)
can be promoted from sim to headless to full by changing a single option.
No test rewriting.

### Why Core extraction

The `Core` struct in `julep_core.rs` holds all renderer state that is not
tied to `iced::daemon`: the tree, widget caches, active subscriptions,
and default font/text-size settings. By extracting this from `App`, we
gain:

- **Testability.** Headless mode can process messages through `Core`
  without instantiating an iced application.
- **Reduced coupling.** `Core::apply()` takes an `IncomingMessage` and
  returns `Vec<CoreEffect>`. The host (App or headless loop) decides
  what to do with the effects.
- **Reuse.** Both `--headless` and `--test` modes share the same Core
  for tree management and cache handling.

### Why correlation-ID protocol

The Rust renderer communicates over stdio, which is inherently
asynchronous from the Elixir side (Port messages arrive as Erlang
messages, not as return values). The correlation-ID protocol allows:

- Multiple in-flight requests without ambiguity.
- Matching responses to the GenServer caller that made the request.
- Interleaving test protocol messages with normal snapshot/patch messages.

Each request includes an `id` field (e.g., `"req_1"`). The renderer
echoes the same `id` in its response. The GenServer maintains a
`pending` map from ID to `{type, from}` tuple and replies to the
correct caller when the response arrives.

### Why `:sim` is the default

Speed and accessibility. Sim tests run in milliseconds with zero external
dependencies. No Rust toolchain, no compiled binary, no display server.
This makes the test framework immediately useful to anyone who depends on
julep, even if they never build the renderer themselves.

The sim backend handles the vast majority of app testing because the Elm
architecture concentrates logic in `update/2` (which sim exercises fully)
and structure in `view/1` (which sim renders and queries). The wire
protocol and rendering are julep's responsibility, not the app's.

### Why extend `.ice` rather than invent from scratch

iced has a nascent `.ice` format for test scripts. By making `.julep` a
superset of this format, we get:

- Familiarity for iced users.
- Potential interop with iced's own testing tools.
- A simple, line-oriented format that is easy to parse and generate.

The extensions we add (header section, `assert_text`, `wait`) are
backwards-compatible -- a `.julep` parser can handle `.ice` files by
treating the absence of a header as defaults.

### Why widget IDs must propagate to iced widgets

The test protocol needs to find widgets by ID in the rendered tree.
This requires that the `id` field from Elixir's `ui_node()` map is
propagated all the way through to the iced widget in `widgets.rs`.
Without this, the headless and full backends cannot implement `find`
or `interact` by ID.

This is already the case for julep's tree structure (every node has an
`id`), but it is worth calling out as a hard requirement: removing or
failing to propagate IDs would break the entire test framework.

## Consequences

### What this enables

- **App developers** can write fast sim tests for all their logic and
  tree structure, with the option to add headless/full tests for
  critical paths.

- **Julep maintainers** can run headless tests to catch protocol
  regressions when modifying the wire format or renderer.

- **CI pipelines** can be configured at any fidelity level, from sim-only
  (seconds) to full (minutes with Xvfb).

- **Script-based testing** provides a language-agnostic way to describe
  and replay interaction sequences, useful for acceptance tests and demos.

- **Iced version bumps** can be validated by running headless/full
  snapshot tests and comparing hashes.

### What this costs

- **Three code paths** for the renderer: normal mode, `--headless`, and
  `--test`. The Core extraction mitigates this by sharing state logic,
  but the message handling still has three entry points.

- **Feature flags** in the Rust build (`--features headless`,
  `--features test-mode`). Not compiled by default to keep the normal
  build lean.

- **Protocol surface area** increases. Four new message types
  (Query, Interact, SnapshotCapture, Reset) and their responses.

- **EventMap maintenance.** The sim backend's event inference table
  must be kept in sync with the renderer's actual event generation.
  A mismatch means a test passes in sim but fails in headless/full
  (or vice versa). This is a feature, not a bug -- it is exactly the
  kind of discrepancy the multi-backend approach is designed to surface.
