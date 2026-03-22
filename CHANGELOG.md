# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

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
- **`Plushie.DSL.Buildable` behaviour** -- formal contract for types
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
- **New value structs** -- `ShapeStyle` (hover/pressed overrides),
  `DragBounds`, `HitRect`, `Dash`, plus `Padding` and `Font` converted
  from utility types to proper structs.
- **Extension DSL integration** -- extension widgets automatically
  generate `Buildable` callbacks and option metadata from `prop`
  declarations.
- **Tree normalizer leak detection** -- shape structs and DSL metadata
  tuples in the widget tree produce clear error messages.
- **Event coalescing** -- `max_rate` on subscriptions, `event_rate` on
  widgets, host-side pending coalesce buffer for mouse moves and sensor
  resizes.
- **Three transport modes** -- `:spawn` (default), `:stdio` (for
  `plushie --exec`), and `{:iostream, pid}` (for SSH/TCP/custom).
- **Canvas interactive shapes** -- renderer-side hit testing with click,
  hover, drag, focus events via the `interactive` field on shapes.
- **`docs/dsl-internals.md`** -- maintainer guide for the DSL
  architecture, Buildable behaviour, and scope walkers.

### Changed

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

- **Elm architecture** -- `init/1`, `update/2`, `view/1`, optional
  `subscribe/1` callbacks via the `Plushie.App` behaviour.
- **38 built-in widget types** -- layout (column, row, container,
  scrollable, stack, grid, pane_grid), display (text, rich_text,
  markdown, image, svg, progress_bar, qr_code, rule, canvas),
  input (button, text_input, text_editor, checkbox, radio, toggler,
  slider, vertical_slider, pick_list, combo_box, table), and
  wrappers (tooltip, mouse_area, sensor, overlay, responsive, themer,
  keyed_column, space, floating, pin, window).
- **22 built-in themes** -- light, dark, dracula, nord, solarized,
  gruvbox, catppuccin, tokyo night, kanagawa, moonfly, nightfly,
  oxocarbon, ferra. Custom palettes and per-widget style overrides
  via `Plushie.Type.StyleMap`.
- **Multi-window** -- declare window nodes in the widget tree; the
  framework manages open/close/update automatically.
- **Platform effects** -- native file dialogs, clipboard (text, HTML,
  primary selection), OS notifications.
- **Accessibility** -- screen reader support via accesskit on all
  platforms. A11y props on all widgets.
- **Commands** -- async work, streaming, timers, widget ops (focus,
  scroll, select), window management (25+ operations), image
  management, platform effects, extension commands.
- **Subscriptions** -- timers, keyboard, mouse, touch, IME, window
  lifecycle, animation frames, system theme changes.
- **16 typed event structs** -- Widget, Key, Mouse, Touch, Ime,
  Window, Canvas, MouseArea, Pane, Sensor, Effect, System, Timer,
  Async, Stream, Modifiers.
- **Scoped widget IDs** -- containers namespace children's IDs
  automatically. Pattern match on local ID or scope chain.
- **Three-backend test framework** -- mocked (fast, no display),
  headless (real rendering via tiny-skia, screenshots), windowed
  (real GPU windows). Same API across all three.
- **Extension system** -- pure Elixir composite widgets or Rust-backed
  native widgets via `Plushie.Extension` macro DSL.
- **Live reload** -- file watching in dev mode, enabled by default
  via `mix plushie.gui`. State preserved across reloads.
- **Daemon mode** -- `Plushie.start_link(MyApp, daemon: true)` keeps
  the process running after the last window closes.
- **Precompiled binaries** -- `mix plushie.download` fetches
  platform-specific binaries with mandatory SHA256 verification.
- **Build from source** -- `mix plushie.build` compiles the plushie
  binary, with optional extension workspace generation.
- **State helpers** -- `Plushie.State` (revision tracking),
  `Plushie.Undo` (undo/redo), `Plushie.Selection` (single/multi/range),
  `Plushie.Route` (navigation), `Plushie.Data` (query pipeline),
  `Plushie.Animation` (easing functions).
- **Canvas drawing** -- shape primitives (rect, circle, arc, path,
  text, image) with layers, gradients, opacity, and caching.
- **8 example apps** -- Counter, Todo, Notes, Clock, Shortcuts,
  AsyncFetch, ColorPicker, Catalog.
