# 0012: Widget extension architecture

## Status

Accepted.

## Context

ADR 0007 established two tiers for custom widgets: interactive canvas (Tier
1, available now) and a future JulepWidget trait for native Rust extensions
(Tier 2). This ADR details the package architecture for Tier 2 and clarifies
how third-party widget packages integrate with Julep's build and distribution
model.

Two categories of widget packages exist:

1. **Pure Elixir** -- composition of existing primitives. These already work
   today via the `Julep.Iced.Widget` protocol.
2. **Elixir + Rust** -- new native widget types that require custom rendering
   code. These need build infrastructure, trait contracts, and discovery.

The existing `iced_features` config toggles built-in iced feature gates
(e.g., `svg`, `image`, `canvas`). Extensions are a separate concern --
they add entirely new widget types from external dependencies rather than
toggling capabilities of the stock renderer.

## Decision

### Pure Elixir widget packages

These already work with no additional infrastructure. A package provides
Elixir modules implementing the `Julep.Iced.Widget` protocol. The `to_node/1`
implementation composes existing built-in node types -- canvas layers, columns,
rows, containers, sliders, etc. No Rust code, no custom build steps.

Example: a color picker package provides a `ColorPicker` struct whose
`to_node/1` emits a canvas (hue wheel) alongside sliders (saturation,
lightness). The result is a standard `ui_node()` map that the stock renderer
handles without modification.

Pure Elixir packages work with prebuilt renderer binaries. They are the
recommended approach for most extension needs.

### Elixir + Rust widget packages

For cases where composition is insufficient -- custom text layout, GPU
shaders, platform-native controls, or performance-critical rendering -- a
package ships both Elixir modules and a Rust crate.

The model follows Rustler's precedent: the Rust crate lives in the package
(e.g., `native/my_widget/`), and Julep's build task discovers it, adds it
as a Cargo dependency, and links it into a custom renderer binary that
replaces the stock `julep_gui`.

The Elixir side provides typed widget structs implementing the
`Julep.Iced.Widget` protocol, same as pure Elixir packages. The `to_node/1`
output uses a custom `type` string that the stock renderer does not recognize
but the extended renderer does.

### WidgetExtension trait

The Rust side of an extension crate implements a `WidgetExtension` trait
(the production name for ADR 0007's "JulepWidget trait"):

```rust
pub trait WidgetExtension {
    /// Widget type names this extension handles (e.g., ["color_wheel"]).
    fn type_names(&self) -> &[&str];

    /// Render a node of a supported type into an iced Element.
    fn render<'a>(
        &'a self,
        node: &UiNode,
        children: Vec<Element<'a, Message>>,
    ) -> Element<'a, Message>;

    /// Populate caches for stateful extension widgets.
    /// Called during apply(), before view().
    fn ensure_caches(&mut self, node: &UiNode);
}
```

Dispatch in the renderer's `render()` function falls through after built-in
widget types. If no built-in matches, registered extensions are checked in
order. If no extension matches either, the node is skipped with a warning log.

### Discovery and build

Extension crates are discovered via Mix project configuration:

```elixir
def project do
  [
    julep_extensions: [
      {:fancy_charts, path: "native/fancy_charts"},
      {:my_widget, dep: :my_widget_package}
    ]
  ]
end
```

`mix julep.build` reads this list, generates a Cargo workspace that includes
the stock `julep_gui` crate plus all extension crates, and builds a single
renderer binary. The generated `main.rs` registers each extension with the
renderer before entering the event loop.

Auto-discovery from Mix deps is a possible future convenience -- scan deps
for a `julep_extension: true` marker in their `mix.exs` -- but explicit
configuration is the initial approach. Explicit is better than magic.

### Prebuilt binaries

Prebuilt renderer binaries do not include extensions. They contain only the
stock built-in widgets. This is a deliberate constraint:

- Pure Elixir extension packages work with prebuilt binaries (no custom
  rendering code needed).
- Elixir + Rust extension packages require compiling a custom renderer from
  source. The app using them must have a Rust toolchain available at build
  time.

This keeps prebuilt binary distribution simple and avoids combinatorial
explosion of binary variants.

### iced_features vs extensions

These are orthogonal:

- `iced_features` toggles built-in iced feature gates on the stock renderer.
  Affects what built-in widgets are available (e.g., `image`, `svg`, `canvas`).
  Works with prebuilt binaries when prebuilts include the feature.
- Extensions add new widget types from external Rust crates. Always requires
  compiling from source. Does not affect built-in widget availability.

A project can use both: toggle `iced_features` for built-in capabilities and
add extensions for custom widget types.

## Consequences

- Pure Elixir widget packages work today with zero infrastructure changes.
  This covers the majority of extension use cases.
- Elixir + Rust packages follow an established pattern (Rustler) that the
  Elixir ecosystem already understands.
- The renderer remains a single statically-linked binary. No runtime plugin
  loading, no WASM sandbox, no shared library fragility.
- Apps using only pure Elixir extensions can ship with prebuilt binaries.
  Apps using Rust extensions require a build-from-source step.
- The `WidgetExtension` trait contract is minimal (three functions). It
  mirrors the renderer's own internal structure (`type_names` for dispatch,
  `render` for view, `ensure_caches` for stateful widgets).
- Extension discovery is explicit via project config, avoiding hidden
  dependencies or surprising build behavior.
- The trait and build infrastructure are not implemented yet. This ADR
  establishes the architecture so that when Tier 2 demand materializes
  (per ADR 0007), the design is already decided.
