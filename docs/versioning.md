# Versioning

This SDK has two version numbers that evolve independently.

## SDK version

The Elixir package's own semver, declared in `mix.exs` and published
to [Hex](https://hex.pm/packages/plushie). Bumps cover Elixir-side
changes: bug fixes, new DSL helpers, typespec improvements, docs,
test helpers, and so on.

Pre-1.0, breaking changes may land in any minor bump (`0.X.0`). Patch
releases (`0.X.Y`) stay backwards-compatible within the SDK. The
[CHANGELOG](../CHANGELOG.md) lists every release's changes with
breaking items called out first.

## `PLUSHIE_RUST_VERSION`

The `PLUSHIE_RUST_VERSION` file at the project root (surfaced via
`Plushie.Binary.plushie_rust_version/0`) pins the exact
[plushie-rust](https://github.com/plushie-ui/plushie-rust) release
this SDK targets. Every plushie-rust artefact the SDK touches comes
from that release:

- The `plushie-renderer` binary downloaded by `mix plushie.download`.
- The `cargo-plushie` tool invoked by `mix plushie.build`.
- The plushie crate versions emitted into the generated renderer
  workspace Cargo.toml.

Bumping this file is how the SDK opts in to a newer renderer. The
two version axes move independently:

- SDK-only fixes bump the SDK version only; `PLUSHIE_RUST_VERSION`
  stays put.
- plushie-rust upgrades bump `PLUSHIE_RUST_VERSION` (and usually the
  SDK version too, to cut a release that ships the upgrade).

`PLUSHIE_RUST_VERSION` must match a plushie-rust release exactly: no
semver ranges, no `~> 0.6` fuzzy pins. Exact match is the only way
to guarantee the renderer binary, the generated dependencies, and
the wire protocol travel together.

See [plushie-rust's versioning policy](https://github.com/plushie-ui/plushie-rust/blob/main/docs/versioning.md)
for the canonical rules covering the full Rust workspace, the wire
protocol version, and cross-SDK compatibility.
