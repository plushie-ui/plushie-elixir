# ADR 0015: iced-native accessibility

## Status

Accepted

## Context

Julep's original accessibility implementation (ADR 0013) built its own
accesskit tree by walking the UI tree. `julep-core/accessibility.rs`
contained ~600 lines of Rust code (with 19 tests) that mapped widget types
to accesskit roles, extracted labels and state from props, applied `a11y`
overrides, and assembled `TreeUpdate` objects. A vendored copy of iced_winit
managed per-window accesskit adapters behind an `a11y` feature flag.

This approach worked but duplicated work that iced could do natively. Every
iced widget already knows its own semantics -- buttons know they're buttons,
sliders know their range and value. Having julep re-derive this information
from serialized props was fragile and required keeping the Rust-side role
mapping in sync with iced's widget behavior.

The iced fork's `v0.14.0-a11y-accesskit` branch adds native accessibility:
widgets report `Accessible` metadata via `operate()`, a `TreeBuilder` in
iced_winit builds the accesskit tree, and AT actions are translated to
native iced events. This is the mechanism iced would use upstream.

## Decision

Switch from custom tree conversion to iced-native accessibility.

1. Delete `julep-core/accessibility.rs` and its 19 tests.
2. Replace the vendored iced_winit with the iced fork's
   `v0.14.0-a11y-accesskit` branch, referenced via `[patch.crates-io]` in
   the renderer's `Cargo.toml`.
3. Add an `A11yOverride` wrapper widget (`a11y_widget.rs`) that intercepts
   `operate()` to apply Elixir-side overrides from the `a11y` prop (role,
   label, description, live, expanded, required, level).
4. Add a `HiddenInterceptor` wrapper widget that suppresses elements from
   the accessibility tree when `hidden: true` is set.
5. Convert `Julep.Iced.A11y` from a bare type module to a struct with
   `cast/1` for type safety.

## Consequences

- ~600 lines of custom Rust tree conversion code deleted, along with 19
  tests that validated julep's reimplementation of what iced already knows.

- Extension widgets get free accessibility support. They are already iced
  `Element`s that participate in `operate()`, so they report `Accessible`
  metadata without any julep-specific code.

- Simpler architecture. Iced handles tree building, AT actions, and
  platform integration. Julep only intercepts `operate()` to apply
  Elixir-side overrides.

- `A11y` struct with `cast/1` provides compile-time safety: dialyzer
  catches typos in field names, and the struct definition documents
  available fields. Bare maps are still accepted via `cast/1` for
  convenience.

- Depends on the iced fork's `v0.14.0-a11y-accesskit` branch. An upstream
  PR is pending. If upstream merges native a11y support, julep can switch
  to the official release by removing the `[patch.crates-io]` entry.

## Alternatives considered

1. **Keep the custom tree conversion.** Works, but ~600 lines of Rust
   duplicating what iced already knows about its own widgets. Every new
   widget or prop change requires updating the conversion code.

2. **Wait for upstream iced a11y support.** The upstream PR may take time.
   The fork branch gives us native a11y now, and migration to upstream is
   a one-line Cargo.toml change when it lands.
