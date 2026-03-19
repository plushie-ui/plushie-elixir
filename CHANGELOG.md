# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- Code review remediation (in progress)
- Widget extension architecture: `WidgetExtension` trait, `ExtensionDispatcher`,
  `ExtensionCaches`, SDK prelude, public prop helpers, test factory helpers
- `Julep.Extension` behaviour and build system for native extensions
- Extension config via Settings wire message
- ExtensionCommand wire protocol for high-frequency data push to extensions
- Split `julep_gui` into `julep-core` library crate and `julep-bin` binary crate
- Moved Rust renderer into separate `julep-renderer` repo; renamed binary
  from `julep_gui` to `julep-renderer`
- Protocol version handshake: renderer emits `hello` on startup, bridge
  validates protocol compatibility

### Fixed
- Overlay widget: missing trait methods, viewport clamping, safe unwraps
- Feature gates: clean compilation with any feature combination
- Mouse area `on_middle_press` event
- Tree diff child reordering and index stability
- Credo warnings across the codebase

## [0.5.0] - Phase 5: Distribution

### Added
- Hex package publication
- Precompiled renderer binaries for macOS (arm64, x86_64), Linux (x86_64),
  and Windows (x86_64)
- Automatic binary download on `mix deps.get` (rustler_precompiled-style)
- Fallback to source build when no precompiled binary is available
- CI pipeline for building and publishing release binaries
- `mix julep.download` task for fetching precompiled binaries
- `mix julep.build` task for source builds

## [0.4.0] - Phase 4: State Helpers & MessagePack Protocol

### Added
- `Julep.State` -- path-based access with change tracking and transactions
- `Julep.Undo` -- undo/redo stack with coalescing
- `Julep.Selection` -- single/multi/range selection with keyboard modifiers
- `Julep.Route` -- stack-based client-side navigation
- `Julep.Data` -- in-memory queryable data store with pipeline API
- MessagePack as default wire format (dual-format: msgpack + JSONL)
- 4-byte big-endian length-prefix framing for MessagePack mode
- Auto-detection of wire format from first byte of stdin
- Format locked at startup (no per-message switching)
- Native msgpack binary type for image registry payloads (no base64 overhead)
- `Julep.Command.set_icon/4` -- window icon from RGBA pixel data

### Changed
- Wire protocol default changed from JSONL to MessagePack
- Bridge accepts `:format` option (`:msgpack` default, `:json` for debugging)

## [0.3.0] - Phase 3: Effects, Testing & Polish

### Added
- File dialogs (open, save, directory) via `Julep.Effects`
- Clipboard read/write
- OS notifications
- System theme detection
- `mix julep.inspect` for headless tree output
- Snapshot testing helpers (`assert_tree_snapshot`)
- Screenshot testing (pixel capture with golden file comparison)
- Three-backend test framework: Mock (pure Elixir), Headless (Rust + iced_test),
  Full (real iced::daemon windows)
- `Julep.Test.Case` ExUnit template with backend resolution
- `Julep.Test.Helpers` -- find, click, assert_text, assert_snapshot
- `.julep` test script parser and runner (superset of `.ice` format)
- Hot code reload
- Error recovery (update/view exceptions do not crash the app)
- Custom widget styling via `Julep.Iced.StyleMap` -- 13 styleable widgets
  accept style maps with status overrides (hovered, pressed, disabled)
- Canvas drawing primitives: layers, arbitrary paths, stroke styles, gradient
  fills, transforms, text, image/SVG drawing, fill rules, clipping
- In-memory image handles (`create_image`, `update_image`, `delete_image`)
- `Command.stream/2` and `Command.cancel/1` for streaming async results
- Iced parity audit and gap closure: PickList/ComboBox open/close events,
  TextEditor syntax highlighting and key bindings, Checkbox icon, Container
  center helpers, Canvas fill_rule and clipping, Table sort/alignment/width,
  vsync, resize increments, system info/theme queries, SVG color tint,
  scale_factor, QR code widget, overlay widget, IME support

### Changed
- Canvas widget uses `layers` prop (replaces old `shapes` prop)
- `Color.t()` simplified to hex-only string format

## [0.2.0] - Phase 2: Widget Catalog

### Added
- Full iced widget set mapped to Elixir: button, text_input, checkbox,
  toggler, radio, pick_list, combo_box, slider, vertical_slider,
  text_editor, text, progress_bar, tooltip, image, svg, markdown,
  rich_text, rule, mouse_area, sensor, pane_grid, canvas, scrollable,
  container, column, row, stack, space, grid, keyed_column, pin, float,
  responsive, themer
- Typed widget structs (`Julep.Iced.Widget.*`) with builder pattern
- `Julep.Iced` untyped convenience facade
- `Julep.Iced.Encode` protocol for automatic type conversion in props
- Composite table widget with headers, sorting, column alignment/width
- Theming: 22 built-in themes, custom palettes with hex colors,
  per-subtree override via themer widget
- Multi-window support (window nodes in tree drive window lifecycle)
- Widget state continuity (scroll, focus, cursor across re-renders)
- Shared type modules: Alignment, Length, Padding, Color, Font, Wrapping,
  Shaping, ContentFit, Direction, Position, FilterMethod, Anchor, Shadow

## [0.1.0] - Phase 1: Core Loop (Skeleton)

### Added
- `Julep.App` behaviour: `init/1`, `update/2`, `view/1`, `subscribe/1`
- `Julep.Runtime` GenServer managing app lifecycle and update/view loop
- `Julep.Bridge` Port-based renderer bridge (spawns `julep_gui`)
- `Julep.Protocol` encode/decode for wire messages
- `Julep.Tree` normalization and diffing with patch generation
- `Julep.Command` command constructors (async, widget ops, window, timer)
- `Julep.Subscription` subscription constructors (time, keyboard, window)
- `Julep.UI` ergonomic builder layer with `do` blocks and keyword props
- Rust renderer binary (`julep_gui`) using `iced::daemon` for multi-window
- Incremental tree patching (not full snapshot every frame)
- Event encoding/decoding for click, input, toggle, submit
- Renderer restart with snapshot replay on crash
- `mix julep.gui` task for building and running apps
- Counter and todo-list example apps
- Basic ExUnit test helpers
