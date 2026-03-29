# Scoped IDs reference

Named containers automatically scope their children's IDs,
producing unique hierarchical paths without manual prefixing. See
`Plushie.Tree` for normalization internals and the
[Lists and Inputs guide](../guides/06-lists-and-inputs.md) for a narrative introduction.

## Scoping rules

| Node type | Creates scope? | Notes |
|---|---|---|
| Named container (explicit ID) | Yes | ID pushed onto scope chain |
| Auto-ID container (`auto:` prefix) | No | Transparent, no scope effect |
| Window node (`type: "window"`) | No | Logical boundary, not containment |

User-provided IDs must not contain `/`. The slash is reserved for
the scope separator; `Tree.normalize/1` raises `ArgumentError` on
violation.

## ID resolution

During normalization, each named container pushes its ID onto the
scope chain. Descendant IDs are prefixed with the full scope path,
joined by `/`:

```
sidebar (container)       ->  "sidebar"
  form (container)        ->  "sidebar/form"
    email (text_input)    ->  "sidebar/form/email"
    save (button)         ->  "sidebar/form/save"
```

Resolution is recursive -- nesting depth is unlimited.

## Event scope field

When the renderer emits a widget event, the wire ID is the full
scoped path. The SDK splits it into `id` (local) and `scope`
(reversed ancestor chain, nearest parent first):

```elixir
%WidgetEvent{type: :click, id: "save", scope: ["form", "sidebar"]}
```

Pattern matching examples:

```elixir
# Local ID only (any scope)
def update(model, %WidgetEvent{type: :click, id: "save"}), do: ...

# Immediate parent match
def update(model, %WidgetEvent{type: :click, id: "save", scope: ["form" | _]}), do: ...

# Bind dynamic parent (list items)
def update(model, %WidgetEvent{type: :toggle, id: "done", scope: [item_id | _]}), do: ...

# Exact depth (only one ancestor)
def update(model, %WidgetEvent{id: "query", scope: ["search"]}), do: ...

# Unscoped widget
def update(model, %WidgetEvent{id: "save", scope: []}), do: ...
```

Only `Plushie.Event.WidgetEvent` carries scope. Subscription events
(Key, Mouse, Touch, IME, Modifiers) are global and unscoped.

## Path reconstruction

`Plushie.Event.target/1` reconstructs the full forward-slash path
from an event's `id` and `scope` fields:

```elixir
Plushie.Event.target(%WidgetEvent{id: "save", scope: ["form", "sidebar"]})
# => "sidebar/form/save"
```

## Canvas element scoping

Canvas elements participate in the same mechanism. The renderer
uses `canvas_id/element_id` as the wire ID, which the SDK splits
identically:

```
canvas "drawing"              ->  "drawing"
  rect("bg", ...)            ->  "drawing/bg"
  interactive "handle" ...   ->  "drawing/handle"
```

Canvas element events look like regular scoped widget events:

```elixir
%WidgetEvent{type: :canvas_element_click, id: "handle", scope: ["drawing"]}
```

## Command paths

Commands that target widgets by path use forward-slash format:

```elixir
Command.focus("form/email")
Command.scroll_to("sidebar/list", 0)
```

## Test selectors

Test helpers (`find/1`, `click/1`, etc.) accept both local and
full-path selectors:

```elixir
find("#save")                  # local ID
click("#sidebar/form/save")    # full scoped path
```

The test backend resolves local IDs against the Elixir-side tree
before sending queries to the renderer.

## Accessibility cross-references

A11y props (`labelled_by`, `described_by`, `error_message`) are
resolved relative to the current scope during normalization.
References already containing `/` pass through unchanged.

## See also

- [Lists and Inputs guide](../guides/06-lists-and-inputs.md) -- narrative walkthrough
  with dynamic list examples
- `Plushie.Tree` -- normalization and search
- `Plushie.Event.WidgetEvent` -- scope field semantics
- `Plushie.Event.target/1` -- path reconstruction
