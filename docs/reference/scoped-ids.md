# Scoped IDs

Named containers automatically scope their children's IDs, producing
unique hierarchical paths without manual prefixing. This is how you
distinguish "the delete button in file A" from "the delete button in
file B" because the container's ID becomes part of the path.

## Scoping rules

| Node type | Creates scope? | Notes |
|---|---|---|
| Named container (explicit ID) | Yes | ID pushed onto scope chain |
| Auto-ID container (`auto:` prefix) | No | Transparent, no scope effect |
| Window node (`type: "window"`) | No | Namespace boundary, not scope |
| Custom widget | No | Widget IDs are transparent to scoping |

User-provided IDs must not contain `/`. The slash is reserved for the
scope separator; `Plushie.Tree.normalize/1` raises `ArgumentError` on
violation.

## ID resolution

During normalisation, each named container pushes its ID onto the
scope chain. Descendant IDs are prefixed with the full scope path,
joined by `/`:

```
sidebar (container)       ->  "sidebar"
  form (container)        ->  "sidebar/form"
    email (text_input)    ->  "sidebar/form/email"
    save (button)         ->  "sidebar/form/save"
```

Resolution is recursive; nesting depth is unlimited. Internally, the
scope is tracked as a forward-order string (e.g. `"sidebar/form"`) and
prepended to each child's ID during the normalisation pass.

### Auto-ID containers are transparent

Layout containers with auto-generated IDs (`column`, `row`, `stack`,
etc.) do not create scopes. This means you can wrap content in layout
containers freely without affecting the ID hierarchy:

```elixir
container "form" do
  column spacing: 8 do          # auto-ID, no scope effect
    text_input("email", "")     # scoped as "form/email", not "form/auto:.../email"
    button("save", "Save")      # scoped as "form/save"
  end
end
```

This is intentional. Intermediate layout containers exist for visual
arrangement, not semantic grouping. Only named containers that you give
an explicit ID create scope boundaries.

### Custom widgets are transparent

Custom widget IDs do **not** create scopes. When a custom widget's
`view/2` or `view/3` renders children, those children inherit the
**parent's** scope, not the widget's:

```elixir
# If MyWidget has ID "my-widget" and renders a button "save":
container "form" do
  MyWidget.new("my-widget", label: "Submit")
end

# The button inside MyWidget gets scoped as "form/save"
# NOT "form/my-widget/save"
```

This means custom widgets are invisible to the scope chain. Events
from widgets inside a custom widget carry the enclosing container's
scope, not the custom widget's ID. The widget's `handle_event/2`
callback intercepts events before they reach `update/2`, providing
the encapsulation layer instead.

## Duplicate ID detection

Normalisation detects duplicate sibling IDs (two children of the same
parent with the same ID) and raises `ArgumentError`:

```
** (ArgumentError) duplicate sibling IDs detected during normalize: ["save"]
```

Detection is **sibling-scoped**. The same local ID can exist in
different scopes safely. The scope prefix ensures global uniqueness:

```elixir
container "form-a" do
  button("save", "Save")   # "form-a/save"
end

container "form-b" do
  button("save", "Save")   # "form-b/save", no conflict
end
```

## Dynamic IDs

IDs can be any string expression, including dynamic values from your
model. This is how you scope list items:

```elixir
for file <- model.files do
  container file do
    button("select", file)
    button("delete", "x")
  end
end
```

Each file becomes a scope. The delete button for `"hello.ex"` gets
the wire ID `"hello.ex/delete"`. In the event, you extract the
filename from the scope:

```elixir
def update(model, %WidgetEvent{type: :click, id: "delete", scope: [file | _]}) do
  delete_file(file)
end
```

Dynamic IDs follow the same rules as static IDs: no `/` characters,
and no duplicates among siblings.

## Event scope field

When the renderer emits a widget event, the wire ID is the full
scoped path (e.g. `"sidebar/form/save"`). The SDK splits it into
`id` (local) and `scope` (reversed ancestor chain, nearest parent
first):

```elixir
%WidgetEvent{type: :click, id: "save", scope: ["form", "sidebar"]}
```

The scope is reversed so you can pattern match on the immediate parent
with `[parent | _]` without knowing the full ancestry.

### Pattern matching examples

```elixir
# Local ID only (any scope)
def update(model, %WidgetEvent{type: :click, id: "save"}), do: ...

# Immediate parent match
def update(model, %WidgetEvent{type: :click, id: "save", scope: ["form" | _]}), do: ...

# Bind dynamic parent (list items)
def update(model, %WidgetEvent{type: :toggle, id: "done", scope: [item_id | _]}), do: ...

# Exact depth (only one ancestor)
def update(model, %WidgetEvent{id: "query", scope: ["search"]}), do: ...

# Unscoped widget (top-level)
def update(model, %WidgetEvent{id: "save", scope: []}), do: ...
```

Only `Plushie.Event.WidgetEvent` carries scope. Subscription events
(`KeyEvent`, `MouseEvent`, `TouchEvent`, `ImeEvent`, `ModifiersEvent`)
are global and unscoped.

## Path reconstruction

`Plushie.Event.target/1` reconstructs the full forward-slash path from
an event's `id` and `scope` fields:

```elixir
Plushie.Event.target(%WidgetEvent{id: "save", scope: ["form", "sidebar"]})
# => "sidebar/form/save"
```

## Canvas element scoping

Canvas elements participate in the same mechanism. The canvas widget's
ID creates a scope, and interactive group IDs within it are scoped
under it:

```
canvas "drawing"              ->  "drawing"
  group "handle" ...          ->  "drawing/handle"
```

Canvas element clicks are regular `:click` events with the canvas ID in
scope:

```elixir
%WidgetEvent{type: :click, id: "handle", scope: ["drawing"]}
```

## Command paths

Commands that target widgets by path use the forward-slash scoped
format:

```elixir
Command.focus("form/email")
Command.scroll_to("sidebar/list", 0)
```

## Multi-window scoping

Scopes do not cross window boundaries. Each window creates a separate
namespace. The widget handler registry keys entries by
`{window_id, scoped_id}`. A widget with scoped ID `"form/save"` in
window `"main"` is a different registry entry from `"form/save"` in
window `"settings"`.

Events include `window_id` so the runtime dispatches to the correct
window's handler chain. In multi-window apps, events from one window
never trigger handlers in another.

## Test selectors

Test helpers (`find/1`, `click/1`, etc.) accept `#`-prefixed ID
selectors with full scoped paths:

```elixir
find!("#save")                     # local ID
click("#sidebar/form/save")        # full scoped path
assert_text("#form/email", "")     # scoped assertion
```

The test backend resolves IDs against the normalised tree.

## Accessibility cross-references

A11y props (`labelled_by`, `described_by`, `error_message`) reference
widget IDs. Bare IDs are resolved relative to the current scope during
normalisation. An ID already containing `/` passes through unchanged:

```elixir
text_input("email", model.email,
  a11y: %{labelled_by: "email-label"}  # resolves to "form/email-label" inside "form"
)
```

## See also

- [Lists and Inputs guide](../guides/06-lists-and-inputs.md) --
  dynamic list scoping in practice
- [Custom Widgets reference](custom-widgets.md) - widget event
  interception and scope transparency
- [Layout reference](windows-and-layout.md) - which containers support auto-IDs
- `Plushie.Tree` - normalisation and scope resolution internals
- `Plushie.Event.WidgetEvent` - scope field semantics
- `Plushie.Event.target/1` - path reconstruction
