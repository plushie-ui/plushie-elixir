# 0012: Widget extension architecture

## Status

Accepted and implemented (steps 1-9). Supersedes the placeholder version
of this ADR and fulfils ADR 0007's deferred Tier 2 design. Steps 10-14
(dogfooding extensions, generator, docs) are future work.

## Context

ADR 0007 established two tiers: interactive canvas (Tier 1, shipped) and
native Rust extensions (Tier 2, deferred). Canvas covers most custom
rendering needs, but some widgets genuinely need Rust: terminal emulators
backed by PTY connections, GPU-accelerated plotting, virtual-scrolling log
viewers, force-directed graph layouts. These all share the same problem:
they need internal state that lives in Rust and events that don't
round-trip through Elixir.

The renderer is currently a monolithic binary (`julep-renderer`) with no
library API. The `Message` enum is closed. `WidgetCaches` has named fields
for each built-in stateful widget. External code has no way in.

Several iced 0.14-compatible widget crates exist on crates.io (iced_term,
iced_plot, iced_aw, iced_gif, iced_color_picker) that could be wrapped as
julep extensions if the infrastructure existed.

A detailed design document with code examples, stress-test widgets, and
a 14-step implementation sequence exists as a working document outside
the repository (`rust-extensions.md`).

## Decision

### Crate restructuring

Split the renderer into a workspace with two crates:

- **julep-core** -- library crate (the SDK). Exports TreeNode, Message,
  WidgetCaches, prop helpers, the render function, the WidgetExtension
  trait, ExtensionCaches, ExtensionDispatcher, and re-exported iced types.
  Published to crates.io.
- **julep-renderer** -- binary crate (thin main). Creates a JulepApp with no
  extensions and runs it.

The existing `julep_core.rs` module (the `Core` struct) is renamed to
`engine.rs` to avoid collision with the crate name.

### WidgetExtension trait

Eight methods, most with defaults:

```rust
pub trait WidgetExtension: Send + Sync + 'static {
    fn type_names(&self) -> &[&str];
    fn config_key(&self) -> &str;
    fn init(&mut self, _config: &Value) {}
    fn prepare(&mut self, _node: &TreeNode, _caches: &mut ExtensionCaches,
               _theme: &Theme) {}
    fn render<'a>(&self, node: &'a TreeNode, env: &'a WidgetEnv<'a>)
        -> Element<'a, Message>;
    fn handle_event(&mut self, _node_id: &str, _family: &str,
        _data: &Value, _caches: &mut ExtensionCaches) -> EventResult {
        EventResult::PassThrough
    }
    fn handle_command(&mut self, _node_id: &str, _op: &str,
        _payload: &Value, _caches: &mut ExtensionCaches) -> Vec<OutgoingEvent> {
        vec![]
    }
    fn cleanup(&mut self, _node_id: &str, _caches: &mut ExtensionCaches) {}
}
```

- **type_names** -- node type strings this extension handles.
- **config_key** -- key used to route config from the Settings wire
  message's `extension_config` object.
- **init** -- receives config from Elixir on startup and renderer restart.
- **prepare** -- mutable phase before view. Initializes or syncs per-node
  state in ExtensionCaches. Has theme access for pre-computing
  theme-dependent values.
- **render** -- immutable phase. Builds an iced Element from a node.
  Receives a WidgetEnv with caches, images, theme, and a RenderContext
  for rendering child nodes.
- **handle_event** -- intercepts events before they reach the wire.
  Returns PassThrough, Consumed, or Observed.
- **handle_command** -- receives high-frequency data push from Elixir
  without triggering a view/diff/patch cycle.
- **cleanup** -- called when a node is removed from the tree.

### Three usage tiers through one trait

**Tier A (render-only):** Implement type_names, config_key, render. No
state, no events. Example: syntax-highlighted code view via tree-sitter.

**Tier B (wrapping iced crates):** Add prepare and handle_event. Map the
wrapped crate's messages to Message::Event via Element::map. Example:
iced_plot GPU-accelerated plotting.

**Tier C (custom Widget):** Return a custom `iced::advanced::Widget` impl
from render(). Full iced lifecycle: size(), layout(), draw(), update()
with shell.publish() and shell.capture_event(). Example: interval
timeline for distributed trace visualization.

### ExtensionDispatcher

Owns extensions and routing state. Lives on the App struct alongside
Core:

- **type_name_index** (HashMap) -- built once at construction for O(1)
  lookup. Also detects duplicate type names (panics with a clear error).
- **node_extension_map** (HashMap) -- rebuilt on each prepare walk. Maps
  node IDs to extension indices.
- **poisoned flags** -- per-extension panic flag, cleared on Snapshot.

Key methods: `prepare_all()` (walks tree, calls prepare, prunes stale
nodes), `handle_event()`, `handle_command()`, `init_all()` (routes
config via config_key), `render()` (builds WidgetEnv, delegates to
extension), `clear_poisoned()`.

### ExtensionCaches

Type-erased `HashMap<String, Box<dyn Any + Send + Sync>>` keyed by node
ID. One struct per node containing all per-node state. `canvas::Cache`
is `!Send + !Sync` (wraps RefCell) and cannot be stored here -- it
belongs in iced's widget tree state (Tag/State). Caches are cleared on
Snapshot (full tree replacement) and pruned on Patch (stale nodes get
cleanup).

### RenderContext for child rendering

A Copy struct holding shared references (caches, images, theme,
dispatcher). Extensions call `env.render_ctx.render_child(node)` to
render subtrees through the main dispatch. Avoids closure lifetime
challenges entirely.

### EventResult

Three variants: PassThrough (forward to Elixir unchanged), Consumed
(handle internally, optionally emit different events), Observed (handle
AND forward original). The distinction matters for reusability -- a
terminal extension can't predict whether consumers want keystroke events
for macro recording or accessibility.

### Data push pattern

ExtensionCommand and extension_command_batch wire messages bypass the
Elixir view/diff/patch cycle. The renderer routes commands to extensions
by node ID. Batch messages trigger one view cycle for all commands.
Essential for real-time monitoring widgets (sparklines, log viewers).

### Extension panic safety

catch_unwind at all dispatch boundaries. render() panics return a red
diagnostic placeholder. prepare/handle_event/handle_command panics
poison the extension -- subsequent calls are skipped, nodes render as
placeholders. Poisoned extensions can't receive cleanup() calls; the
dispatcher removes cache entries directly. Poisoned flags clear on
Snapshot.

### Julep.Extension behaviour (Elixir side)

```elixir
@callback native_crate() :: String.t()
@callback rust_constructor() :: String.t()
@callback type_names() :: [String.t()]
```

- **native_crate** -- path to the Rust crate relative to package root.
- **rust_constructor** -- full Rust constructor expression, pasted into
  the generated main.rs as `Box::new(<expression>)`.
- **type_names** -- enables compile-time collision detection without
  touching Rust.

Discovery scans compiled modules (both deps and consumer's own app) for
Julep.Extension implementations via module attribute introspection.

### Build system

When extensions are present, `mix julep.build` generates a Cargo
workspace in `_build/julep_renderer/` with a main.rs that registers all
extensions, then runs `cargo build --release`. Crate paths are resolved
relative to dep roots (for packages) or project root (for consumer-
authored extensions). Cache manifest tracks extension list and source
mtimes for incremental rebuilds.

### Consumer-authored extensions

Consumers can write extensions directly in their app (no separate hex
package needed). They put a Rust crate in their project's `native/`
directory and implement `Julep.Extension` in their app. The build task
discovers it alongside dep extensions.

### Render dispatch changes

The current `render()` function takes 3 parameters (node, caches,
images). Extensions add 2 more: theme (needed for palette access when
building Elements) and dispatcher (for extension routing). Built-in
types are unchanged in the match. Unknown types fall through to
`dispatcher.render()`.

### Prerequisite fixes

Before any extension code:

1. Change `OutgoingEvent.family` from `&'static str` to `String`.
   Remove `family_str_to_static()`.
2. Add a family-level catch-all to `protocol.ex` dispatch for unknown
   event families (returns `{String.to_atom(family), id, data}`).

### Extension config

Piggybacks on the existing Settings wire message via an
`extension_config` field keyed by config_key. No new message type.
Consumer sets config in application env; Runtime includes it in Settings.

## Alternatives considered

- **Dynamic loading (dlopen).** ABI stability nightmare, unsafe,
  platform-specific. iced types can't cross a C FFI boundary.
- **WASM sandbox.** Serialization boundary, performance overhead, no
  platform APIs or GPU.
- **Function registry (no trait).** Loses shared state between
  prepare/render/handle_event.
- **iced Component wrapper.** Communication back to parent is
  constrained; custom Widget is more powerful.
- **Two separate traits (simple + power).** Single trait with defaults
  achieves the same scaling without migration.
- **Per-type registration.** Makes sharing state between types harder
  (requires Arc). Internal match on type_name is mechanical boilerplate.
- **Result return from render().** Forces every simple extension to wrap
  in Ok(). Extensions should handle their own error states.

## Consequences

- Package authors can create hybrid Elixir + Rust widget packages
  following an established pattern (Rustler-like).
- The renderer remains a single statically-linked binary. No runtime
  plugins, no WASM, no shared libraries.
- Pure Elixir widget packages continue to work with prebuilt binaries.
  Rust extensions require a toolchain.
- The trait scales from trivial render-only widgets (one method) to
  full custom iced Widgets with autonomous state (all methods).
- Event interception (Consumed/Observed/PassThrough) enables wrapping
  existing iced widget crates without modifying them.
- Data push commands bypass the Elixir view cycle for high-frequency
  updates.
- Panic isolation prevents buggy extensions from crashing the renderer.
- Build-time collision detection catches conflicting type names before
  Rust compilation.
- The crate split (julep-core + julep-renderer) makes julep-core publishable
  to crates.io as an extension SDK.
- ADR 0007's Tier 2 is no longer deferred.
