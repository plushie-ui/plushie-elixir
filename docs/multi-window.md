# Multi-window

Julep supports multiple windows driven declaratively from `view/1`. Windows
are nodes in the tree -- if a window node is present, the window is open; if
it disappears, the window closes.

## The model

`view/1` returns a list of window nodes (or a single window node for
single-window apps):

```elixir
def view(model) do
  import Julep.UI

  windows = [
    window "main", title: "My App" do
      main_content(model)
    end
  ]

  if model.inspector_open do
    inspector = window "inspector", title: "Inspector", size: {400, 600} do
      inspector_panel(model)
    end
    windows ++ [inspector]
  else
    windows
  end
end
```

Single-window apps can return a single window node directly (no list
needed):

```elixir
def view(model) do
  import Julep.UI

  window "main", title: "Counter" do
    text("Count: #{model.count}")
  end
end
```

The runtime normalizes both forms. A bare window node is wrapped in a
single-element list internally.

## Window identity

Each window node has an `id` (like all nodes). The renderer uses this ID
to track which OS window corresponds to which tree node:

- **New ID appears** -- renderer opens a new OS window.
- **Existing ID present** -- renderer updates that window's content.
- **ID disappears** -- renderer closes that OS window.

Window IDs must be stable strings. Do not generate random IDs per render
or the renderer will close and reopen the window on every update.

## Window properties

```elixir
window "main",
  title: "My App",
  size: {800, 600},
  min_size: {400, 300},
  max_size: {1920, 1080},
  position: {100, 100},
  resizable: true,
  closeable: true,
  minimizable: true,
  decorations: true,
  transparent: false,
  visible: true,
  theme: "dark",       # or "system" to follow OS preference
  level: :normal,      # :normal | :always_on_top | :always_on_bottom
  scale_factor: 1.5    # per-window UI scale (overrides global setting)
do
  content(model)
end
```

Properties are set when the window first appears. To change properties
after creation, use window commands:

```elixir
def update(model, {:click, "go_fullscreen"}) do
  {model, Julep.Command.set_window_mode("main", :fullscreen)}
end
```

## Window events

Window events include the window ID so your app knows which window they
came from:

```elixir
def update(model, {:window_close_requested, "inspector"}) do
  %{model | inspector_open: false}
end

def update(model, {:window_close_requested, "main"}) do
  if model.unsaved_changes do
    %{model | confirm_exit: true}
  else
    {model, Julep.Command.close_window("main")}
  end
end

def update(model, {:window_resized, "main", width, height}) do
  %{model | window_size: {width, height}}
end

def update(model, {:window_focused, window_id}) do
  %{model | active_window: window_id}
end
```

## Window close behaviour

By default, when the user clicks the close button on a window, the
renderer sends a `{:window_close_requested, window_id}` event instead
of closing immediately. Your app decides what to do:

```elixir
# Let it close (remove it from view):
def update(model, {:window_close_requested, "settings"}) do
  %{model | settings_open: false}
end

# Block the close:
def update(model, {:window_close_requested, "main"}) do
  %{model | show_save_dialog: true}
end
```

If `close_requested` is not handled (falls through to the catch-all), the
window stays open. This prevents accidental closes. To close a window
programmatically, remove it from the tree (return `view/1` without it) or
use `Julep.Command.close_window(id)`.

## Opening windows declaratively

Windows are opened by adding window nodes to the tree returned by
`view/1`. There is no `open_window` command. To open a new window, set a
flag in your model and include the window node conditionally:

```elixir
def update(model, {:click, "open_settings"}) do
  %{model | settings_open: true}
end

def view(model) do
  import Julep.UI

  windows = [
    window "main", title: "My App" do
      main_content(model)
    end
  ]

  if model.settings_open do
    settings = window "settings", title: "Settings", size: {500, 400} do
      settings_panel(model)
    end
    windows ++ [settings]
  else
    windows
  end
end
```

When the runtime detects a new window ID in the tree, the renderer opens
the corresponding OS window. When the ID disappears, the window closes.

## Primary window

The first window in the list returned by `view/1` is the primary window.
When the primary window is closed, the runtime exits (unless
`handle_renderer_exit/2` is overridden to prevent it).

Secondary windows can be opened and closed freely without affecting the
runtime lifecycle.

## Focus and active window

The renderer tracks which window has OS focus. Window focus/unfocus events
are delivered as:

```elixir
{:window_focused, window_id}
{:window_unfocused, window_id}
```

The app can use these to adjust behaviour (e.g., pause animations in
unfocused windows, track the active window for keyboard shortcuts).

## Common patterns

### Detachable panel

```elixir
def view(model) do
  import Julep.UI

  main = window "main", title: "Editor" do
    column do
      editor_content(model)
      unless model.panel_detached do
        panel_content(model)
      end
    end
  end

  if model.panel_detached do
    panel = window "panel", title: "Panel", size: {300, 500} do
      panel_content(model)
    end
    [main, panel]
  else
    main
  end
end
```

### Dialog window

```elixir
def view(model) do
  import Julep.UI

  main = window "main", title: "App" do
    main_content(model)
  end

  if model.confirm_dialog do
    dialog = window "confirm", title: "Confirm",
             size: {300, 150}, resizable: false, minimizable: false,
             level: :always_on_top do
      column padding: 16, spacing: 12 do
        text("Are you sure?")
        row spacing: 8 do
          button("confirm_yes", "Yes")
          button("confirm_no", "No")
        end
      end
    end
    [main, dialog]
  else
    main
  end
end
```
