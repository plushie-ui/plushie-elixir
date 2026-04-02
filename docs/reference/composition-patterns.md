# Composition Patterns

Recipes for common UI patterns built from Plushie's built-in widgets.
Each pattern shows complete code with the view and update logic. These
are not special framework features. They are compositions of existing
widgets and state helpers.

| Section | Patterns |
|---|---|
| [Navigation](#navigation) | Tabs, sidebar, breadcrumbs, route dispatch |
| [Overlays](#overlays) | Modal dialog, toast notifications, popover, loading indicator |
| [Layout](#layout-patterns) | Toolbar, cards, split panel, badges |
| [Forms](#form-patterns) | Validated fields, search and filter |
| [State helpers](#state-helper-patterns) | Selection, undo, data query with sort |
| [Interaction](#interaction-patterns) | Debounced search, context menu, keyboard shortcuts, focus management, multi-window |

## Navigation

### Tabs

Buttons in a row with conditional content. Track the active tab in the
model.

```elixir
def view(model) do
  tabs = [:overview, :details, :settings]

  window "main", title: "Tabs" do
    column width: :fill do
      row spacing: 0 do
        for tab <- tabs do
          button(
            "tab:#{tab}",
            tab |> Atom.to_string() |> String.capitalize(),
            style: if(model.active_tab == tab, do: :primary, else: :text)
          )
        end
      end

      rule()

      case model.active_tab do
        :overview -> overview_content(model)
        :details -> details_content(model)
        :settings -> settings_content(model)
      end
    end
  end
end

def update(model, %WidgetEvent{type: :click, id: "tab:" <> tab_name}) do
  %{model | active_tab: String.to_existing_atom(tab_name)}
end
```

### Sidebar navigation

A fixed-width column alongside the main content. The sidebar has a
fixed pixel width; the content area fills the rest.

```elixir
row width: :fill, height: :fill do
  column width: 200, height: :fill, padding: 8, spacing: 4 do
    for item <- nav_items do
      button(item.id, item.label,
        width: :fill,
        style: if(item.id == model.active, do: :primary, else: :text)
      )
    end
  end

  container "content", width: :fill, height: :fill, padding: 16 do
    render_active_page(model)
  end
end
```

### Breadcrumbs

Interleaved buttons and separators. The last segment is plain text
(current location); earlier segments are clickable for navigation.

```elixir
row spacing: 4 do
  for {segment, i} <- Enum.with_index(model.breadcrumbs) do
    if i > 0 do
      text("sep-#{i}", "/", size: 12, color: "#999")
    end

    if i == length(model.breadcrumbs) - 1 do
      text("crumb-#{i}", segment, size: 12)
    else
      button("crumb-#{i}", segment, style: :text)
    end
  end
end
```

### Route-based view dispatch

Use `Plushie.Route` for a navigation stack with back/forward and
per-route parameters:

```elixir
def view(model) do
  window "main", title: "App" do
    case Route.current(model.route) do
      :list -> list_view(model)
      :detail -> detail_view(model, Route.params(model.route))
      :settings -> settings_view(model)
    end
  end
end

def update(model, %WidgetEvent{type: :click, id: "show-detail", scope: [item_id | _]}) do
  %{model | route: Route.push(model.route, :detail, %{id: item_id})}
end

def update(model, %WidgetEvent{type: :click, id: "back"}) do
  %{model | route: Route.pop(model.route)}
end
```

## Overlays

Overlays (modals, toasts, popovers) must be placed at the **window
level** to stay visible regardless of scrolling. A `stack` as the
direct child of the window layers overlay content on top of everything
else. If you put an overlay inside a scrollable or a fixed-height
container, it scrolls or clips with that container.

```elixir
def view(model) do
  window "main", title: "App" do
    stack width: :fill, height: :fill do
      # Layer 0: all app content (may scroll internally)
      main_content(model)

      # Layer 1: modal (covers full window when active)
      if model.show_modal, do: modal_overlay(model)

      # Layer 2: toasts (topmost, visible even over modals)
      toast_overlay(model)
    end
  end
end
```

### Modal dialog

The modal overlay covers the full window with a semi-transparent
backdrop and centres the dialog. The `if` without `else` returns `nil`,
which `stack` filters out.

```elixir
defp modal_overlay(model) do
  container "overlay",
    width: :fill, height: :fill,
    background: "#00000088",
    center: true do

    container "dialog", padding: 24, background: "#ffffff",
      border: Border.new() |> Border.rounded(8) do
      column spacing: 12 do
        text("modal-title", "Confirm", size: 18)
        text("modal-body", "Are you sure?")
        row spacing: 8 do
          button("modal-cancel", "Cancel")
          button("modal-confirm", "Confirm", style: :primary)
        end
      end
    end
  end
end

def update(model, %WidgetEvent{type: :click, id: "delete"}) do
  %{model | show_modal: true, pending_action: :delete}
end

def update(model, %WidgetEvent{type: :click, id: "modal-confirm"}) do
  model = perform_action(model, model.pending_action)
  %{model | show_modal: false, pending_action: nil}
end

def update(model, %WidgetEvent{type: :click, id: "modal-cancel"}) do
  %{model | show_modal: false, pending_action: nil}
end
```

### Toast notifications

Toasts are transient messages that auto-dismiss after a timeout. Place
them at the window level in a `stack` so they stay visible regardless
of scroll position. Use `Command.send_after` for auto-dismiss and
`Command.announce` for screen reader announcements.

```elixir
# Model: toasts is a list of %{id: string, text: string, level: atom}

defp toast_overlay(model) do
  if model.toasts != [] do
    container width: :fill, height: :fill, align_x: :right, align_y: :bottom do
      column spacing: 8, padding: 16 do
        for toast <- model.toasts do
          container toast.id, padding: {8, 16},
            background: toast_color(toast.level),
            border: Border.new() |> Border.rounded(6),
            opacity: transition(200, to: 1.0, from: 0.0) do
            row spacing: 8 do
              text(toast.id <> "-msg", toast.text, color: "#fff")
              button(toast.id <> "-dismiss", "x", style: :text)
            end
          end
        end
      end
    end
  end
end

defp toast_color(:error), do: "#ef4444"
defp toast_color(:success), do: "#22c55e"
defp toast_color(_), do: "#333333"

# Show a toast with auto-dismiss:
defp show_toast(model, text, level \\ :info) do
  id = "toast-#{:erlang.unique_integer([:positive])}"
  toast = %{id: id, text: text, level: level}
  model = %{model | toasts: model.toasts ++ [toast]}

  # Auto-dismiss after 5 seconds; announce for screen readers
  {model, Command.batch([
    Command.send_after(5000, {:dismiss_toast, id}),
    Command.announce(text)
  ])}
end

def update(model, {:dismiss_toast, id}) do
  %{model | toasts: Enum.reject(model.toasts, &(&1.id == id))}
end

def update(model, %WidgetEvent{type: :click, id: id, scope: [toast_id | _]})
    when id in ["-dismiss"] do
  %{model | toasts: Enum.reject(model.toasts, &(&1.id == toast_id))}
end
```

### Popover

The `overlay` widget positions floating content relative to an anchor.
First child is the anchor, second is the overlay. Exactly two children
required.

```elixir
overlay "menu", position: :below, gap: 4, flip: true do
  button("trigger", "Options")

  container "dropdown", padding: 8, background: "#fff",
    border: Border.new() |> Border.width(1) |> Border.color("#ddd") |> Border.rounded(4) do
    column spacing: 2 do
      button("opt-edit", "Edit", style: :text, width: :fill)
      button("opt-delete", "Delete", style: :text, width: :fill)
    end
  end
end
```

`flip: true` auto-repositions when the overlay would go off-screen.

### Loading indicator

Conditionally show a loading overlay while async work is in flight.
Like modals, place this at the window level so it covers scrollable
content:

```elixir
# Inside the window-level stack:
if model.loading do
  container width: :fill, height: :fill, background: "#ffffff88", center: true do
    text("loading", "Loading...", size: 16)
  end
end

def update(model, %WidgetEvent{type: :click, id: "fetch"}) do
  {%{model | loading: true}, Command.async(fn -> fetch_data() end, :fetch)}
end

def update(model, %AsyncEvent{tag: :fetch, result: {:ok, data}}) do
  %{model | loading: false, data: data}
end
```

## Layout patterns

### Toolbar

A row with button groups, separators, and trailing alignment.
`space(width: :fill)` pushes everything after it to the right.

```elixir
row spacing: 4, padding: {4, 8} do
  button("bold", "B")
  button("italic", "I")

  rule(direction: :vertical, height: 20)

  button("align-left", "Left")
  button("align-center", "Center")

  space(width: :fill)

  button("settings", "Settings")
end
```

### Cards

A reusable card helper with border, shadow, and padding:

```elixir
defp card(id, do: block) do
  container id,
    padding: 16,
    background: "#ffffff",
    border: Border.new() |> Border.color("#e5e7eb") |> Border.width(1) |> Border.rounded(8),
    shadow: Shadow.new() |> Shadow.color("#0000001a") |> Shadow.offset(0, 2) |> Shadow.blur_radius(4) do
    block
  end
end

# Usage:
card "user-info" do
  column spacing: 8 do
    text("name", model.user.name, size: 16)
    text("email", model.user.email, color: "#666")
  end
end
```

### Split panel

A resizable divider between two panes. Use `pointer_area` for drag
tracking and a subscription for mouse move during drag:

```elixir
row width: :fill, height: :fill do
  container "left", width: model.split_width, height: :fill do
    left_content(model)
  end

  pointer_area "divider",
    cursor: :resizing_horizontally,
    on_press: "drag-start",
    on_release: "drag-end" do
    container width: 4, height: :fill, background: "#ddd" do
    end
  end

  container "right", width: :fill, height: :fill do
    right_content(model)
  end
end

def subscribe(model) do
  if model.dragging do
    [Plushie.Subscription.on_mouse_move(:drag, max_rate: 60)]
  else
    []
  end
end

def update(model, %WidgetEvent{type: :click, id: "drag-start"}), do: %{model | dragging: true}
def update(model, %WidgetEvent{type: :click, id: "drag-end"}), do: %{model | dragging: false}
def update(model, %MouseEvent{type: :moved, x: x}), do: %{model | split_width: max(100, x)}
```

### Badges and chips

Pills with large border radius. `rounded(999)` clamps to the maximum,
creating a pill shape.

```elixir
container "badge",
  padding: {2, 8},
  background: "#3b82f6",
  border: Border.new() |> Border.rounded(999) do
  text("count", "#{model.unread}", color: "#fff", size: 12)
end
```

## Form patterns

### Validated form field

Show inline validation errors below the input:

```elixir
column spacing: 4 do
  text_input("email", model.email, placeholder: "Email",
    a11y: %{required: true, invalid: model.email_error != nil})

  if model.email_error do
    text("email-error", model.email_error, color: "#ef4444", size: 12)
  end
end

def update(model, %WidgetEvent{type: :input, id: "email", value: email}) do
  error = if String.contains?(email, "@"), do: nil, else: "Must be a valid email"
  %{model | email: email, email_error: error}
end
```

### Search and filter

A text input that filters a list in real time using `Plushie.Data`:

```elixir
column spacing: 8 do
  text_input("search", model.query, placeholder: "Search...")

  keyed_column spacing: 4 do
    for item <- filtered_items(model) do
      text(item.id, item.name)
    end
  end
end

defp filtered_items(model) do
  if model.query == "" do
    model.items
  else
    Data.query(model.items, search: {[:name], model.query}).entries
  end
end
```

## State helper patterns

### Selection with highlighting

Use `Plushie.Selection` to manage single or multi-select state. The
selection state is a standalone data structure. Toggle items and
check membership:

```elixir
# In init:
selection: Selection.new(mode: :multi)

# In view:
keyed_column spacing: 4 do
  for item <- model.items do
    container item.id,
      style: if(Selection.selected?(model.selection, item.id),
        do: :primary, else: :transparent) do
      row spacing: 8 do
        checkbox("select", Selection.selected?(model.selection, item.id))
        text(item.id <> "-name", item.name)
      end
    end
  end
end

# In update:
def update(model, %WidgetEvent{type: :toggle, id: "select", scope: [item_id | _]}) do
  %{model | selection: Selection.toggle(model.selection, item_id)}
end
```

### Undo with coalesced keystrokes

Use `Plushie.Undo` to track reversible changes. Coalescing groups
rapid sequential changes (like typing) into a single undo step:

```elixir
# In init:
undo: Undo.new("")

# In update: track editor changes with coalescing
def update(model, %WidgetEvent{type: :input, id: "editor", value: text}) do
  undo = Undo.apply(model.undo, %{
    apply: fn _ -> text end,
    undo: fn _ -> model.source end,
    coalesce: :typing,
    coalesce_window_ms: 500
  })
  %{model | source: text, undo: undo}
end

# Ctrl+Z / Ctrl+Shift+Z:
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

### Data query with sort controls

Use `Plushie.Data` to filter, sort, and paginate in-memory collections:

```elixir
defp query_items(model) do
  Data.query(model.items,
    search: if(model.query != "", do: {[:name, :email], model.query}),
    sort: {model.sort_dir, model.sort_field},
    page: model.page,
    page_size: 25
  )
end

# In view: sortable column headers
row spacing: 0 do
  for col <- [:name, :email, :role] do
    button("sort:#{col}", "#{col} #{sort_indicator(model, col)}",
      style: :text, width: {:fill_portion, 1})
  end
end

# In update: toggle sort direction
def update(model, %WidgetEvent{type: :click, id: "sort:" <> field}) do
  field = String.to_existing_atom(field)
  dir = if model.sort_field == field and model.sort_dir == :asc, do: :desc, else: :asc
  %{model | sort_field: field, sort_dir: dir}
end
```

## Interaction patterns

### Debounced search

Don't search on every keystroke. Wait for a pause. Use
`Command.send_after` which cancels-and-restarts on each keystroke.
The search only fires when the user stops typing:

```elixir
def update(model, %WidgetEvent{type: :input, id: "search", value: query}) do
  # Update the display immediately
  model = %{model | query: query}
  # Debounce: cancel previous timer, start new one
  {model, Command.send_after(300, {:run_search, query})}
end

def update(model, {:run_search, query}) do
  # Only runs if no keystroke arrived in the last 300ms
  %{model | results: search(model.items, query)}
end
```

`send_after` with the same event term cancels the previous timer
automatically. No manual cleanup needed.

### Context menu

Right-click menu using `pointer_area` and the window-level stack:

```elixir
# In the content area, wrap the target in a pointer_area:
pointer_area "item-#{item.id}",
  on_right_press: true do
  text(item.id, item.name)
end

def update(model, %WidgetEvent{type: :press, data: %{button: :right}, scope: [item_id | _]}) do
  %{model | context_menu: %{item_id: item_id, x: model.cursor_x, y: model.cursor_y}}
end

# In the window-level stack, render the menu at the cursor position:
if model.context_menu do
  pin x: model.context_menu.x, y: model.context_menu.y do
    container "ctx-menu", padding: 4, background: "#fff",
      border: Border.new() |> Border.width(1) |> Border.color("#ddd") |> Border.rounded(4),
      shadow: Shadow.new() |> Shadow.color("#0000001a") |> Shadow.blur_radius(8) do
      column spacing: 2 do
        button("ctx-edit", "Edit", style: :text, width: :fill)
        button("ctx-delete", "Delete", style: :text, width: :fill)
      end
    end
  end
end
```

Dismiss on any click outside the menu or on Escape.

### Keyboard shortcuts

Organise shortcuts with a dedicated function to keep `update/2` clean:

```elixir
def subscribe(_model) do
  [Plushie.Subscription.on_key_press(:keys)]
end

def update(model, %KeyEvent{type: :press} = key) do
  case shortcut(key) do
    :save -> save(model)
    :undo -> undo(model)
    :redo -> redo(model)
    :new -> {model, Command.focus("new-name")}
    :find -> {model, Command.focus("search")}
    :escape -> %{model | context_menu: nil, show_modal: false}
    nil -> model
  end
end

defp shortcut(%KeyEvent{key: "s", modifiers: %{command: true}}), do: :save
defp shortcut(%KeyEvent{key: "z", modifiers: %{command: true, shift: false}}), do: :undo
defp shortcut(%KeyEvent{key: "z", modifiers: %{command: true, shift: true}}), do: :redo
defp shortcut(%KeyEvent{key: "n", modifiers: %{command: true}}), do: :new
defp shortcut(%KeyEvent{key: "f", modifiers: %{command: true}}), do: :find
defp shortcut(%KeyEvent{key: :escape}), do: :escape
defp shortcut(_), do: nil
```

The `command` modifier is platform-aware: Ctrl on Linux/Windows, Cmd on
macOS.

### Focus management

Return focus to the right place after actions:

```elixir
# After deleting an item, focus the next item in the list:
def update(model, %WidgetEvent{type: :click, id: "delete", scope: [item_id | _]}) do
  index = Enum.find_index(model.items, &(&1.id == item_id))
  items = List.delete_at(model.items, index)
  next_id = Enum.at(items, min(index, length(items) - 1))

  focus_cmd = if next_id, do: Command.focus("#{next_id.id}/select"), else: Command.none()
  {%{model | items: items}, focus_cmd}
end

# After closing a modal, return focus to the element that opened it:
def update(model, %WidgetEvent{type: :click, id: "modal-confirm"}) do
  model = perform_action(model, model.pending_action)
  {%{model | show_modal: false}, Command.focus(model.modal_trigger_id)}
end
```

Good focus management prevents keyboard and screen reader users from
losing their place. Always think about where focus should go after
removing content, closing dialogs, or completing flows.

### Multi-window detail view

Open an item in its own window. The `view/1` conditionally adds a
second window when an item is detached:

```elixir
def view(model) do
  windows = [
    window "main", title: "Items" do
      keyed_column spacing: 4 do
        for item <- model.items do
          container item.id do
            row spacing: 8 do
              text(item.id <> "-name", item.name)
              button("detach", "Open in window")
            end
          end
        end
      end
    end
  ]

  for id <- model.detached_items, item = find_item(model, id), reduce: windows do
    acc ->
      acc ++ [
        window "detail:#{id}",
          title: item.name,
          exit_on_close_request: false do
          detail_view(item)
        end
      ]
  end
end

def update(model, %WidgetEvent{type: :click, id: "detach", scope: [item_id | _]}) do
  %{model | detached_items: [item_id | model.detached_items]}
end

def update(model, %WindowEvent{type: :close_requested, window_id: "detail:" <> item_id}) do
  %{model | detached_items: List.delete(model.detached_items, item_id)}
end
```

Each detached window has `exit_on_close_request: false` so closing it
only removes it from the view rather than exiting the app.

## See also

- [Built-in Widgets reference](built-in-widgets.md) - widget catalog
- [Canvas reference](canvas.md) - shapes, transforms, interactive groups
- [Styling reference](themes-and-styling.md) - Color, Theme, StyleMap, Border,
  Shadow, Gradient
- [Layout reference](windows-and-layout.md) - sizing, alignment, containers
- [Animation reference](animation.md) - transitions, springs, sequences
- [Custom Widgets reference](custom-widgets.md) - extracting reusable
  widgets from patterns
- `Plushie.Undo`, `Plushie.Data`, `Plushie.Selection`, `Plushie.Route`
  - state helper module docs
