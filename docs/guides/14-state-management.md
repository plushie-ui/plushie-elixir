# State Management

As apps grow, model management gets complex. Tracking undo history, managing
list selection, navigating between views, searching and sorting data. These
are recurring patterns that Plushie provides as standalone helper modules.

Each helper is a pure data structure. No processes, no side effects, no
framework coupling. You store them in your model and update them in
`update/2`. They compose freely: use one, some, or all.

This chapter introduces each helper with an isolated example, then applies
it to the pad.

## Plushie.Undo

`Plushie.Undo` tracks reversible actions with an undo/redo stack.

```elixir
alias Plushie.Undo

undo = Undo.new(%{text: ""})

# Apply a change
undo = Undo.push(undo, %{
  apply: fn state -> %{state | text: "hello"} end,
  undo: fn state -> %{state | text: ""} end,
  label: "Type hello"
})

Undo.current(undo)        # %{text: "hello"}
Undo.can_undo?(undo)      # true

undo = Undo.undo(undo)
Undo.current(undo)        # %{text: ""}
Undo.can_redo?(undo)      # true

undo = Undo.redo(undo)
Undo.current(undo)        # %{text: "hello"}
```

Each command is a map with `:apply` and `:undo` functions, plus an optional
`:label` for display.

### Coalescing

Rapid sequential changes (like keystrokes) can be grouped into a single undo
step. Add `:coalesce` and `:coalesce_window_ms`:

```elixir
Undo.push(undo, %{
  apply: fn state -> %{state | text: state.text <> "a"} end,
  undo: fn state -> %{state | text: String.slice(state.text, 0..-2//1)} end,
  coalesce: :typing,
  coalesce_window_ms: 500
})
```

Changes with the same `:coalesce` key within the time window merge into one
undo entry. One Ctrl+Z undoes the entire burst.

### Applying it: editor undo/redo

Track editor changes with Undo. Add `undo: Undo.new("")` to the model:

```elixir
def update(model, %WidgetEvent{type: :input, id: "editor", value: source}) do
  undo = Undo.push(model.undo, %{
    apply: fn _old -> source end,
    undo: fn _new -> model.source end,
    coalesce: :typing,
    coalesce_window_ms: 500
  })

  %{model | source: source, undo: undo, dirty: true}
end

def update(model, %KeyEvent{key: "z", modifiers: %{command: true, shift: false}}) do
  if Undo.can_undo?(model.undo) do
    undo = Undo.undo(model.undo)
    %{model | undo: undo, source: Undo.current(undo)}
  else
    model
  end
end

def update(model, %KeyEvent{key: "z", modifiers: %{command: true, shift: true}}) do
  if Undo.can_redo?(model.undo) do
    undo = Undo.redo(model.undo)
    %{model | undo: undo, source: Undo.current(undo)}
  else
    model
  end
end
```

See `Plushie.Undo` for the full API.

## Plushie.Data

`Plushie.Data` provides a query pipeline for filtering, searching, sorting,
and paginating in-memory collections.

```elixir
alias Plushie.Data

records = [
  %{name: "Alice", role: "dev"},
  %{name: "Bob", role: "design"},
  %{name: "Carol", role: "dev"}
]

result = Data.query(records,
  search: {[:name, :role], "dev"},
  sort: {:asc, :name},
  page: 1,
  page_size: 10
)

result.entries  # [%{name: "Alice", ...}, %{name: "Carol", ...}]
result.total    # 2
```

The pipeline runs in order: filter -> search -> sort -> paginate -> group.
All options are optional.

| Option | Type | Description |
|---|---|---|
| `:filter` | `(record -> boolean)` | Predicate function |
| `:search` | `{[field_keys], query}` | Case-insensitive substring match |
| `:sort` | `{:asc \| :desc, field}` or list | Sort by field(s) |
| `:page` | integer | 1-based page number |
| `:page_size` | integer | Records per page (default 25) |
| `:group` | atom | Group results by field |

### Applying it: search experiments

Add a search bar to the sidebar that filters the file list:

```elixir
# In the model
search_query: ""

# In update/2
def update(model, %WidgetEvent{type: :input, id: "search", value: query}) do
  %{model | search_query: query}
end

# In the sidebar view
filtered = if model.search_query == "" do
  model.files
else
  Data.query(
    Enum.map(model.files, &%{name: &1}),
    search: {[:name], model.search_query}
  ).entries |> Enum.map(& &1.name)
end
```

See `Plushie.Data` for the full API.

## Plushie.Selection

`Plushie.Selection` manages selection state for lists with three modes:

```elixir
alias Plushie.Selection

sel = Selection.new(mode: :multi)

sel = Selection.select(sel, "file_a")
sel = Selection.toggle(sel, "file_b")
Selection.selected?(sel, "file_a")  # true
Selection.selected?(sel, "file_b")  # true
Selection.selected(sel)             # MapSet.new(["file_a", "file_b"])

sel = Selection.clear(sel)
Selection.selected(sel)             # MapSet.new([])
```

Modes:

- `:single` - at most one item selected. Selecting a new item deselects the
  previous one.
- `:multi` - any number of items. `toggle/2` adds or removes.
- `:range` - contiguous selection with an anchor. `range_select/2` selects
  everything between the anchor and the target.

### Applying it: multi-select experiments

Add selection to the file list for bulk operations. Use a dedicated
"select" checkbox alongside each file entry:

```elixir
# In the model
selection: Selection.new(mode: :multi)

# Toggle selection via checkbox
def update(model, %WidgetEvent{type: :toggle, id: "select", scope: [file | _]}) do
  %{model | selection: Selection.toggle(model.selection, file)}
end

# In the file list view, add a checkbox per file:
checkbox("select", Selection.selected?(model.selection, file))

# Visual highlight in the sidebar
style: cond do
  file == model.active_file -> :primary
  Selection.selected?(model.selection, file) -> :secondary
  true -> :text
end
```

Add a "Delete Selected" button that removes all selected experiments.

See `Plushie.Selection` for the full API.

## Plushie.Route

`Plushie.Route` manages a navigation stack for multi-view apps:

```elixir
alias Plushie.Route

route = Route.new(:editor)
Route.current(route)       # :editor

route = Route.push(route, :browser, %{sort: :name})
Route.current(route)       # :browser
Route.params(route)        # %{sort: :name}
Route.can_go_back?(route)  # true

route = Route.pop(route)
Route.current(route)       # :editor
```

The stack is LIFO. The root entry never pops. `pop/1` on a single-entry
stack returns it unchanged.

### Applying it: view switching

Add a browser view to the pad that shows all experiments in a grid with
previews:

```elixir
# In the model
route: Route.new(:editor)

# In update/2
def update(model, %WidgetEvent{type: :click, id: "show-browser"}) do
  %{model | route: Route.push(model.route, :browser)}
end

def update(model, %WidgetEvent{type: :click, id: "back-to-editor"}) do
  %{model | route: Route.pop(model.route)}
end

# In view/1
case Route.current(model.route) do
  :editor -> editor_view(model)
  :browser -> browser_view(model)
end
```

See `Plushie.Route` for the full API.

## Plushie.State

`Plushie.State` wraps a map with path-based access and revision tracking:

```elixir
alias Plushie.State

state = State.new(%{settings: %{theme: :dark, font_size: 14}})

State.get(state, [:settings, :theme])     # :dark
State.revision(state)                      # 0

state = State.put(state, [:settings, :font_size], 16)
State.revision(state)                      # 1
```

Every mutation increments the revision counter. This is useful for change
detection. If the revision has not changed, neither has the data.

Transactions group multiple mutations into a single revision bump:

```elixir
state = State.begin_transaction(state)
state = State.put(state, [:settings, :theme], :light)
state = State.put(state, [:settings, :font_size], 18)
state = State.commit_transaction(state)  # revision increments once
```

`rollback_transaction/1` reverts to the pre-transaction snapshot.

### Applying it: pad settings

Store pad settings (theme, font size, auto-save preference) in a State
container:

```elixir
# In the model
settings: State.new(%{theme: :dark, font_size: 14, auto_save: false})

# Update a setting
settings = State.put(model.settings, [:theme], :nord)
```

See `Plushie.State` for the full API.

## Plushie.Animation.Tween

For most property animations, renderer-side transitions ([chapter 9](09-animation.md))
are simpler and more performant. `Plushie.Animation.Tween` is for cases
that need frame-by-frame control in Elixir (canvas animations, physics
simulations, or values that drive model logic rather than widget props).

```elixir
alias Plushie.Animation.Tween

anim = Tween.new(from: 0.0, to: 1.0, duration: 300, easing: :ease_out)
anim = Tween.start(anim, System.monotonic_time(:millisecond))
```

On each frame, advance the animation and read the current value:

```elixir
anim = Tween.advance(anim, current_timestamp)
Tween.value(anim)      # number between 0.0 and 1.0, eased
Tween.finished?(anim)  # true when duration has elapsed
```

Tween requires a subscription to `on_animation_frame` for the timestamp
source:

```elixir
def subscribe(model) do
  subs = [...]
  if model.animating do
    [Plushie.Subscription.on_animation_frame(:frame) | subs]
  else
    subs
  end
end

def update(model, %Plushie.Event.SystemEvent{type: :animation_frame, data: ts}) do
  anim = Tween.advance(model.anim, ts)

  if Tween.finished?(anim) do
    %{model | anim: nil, animating: false, opacity: 1.0}
  else
    %{model | anim: anim, opacity: Tween.value(anim)}
  end
end
```

### Applying it: view transitions

Animate the transition between editor and browser views with a fade:

```elixir
# When switching views, start an opacity animation
anim = Tween.new(from: 0.0, to: 1.0, duration: 200, easing: :ease_out)
anim = Tween.start(anim, System.monotonic_time(:millisecond))
%{model | route: Route.push(model.route, :browser), anim: anim, animating: true}
```

In the view, use `Tween.value(model.anim)` as the opacity on the container.

See `Plushie.Animation.Tween` for the full API including spring mode,
redirect, and the complete easing catalogue.

## Verify it

Test that undo/redo works on the editor:

```elixir
test "ctrl+z undoes editor changes" do
  type_text("#editor", "new content")
  source_after_edit = model().source

  press("ctrl+z")
  assert model().source != source_after_edit

  press("ctrl+shift+z")
  assert model().source == source_after_edit
end
```

This verifies the full undo/redo cycle through the real runtime. Typing
creates an undo entry, Ctrl+Z reverts it, Ctrl+Shift+Z restores it.

## Try it

Write state management experiments in your pad:

- Build a mini text editor with undo/redo. Show the undo history with
  `Undo.history/1`.
- Create a filterable list with `Data.query`. Add sort controls that toggle
  between `:asc` and `:desc`.
- Build a multi-select list with checkboxes. Show the selection count. Add
  a "Select All" and "Clear" button.
- Create a two-view app with `Route`: a list view and a detail view. Use
  `Route.params/1` to pass the selected item ID.

In the next chapter, we will test the pad and its extracted widgets.

---

Next: [Testing](15-testing.md)
