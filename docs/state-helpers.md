# State helpers

Julep provides optional state management modules. None of these are required
to use julep -- your model can be any term. These exist because the patterns
come up repeatedly in desktop apps and getting them right from scratch is
tedious.

All helpers are pure data structures with no processes or side effects.

## Julep.State

Path-based access to nested model data with revision tracking and
transactions.

```elixir
state = Julep.State.new(%{user: %{name: "Alice", prefs: %{theme: "dark"}}})

# Read
Julep.State.get(state, [:user, :name])
# => "Alice"

# Write
state = Julep.State.put(state, [:user, :prefs, :theme], "light")
Julep.State.revision(state)
# => 1

# Transaction (atomic multi-step update with rollback)
state = Julep.State.begin_transaction(state)
state = Julep.State.put(state, [:user, :name], "Bob")
state = Julep.State.put(state, [:user, :prefs, :theme], "dark")
state = Julep.State.commit_transaction(state)
# Both changes applied atomically. Revision incremented once.

# Or roll back:
state = Julep.State.rollback_transaction(state)
# All changes since begin_transaction discarded.
```

The revision counter is useful for determining whether a re-render is
needed. If the revision has not changed, the tree has not changed.

### When to use it

Use `Julep.State` when your model has deeply nested data that you update
from multiple event handlers. The path-based access avoids the nested
`Map.update_in` chains that get unwieldy fast.

Skip it when your model is flat or simple enough that plain map updates
read clearly.

## Julep.Undo

Undo/redo stack for commands.

```elixir
undo = Julep.Undo.new(model)

# Apply a command (records it for undo)
undo = Julep.Undo.apply(undo, %{
  apply: fn m -> %{m | name: "Bob"} end,
  undo: fn m -> %{m | name: "Alice"} end,
  label: "Rename to Bob"
})

Julep.Undo.current(undo).name
# => "Bob"

# Undo
undo = Julep.Undo.undo(undo)
Julep.Undo.current(undo).name
# => "Alice"

# Redo
undo = Julep.Undo.redo(undo)
Julep.Undo.current(undo).name
# => "Bob"

# Coalescing (group rapid changes, like typing)
undo = Julep.Undo.apply(undo, %{
  apply: fn m -> %{m | text: m.text <> "a"} end,
  undo: fn m -> %{m | text: String.slice(m.text, 0..-2//1)} end,
  coalesce: {:typing, "editor"},
  coalesce_window_ms: 500
})
# Multiple applies with the same coalesce key within the time window
# are merged into a single undo entry.
```

### When to use it

Use `Julep.Undo` when your app has user actions that should be reversible
(text editing, form filling, drawing, configuration changes). Skip it for
apps where undo does not make sense (dashboards, monitoring).

## Julep.Selection

Selection state for lists and tables.

```elixir
sel = Julep.Selection.new(mode: :multi)

sel = Julep.Selection.select(sel, "item_1")
sel = Julep.Selection.select(sel, "item_3", extend: true)

Julep.Selection.selected(sel)
# => MapSet.new(["item_1", "item_3"])

sel = Julep.Selection.toggle(sel, "item_1")
Julep.Selection.selected(sel)
# => MapSet.new(["item_3"])

# Range select (shift-click pattern)
sel = Julep.Selection.new(mode: :range, order: ["a", "b", "c", "d", "e"])
sel = Julep.Selection.select(sel, "b")
sel = Julep.Selection.range_select(sel, "d")
Julep.Selection.selected(sel)
# => MapSet.new(["b", "c", "d"])
```

### When to use it

Use `Julep.Selection` when you have selectable lists, tables, or tree
views. It handles single, multi (ctrl-click), and range (shift-click)
selection modes correctly. Skip it for simple cases where a single
`selected_id` in your model is sufficient.

## Julep.Route

Client-side routing for multi-view apps.

```elixir
route = Julep.Route.new("/dashboard")

route = Julep.Route.push(route, "/settings", %{tab: "general"})
Julep.Route.current(route)
# => "/settings"
Julep.Route.params(route)
# => %{tab: "general"}

route = Julep.Route.pop(route)
Julep.Route.current(route)
# => "/dashboard"
```

Routes are just data. There is no URL bar, no browser history API. This
is for apps that have multiple "screens" and want back/forward navigation
with history tracking.

### When to use it

Use `Julep.Route` for apps with distinct screens (settings, detail views,
wizards). Skip it for single-screen apps.

## Julep.Data

Query pipeline for in-memory record collections.

```elixir
records = [
  %{id: 1, name: "Alice", role: "admin", active: true},
  %{id: 2, name: "Bob", role: "user", active: false},
  %{id: 3, name: "Carol", role: "admin", active: true}
]

Julep.Data.query(records,
  filter: fn r -> r.active end,
  sort: {:asc, :name},
  page: 1,
  page_size: 10
)
# => %{
#   entries: [%{id: 1, ...}, %{id: 3, ...}],
#   total: 2,
#   page: 1,
#   page_size: 10
# }
```

### When to use it

Use `Julep.Data` when you have tabular data that needs filtering, sorting,
grouping, or pagination in the UI. It is a query pipeline over lists, not a
database -- keep data sets small enough to fit in memory.

## General philosophy

These helpers share a few properties:

- **Pure data.** No GenServers, no processes, no side effects. They are
  just structs and functions.
- **Optional.** You can use zero, one, or all of them. They do not depend
  on each other.
- **Composable.** They work with your model, not instead of it. Embed them
  as fields in your model map.

```elixir
def init(_opts) do
  %{
    state: Julep.State.new(%{...}),
    undo: Julep.Undo.new(%{...}),
    selection: Julep.Selection.new(mode: :single),
    route: Julep.Route.new("/home"),
    todos: []
  }
end
```
