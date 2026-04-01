# Custom Widgets Reference

This page covers the widget macro API, handler protocol, and native widget
integration. For a narrative introduction, see the
[Custom Widgets guide](../guides/13-custom-widgets.md).

## Widget macro API

See `Plushie.Widget` for the full module docs with examples.

### Declarations

| Macro | Purpose | Example |
|---|---|---|
| `widget/2` | Type name and options | `widget :my_widget` or `widget :my_widget, container: true` |
| `prop/3` | Typed property | `prop :label, :string, default: "Hello"` |
| `event/2` | Event declaration | `event :change, value: :number` |
| `state/1` | Internal state fields | `state hover: nil, count: 0` |
| `command/2` | Widget command (native) | `command :reset, value: :number` |
| `rust_crate/1` | Rust crate path (native) | `rust_crate "path/to/crate"` |
| `rust_constructor/1` | Rust constructor (native) | `rust_constructor "gauge::new()"` |

### Prop types

`:string`, `:number`, `:boolean`, `:color`, `:length`, `:padding`,
`:alignment`, `:style`, `:font`, `:atom`, `:map`, `:any`.

### Event routing

- `event :name, value: :type` -- scalar, delivered in `WidgetEvent.value`
- `event :name, data: [field: :type, ...]` -- map, delivered in `WidgetEvent.data`

Custom events appear in `WidgetEvent.type` as `{module_type, :event_name}`
tuples (e.g., `{:my_widget, :change}`). Built-in event names (`:click`,
`:toggle`, etc.) use the standard spec automatically.

## Generated code

`use Plushie.Widget` generates:

- `defstruct` with `:id`, all declared props, `:a11y`, `:event_rate`
  (plus `:children` if `container: true`)
- `@type t` and `@type option`
- `new/2` constructor
- Per-prop setter functions (for pipeline style)
- `Plushie.Widget.WidgetProtocol` implementation
- `Plushie.Widget.Handler` behaviour (if stateful)
- `__initial_state__/0`, `__option_keys__/0`, `__option_types__/0`

## Handler protocol

See `Plushie.Widget.Handler` for callback specs.

### Callbacks

| Callback | Signature | Required? |
|---|---|---|
| `render/2` | `(id, props) -> tree` | Yes (stateless) |
| `render/3` | `(id, props, state) -> tree` | Yes (stateful) |
| `handle_event/2` | `(event, state) -> result` | No (default depends on declarations) |
| `subscribe/2` | `(props, state) -> [sub]` | No |

### handle_event/2 return values

| Return | Effect |
|---|---|
| `{:emit, family, data}` | Emit event to parent. Original replaced. |
| `{:emit, family, data, new_state}` | Emit and update state. |
| `{:update_state, new_state}` | Update state. No event to parent. |
| `:consumed` | Suppress the event entirely. |
| `:ignored` | Pass through unchanged. Next handler in scope chain gets it. |

Default behaviour when `handle_event/2` is not defined:
- If the widget declares events: `:consumed` (opaque by default)
- If no events declared: `:ignored` (transparent by default)

## Widget tiers

Widgets are classified by capabilities. The macro detects which callbacks
and declarations are present and generates the appropriate code.

| Tier | Declarations | Behaviour |
|---|---|---|
| Render-only | `widget`, `prop`, `render/2` | Transparent to events. No state. |
| Interactive | + `state`, `handle_event/2` | Captures and transforms events. Has state. |
| Full lifecycle | + `subscribe/2`, `event` | Events, state, subscriptions. |

## Event flow through widgets

Events walk the scope chain from innermost to outermost:

1. Event arrives with `id` and reversed `scope` list.
2. Runtime builds handler chain from the scope.
3. Each handler's `handle_event/2` is called in order.
4. `{:emit, ...}` replaces the event and continues to the next handler.
5. `:consumed` stops propagation.
6. `:ignored` passes the original event to the next handler.
7. If no handler captures, the event reaches `c:Plushie.App.update/2`.

Canvas-internal events (`:canvas_element_*`) that are not intercepted by any
handler are auto-consumed by the runtime and never reach `update/2`.

## Placeholder-to-rendered pipeline

1. `MyWidget.new(id, opts)` returns a widget struct.
2. `Plushie.Widget.to_node/1` (via `WidgetProtocol`) converts to a
   `widget_placeholder` node with metadata tags.
3. During `Plushie.Tree.normalize/1`, placeholders are detected.
4. State is looked up (from process dictionary, set by the runtime) or
   initialized from `__initial_state__/0`.
5. `render/3` is called with the ID, props, and state.
6. The rendered output replaces the placeholder and is normalized
   recursively.
7. Widget metadata (module, state, event specs) is attached to the final
   node's `:meta` field.

Tree presence is the lifecycle. No mount/unmount callbacks. When a widget
appears in the tree, state is initialized. When it disappears, state is
cleaned up.

## Native widget integration

Native widgets are backed by Rust. Use `use Plushie.Widget, :native_widget`.

### Elixir side

```elixir
defmodule MyApp.Gauge do
  use Plushie.Widget, :native_widget

  widget :gauge
  prop :value, :number
  rust_crate "path/to/gauge_crate"
  rust_constructor "gauge::new()"
  event :value_changed, data: [value: :number]
  command :set_value, value: :number
end
```

### Rust side

Implement the `WidgetExtension` trait from `plushie_ext::prelude::*`:

| Method | Phase | Required? |
|---|---|---|
| `type_names()` | Registration | Yes |
| `config_key()` | Registration | Yes |
| `render()` | View (immutable) | Yes |
| `init()` | Startup | No |
| `prepare()` | Pre-view (mutable) | No |
| `handle_event()` | Event dispatch | No |
| `handle_command()` | Command dispatch | No |
| `cleanup()` | Node removal | No |

### Panic isolation

The renderer wraps all mutable extension methods in `catch_unwind`. Three
consecutive render panics auto-poison the extension (red placeholder shown).
Poisoned state is cleared on the next full snapshot (triggered by tree
changes or renderer restart).

### Build system

`mix plushie.build` auto-detects native widgets via `Plushie.Widget.WidgetProtocol`
consolidation. It generates a Cargo workspace with a `main.rs` that
registers each native widget.

When building with a local source checkout (`PLUSHIE_SOURCE_PATH`), the
workspace adds `[patch.crates-io]` to redirect crate dependencies to local
paths.

## See also

- `Plushie.Widget` -- macro API docs
- `Plushie.Widget.Handler` -- callback specs
- [Custom Widgets guide](../guides/13-custom-widgets.md) -- step-by-step tutorial
