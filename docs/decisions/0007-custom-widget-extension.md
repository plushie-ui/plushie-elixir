# 0007: Two-tier custom widget strategy

## Status

Accepted.

## Context

Users will want custom rendering beyond what built-in widgets provide. An
extension mechanism is needed that works within Julep's JSONL-over-stdio
architecture, where the Elixir side builds declarative trees and the Rust
side renders them.

## Decision

Two tiers of custom widget support:

**Tier 1: Interactive canvas** (see ADR 0004). The universal escape hatch.
Users describe shapes and handle events from Elixir. Covers charts, diagrams,
custom controls, and simple games without writing any Rust.

**Tier 2: JulepWidget trait** (future). For power users who need native text
layout, custom scrolling, or deep iced styling integration. Users write Rust
implementing a `JulepWidget` trait, build a custom renderer binary, and
register their widget types. The custom renderer replaces the stock
`julep_gui` binary.

Explicitly rejected alternatives:

- **WASM plugins.** Adds a runtime, a sandbox, and a new compilation target.
  Complexity is not justified by the use case.
- **Runtime dynamic loading.** Shared library plugins loaded at startup.
  Platform-specific, fragile, and a security surface. Not worth it.

## Consequences

- Most custom widget needs are met immediately via canvas (Tier 1). No Rust
  knowledge required.
- Power users who need native rendering capabilities can build custom
  renderers (Tier 2). The escape hatch exists but requires deliberate
  investment.
- No runtime plugin complexity. The renderer binary is always a single
  statically-linked executable.
- Tier 2 is explicitly deferred. It will be designed when real demand
  materializes, informed by Tier 1 usage patterns.
