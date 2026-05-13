# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.7.2] - 2026-05-09

### Fixed

- **`mix plushie.gui` crashed on every invocation** with `BadBooleanError`
  because `resolve_binary!/1` used the strict `and`/`not` operators with
  keyword list lookups that return `nil` when a flag is absent. Replaced
  with `&&`/`!`. This made `mix plushie.gui` (and any task that calls
  `resolve_binary!/1`) completely unusable in 0.7.1 without `--release`
  or `--build` flags.

## [0.7.1] - 2026-05-09

### Fixed

- **Screenshot requests now include the required `id` field**, matching
  the renderer 0.7.1 wire protocol. Without it the renderer logged a
  decode error and `Bridge.screenshot` timed out after 30 seconds.
- **Screenshot assertions now save a PNG alongside the `.sha256` hash.**
  The PNG is written when `rgba_data` is present (headless and windowed
  backends). Pass `png: false` to `assert_screenshot/2` or
  `assert_screenshot_match/3` to write the hash only. The `.sha256` file
  is the actual CI assertion; the PNG is a human convenience for visual
  inspection.
- **`SocketAdapter` JSON buffer accumulation is now O(n)** instead of
  O(n^2). Incoming TCP chunks are accumulated in an iolist and only
  materialized to binary when a newline arrives. The overflow check now
  runs against the tracked size before any allocation, preventing
  timeouts on slow networks or tight socket buffers.

## [0.7.0] - 2026-05-09

### Breaking

- **`BINARY_VERSION` renamed to `PLUSHIE_RUST_VERSION`.** The version
  file now makes its purpose explicit: it pins the plushie-rust
  release this SDK targets, independent of the SDK's own semver.
  `Plushie.Binary.plushie_rust_version/0` replaces the previous
  `binary_version/0`.
- **`PLUSHIE_SOURCE_PATH` renamed to `PLUSHIE_RUST_SOURCE_PATH`.** The
  application config key `:source_path` is unchanged.
- **`Command.async/1,2` renamed to `Command.task/1,2`.** Converges
  with Python, TypeScript, Gleam, and Ruby SDKs. The internal `:async`
  command type atom becomes `:task`. `AsyncEvent` is unchanged.
- **`grid.columns` renamed to `grid.num_columns`.** Matches the
  renderer field name and avoids the collision with `table.columns`
  (column spec lists).
- **Window query functions drop the `get_` prefix.**
  `Command.get_window_size` -> `Command.window_size`,
  `Command.get_window_position` -> `Command.window_position`,
  `Command.get_mode` -> `Command.window_mode`,
  `Command.get_scale_factor` -> `Command.scale_factor`,
  `Command.get_system_theme` -> `Command.system_theme`,
  `Command.get_system_info` -> `Command.system_info`.
- **`WidgetCommandError` renamed to `CommandError`.** Fields renamed:
  `node_id` -> `id`, `op` -> `family`. Update pattern matches and any
  `@impl Plushie.App` clauses that matched the old struct.
- **`SystemEvent.data` renamed to `SystemEvent.value`.** Consistent
  with `WidgetEvent.value` and `StreamEvent.value`.
- **Angles throughout the canvas API are now in degrees.** Previously
  `Plushie.Canvas.Angle` normalized to radians; it now normalizes to
  degrees. The `arc`, `ellipse`, and `rotate` builders and the
  `image.rotation` field all send degrees to the renderer.
  Use `Plushie.Canvas.Angle.to_radians/1` when a radian value is needed.
- **Renderer subscriptions drop the tag parameter.** Key, pointer,
  window, and touch subscriptions now take keyword opts only:
  `Subscription.on_key_press(window: "main", max_rate: 60)`. The old
  `tag:` opt was management-only and never appeared in events. Timer
  subscriptions retain their positional tag.
- **Command renames.** `Command.request_user_attention/1` ->
  `Command.request_attention/1`, `Command.done/2` ->
  `Command.dispatch/2`, `Command.widget_commands/1` ->
  `Command.widget_batch/1`.
- **`ime_purpose` renamed to `input_purpose`** on `TextInput` and
  `TextEditor`, matching the renderer field rename.
- **`data:` renamed to `fields:` in inline widget event declarations.**
  The widget DSL `event :name, data: [field: type]` form now uses
  `fields:`. Do-block event declarations are unaffected.
- **`LinearGradient` renamed to `Plushie.Canvas.Gradient`.** The
  module was `Plushie.Canvas.Shape.LinearGradient`. The
  `Plushie.Type.Gradient` module (widget background gradients) is
  unchanged.
- **`Command.scroll_to` signature changed.** `(id, offset)` ->
  `(id, x, y)` with separate typed float parameters. `snap_to/2` and
  `scroll_by/2` lose their default-argument overloads.
- **`Command.select_range` field names changed** to `start_pos` and
  `end_pos` (the old names shadow Elixir reserved words in pattern
  matching contexts).
- **Table rows are now children, not a prop.** The `rows:` keyword
  prop is removed. Use `table_row "id" do cell "col", content end`
  DSL macros in a do-block. The `separator` field changed from boolean
  to float (thickness in pixels). Table gains `selected`, `striped`,
  and `height` fields and a `row_click` event.
- **`gain_focus/1` renamed to `focus_window/1`.** The deprecated alias
  will be removed in a future release.
- **Renderer binary version** bumped to 0.7.0. Run
  `mix plushie.download --force` after updating.

### Added

- **`memo/2` DSL primitive** for subtree memoization. Wraps a widget
  view with a `cache_key`; the subtree is not re-rendered when the key
  is unchanged. Combine with `cache_key` state declaration for
  widget-level view caching.
- **Typed `RichText.Span` builder.** `Plushie.RichText.Span` provides
  a typed struct instead of raw maps.
- **`:link_click` event type** on rich_text. Clicked links deliver a
  `WidgetEvent` with `type: :link_click`.
- **`on_focus`/`on_blur` props** on text_input and text_editor;
  `:focused` and `:blurred` event types delivered on focus change.
- **`pointer_captured`, `pointer_lost`, `coords` fields** on pointer
  events where the renderer provides them.
- **Typed effect result variants.** `EffectEvent.result` is a tagged
  tuple per kind (e.g., `{:file_open, {:ok, path}}`).
- **Typed diagnostic exceptions.** `Plushie.Runtime.BufferOverflowError`
  and `Plushie.Runtime.VersionMismatchError` raised as structured
  exceptions.
- **`rule.thickness` prop** - direction-agnostic line thickness;
  avoids choosing between `width` and `height` based on orientation.
- **Full `input_purpose` set** on text_input and text_editor. Supports
  all nine renderer purposes: `normal`, `secure`, `terminal`,
  `number`, `decimal`, `phone`, `email`, `url`, `search`.
- **A11y improvements.** `resolved_a11y/1` helper for scoped ref
  resolution; builder defaults populate `role` automatically; canvas
  radio groups auto-infer `position_in_set`/`size_of_set`; focus
  commands scoped to canvas elements; `announce` politeness on `a11y`
  props.
- **`Plushie.Canvas.Angle` type** for explicit angle values with
  `to_degrees/1` and `to_radians/1` converters.
- **Bridge heartbeat watchdog.** Detects unresponsive renderers and
  triggers restart rather than hanging indefinitely.
- **`use Plushie.Command` standalone DSL** for defining command modules
  with the same `command`/`field` macro infrastructure as native
  widgets.
- **`:page` scroll unit.** Scroll events now carry `unit: :page` for
  page-delta events from the renderer.
- **Telemetry counters** on normalize, diff, command execution, and
  subscription lifecycle.

### Fixed

- `default_font` always emitted as a family object.
- Image `list`/`clear` sent through the typed `image_op` channel.
- `op_query_response` decoded from the canonical `"data"` field.
- `window_opened` decoded from the top-level `x`/`y` fields.
- `prop_validation` events from debug renderer builds silently dropped
  rather than logged as protocol errors.

### Changed

- **`mix plushie.build` delegates to `cargo-plushie`.** Workspace
  generation, widget collision checks, main.rs emission, and Cargo.lock
  shepherding moved to the `cargo-plushie` Cargo subcommand in the
  plushie-rust workspace. The Mix task writes a "renderer spec"
  Cargo.toml listing native widget crates and shells out. Widget
  crates must declare `[package.metadata.plushie.widget]` in their own
  Cargo.toml for discovery. Install with
  `cargo install cargo-plushie --version 0.7.0 --locked`.
  See `docs/versioning.md` for the version correspondence table.
- **`Plushie.Dev.DevServer`** now triggers incremental Rust builds
  through `cargo plushie build` instead of driving `cargo build`
  directly.

### Removed

- **`native/plushie/Cargo.lock` stash.** cargo-plushie preserves its
  own lockfile across runs; no SDK-level stash is needed.

## [0.6.0] - 2026-04-02

### Breaking

- **Unified pointer events.** 14 device/widget-specific event types
  replaced with 8 generic types: `:press`, `:release`, `:move`,
  `:scroll`, `:enter`, `:exit`, `:double_click`, `:resize`. All carry
  `pointer` type (`:mouse`/`:touch`/`:pen`), `modifiers` state, and
  optional `finger` ID for touch. Removed types: `canvas_press`,
  `canvas_release`, `canvas_move`, `canvas_scroll`, `mouse_right_press`,
  `mouse_right_release`, `mouse_middle_press`, `mouse_middle_release`,
  `mouse_move`, `mouse_scroll`, `mouse_enter`, `mouse_exit`,
  `mouse_double_click`, `sensor_resize`.

- **Canvas element events unified.** `canvas_element_enter`/`leave`/
  `focused`/`blurred`/`drag`/`drag_end`/`key_press`/`key_release` and
  `canvas_element_click` replaced with standard types using scoped IDs.
  Canvas elements look like regular widgets from the SDK's perspective.

- **`MouseEvent` and `TouchEvent` removed.** Subscription pointer
  events are now delivered as `WidgetEvent` structs with `id` set to
  the window ID and `scope` of `[]`.

- **`mouse_area` renamed to `pointer_area`.** The widget, DSL macro,
  and wire type all use the new name.

- **Window ID in scope chain.** Window IDs are appended to the end of
  the scope list. Pattern matching with `| _` at the end of scope
  naturally ignores the window for single-window apps.

- **`:scroll` vs `:scrolled`.** `:scroll` is pointer wheel input (with
  coordinates and deltas). `:scrolled` is scrollable container viewport
  state change. Previously both used `:scroll`.

- **`:start`/`:end` alignment aliases removed.** Use `:left`/`:right`/
  `:top`/`:bottom`/`:center`.

- **Subscription functions renamed.** `on_mouse_move` -> `on_pointer_move`,
  `on_mouse_button` -> `on_pointer_button`, `on_mouse_scroll` ->
  `on_pointer_scroll`, `on_touch` -> `on_pointer_touch`.

- **Canvas auto-consumption removed.** Canvas background pointer events
  now reach `update/2` when opted in via `on_press`/`on_move`/etc.

- **Renderer binary version** bumped to 0.6.0.

### Added

- **Device awareness on pointer events.** `Plushie.Type.Pointer` module
  with `pointer_type` (`:mouse`/`:touch`/`:pen`) and `button` types.
  Every pointer event includes pointer type, modifier state, and finger
  ID for touch.

- **Window-qualified selector syntax.** `"main#form/save"` targets a
  widget in a specific window. Works in test selectors and commands
  (`Command.focus`, `Command.scroll_to`, etc.).

- **Widget state re-render.** When a widget's `handle_event/2` returns
  `{:update_state, new_state}`, the view is immediately re-rendered.
  Previously required an unrelated event to trigger the re-render.

- **Mock canvas element click.** `click("#canvas-id/element-id")` works
  in mock mode tests by detecting scoped IDs and verifying element
  existence.

- **Mock sequential click fix.** Sequential clicks on different widgets
  now work reliably in mock mode (synthetic event path replaces fragile
  focus+space approach).

- **Coalescing for pointer events.** `:move` (Replace), `:scroll`
  (Accumulate deltas), `:scrolled` (Replace), `:resize` (Replace).

### Fixed

- **Widget re-render on state change** with window sync and error
  revert.
- **Pre-existing decoder bugs**: `transition_complete` missing from
  specs and missing scope extraction, `sort` data shape mismatch,
  `pane_focus_cycle` spec/decoder mismatch.
- **`plushie.build`** patches vendored iced subcrates when local source
  checkout exists. Handles file read errors in Cargo.toml parsing.

### Changed

- **Documentation overhaul.** README rewritten, `docs/README.md` index
  added for hexdocs, `CONTRIBUTING.md` created. All em-dashes replaced
  with single dashes. Comprehensive docs for pointer events, device
  awareness, canvas touch, modifier patterns, window scope, and
  selector syntax.

## [0.5.0] - 2026-03-23

### Breaking

- **Renderer binary renamed** from `plushie` to `plushie-renderer`.
  The binary resolution chain, download task, and build task all use
  the new name. The `bin/plushie-renderer` symlink replaces the old
  `bin/plushie`.
- **WASM files renamed** from `plushie_wasm.*` to
  `plushie_renderer_wasm.*`. Update any HTML script tags that reference
  the old names.

### Added

- **`--bin-file PATH` and `--wasm-dir PATH`** options on
  `mix plushie.build`, matching the existing options on
  `mix plushie.download`. Override output locations for both stock and
  extension builds.
- **Canvas group redesign** - groups now support `role` and
  `arrow_mode` props for accessible tree/list patterns in canvas.
- **Block-form options on Canvas widget** - `role` and `arrow_mode`
  can be set via the DSL block form.
- **Focus ring support** - `focus_ring_radius` on canvas groups,
  focus ring padding on interactive canvas widgets.
- **Expanded test helpers** - additional utility functions for test
  sessions.
- **Demo project links** in docs - extensions guide, testing guide,
  running guide, getting-started guide, and examples README all link
  to the [plushie-demos](https://github.com/plushie-ui/plushie-demos/tree/main/elixir)
  repo.

### Changed

- **Renderer binary version** bumped to 0.5.1.
- **Download URL** updated from `plushie-ui/plushie` to
  `plushie-ui/plushie-renderer` releases.
- **Rust crate references** updated throughout for the
  `plushie-renderer` workspace split (`plushie-ext`, `plushie-core`,
  `plushie-renderer-lib`).
- Canvas element terminology updated across docs and code.

### Fixed

- Protocol dispatch warning in `Canvas.build/1`.
- Credo string literal warnings in Canvas doc comments.
- Star rating `focus_style` uses correct stroke object format.
- Button style map removed from RatePlushie (uses default theme).
- Review form theme contrast in RatePlushie.
- Canvas scope walker wraps transform/clip directives as metadata.
- Heading text colors restored for contrast.
- Vestigial `interactive` field removed from leaf shape structs.

## [0.4.0] - 2026-03-22

### Breaking

- **Project renamed from toddy to plushie.** All module names (`Toddy.*`
  -> `Plushie.*`), config keys (`:toddy` -> `:plushie`), environment
  variables (`TODDY_*` -> `PLUSHIE_*`), and mix tasks (`toddy.*` ->
  `plushie.*`) have changed.
- **Canvas shapes are now typed structs** instead of plain maps. Builder
  functions (`rect`, `circle`, `line`, `text`, `path`, `image`, `svg`,
  `stroke`, `linear_gradient`) return struct instances (`%Rect{}`,
  `%Circle{}`, etc.) with `Plushie.Encode` protocol implementations.
  Code that pattern-matched on `%{type: "rect"}` must use `%Rect{}`.
- **`import Plushie.Canvas.Shape` no longer needed** for `group`, `layer`,
  or `interactive` in canvas blocks. Use `import Plushie.UI` instead.
  Canvas `text`, `image`, and `svg` calls are automatically resolved
  inside canvas/layer/group blocks.
- **Test backend renamed**: `:pooled_mock` -> `:mock`,
  `Plushie.Test.Backend.Pooled` -> `Plushie.Test.Backend.MockRenderer`.
  The env var value changes: `PLUSHIE_TEST_BACKEND=mock` (was
  `pooled_mock`). `Plushie.Test.MockBridge` renamed to
  `Plushie.Test.InternalMockBridge` (`@moduledoc false`).
- **`Padding.encode/1` renamed to `Padding.cast/1`** (normalization, not
  wire encoding).

### Added

- **Block-form options for all widgets.** Every leaf widget and canvas
  shape supports a do-block syntax for declaring options:
  ```elixir
  button "save", "Save" do
    style :primary
    padding %{top: 10, bottom: 10}
  end
  ```
- **Container inline props.** Container widgets (column, row, container,
  etc.) accept option declarations directly in their do-blocks, mixed
  with children:
  ```elixir
  column do
    spacing 8
    padding 16
    text("Hello")
  end
  ```
- **Nested do-blocks for struct-typed options.** Options like `padding`,
  `a11y`, `border`, `shadow`, and `style` support nested do-blocks that
  construct typed structs:
  ```elixir
  container "card" do
    border do
      width 1
      color "#ddd"
      rounded 8
    end
    shadow do
      color "#0000001a"
      offset_y 2
      blur_radius 8
    end
    text("Content")
  end
  ```
- **`interactive` directive** with id-first syntax, keyword form, block
  form, and pipe form for canvas shape interactivity.
- **`Plushie.DSL.Buildable` behaviour** - formal contract for types
  participating in the DSL block-form pattern (`from_opts/1`,
  `__field_keys__/0`, `__field_types__/0`).
- **Compile-time validation everywhere.** All widget block forms validate
  option keys at compile time. Using an option that doesn't belong to
  the current widget produces a helpful error. Canvas blocks validate
  every call against its context (canvas/layer/group).
- **Context-aware `canvas_scope` walker** validates and rewrites calls
  inside canvas blocks. Wrong-arity `text`/`image`/`svg` calls,
  widget macros, and misplaced shapes produce compile-time errors.
- **Context-aware `container_scope` walker** validates container options.
  Using an option on the wrong container lists which containers support
  it.
- **New value structs** - `ShapeStyle` (hover/pressed overrides),
  `DragBounds`, `HitRect`, `Dash`, plus `Padding` and `Font` converted
  from utility types to proper structs.
- **Extension DSL integration** - extension widgets automatically
  generate `Buildable` callbacks and option metadata from `prop`
  declarations.
- **Tree normalizer leak detection** - shape structs and DSL metadata
  tuples in the widget tree produce clear error messages.
- **Event coalescing** - `max_rate` on subscriptions, `event_rate` on
  widgets, host-side pending coalesce buffer for mouse moves and sensor
  resizes.
- **Three transport modes** - `:spawn` (default), `:stdio` for
  renderer-parent stdio, and `{:iostream, pid}` (for SSH/TCP/custom).
- **Canvas interactive shapes** - renderer-side hit testing with click,
  hover, drag, focus events via the `interactive` field on shapes.
- **`docs/dsl-internals.md`** - maintainer guide for the DSL
  architecture, Buildable behaviour, and scope walkers.
- **`--wasm` flag** for `mix plushie.download` and `mix plushie.build`.
- **`bin/plushie` symlink** created by `mix plushie.download` for
  stable path references without the platform-specific name.
- **`mix plushie.connect`** replaces `mix plushie.stdio`. Connects to
  the renderer via Unix socket or TCP instead of stdin/stdout. Token
  auth via Settings message.
- **Doc-sync tests** linking doc code blocks to test functions via
  HTML comment markers.

### Changed

- **Downloaded binaries moved** from `priv/bin/` to `_build/plushie/bin/`.
  Build artifacts belong in `_build/` where `mix clean` removes them.
- **`mix plushie.stdio` renamed** to `mix plushie.connect`. The old
  stdin/stdout transport is still available as a fallback when
  `PLUSHIE_SOCKET` is not set.

- `Plushie.UI` is now the single macro/DSL layer. All shape macros
  (`rect`, `circle`, `group`, `layer`, etc.), path commands, transforms,
  clips, and gradients are available via `import Plushie.UI`.
- `Plushie.Canvas.Shape` is now a pure-function module (no macros).
  Import it directly only for helper functions outside canvas blocks.
- All `Encode` protocol implementations moved to their respective struct
  module files. `Plushie.Encode` contains only the protocol definition
  and primitive implementations.
- Widget struct field types tightened to reference specific type modules
  (e.g., `Plushie.Type.Padding.t()` instead of `term()`).
- Canvas widget type annotations use `canvas_shape()` union type.
- `@widget_calls` derived from component lists instead of manually
  maintained.
- Doc code examples use `use Plushie.App` instead of
  `@behaviour Plushie.App` (the latter misses default implementations
  of optional callbacks like `window_config/1`).

## [0.3.0] - 2026-03-19

Initial public release.

### Added

- **Elm architecture** - `init/1`, `update/2`, `view/1`, optional
  `subscribe/1` callbacks via the `Plushie.App` behaviour.
- **38 built-in widget types** - layout (column, row, container,
  scrollable, stack, grid, pane_grid), display (text, rich_text,
  markdown, image, svg, progress_bar, qr_code, rule, canvas),
  input (button, text_input, text_editor, checkbox, radio, toggler,
  slider, vertical_slider, pick_list, combo_box, table), and
  wrappers (tooltip, pointer_area, sensor, overlay, responsive, themer,
  keyed_column, space, floating, pin, window).
- **22 built-in themes** - light, dark, dracula, nord, solarized,
  gruvbox, catppuccin, tokyo night, kanagawa, moonfly, nightfly,
  oxocarbon, ferra. Custom palettes and per-widget style overrides
  via `Plushie.Type.StyleMap`.
- **Multi-window** - declare window nodes in the widget tree; the
  framework manages open/close/update automatically.
- **Platform effects** - native file dialogs, clipboard (text, HTML,
  primary selection), OS notifications.
- **Accessibility** - screen reader support via accesskit on all
  platforms. A11y props on all widgets.
- **Commands** - async work, streaming, timers, widget ops (focus,
  scroll, select), window management (25+ operations), image
  management, platform effects, extension commands.
- **Subscriptions** - timers, keyboard, mouse, touch, IME, window
  lifecycle, animation frames, system theme changes.
- **16 typed event structs** - Widget, Key, Mouse, Touch, Ime,
  Window, Canvas, PointerArea, Pane, Sensor, Effect, System, Timer,
  Async, Stream, Modifiers.
- **Scoped widget IDs** - containers namespace children's IDs
  automatically. Pattern match on local ID or scope chain.
- **Three-backend test framework** - mocked (fast, no display),
  headless (real rendering via tiny-skia, screenshots), windowed
  (real GPU windows). Same API across all three.
- **Extension system** - pure Elixir composite widgets or Rust-backed
  native widgets via `Plushie.Extension` macro DSL.
- **Live reload** - file watching in dev mode, enabled by default
  via `mix plushie.gui`. State preserved across reloads.
- **Daemon mode** - `Plushie.start_link(MyApp, daemon: true)` keeps
  the process running after the last window closes.
- **Precompiled binaries** - `mix plushie.download` fetches
  platform-specific binaries with mandatory SHA256 verification.
- **Build from source** - `mix plushie.build` compiles the plushie
  binary, with optional extension workspace generation.
- **State helpers** - `Plushie.State` (revision tracking),
  `Plushie.Undo` (undo/redo), `Plushie.Selection` (single/multi/range),
  `Plushie.Route` (navigation), `Plushie.Data` (query pipeline),
  `Plushie.Animation` (easing functions).
- **Canvas drawing** - shape primitives (rect, circle, arc, path,
  text, image) with layers, gradients, opacity, and caching.
- **8 example apps** - Counter, Todo, Notes, Clock, Shortcuts,
  AsyncFetch, ColorPicker, Catalog.
