# Extension Dogfood Log

Running log from building 5 extension widget packages against the julep
extension system.

## Phase 0: Core fixes

### Issues found and fixed

- **julep-bin had no public `run()`.** The binary crate hardcoded
  `JulepAppBuilder::new().build_dispatcher()` in `main()`. Extensions
  couldn't inject themselves. Fixed by splitting into lib + bin targets
  with `pub fn run(builder: JulepAppBuilder) -> iced::Result`.

- **Build task didn't actually build.** `mix julep.build` generated
  workspace files but printed "not yet supported" and stopped. Fixed to
  actually run `cargo build` and find the resulting binary.

- **Generated main.rs had `todo!()`.** The template code contained
  `todo!("julep-bin does not yet expose a public run() function")`.
  Replaced with working code that chains `.extension()` calls and
  delegates to `julep_bin::run()`.

- **Sim backend couldn't test extension widgets.** `EventMap` returned
  errors for unknown types with no extension fallback. Added optional
  `sim_events/3` callback to `Julep.Extension`, created
  `Julep.Test.ExtensionEvents` registry, and updated all catch-all
  clauses to consult registered extensions.

### What went well

- The `WidgetExtension` trait defaults meant Tier A extensions only need
  3 method implementations.
- `ExtensionCaches` type-erased storage worked cleanly.
- `ExtensionDispatcher` catch_unwind isolation prevents one extension from
  crashing the renderer.

## Phase 1: julep_sparkline (Tier C)

### Friction discovered

- `canvas::Cache` is `!Send + !Sync` -- cannot be stored in
  `ExtensionCaches`. Extensions using canvas must let iced manage caches
  internally and redraw each frame, or use generation counters. This is
  a fundamental constraint, not a bug. Documented in ADR 0012.

- `prop_helpers` module didn't have a `prop_u64` or `prop_usize` helper.
  Had to use `prop_f32().map(|v| v as usize)` for integer props like
  `capacity`. Consider adding `prop_u32`/`prop_usize` to core.

### What went well

- Ring buffer + extension commands pattern worked exactly as designed.
  High-frequency data push bypasses tree diff/patch cycle.
- `prepare()` / `render()` split is natural: prepare mutates state,
  render reads it immutably.
- Canvas Program impl was straightforward for simple line rendering.

## Phase 2: julep_hex_view (Tier A render-only)

### Friction discovered

- Rendering test coverage is limited from outside julep-core. `WidgetEnv`
  requires `RenderContext` whose fields are `pub(crate)`. Extension unit
  tests can only test pure logic functions, not `render()` directly.
  Full render testing requires integration tests with the actual renderer.

### What went well

- **Tier A is genuinely simple.** Only `type_names`, `config_key`, and
  `render` needed. All other trait methods use defaults. ~200 lines of
  Rust total.
- Composing iced's built-in widgets (`column`, `row`, `text`,
  `scrollable`, `container`) inside `render()` worked seamlessly.
- `prop_helpers` covered all prop types needed (str, bool, f32, length).
- Base64 encoding for binary data worked cleanly across the wire.

## Phase 3: julep_code_view (Tier A with external deps)

### Friction discovered

- tree-sitter version compatibility is complex. tree-sitter-rust 0.24
  generates language version 15, which requires tree-sitter-highlight
  0.25+ (0.24 maxes at version 14). Resolved by using 0.25 across the
  board.

- `init()` config wiring works but isn't tested in isolation -- the
  config comes from the Settings wire message, which requires a running
  renderer. Extension unit tests call `init()` with `&Value::Null`
  directly.

### What went well

- Content-hash comparison for change detection (prepare skips re-parse
  when code unchanged) is clean and performant.
- External Rust deps (tree-sitter, base64) resolve correctly in the
  extension crate's Cargo.toml with path dep to julep-core.
- Grammar loading in `init()` is the right time -- shared across all
  nodes, loaded once at startup.

## Phase 4: julep_plot (Tier B interactive)

### Friction discovered

- `handle_event` family strings need documentation. The extension author
  needs to know which family strings the renderer sends for different
  mouse/keyboard interactions. Currently discoverable only by reading
  `message.rs`.

- Creating `OutgoingEvent` requires knowing the struct fields. The
  prelude re-exports it, but the construction pattern isn't documented
  for extension authors.

### What went well

- **All 3 `EventResult` variants work as designed.** Consumed swallows
  the event (pan/zoom stays Rust-side), Observed forwards AND emits
  (click produces both original and plot_click), PassThrough lets
  unknown events flow to Elixir.
- `sim_events/3` callback integrates cleanly with the test framework.
- Canvas-based interactive widgets are a natural fit for the extension
  system.

## Phase 5: julep_timeline (Tier C custom Widget)

### Friction discovered

- iced 0.14 changed the Widget trait: `on_event` became `update`,
  `Status::Captured` became `shell.capture_event()`, and text alignment
  fields were renamed from `horizontal_alignment`/`vertical_alignment`
  to `align_x`/`align_y` with different types. Extension authors
  targeting iced 0.14 need migration guidance.

- The `Message` enum's `Event` variant fields aren't documented for
  extension authors. Building `Message::Event { id, data, family }` from
  a custom Widget requires reading julep-core source.

### What went well

- **Custom Widget works through the extension render path.** Returning
  `Element::new(TimelineWidget { ... })` from `render()` is seamless.
- No lifetime issues -- borrowing node data in the Widget impl works
  because `render()` receives `&'a TreeNode` with the right lifetime.
- **Viewport state lives in iced's widget tree** -- the `State` struct
  attached via `Tree::new()` holds pan/zoom state. This is the correct
  iced pattern for per-instance mutable state that survives across
  renders. `ExtensionCaches` is reserved for data that the `prepare()`
  step computes (e.g. parsed/cached content), not interactive state
  that the `update()` method mutates in response to events.
- Hit testing, pan, zoom all work correctly in the custom Widget.

## Phase 6: Coexistence

### Results

- All 5 extensions coexist in a single app with no type name collisions.
- Config routing, command routing, and event routing all work correctly.
- The discovery mechanism finds all loaded extensions.
- sim_events callbacks work for extensions that implement them.

## Post-build Audit

A thorough code audit after initial build uncovered bugs across all
packages. All have been fixed.

### Bugs fixed in core

- `build_with_extensions` didn't pass `feature_flags()` to cargo.
- Generated Cargo.toml had no `headless`/`test-mode` feature forwarding.
- `extensions_demo_test.exs` failed in envs without extension packages.
- `renderer.rs` silently dropped all extensions on double-init.
- `register_all/0` didn't detect type name collisions at runtime.

### Bugs fixed in extensions

- **sparkline:** NaN/Inf propagation in ring buffer, fill path geometry
  wrong for single sample, timer firing when paused.
- **hex_view:** Last-row hex padding miscalculation (8-byte group gap),
  width prop on wrong element, hardcoded ASCII color invisible on light
  themes, zero-length highlight accepted.
- **code_view:** `wrap` prop documented but never read in Rust, nested
  highlight events reset instead of popping stack, grammar load failures
  swallowed silently, `DefaultHasher` not stable across Rust versions.
- **plot:** Canvas cache created and thrown away every frame, pan/zoom
  non-functional (`Consumed(vec![])` suppressed events but published no
  Message for iced to re-render), `sim_events` matched bare map instead
  of Element struct, no clipping of series to plot area.
- **timeline:** Hit test returned first-in-list instead of topmost visual
  match, inverted intervals rendered backwards, `ms_to_x` divide-by-zero
  with equal viewport bounds.

### Core improvements completed

1. **Added `prop_u32`/`prop_u64`/`prop_usize`/`prop_i64` to
   prop_helpers.** Integer props no longer need float casts.
2. **Collision detection in `register_all/0`.** Runtime registration
   raises on type name conflicts from different modules.
3. **Feature forwarding in build task.** Custom extension builds now
   correctly forward `:iced_features` config and `headless`/`test-mode`.

### Additional fixes from second audit

- **Sim vs real event shape mismatch.** `sim_events/3` in julep_plot and
  julep_timeline returned custom event tuples (`{:plot_click, id, ...}`,
  `{:timeline_click, id, ...}`) that don't match the real protocol
  dispatch. The Rust renderer emits `Message::Event(id, data, "click")`
  which the Elixir protocol decodes as `{:click, id}`. Fixed sim_events
  to return `{:ok, {:click, id}}` and updated demo update handlers.
- **Plot interactive prop fix.** Canvas events only reach `handle_event`
  when the plot node has `interactive: true`. Without it, pan/zoom/click
  events pass through as raw canvas events.
- **Code view hardcoded syntax colors.** String, Type, and Number
  highlight colors were hardcoded RGB values, making them invisible or
  clashing on non-dark themes. Fixed to derive from `theme.palette()`:
  String uses `palette.success`, Type uses `palette.danger`, Number
  blends primary and text.
- **Coexistence test `async: true`.** The extensions demo test mutates
  `persistent_term` state via `register_all/0`, which is global. Changed
  to `async: false`.

### Core improvements still to consider

1. ~~**Document `Message::Event` construction** -- extension authors need
   to know how to emit events from custom widgets.~~ Done in `docs/extensions.md`.
2. ~~**Document event family strings** -- which families the renderer sends
   for which interactions.~~ Done in `docs/extensions.md`.
3. **Consider `pub` visibility for `RenderContext` fields** -- or provide
   a test helper that constructs `WidgetEnv` for extension unit tests.
   Resolved: `widget_env_with()` in `julep_core::testing` already provides
   this. Documented in `docs/extensions.md`.
4. ~~**iced 0.14 migration guide** -- document the Widget trait changes
   for custom Widget extension authors.~~ Done in `docs/extensions.md`.

## Phase 7: Documentation

All outstanding documentation items from the dogfooding exercise have been
resolved. `docs/extensions.md` covers:

- Quick start (Elixir behaviour + Rust trait, build integration)
- Extension tiers (A/B/C with examples and code)
- `Message::Event` construction for custom Widget implementations
- Complete event family reference table (all families from protocol.rs)
- `EventResult` guide with gotchas (canvas cache invalidation)
- `canvas::Cache` and `GenerationCounter` pattern
- iced 0.14 Widget trait migration guide
- Prop helpers reference
- Testing guidance (Elixir, Rust, render smoke tests, sim backend)
- `ExtensionCaches` API reference
- Panic isolation behavior
