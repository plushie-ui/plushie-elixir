# Custom Widgets

As the pad has grown, the view function has gotten larger. The file list,
event log, and preview pane are each self-contained pieces of UI with their
own rendering logic. In this chapter we extract them into **custom widgets**
-- reusable modules that encapsulate UI and behaviour.

Plushie has two kinds of custom widgets: pure Elixir (compose existing
widgets or draw custom visuals with canvas and SVG) and native (Rust-backed,
for custom GPU rendering). This chapter covers pure Elixir widgets. Native
widgets get a brief section at the end, with full details in the
[Custom Widgets reference](../reference/custom-widgets.md).

## Stateless widgets

The simplest custom widget is stateless: it takes props, returns a UI tree,
and has no internal state. Events from widgets inside it pass through
transparently to the parent app.

```elixir
defmodule PlushiePad.LabeledInput do
  use Plushie.Widget

  widget :labeled_input

  prop :label, :string
  prop :value, :string
  prop :placeholder, :string, default: ""

  def view(id, props) do
    import Plushie.UI

    column id: id, spacing: 4 do
      text(props.label, size: 12)
      text_input("input", props.value, placeholder: props.placeholder)
    end
  end
end
```

`use Plushie.Widget` generates a struct, a `new/2` constructor, setter
functions, and the protocol implementation that connects it to the rendering
pipeline.

`widget :labeled_input` declares the widget's type name. This must be unique
across your application. It is used for event namespacing and protocol
dispatch.

`prop` declarations define typed properties with optional defaults. Available
types include `:string`, `:number`, `:boolean`, `:color`, `:length`,
`:padding`, `:font`, `:atom`, `:map`, `:any`, and others. See
`Plushie.Widget` for the full list.

`view/2` receives the widget ID and a props map. It returns a UI tree using
the same DSL as `view/1`. Events from widgets inside (like the `text_input`)
flow through to the parent app's `update/2` without any special handling.

Use it in a view:

```elixir
PlushiePad.LabeledInput.new("email",
  label: "Email",
  value: model.email,
  placeholder: "you@example.com"
)
```

### Applying it: extract FileList

The file list sidebar is a good candidate. It takes the files list and
active file, renders the sidebar, and events (select, delete) pass through
to the pad's `update/2`:

```elixir
defmodule PlushiePad.FileList do
  use Plushie.Widget

  widget :file_list
  prop :files, :any        # list of filenames
  prop :active_file, :any  # currently selected filename

  def view(id, props) do
    import Plushie.UI

    column id: id, width: 200, height: :fill, padding: 8, spacing: 8 do
      text("sidebar-title", "Experiments", size: 14)

      scrollable "file-scroll", height: :fill do
        keyed_column spacing: 2 do
          for file <- props.files do
            container file do
              row spacing: 4 do
                button("select", file,
                  width: :fill,
                  style: if(file == props.active_file, do: :primary, else: :text)
                )
                button("delete", "x")
              end
            end
          end
        end
      end
    end
  end
end
```

In the pad's view:

```elixir
PlushiePad.FileList.new("sidebar",
  files: model.files,
  active_file: model.active_file
)
```

The pad's `update/2` still handles the select and delete events via scoped
IDs. The widget is transparent to events.

## Stateful widgets

When a widget needs internal state that the parent app should not manage,
add `state` declarations and a three-argument `view/3`:

```elixir
defmodule PlushiePad.CollapsiblePanel do
  use Plushie.Widget

  widget :collapsible_panel, container: true

  prop :title, :string

  state expanded: true

  @impl Plushie.Widget.Handler
  def view(id, props, state) do
    import Plushie.UI

    column id: id, spacing: 4 do
      button("toggle", if(state.expanded, do: "- #{props.title}", else: "+ #{props.title}"))

      if state.expanded do
        container "content", padding: 8 do
          props.children
        end
      end
    end
  end

  @impl Plushie.Widget.Handler
  def handle_event(%Plushie.Event.WidgetEvent{type: :click, id: "toggle"}, state) do
    {:update_state, %{state | expanded: not state.expanded}}
  end

  def handle_event(_event, _state), do: :ignored
end
```

`state expanded: true` declares internal state with a default value. The
runtime manages this state. It persists across re-renders as long as the
widget remains in the tree.

`view/3` receives the ID, props, and current state.

`container: true` on the widget declaration allows the widget to accept
children via `props.children`.

## Handling events

The `handle_event/2` callback intercepts events before they reach the parent
app. All clauses must return one of:

| Return value | Effect |
|---|---|
| `{:emit, family, data}` | Emit a new event to the parent. Original is replaced. |
| `{:emit, family, data, new_state}` | Emit to parent and update internal state. |
| `{:update_state, new_state}` | Update internal state. No event reaches the parent. |
| `:consumed` | Suppress the event. Nothing reaches the parent. |
| `:ignored` | Pass through. The event continues to the parent unchanged. |

Events walk up the widget scope chain. If a widget returns `:ignored`, the
next widget handler in the chain gets a chance. If no handler captures the
event, it reaches `update/2`.

### Applying it: extract EventLog

The event log can track its own expanded/collapsed state:

```elixir
defmodule PlushiePad.EventLog do
  use Plushie.Widget

  widget :event_log

  prop :events, :any  # list of event description strings

  state expanded: true

  @impl Plushie.Widget.Handler
  def view(id, props, state) do
    import Plushie.UI

    column id: id, spacing: 4 do
      row spacing: 8 do
        button("toggle-log", if(state.expanded, do: "Hide Log", else: "Show Log"))
        text("count", "#{length(props.events)} events", size: 12)
      end

      if state.expanded do
        scrollable "log-scroll", height: 120 do
          column spacing: 2, padding: 4 do
            for {entry, i} <- Enum.with_index(props.events) do
              text("log-#{i}", entry, size: 12, font: :monospace)
            end
          end
        end
      end
    end
  end

  @impl Plushie.Widget.Handler
  def handle_event(%Plushie.Event.WidgetEvent{type: :click, id: "toggle-log"}, state) do
    {:update_state, %{state | expanded: not state.expanded}}
  end

  def handle_event(_event, _state), do: :ignored
end
```

The toggle button updates the widget's internal state. All other events
(from the log entries, if any were interactive) pass through via `:ignored`.

## Declaring events

When a widget should emit semantic events to the parent, declare them with
`event`:

```elixir
defmodule PlushiePad.RatingWidget do
  use Plushie.Widget

  widget :rating

  prop :value, :number, default: 0

  event :change, value: :number

  @impl Plushie.Widget.Handler
  def view(id, props, _state) do
    import Plushie.UI

    row id: id, spacing: 4 do
      for i <- 1..5 do
        button("star-#{i}", if(i <= props.value, do: "★", else: "☆"))
      end
    end
  end

  @impl Plushie.Widget.Handler
  def handle_event(%Plushie.Event.WidgetEvent{type: :click, id: "star-" <> n}, _state) do
    {:emit, :change, String.to_integer(n)}
  end

  def handle_event(_event, _state), do: :ignored
end
```

The `event :change, value: :number` declaration tells the framework that
this widget emits `:change` events with a numeric value. In the parent app,
these arrive as:

```elixir
%WidgetEvent{type: {:rating, :change}, id: "my-rating", value: 3}
```

Custom widget event types are tuples: `{widget_type, event_name}`. This
distinguishes them from built-in events.

For events with multiple fields, use `data:` instead of `value:`:

```elixir
event :change, data: [hue: :number, saturation: :number, value: :number]
```

These arrive in `WidgetEvent.data` as an atom-keyed map.

## Widget subscriptions

Widgets can declare their own subscriptions via the optional `subscribe/2`
callback:

```elixir
@impl Plushie.Widget.Handler
def subscribe(_props, state) do
  if state.animating do
    [Plushie.Subscription.every(16, :animate)]
  end
end
```

Widget subscriptions are automatically namespaced per instance. Timer events
are routed through the widget's `handle_event/2`, not the app's `update/2`.
Multiple instances of the same widget each get independent subscriptions.

## Canvas-based widgets

A widget's `view/2` can return a canvas instead of layout widgets:

```elixir
defmodule PlushiePad.Gauge do
  use Plushie.Widget

  widget :gauge

  prop :value, :number, default: 0
  prop :max, :number, default: 100

  @impl Plushie.Widget.Handler
  def view(id, props, _state) do
    import Plushie.UI

    pct = min(props.value / props.max, 1.0)
    angle = pct * :math.pi()

    canvas id, width: 120, height: 70 do
      layer "gauge" do
        # Background arc
        path([arc(60, 60, 50, :math.pi(), 0)],
          stroke: stroke("#ddd", 8, cap: :round)
        )
        # Value arc
        path([arc(60, 60, 50, :math.pi(), :math.pi() + angle)],
          stroke: stroke("#3b82f6", 8, cap: :round)
        )
        # Value text
        text(40, 55, "#{round(pct * 100)}%", fill: "#333", size: 16)
      end
    end
  end
end
```

Canvas-based widgets with interactivity combine `handle_event/2` with
canvas events (`:canvas_press`, `:canvas_element_enter`, etc.) to build
rich custom controls like colour pickers, drawing tools, and data
visualisations. You can also embed SVG content in canvas layers (as
shown in [chapter 12](12-canvas.md)). Design your visuals in a vector
editor and use them as interactive widget elements.

## The widget lifecycle

Understanding the lifecycle helps when debugging:

1. Your view calls `MyWidget.new(id, opts)`, which returns a widget struct.
2. During tree normalization, the struct is converted to a placeholder node
   tagged with the widget module and props.
3. The runtime detects the placeholder, looks up stored state (or uses
   initial defaults for new widgets), and calls `view/3`.
4. The rendered output replaces the placeholder in the final tree.
5. Widget metadata (module, state, event handlers) is attached to the
   node's `:meta` field.
6. The runtime derives a handler registry from the tree for event dispatch.

There are no explicit mount or unmount callbacks. **Tree presence is the
lifecycle.** When a widget appears in the tree, it is "mounted" with initial
state. When it disappears, its state is cleaned up. This is why widget IDs
must be stable. A changing ID looks like a removal and re-creation.

## Native widgets

When you need rendering capabilities beyond what built-in widgets offer --
custom GPU drawing, new input types, or performance-critical visuals, you
can build a **native widget** backed by Rust:

```elixir
defmodule MyApp.Gauge do
  use Plushie.Widget, :native_widget

  widget :gauge
  prop :value, :number
  rust_crate "path/to/gauge_crate"
  rust_constructor "gauge::new()"
end
```

On the Rust side, you implement the `WidgetExtension` trait with `render()`,
and optionally `init()`, `prepare()`, `handle_event()`, and `cleanup()`.

`mix plushie.build` auto-detects native widgets via protocol consolidation,
generates a Cargo workspace that includes them, and builds the renderer
binary with your widgets registered.

Native widgets are an escape hatch for when pure Elixir composition is not
enough. Most apps will never need them. See the
[Custom Widgets reference](../reference/custom-widgets.md) for the full Rust
integration guide.

## Verify it

Test the EventLog widget using `Plushie.Test.WidgetCase`:

```elixir
defmodule PlushiePad.EventLogTest do
  use Plushie.Test.WidgetCase, widget: PlushiePad.EventLog

  setup do
    init_widget("log", events: ["click on btn", "input on name"])
  end

  test "shows event entries" do
    element = find!({:text, "click on btn"})
    assert element.type == "text"
  end
end
```

`WidgetCase` hosts a single widget in a test harness. The `init_widget/2`
call creates the widget with the given props. This is covered in detail in
[chapter 15](15-testing.md).

## Try it

Build custom widgets in your pad experiments:

- Start with a stateless widget that composes a label and an input. Use it
  in another experiment.
- Add `state` and `handle_event/2` to make a collapsible section.
- Declare a custom event and match on the `{widget_type, :event_name}` tuple
  in the parent experiment.
- Build a canvas-based widget: a simple progress ring, a mini sparkline, or
  a colour swatch.
- Try a widget with `subscribe/2` that animates on a timer.

In the next chapter, we will enhance the pad with state management helpers
for undo, search, selection, and navigation.

---

Next: [State Management](14-state-management.md)
