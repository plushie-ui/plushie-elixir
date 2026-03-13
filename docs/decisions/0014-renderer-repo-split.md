# ADR 0014: Split renderer into separate repository

## Status

Accepted

## Context

The Rust renderer lived at `native/julep_gui/` inside the Julep Elixir
project. This coupling created problems:

1. Hex package included Rust source, requiring a Rust toolchain for
   all consumers.
2. CI for Elixir-only changes also built the renderer.
3. Extension authors needed the entire julep repo to access julep-core.
4. The binary name `julep_gui` was a leftover from the icing project.

## Decision

Split the renderer into `julep-renderer`, a sibling repository. Rename
the binary crate from `julep-bin` to `julep-renderer` and the binary
from `julep_gui` to `julep-renderer`. Keep `julep-core` unchanged as
the public SDK for extensions.

Add a protocol version handshake: the renderer emits a `hello` message
on startup. The Elixir bridge validates the protocol version.

Binary resolution falls back through: `JULEP_RENDERER_PATH` env var,
application config, custom extension build, precompiled binary, sibling
repo checkout.

## Consequences

- `mix preflight` conditionally runs Rust checks only when the renderer
  source is available.
- Extension repos change one path in their Cargo.toml (julep-core now
  at `../../julep-renderer/julep-core`).
- `JULEP_RENDERER_SOURCE` env var controls where mix tasks find renderer
  source for building.
- The Hex package no longer ships Rust source.
