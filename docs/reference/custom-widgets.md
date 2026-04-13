# Custom Widgets

Plushie has two kinds of custom widgets: **pure Elixir** (compose
existing widgets or draw with canvas) and **native** (Rust-backed, for
custom GPU rendering). This reference covers the macro API, handler
protocol, event flow, state management, testing, and native widget
integration.

For a narrative introduction, see the
[Custom Widgets guide](../guides/13-custom-widgets.md).

## Widget macro API

`use Plushie.Widget` generates a struct, constructor, setters,
protocol implementations, and (for stateful widgets) the Handler
behaviour. The macro detects which callbacks and declarations are
present and generates the appropriate code.

### Declarations

| Macro | Purpose | Example |
|---|---|---|
| `widget/2` | Type name and options | `widget :gauge` or `widget :gauge, container: true` |
| `field/3` | Typed property | `field :label, :string, default: "Hello"` |
| `event/2` | Event declaration | `event :change, value: :float` |
| `state/1` | Internal state fields | `state hover: nil, count: 0` |
| `command/2` | Widget command (native) | `command :set_value, value: :float` |
| `rust_crate/1` | Rust crate path (native) | `rust_crate "path/to/crate"` |
| `rust_constructor/1` | Rust constructor (native) | `rust_constructor "gauge::new()"` |

### Widget type name

`widget :my_widget` declares the type name. This name appears in
custom event tuples (`{:my_widget, :change}`) and is used for protocol
dispatch. Choose a unique name across your application. Duplicate
type names are not validated at compile time and will cause event
routing confusion.

### Field types

Primitive atom shortcuts: `:integer`, `:float`, `:string`, `:boolean`,
`:atom`, `:any`, `:map`.

Domain types use their full module name (e.g. `Plushie.Type.Color`,
`Plushie.Type.Length`, `Plushie.Type.Font`).

Composite types can be expressed inline as tuples:

```elixir
field :tags, {:list, :string}
field :mode, {:enum, [:read, :write]}
field :scores, {:map, {:string, :integer}}
field :range, {:tuple, [:float, :float]}
```

Any module that implements `Plushie.Type` can be used as a field type.
See the [Custom Types reference](custom-types.md) for building your
own type modules.

### Field options

Every `field` declaration accepts the type as the second argument and
an optional keyword list of options:

```elixir
field :name, :string, default: "untitled", doc: "Display name."
```

| Option | Type | Purpose |
|--------|------|---------|
| `:doc` | `String.t()` | Description for setter `@doc` and the auto-generated Props table in `@moduledoc`. Always provide this for public-facing widgets. |
| `:default` | `term()` | Default value in the struct. When present, the field is not required at construction time. |
| `:option` | `boolean()` | When `false`, excludes the field from the keyword options API (`with_options/2`, `__field_keys__/0`). Use for positional-only fields. Default: `true`. |
| `:wire_name` | `atom()` | Override the prop key sent over the wire. Use when the Elixir field name differs from the renderer's expected key (e.g., `field :is_toggled, :boolean, wire_name: :checked`). |
| `:required` | `boolean()` | Explicit required flag. Positional fields without a default are required automatically. |
| `:cast` | `(term() -> term())` | Custom cast function for the setter, bypassing the type's `cast/1`. Use for fields that need coercion beyond what the type provides. |

Type-specific constraints (like `:min`, `:max`, `:min_length`) are
passed through to the type module. See
[Custom Types: Field constraints](custom-types.md#field-constraints).

### Writing good field docs

The `:doc` option is the primary way to document widget props. It
appears in two places:

1. The setter's `@doc` (visible in `h MyWidget.spacing` in iex and
   in per-function hexdocs)
2. The auto-generated Props table in the widget's `@moduledoc`
   (visible at the top of the module's hexdocs page)

Write concise, specific descriptions:

```elixir
# Good: specific, actionable
field :spacing, :float, doc: "Space between checkbox and label in pixels."
field :style, Plushie.Type.Style, doc: "Named preset (`:primary`, `:danger`) or custom `StyleMap`."

# Bad: restates the name
field :spacing, :float, doc: "The spacing."
field :style, Plushie.Type.Style, doc: "The style."
```

Include the unit (pixels, milliseconds) when applicable. Link to
related types or docs with backtick references. Mention the default
behavior when nil ("Default: fill", "Default: shrink").

Fields without `:doc` get a generic "Sets the `:name` field."
message. For internal or experimental widgets this is fine, but
published widgets should document every field.

### Reserved field names

The following names are reserved and cannot be used in `field`
declarations. The macro raises a compile error if you try:

| Name | Reason |
|------|--------|
| `:id` | Always the first positional argument to `new/N`. Present on every widget struct. |
| `:type` | Used internally for the widget's type string on the wire. |
| `:children` | Managed by the container system (`container: true`). |
| `:a11y` | Auto-generated accessibility field with special cast (`A11y.cast/1`). Set via `a11y: %{role: :button}` in options, not as a declared field. |
| `:event_rate` | Auto-generated rate-limiting field. Set via `event_rate: 60` in options. |
| `:do` | Reserved by Elixir for block syntax. |

If you need to send a prop with one of these names over the wire,
use `:wire_name` on a differently-named field:

```elixir
field :widget_type, :string, wire_name: :type, doc: "Custom type tag."
```

### Container widgets

`widget :my_widget, container: true` adds a `:children` field to the
struct and configures `new/2` to accept `:do` blocks. Children are
available in `view/3` via `props.children`:

```elixir
def view(id, props, state) do
  import Plushie.UI
  column id: id do
    props.children
  end
end
```

Note: `container: true` does not auto-generate `push/2` or `extend/2`
methods. If you need the pipeline API for your container widget, define
them manually:

```elixir
def push(%__MODULE__{} = w, child), do: %{w | children: [child | w.children]}
def extend(%__MODULE__{} = w, children), do: %{w | children: w.children ++ children}
```

### Event routing

- `event :name, value: :type` - scalar payload, delivered in
  `WidgetEvent.value`
- `event :name, fields: [field: :type, ...]` - structured payload,
  delivered in `WidgetEvent.value` as an atom-keyed map

Custom events appear in `WidgetEvent.type` as `{widget_type, :event_name}`
tuples (e.g. `{:my_widget, :change}`). Built-in event names (`:click`,
`:toggle`, etc.) use the standard spec automatically.

## Generated code

`use Plushie.Widget` generates:

- `defstruct` with `:id`, all declared props, `:a11y`, `:event_rate`
  (plus `:children` if `container: true`)
- `@type t` and `@type option`
- `new/2` constructor with prop validation
- Per-prop setter functions (for pipeline style)
- `with_options/2` for applying keyword options
- `Plushie.Tree.Node` implementation
- `Plushie.Widget.Handler` behaviour (if `view/2` or `view/3` defined)
- `__initial_state__/0` - returns the default state map
- `__widget__?/0` - returns `true` (marker function)
- `__field_keys__/0` - valid option names for compile-time validation
- `__field_types__/0` - nested struct types for do-block syntax

For native widgets, additionally generates:
- `native_crate/0`, `rust_constructor/0`, `type_names/0`
- Per-command functions (e.g. `set_value/2` for `command :set_value`)

## Handler protocol

`Plushie.Widget.Handler`

### Callbacks

| Callback | Signature | Required? |
|---|---|---|
| `view/2` | `(id, props) -> tree` | Yes (stateless) |
| `view/3` | `(id, props, state) -> tree` | Yes (stateful) |
| `handle_event/2` | `(event, state) -> result` | No |
| `subscribe/2` | `(props, state) -> [sub]` | No |

If only `view/2` is defined (no state), the macro generates a `view/3`
adapter that ignores the state argument. This means the normalisation
pipeline always calls `view/3` uniformly.

### handle_event/2 return values

All clauses must return one of:

| Return | Effect |
|---|---|
| `{:emit, family, data}` | Emit event to parent. Original replaced. |
| `{:emit, family, data, new_state}` | Emit and update state. |
| `{:update_state, new_state}` | Update state. No event to parent. |
| `:consumed` | Suppress the event entirely. |
| `:ignored` | Pass through unchanged. Next handler in scope chain gets it. |

**Default behaviour** when `handle_event/2` is not defined:
- If the widget declares events: `:consumed` (opaque by default)
- If no events declared: `:ignored` (transparent by default)

## Widget tiers

| Tier | Declarations | Behaviour |
|---|---|---|
| Stateless | `widget`, `field`, `view/2` | Transparent to events. No state. |
| Stateful | + `state`, `view/3`, `handle_event/2` | Captures and transforms events. Has state. |
| Full lifecycle | + `subscribe/2`, `event` | Events, state, subscriptions. |

The macro detects which tier applies at compile time based on what
callbacks and declarations are present.

## Event flow

Events walk the scope chain from innermost to outermost:

1. Event arrives with `id` and reversed `scope` list.
2. Runtime builds handler chain from the scope using the widget handler
   registry.
3. Each handler's `handle_event/2` is called in order (innermost first).
4. `{:emit, ...}` replaces the event and continues to the next handler.
5. `:consumed` stops propagation.
6. `:ignored` passes the original event to the next handler.
7. If no handler captures, the event reaches `update/2`.

Canvas background events use the unified pointer types (`:press`,
`:release`, `:move`, `:scroll`) and are delivered to `update/2`
like any other event. They are not auto-consumed.

## Widget-scoped subscriptions

Widgets can declare their own subscriptions via `subscribe/2`. These
are automatically namespaced per widget instance to prevent collisions
with app subscriptions or other widget instances:

```elixir
@impl Plushie.Widget.Handler
def subscribe(_props, state) do
  if state.animating do
    [Plushie.Subscription.every(16, :animate)]
  end
end
```

The runtime wraps each subscription tag in a tuple:
`{:__widget__, window_id, widget_id, inner_tag}`. Timer events matching
this structure are intercepted and routed through the widget's
`handle_event/2` instead of reaching `update/2`. The inner tag (e.g.
`:animate`) is what the widget sees in the event.

Multiple instances of the same widget each get independent subscriptions.
If instance A is animating and instance B is not, only A receives timer
events.

## State management

### State lifecycle

Widget state follows tree presence:

- **Appear**: widget enters the tree -> state initialised from
  `__initial_state__/0`
- **Update**: `handle_event/2` returns `{:update_state, new_state}` or
  `{:emit, ..., new_state}` -> state updated
- **Re-render**: `view/3` called with current state on each update cycle
- **Disappear**: widget leaves the tree -> state cleaned up

There are no explicit mount or unmount callbacks. If the widget's ID
changes between renders, the runtime sees it as a removal and
re-creation, resetting state.

### State storage

The runtime maintains widget state in the handler registry, keyed by
canonical scoped ID (e.g., `"main#form/picker"`). During the render
cycle, states are passed to `Plushie.Tree.normalize/2` via the
normalize context map, where they are looked up when widget
placeholders are encountered. New widgets (no stored state) fall back
to `__initial_state__/0`.

## Placeholder-to-rendered pipeline

1. `MyWidget.new(id, opts)` returns a widget struct.
2. `Plushie.Widget.to_node/1` (via `Tree.Node`) converts to a
   `widget_placeholder` node tagged with the module and props.
3. During `Plushie.Tree.normalize/1`, placeholders are detected.
4. State is looked up from the registry or initialised from
   `__initial_state__/0`.
5. `view/3` is called with the ID, props, and state.
6. The rendered output replaces the placeholder and is normalised
   recursively.
7. Widget metadata (module, state, event specs) is accumulated in the
   `NormalizeCtx` during normalization. Tree nodes are pure wire
   representations and do not carry metadata.
8. The runtime derives the handler registry from the tree for O(1)
   event dispatch lookups.

Custom widget IDs are **transparent to scoping**. They do not create
scope boundaries. Children rendered by a widget inherit the parent
container's scope, not the widget's ID. See
[Scoped IDs](scoped-ids.md#custom-widgets-are-transparent).

## Testing custom widgets

`Plushie.Test.WidgetCase` hosts a single widget in a test harness
connected to a real renderer:

```elixir
defmodule MyApp.GaugeTest do
  use Plushie.Test.WidgetCase, widget: MyApp.Gauge

  setup do
    init_widget("gauge", value: 50, max: 100)
  end

  test "displays initial value" do
    assert_text("#gauge/value", "50%")
  end

  test "emits change event on click" do
    click("#gauge/increment")
    assert last_event().type == {:gauge, :change}
  end
end
```

`init_widget/2` starts the widget with the given ID and props. The
harness wraps it in a window and records emitted events.

### WidgetCase helpers

| Helper | Purpose |
|---|---|
| `last_event/0` | Most recently emitted `WidgetEvent`, or nil |
| `events/0` | All emitted events, newest first |

All standard test helpers (`click/1`, `find!/1`, `assert_text/2`,
`model/0`, etc.) are also available. See the
[Testing reference](testing.md) for the full API.

## Native widget integration

When you need rendering capabilities beyond what built-in widgets and
canvas offer (custom GPU drawing, new input types, performance-critical
visuals), build a **native widget** backed by Rust.

### Elixir side

```elixir
defmodule MyApp.Gauge do
  use Plushie.Widget, :native_widget

  widget :gauge
  field :value, :float
  rust_crate "path/to/gauge_crate"
  rust_constructor "gauge::new()"
  event :value_changed, fields: [value: :float]

  # No payload
  command :reset

  # Typed scalar value
  command :set_value, value: :float

  # Structured fields (required fields become positional args)
  command :set_range, fields: [min: :float, max: :float]

  # Block form (optional fields become keyword opts)
  command :configure do
    field :min, :float
    field :max, :float
    field :step, :float, required: false
  end
end
```

The `command` macro supports the same forms as `event`:

- `command :reset` (no payload)
- `command :set_value, value: :float` (typed scalar value)
- `command :set_range, fields: [min: :float, max: :float]` (structured fields)
- Block form with `field` declarations (supports `required: false` for optional fields)

Required fields become positional arguments in the generated function.
Optional fields become keyword options. Values go through
`Plushie.Type.encode_value/1` before hitting the wire.

Commands use the unified wire format matching events:

```json
{"type": "command", "id": "gauge", "family": "set_value", "value": 72.0}
```

The `command` macro also works in standalone modules via
`use Plushie.Command` (without `use Plushie.Widget`). See the
[commands guide](commands.md#custom-command-modules) for details.

### Rust side

Implement the `PlushieWidget` trait from `plushie_widget_sdk::prelude::*`:

| Method | Phase | Required? |
|---|---|---|
| `type_names()` | Registration | Yes |
| `namespace()` | Registration | No |
| `render()` | View (immutable) | Yes |
| `clone_for_session()` | Multiplexing | Yes |
| `init()` | Startup | No |
| `prepare()` | Pre-view (mutable) | No |
| `handle_message()` | Message dispatch | No |
| `handle_widget_op()` | Command dispatch (receives the `family` and `value` from the wire) | No |
| `cleanup()` | Node removal | No |
| `infer_a11y()` | Accessibility | No |

### Panic isolation

The renderer wraps all mutable widget methods in `catch_unwind`.
Three consecutive render panics auto-poison the widget (red
placeholder shown). Poisoned state is cleared on the next full snapshot
(triggered by tree changes or renderer restart).

### Build system

`mix plushie.build` auto-detects native widgets via
`Plushie.Tree.Node` consolidation. It generates a Cargo
workspace with a `main.rs` that registers each native widget via its
`rust_constructor` expression. No configuration needed. Add a native
widget to your dependencies and it appears in the next build.

When removing a native widget, run `mix clean` to clear stale BEAM
files. Protocol consolidation reads compiled `.beam` files, so leftover
files from the removed widget will cause phantom detection until
cleaned out.

See the [Mix Tasks reference](mix-tasks.md#plushiebuild) for build
details.

## Table element composition

Tables use a structural composition model via `Plushie.Table.Element`,
`Plushie.Table.Row`, and `Plushie.Table.Cell`. Rows are children of
the table widget (not data props), which enables LIS-based wire
diffing for efficient updates when rows change order.

```elixir
table "users", columns: columns do
  for user <- model.users do
    table_row user.id do
      cell "name", text(user.name)
      cell "email", text(user.email)
    end
  end
end
```

`Plushie.Table.Element` is the table-domain counterpart of
`Plushie.Canvas.Element`. It shares the same `Plushie.DSL.Element`
infrastructure and generates the same set of functions (`new/1`,
`new/2`, setters, `build/1`, `Plushie.Tree.Node` impl). The
separate module provides domain-appropriate naming.

## See also

- `Plushie.Widget` - macro API docs and examples
- `Plushie.Widget.Handler` - callback specs
- `Plushie.Type` - type behaviour and resolution
- [Custom Widgets guide](../guides/13-custom-widgets.md) - step-by-step
  tutorial
- [Scoped IDs reference](scoped-ids.md) - widget scope transparency
- [Testing reference](testing.md) - full test helper API
- [Rust Widget Guide](https://github.com/plushie-ui/plushie-rust/blob/main/docs/core-widget-guide.md) - `PlushieWidget` trait and Rust-side lifecycle
