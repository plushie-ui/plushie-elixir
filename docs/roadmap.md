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

- [ ] Elixir mix project with `Julep.App` behaviour and `Julep.UI` module.
- [ ] `Julep.Runtime` GenServer: starts app, manages model, dispatches
      events, calls view, sends trees to bridge.
- [ ] `Julep.Bridge`: spawns renderer via Port, sends/receives JSONL.
- [ ] `Julep.Protocol`: encode snapshots, decode events.
- [ ] Rust binary (`julep_gui`) that reads a snapshot from stdin, renders
      a basic tree (column, text, button), and writes click events to stdout.
- [ ] `mix julep.gui` task that builds the renderer and runs an app.
- [ ] One trivial app (counter) that compiles, runs, and renders.
- [ ] Basic test: `Counter.init`, `Counter.update`, `Counter.view` work
      without the renderer.

**Gate:** `mix julep.gui Counter` opens a window with a working counter.

## Phase 1: core loop

**Goal:** The full update cycle works end-to-end.

- [ ] `init/1`, `update/2`, `view/1` callbacks wired through the runtime.
- [ ] Tree diffing and patch generation.
- [ ] Renderer applies patches incrementally (not full snapshot every frame).
- [ ] Event encoding/decoding for click, input, toggle, submit.
- [ ] Renderer restart with snapshot replay on crash.
- [ ] Basic ExUnit test helpers (headless app, tree assertions).

**Gate:** A todo-list app with add/remove/toggle works interactively. Tests
pass without the renderer.

## Phase 2: widget catalog

**Goal:** Full coverage of iced's widget set.

- [ ] All direct iced widgets mapped (see renderer.md widget table).
- [ ] Composite widgets: tabs, nav, modal, card, panel, form, split_pane.
- [ ] Theming (built-in themes, custom palettes, per-subtree override).
- [ ] Multi-window support (window nodes in tree drive window lifecycle).
- [ ] Widget state continuity (scroll, focus, cursor across re-renders).

**Gate:** Demo app exercises every widget type. Visual inspection confirms
correct rendering.

## Phase 3: effects and polish

**Goal:** Native platform features and developer experience polish.

- [ ] File dialogs (open, save, directory).
- [ ] Clipboard read/write.
- [ ] OS notifications.
- [ ] System theme detection.
- [ ] `mix julep.inspect` for headless tree output.
- [ ] Snapshot testing helpers.
- [ ] Error recovery (update/view exceptions do not crash the app).
- [ ] Documentation and guides.

**Gate:** Demo app uses file dialogs and clipboard. Snapshot tests pass
in CI. Developer can go from `mix new` to running GUI in under 5 minutes
following the guide.

## Phase 4: state helpers

**Goal:** Ship the optional state management modules.

- [ ] `Julep.State` (path-based access, transactions).
- [ ] `Julep.Undo` (undo/redo with coalescing).
- [ ] `Julep.Selection` (single/multi/range).
- [ ] `Julep.Route` (client-side navigation).
- [ ] `Julep.Data` (query pipeline for records).

**Gate:** Demo app uses all helpers. Each has its own test suite with full
coverage.

## Phase 5: distribution

**Goal:** Make it easy for others to use julep.

- [ ] Publish Hex package.
- [ ] Precompiled renderer binaries for macOS (arm64, x86_64), Linux
      (x86_64), and Windows (x86_64).
- [ ] Automatic binary download on `mix deps.get` (like rustler_precompiled).
- [ ] Fallback to source build if precompiled binary is not available.
- [ ] CI pipeline for building and publishing binaries on release.

**Gate:** A fresh `mix new` project can add `{:julep, "~> 0.1"}`, run
`mix deps.get && mix julep.gui MyApp`, and see a window without having
Rust installed.

## Future (not scheduled)

These are things that might matter but are not on the critical path:

- **Rust-first packaging.** Rust binary as the entrypoint that embeds the
  BEAM. For app store distribution and double-click launchers.
- **Accessibility.** Bridge to platform accessibility APIs (accesskit).
- **Observability.** Tracing, metrics, protocol tap.
- **Hot reload.** Recompile Elixir, push updated tree without restarting.
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
