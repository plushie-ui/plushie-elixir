# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.3.0] - 2026-03-19

Initial public release.

### Added

- **Elm architecture** -- `init/1`, `update/2`, `view/1`, optional
  `subscribe/1` callbacks via the `Toddy.App` behaviour.
- **37 built-in widget types** -- layout (column, row, container,
  scrollable, stack, grid, pane_grid), display (text, rich_text,
  markdown, image, svg, progress_bar, qr_code, rule, canvas),
  input (button, text_input, text_editor, checkbox, radio, toggler,
  slider, vertical_slider, pick_list, combo_box, table), and
  wrappers (tooltip, mouse_area, sensor, overlay, responsive, themer,
  keyed_column, space, float, pin).
- **22 built-in themes** -- light, dark, dracula, nord, solarized,
  gruvbox, catppuccin, tokyo night, kanagawa, moonfly, nightfly,
  oxocarbon, ferra. Custom palettes and per-widget style overrides
  via `Toddy.Iced.StyleMap`.
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
  native widgets via `Toddy.Extension` macro DSL.
- **Live reload** -- file watching in dev mode, enabled by default
  via `mix toddy.gui`. State preserved across reloads.
- **Daemon mode** -- `Toddy.start_link(MyApp, daemon: true)` keeps
  the process running after the last window closes.
- **Precompiled binaries** -- `mix toddy.download` fetches
  platform-specific binaries with mandatory SHA256 verification.
- **Build from source** -- `mix toddy.build` compiles the toddy
  binary, with optional extension workspace generation.
- **State helpers** -- `Toddy.State` (revision tracking),
  `Toddy.Undo` (undo/redo), `Toddy.Selection` (single/multi/range),
  `Toddy.Route` (navigation), `Toddy.Data` (query pipeline),
  `Toddy.Animation` (easing functions).
- **Canvas drawing** -- shape primitives (rect, circle, arc, path,
  text, image) with layers, gradients, opacity, and caching.
- **8 example apps** -- Counter, Todo, Notes, Clock, Shortcuts,
  AsyncFetch, ColorPicker, Catalog.
