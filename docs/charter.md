# Charter

## Problem

We want native cross-platform desktop apps with a strong Elixir developer
experience.

Existing options force a choice: write everything in a systems language for
native performance, or use web technologies and accept the tradeoffs. Elixir
has excellent concurrency, fault tolerance, and developer ergonomics, but no
native GUI story.

## Mission

Build a library where app-specific logic is written entirely in Elixir, while
a reusable Rust renderer handles painting and platform integration.

## Success criteria

- App developers write zero Rust.
- A GUI can be started from a mix task, from IEx, or embedded as part of a
  larger OTP application.
- UI stays responsive during sidecar restart and transient failures.
- The library is a normal Hex dependency. No special build tooling beyond
  having a Rust toolchain available (or using precompiled renderer binaries).
- The protocol between Elixir and Rust is simple, inspectable, and testable
  without running the GUI.

## Non-goals (v1)

- Mobile support.
- Browser/WebAssembly support.
- Binary protocol optimization before real profiling data.
- Capability-based security model (can be added later if needed).
- Rust host mode (Rust as the primary process that loads Elixir). This is a
  future packaging option, not a v1 requirement.

## Guiding principles

1. **Elixir owns everything that matters.** State, logic, UI tree shape, event
   handling, effects. The Rust side is a rendering backend.
2. **Start simple, stay simple.** No speculative architecture. Add complexity
   only when a real use case demands it.
3. **Inspectable by default.** The default transport is MessagePack for
   performance. JSON mode is available for debugging and observability.
   UI trees are plain maps. Everything can be tested without the renderer.
4. **One way to do things.** Minimize API surface. Prefer a single clear path
   over multiple equivalent options.
