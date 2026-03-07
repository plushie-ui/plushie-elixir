# ADR 0013: Accessibility via vendored iced_winit

## Status

Accepted

## Context

Iced 0.14 has no accessibility/accesskit integration. GitHub issue #552 has
been open since October 2020 with no PR. The COSMIC project (Pop!_OS) forked
the entire iced repository to add accessibility, but that approach couples
us to their fork rather than upstream iced.

Julep needs to provide native accessibility support (screen reader
compatibility, keyboard navigation, AT action handling) without waiting for
upstream iced to ship it.

## Decision

Vendor `iced_winit` as a separate repository and patch it with accesskit
integration behind an `a11y` feature flag. The patch adds ~200 lines across
two files:

1. **`a11y.rs`** -- new module managing per-window accesskit adapters via a
   global registry (`OnceLock<Mutex<FxHashMap>>`), with public APIs for
   pushing tree updates and draining action requests.

2. **`lib.rs`** -- four hook points (window creation, window close, event
   forwarding, module declaration) all behind `#[cfg(feature = "a11y")]`.

The vendored crate is referenced via `[patch.crates-io]` in the workspace.
Local development uses `.cargo/config.toml` (gitignored) with a path
override.

Tree-to-accesskit conversion lives in `julep-core/src/accessibility.rs`,
keeping the vendored iced_winit patch minimal.

## Consequences

- **Maintenance burden:** The vendored iced_winit must be updated when
  upgrading iced versions. The patch is small (~200 lines, 4 insertion
  points) so rebasing should be straightforward.

- **Feature-gated:** The `a11y` feature is opt-in. Without it, the
  vendored crate compiles identically to upstream. No cost for users who
  don't need accessibility.

- **No upstream dependency:** We don't depend on iced shipping accesskit
  support. If they do, we can migrate by removing the vendor and the
  feature flag.

- **Separate repository:** The vendored crate lives in its own git
  repository, keeping julep's tree clean and making it independently
  versionable.

## Alternatives considered

1. **Wait for upstream iced accesskit support.** Issue #552 has been open
   5+ years. Not viable.

2. **Fork entire iced repository.** Too much maintenance burden. The
   COSMIC project does this but they have a team dedicated to their fork.

3. **Elixir-only a11y props without platform integration.** Props would
   pass through but nothing would happen. Screen readers wouldn't work.

4. **Separate accessibility process.** Too complex -- window handles can't
   easily cross process boundaries for accesskit adapter creation.
