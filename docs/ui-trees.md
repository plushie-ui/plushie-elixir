# UI trees

A julep UI tree is a plain Elixir map. No structs, no protocols, no macros
required.

## Node shape

Every node in the tree has this shape:

```elixir
%{
  id: "unique-id",
  type: "button",
  props: %{"label" => "Click me", "event" => "do_thing"},
  children: []
}
```

- **id** -- unique string within the tree. Used for diffing, event routing,
  and renderer-side widget state continuity (scroll position, focus, etc.).
- **type** -- string identifying the widget type. Maps directly to an iced
  widget or a composite julep widget on the renderer side.
- **props** -- string-keyed map of widget properties. Serialized as JSON.
- **children** -- ordered list of child nodes.

IDs must be stable across renders for the same logical element. If a list
item's ID changes, the renderer treats it as a removal + insertion, losing
any widget-local state (text cursor position, scroll offset).

## Building trees with Julep.UI

`Julep.UI` provides builder functions that produce these maps. The `do`
block syntax is optional sugar.

```elixir
import Julep.UI

# These are equivalent:
column(padding: 8, children: [text("hello")])

column padding: 8 do
  text("hello")
end
```

### Layout widgets

| Function | Type | Description |
|---|---|---|
| `window(id, opts)` | `window` | Top-level window container |
| `column(opts)` | `column` | Vertical flex layout |
| `row(opts)` | `row` | Horizontal flex layout |
| `container(id, opts)` | `container` | Generic box with alignment/padding |
| `scrollable(id, opts)` | `scrollable` | Scrollable region |
| `stack(opts)` | `stack` | Z-axis stacking (overlays) |
| `space(opts)` | `space` | Flexible spacer |

### Input widgets

| Function | Type | Description |
|---|---|---|
| `button(id, label, opts)` | `button` | Clickable button |
| `text_input(id, value, opts)` | `text_input` | Single-line text field |
| `checkbox(id, checked, opts)` | `checkbox` | Boolean toggle (checkbox) |
| `toggler(id, checked, opts)` | `toggler` | Boolean toggle (switch) |
| `radio(id, value, selected, opts)` | `radio` | Radio button |
| `pick_list(id, options, selected, opts)` | `pick_list` | Dropdown select |
| `combo_box(id, options, value, opts)` | `combo_box` | Searchable select |
| `slider(id, range, value, opts)` | `slider` | Horizontal slider |
| `text_editor(id, content, opts)` | `text_editor` | Multi-line text editor |

### Display widgets

| Function | Type | Description |
|---|---|---|
| `text(content, opts)` | `text` | Text label |
| `progress_bar(range, value, opts)` | `progress_bar` | Progress indicator |
| `tooltip(target, content, opts)` | `tooltip` | Hover tooltip |
| `image(id, path_or_url, opts)` | `image` | Raster image |
| `svg(id, path_or_data, opts)` | `svg` | Vector image |
| `markdown(id, content, opts)` | `markdown` | Rendered markdown |
| `rule(opts)` | `rule` | Horizontal/vertical divider |

### Composite widgets

These are higher-level patterns built from primitives on the renderer side.
They map to common desktop UI patterns.

| Function | Type | Description |
|---|---|---|
| `table(id, columns, rows, opts)` | `table` | Data table with headers |
| `tabs(id, items, active, opts)` | `tabs` | Tab bar with content switching |
| `modal(id, opts)` | `modal` | Modal overlay |
| `nav(id, items, active, opts)` | `nav` | Navigation sidebar/bar |
| `form(id, opts)` | `form` | Form container with field layout |
| `card(id, opts)` | `card` | Content card with header/body |
| `panel(id, opts)` | `panel` | Collapsible panel |
| `split_pane(id, opts)` | `split_pane` | Resizable split layout |

The composite widget list will grow based on real usage. Widgets are only
added when they represent a pattern that appears repeatedly in real apps.

## Props

Props are always string-keyed maps when serialized. The builder functions
accept keyword lists and normalize them.

```elixir
# Builder (keyword syntax):
button("save", "Save", style: :primary, padding: 8)

# Resulting node:
%{
  id: "save",
  type: "button",
  props: %{"label" => "Save", "event" => "save", "style" => "primary", "padding" => 8},
  children: []
}
```

### Common props

These props are recognized across most widget types:

- `padding` -- number or `{top, right, bottom, left}` tuple
- `spacing` -- gap between children (layout widgets)
- `width` / `height` -- `:fill`, `:shrink`, or a fixed number
- `align_x` / `align_y` -- `:start`, `:center`, `:end`
- `style` -- atom or map for widget-specific styling
- `theme` -- override theme for this subtree
- `visible` -- boolean, controls rendering

### Events

Interactive widgets emit events. The event is specified in the props:

```elixir
button("my_btn", "Click")
# Emits: {:click, "my_btn"}

text_input("name", model.name, on_submit: "save_name")
# On typing: {:input, "name", "typed value"}
# On enter:  {:submit, "name", "final value"}

checkbox("agree", model.agreed)
# Emits: {:toggle, "agree", true/false}
```

Event routing uses the node's `id` by default. Custom events can be
specified with `event` or `on_*` props.

## Tree diffing

The runtime diffs consecutive trees by walking them in parallel:

- Nodes with the same ID and type are compared for prop/children changes.
- Changed props produce a `:props` patch operation.
- Added children produce `:insert` operations.
- Removed children produce `:remove` operations.
- Changed ID or type produces a full `:replace` operation.

The diff is position-based within each parent's children list. For dynamic
lists, use stable IDs to help the differ match elements correctly. Keyed
children (via `keyed_column`/`keyed_row`) provide explicit identity for
efficient reordering.

## Inspecting trees

Since trees are plain maps, they can be inspected with standard tools:

```elixir
model = MyApp.init([])
tree = MyApp.view(model)

# Print the tree
IO.inspect(tree, pretty: true)

# Find a node
Julep.UI.find(tree, "my_button")

# Encode as JSON (what the renderer sees)
Jason.encode!(tree, pretty: true)
```

This makes debugging straightforward: you can see exactly what the renderer
will receive without running it.
