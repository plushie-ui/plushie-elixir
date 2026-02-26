# 0001: Clean break from icing

## Status

Accepted.

## Context

The `icing` project was the first implementation attempt at an Elixir-first
native desktop GUI library. It accumulated:

- 86 design docs and 51 ADRs specifying a system far more complex than what
  was built or needed.
- A Rust host runtime with effects, capability gating, and transport
  machinery that was never connected to the actual rendering path.
- A 10,400-line monolithic renderer that was the only thing putting pixels
  on screen.
- A 6,500-line demo app module.
- Over-specified protocol with envelopes, lanes, deadlines, and correlation
  that was not implemented in the actual transport.
- An implementation plan with every checkbox ticked despite significant gaps
  between the spec and the code.

The Elixir side had solid bones: the `Icing.App` behaviour, UI tree/diff
system, state management helpers, and Port-based bridge were well-designed
and functional. But the overall project carried too much speculative
architecture.

## Decision

Start fresh as `julep` with a new repository, keeping the design insights
and patterns from icing but not the code, the over-specified docs, or the
technical debt.

## Key changes from icing

1. **One repo.** Docs and code live together. No separate docs repo.
2. **Minimal docs.** Each doc earns its place by describing something that
   exists or is about to be built. No speculative design docs.
3. **No speculative architecture.** No capability model, no protocol
   envelopes, no priority lanes, no signing pipeline, no dual release rails
   until there is a demonstrated need.
4. **Simplified API names.** `init` instead of `initial_model`. `update`
   instead of `handle_event`. `view` instead of `render`. Standard Elm
   naming that any developer recognizes.
5. **Renderer is a dependency.** It ships as a precompiled binary. App
   developers do not think about Rust.
6. **Phased roadmap with gates.** Each phase produces something usable.
   No phase starts until the previous gate passes.

## What carries forward (as design reference)

- Elm architecture for the app behaviour.
- UI tree as plain maps with id/type/props/children.
- Tree diffing with position-based patches.
- JSONL-over-stdio transport.
- Port-based bridge with reconnection.
- Pure-data state helpers (State, Undo, Selection, Route, Data).
- Widget type catalog and iced parity mapping.

## What does not carry forward

- The 86 design docs and 51 ADRs.
- The Rust host runtime (host/src/).
- The sidecar supervision/router/session-guard layer.
- The protocol envelope/lane/deadline spec.
- The dual release rails and signing pipeline.
- The CI lane matrix.
- The capability/policy engine.
- The demo app in its current form.
