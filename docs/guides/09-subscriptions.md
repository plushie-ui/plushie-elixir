# Subscriptions

So far, every event in the pad has come from direct widget interaction -- a
button click, a text input keystroke. But some events come from outside the
widget tree: keyboard shortcuts, timers, window events, mouse movement.
These are delivered through **subscriptions**.

## What are subscriptions?

Subscriptions are declarative event sources. You implement the optional
`c:Plushie.App.subscribe/1` callback, which receives the current model and
returns a list of subscription specs:

```elixir
def subscribe(model) do
  [
    Plushie.Subscription.on_key_press(:keys)
  ]
end
```

The runtime calls `subscribe/1` after every update cycle and diffs the
returned list against the active subscriptions. New specs start new event
sources; removed specs stop them. You never start or stop subscriptions
manually -- you describe what you want, and the runtime manages the
lifecycle.

This is the same declarative approach as the view: the list is a function of
the model. When the model changes, the active subscriptions change with it.

## Keyboard subscriptions

`Plushie.Subscription.on_key_press/1` subscribes to keyboard events. It
delivers `Plushie.Event.Key` structs to `update/2`:

```elixir
alias Plushie.Event.Key

def subscribe(_model) do
  [Plushie.Subscription.on_key_press(:keys)]
end

def update(model, %Key{key: "s", modifiers: %{command: true}}) do
  # Ctrl+S (or Cmd+S on macOS)
  save_current(model)
end

def update(model, %Key{key: :escape}) do
  # Escape key
  %{model | error: nil}
end
```

The `Plushie.Event.Key` struct has these key fields:

- `type` -- `:press` or `:release`
- `key` -- the key that was pressed. Named keys are atoms (`:escape`,
  `:enter`, `:tab`, `:backspace`, `:arrow_up`, etc.). Single characters are
  strings (`"s"`, `"a"`, `"1"`).
- `modifiers` -- a `Plushie.KeyModifiers` struct with boolean fields:
  `ctrl`, `shift`, `alt`, `logo` (Windows/Super key), and `command`
  (platform-aware: Ctrl on Linux/Windows, Cmd on macOS).

The `command` field is particularly useful. Matching on `command: true`
gives you Ctrl+S on Linux/Windows and Cmd+S on macOS without platform
checks.

There is also `Plushie.Subscription.on_key_release/1` if you need to track
key-up events.

### Applying it: pad keyboard shortcuts

Add keyboard shortcuts to the pad:

```elixir
def subscribe(_model) do
  [Plushie.Subscription.on_key_press(:keys)]
end

def update(model, %Key{key: "s", modifiers: %{command: true}}) do
  # Ctrl+S / Cmd+S: save and compile
  case compile_preview(model.source) do
    {:ok, tree} ->
      if model.active_file, do: save_experiment(model.active_file, model.source)
      %{model | preview: tree, error: nil}

    {:error, msg} ->
      %{model | error: msg, preview: nil}
  end
end

def update(model, %Key{key: "n", modifiers: %{command: true}}) do
  # Ctrl+N / Cmd+N: focus the new experiment input
  {model, Plushie.Command.focus("new-name")}
end

def update(model, %Key{key: :escape}) do
  # Escape: clear error display
  %{model | error: nil}
end
```

The reader builds these shortcuts themselves -- this is a real feature, not a
demonstration. Ctrl+S saves, Ctrl+N focuses the new experiment input, and
Escape dismisses errors.

## Timer subscriptions

`Plushie.Subscription.every/2` fires on a recurring interval:

```elixir
Plushie.Subscription.every(1000, :tick)
```

This delivers a `Plushie.Event.Timer` struct every 1000 milliseconds:

```elixir
alias Plushie.Event.Timer

def update(model, %Timer{tag: :tick}) do
  %{model | time: DateTime.utc_now()}
end
```

The `tag` field in the Timer event matches the tag you gave the subscription.
This is different from renderer subscriptions (like `on_key_press`) where
the tag is for management only and does not appear in the event.

### Conditional subscriptions

Because `subscribe/1` is a function of the model, you can activate
subscriptions conditionally:

```elixir
def subscribe(model) do
  subs = [Plushie.Subscription.on_key_press(:keys)]

  if model.auto_save and model.dirty do
    [Plushie.Subscription.every(1000, :auto_save) | subs]
  else
    subs
  end
end
```

When `auto_save` is false or the content has not changed, the timer is not in
the list, so the runtime stops it. When the conditions are met, the timer
starts. No manual start/stop logic needed.

### Applying it: wire up auto-save

In chapter 6 we added the auto-save checkbox but did not wire it up. Now we
can. We need a `dirty` flag that tracks whether the source has changed since
the last save:

```elixir
# In update/2, when editor content changes:
def update(model, %WidgetEvent{type: :input, id: "editor", value: source}) do
  %{model | source: source, dirty: true}
end

# In subscribe/1:
def subscribe(model) do
  subs = [Plushie.Subscription.on_key_press(:keys)]

  if model.auto_save and model.dirty do
    [Plushie.Subscription.every(1000, :auto_save) | subs]
  else
    subs
  end
end

# Handle the timer:
def update(model, %Timer{tag: :auto_save}) do
  case compile_preview(model.source) do
    {:ok, tree} ->
      if model.active_file, do: save_experiment(model.active_file, model.source)
      %{model | preview: tree, error: nil, dirty: false}

    {:error, msg} ->
      %{model | error: msg, preview: nil}
  end
end
```

When auto-save is checked and the content has changed, a timer fires every
second. The handler compiles, saves, and clears the dirty flag. Once the
flag is cleared, the subscription disappears from the list and the timer
stops -- until the next edit.

## Other subscriptions

Plushie provides subscriptions for many event sources beyond keyboard and
timers:

- **Mouse**: `on_mouse_move/1`, `on_mouse_button/1`, `on_mouse_scroll/1`
- **Window lifecycle**: `on_window_close/1`, `on_window_resize/1`,
  `on_window_event/1`, `on_window_open/1`, `on_window_focus/1`,
  `on_window_unfocus/1`, `on_window_move/1`
- **Touch**: `on_touch/1`
- **IME**: `on_ime/1` for input method editor events
- **System**: `on_theme_change/1`, `on_animation_frame/1`, `on_file_drop/1`
- **Catch-all**: `on_event/1` for any renderer event

Each returns its corresponding event struct in `update/2`. The tag argument
is for managing subscriptions (diffing, starting, stopping) -- for renderer
subscriptions, the tag does not appear in the delivered event. Timer
subscriptions are the exception: the tag is embedded in the `%Timer{}` event.

See the [Subscriptions reference](../reference/subscriptions.md) for the
complete list and details.

## Rate limiting

High-frequency events like mouse movement can overwhelm `update/2`.
`Plushie.Subscription.max_rate/2` throttles delivery:

```elixir
Plushie.Subscription.on_mouse_move(:mouse)
|> Plushie.Subscription.max_rate(30)
```

This caps delivery to 30 events per second. The renderer coalesces
intermediate events, delivering only the latest state at each interval.

You can also set `max_rate` as a constructor option:

```elixir
Plushie.Subscription.on_mouse_move(:mouse, max_rate: 30)
```

Rate limiting works at three levels, from most to least specific:

1. **Per-widget**: `event_rate:` prop on individual widgets
2. **Per-subscription**: `max_rate` on subscription specs
3. **Global**: `default_event_rate` in `c:Plushie.App.settings/0`

More specific settings override less specific ones. See the
[Subscriptions reference](../reference/subscriptions.md) for details.

## Window-scoped subscriptions

In multi-window apps, you can scope subscriptions to a specific window:

```elixir
Plushie.Subscription.for_window("settings", [
  Plushie.Subscription.on_key_press(:settings_keys)
])
```

This delivers key events only from the "settings" window.

## Verify it

Test that the Ctrl+S shortcut compiles the preview:

```elixir
test "ctrl+s saves and compiles" do
  press("ctrl+s")
  assert_exists("#preview/greeting")
end
```

This verifies the full subscription pipeline: the key subscription is
active, the runtime delivers the `%Key{}` event, your handler compiles
the source and updates the preview.

## Try it

Write a subscription experiment in your pad:

- Build a clock: subscribe to `every(1000, :tick)` and display the current
  time. Watch the display update every second.
- Subscribe to `on_key_press(:keys)` and log key names in a list. Press
  modifier keys and see how `modifiers` changes.
- Try a conditional subscription: subscribe to a timer only when a checkbox
  is checked. Toggle the checkbox and observe the timer starting and
  stopping.

In the next chapter, we will add file dialogs, clipboard integration, and
multi-window support to the pad.
