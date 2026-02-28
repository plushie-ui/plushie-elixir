# Roadmap

Julep is built in phases. Each phase has a clear goal and a gate that must
pass before moving on. No checkbox-ticking -- each gate has a concrete
demonstration.

## Phase 0: skeleton

**Goal:** Repository, build tooling, and a working hello-world.

Project structure:

```
julep/
  lib/
    julep.ex                    # Public API (start, stop, dispatch, etc.)
    julep/
      app.ex                    # Julep.App behaviour definition
      ui.ex                     # Julep.UI ergonomic builder layer
      iced.ex                   # Julep.Iced namespace root
      iced/
        ...                     # Strict parity widget modules (phase 1+)
      command.ex                # Julep.Command
      runtime.ex                # GenServer managing app lifecycle
      bridge.ex                 # Port-based renderer bridge
      protocol.ex               # JSONL encode/decode
      tree.ex                   # Tree normalization and diffing
  native/
    julep_gui/
      Cargo.toml
      src/
        main.rs                 # Renderer entry point
  mix.exs
  test/
    ...
  docs/
    ...
```

Checklist:

- [x] Elixir mix project with `Julep.App` behaviour and `Julep.UI` module.
- [x] `Julep.Runtime` GenServer: starts app, manages model, dispatches
      events, calls view, sends trees to bridge.
- [x] `Julep.Bridge`: spawns renderer via Port, sends/receives JSONL.
- [x] `Julep.Protocol`: encode snapshots, decode events.
- [x] Rust binary (`julep_gui`) that reads a snapshot from stdin, renders
      a basic tree (column, text, button), and writes click events to stdout.
- [x] `mix julep.gui` task that builds the renderer and runs an app.
- [x] One trivial app (counter) that compiles, runs, and renders.
- [x] Basic test: `Counter.init`, `Counter.update`, `Counter.view` work
      without the renderer.

**Gate:** `mix julep.gui Counter` opens a window with a working counter.

## Phase 1: core loop

**Goal:** The full update cycle works end-to-end.

- [x] `init/1`, `update/2`, `view/1` callbacks wired through the runtime.
- [x] Tree diffing and patch generation.
- [x] Renderer applies patches incrementally (not full snapshot every frame).
- [x] Event encoding/decoding for click, input, toggle, submit.
- [x] Renderer restart with snapshot replay on crash.
- [x] Basic ExUnit test helpers (headless app, tree assertions).

**Gate:** A todo-list app with add/remove/toggle works interactively. Tests
pass without the renderer.

## Phase 2: widget catalog

**Goal:** Full coverage of iced's widget set.

- [x] All direct iced widgets mapped (see renderer.md widget table).
- [x] Composite widget: table (data table with headers, sorting).
- [x] Theming (built-in themes, custom palettes, per-subtree override).
- [x] Multi-window support (window nodes in tree drive window lifecycle).
- [x] Widget state continuity (scroll, focus, cursor across re-renders).

**Gate:** Demo app exercises every widget type. Visual inspection confirms
correct rendering.

## Phase 3: effects and polish

**Goal:** Native platform features and developer experience polish.

- [x] File dialogs (open, save, directory).
- [x] Clipboard read/write.
- [x] OS notifications.
- [x] System theme detection.
- [x] `mix julep.inspect` for headless tree output.
- [x] Snapshot testing helpers.
- [x] Error recovery (update/view exceptions do not crash the app).
- [x] Documentation and guides.

**Gate:** Demo app uses file dialogs and clipboard. Snapshot tests pass
in CI. Developer can go from `mix new` to running GUI in under 5 minutes
following the guide.

## Phase 4: state helpers

**Goal:** Ship the optional state management modules.

- [x] `Julep.State` (path-based access, transactions).
- [x] `Julep.Undo` (undo/redo with coalescing).
- [x] `Julep.Selection` (single/multi/range).
- [x] `Julep.Route` (client-side navigation).
- [x] `Julep.Data` (query pipeline for records).

**Gate:** Demo app uses all helpers. Each has its own test suite with full
coverage.

## Phase 5: distribution

**Goal:** Make it easy for others to use julep.

- [x] Publish Hex package.
- [x] Precompiled renderer binaries for macOS (arm64, x86_64), Linux
      (x86_64), and Windows (x86_64).
- [x] Automatic binary download on `mix deps.get` (like rustler_precompiled).
- [x] Fallback to source build if precompiled binary is not available.
- [x] CI pipeline for building and publishing binaries on release.

**Gate:** A fresh `mix new` project can add `{:julep, "~> 0.1"}`, run
`mix deps.get && mix julep.gui MyApp`, and see a window without having
Rust installed.

**Iced 0.14 parity audit** -- completed. All widgets, props, events,
subscriptions, commands, and window operations audited and aligned.

## Completed (post-Phase 5)

Hot code reload is complete and shipped in Phase 3.

### Canvas drawing primitives (shipped)

Layer-based caching (`layers` prop replaces old `shapes` prop). Arbitrary
paths (bezier, quadratic, arcs, ellipses, rounded rects), stroked shapes
with full stroke styles (line cap, join, dash), gradient fills (linear),
transforms (translate/rotate/scale with push_transform/pop_transform
stack), draw_image, draw_svg, text with font/size. Remaining minor gaps:
fill rules and clipping.

### In-memory image handles (shipped)

Image registry on the Rust side with `create_image`, `update_image`, and
`delete_image` commands from Elixir. Supports encoded bytes
(`Handle::from_bytes`) and raw RGBA pixels (`Handle::from_rgba`). Elixir
owns lifecycle; renderer is a dumb cache. Canvas `draw_image` works with
in-memory images.

### Custom widget styling / style maps (shipped)

`Julep.Iced.StyleMap` type module. All 13 styleable widgets accept
`StyleMap.t()` alongside named preset atoms. The `style` prop accepts a
map of fields (background, text_color, border, shadow) with status
overrides (hovered, pressed, disabled, focused). Rust constructs one-off
closures from the map values. Auto-derives hover (darken 10%) and
disabled (50% alpha) states.

## Future (not scheduled)

### Other

- **Rust-first packaging.** Rust binary as the entrypoint that embeds the
  BEAM. For app store distribution and double-click launchers.
- **Accessibility.** Bridge to platform accessibility APIs (accesskit).
- **Observability.** Tracing, metrics, protocol tap.
- **Custom Rust widgets.** Let advanced users write custom iced widgets
  that plug into the renderer.
- **Mobile/web.** Way out of scope for now.

## Principles for this roadmap

1. **Each phase ships something usable.** Phase 0 gives you a counter.
   Phase 1 gives you a real app. You do not wait for phase 5 to start
   building things.
2. **Gates are demonstrations, not checklists.** "It works" means
   something specific and observable.
3. **Phases are sequential.** Do not start phase N+1 until phase N's gate
   passes. This prevents the speculative architecture problem.
4. **The roadmap changes.** Real usage will reveal what matters. Items
   will be added, removed, and reordered based on experience.
