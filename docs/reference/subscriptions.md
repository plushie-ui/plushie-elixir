# Subscriptions

Subscriptions are declarative event sources. You return a list of
subscription specs from `c:Plushie.App.subscribe/1` and the runtime
handles starting, stopping, and diffing them each cycle. Subscriptions
are a function of the model. When the model changes, the active
subscriptions change with it.

See `Plushie.Subscription` for the full module API.

## Timer subscriptions

`Plushie.Subscription.every/2` fires on a recurring interval:

```elixir
def subscribe(model) do
  if model.auto_save and model.dirty do
    [Plushie.Subscription.every(1000, :auto_save)]
  else
    []
  end
end

def update(model, %TimerEvent{tag: :auto_save}), do: save(model)
```

Timer subscriptions run in the runtime process via `Process.send_after/3`.
After each tick, the timer is re-armed for the next interval. The tag
you provide is embedded in the `%TimerEvent{}` struct, so you match on
it in `update/2`.

If the timer interval changes between cycles (e.g. switching from
`every(1000, :tick)` to `every(500, :tick)`), the runtime cancels the
old timer and starts a new one automatically. No manual cleanup needed.

## Renderer subscriptions

Renderer subscriptions are forwarded to the renderer binary via the
wire protocol. The tag is for management only (diffing, starting,
stopping). It does **not** appear in the delivered event.

### Keyboard

| Function | Event delivered |
|---|---|
| `on_key_press/1` | `Plushie.Event.KeyEvent` |
| `on_key_release/1` | `Plushie.Event.KeyEvent` |
| `on_modifiers_changed/1` | `Plushie.Event.ModifiersEvent` |

`KeyEvent` includes `key` (atom for named keys like `:escape`,
`:enter`; string for characters like `"s"`, `"a"`), `modifiers`
(`Plushie.KeyModifiers` with boolean `ctrl`, `shift`, `alt`, `logo`,
`command` fields), and `type` (`:press` or `:release`).

The `command` modifier is platform-aware: Ctrl on Linux/Windows, Cmd on
macOS. Match on `command: true` for cross-platform shortcuts.

### Window lifecycle

| Function | Event delivered | Scope |
|---|---|---|
| `on_window_event/1` | `WindowEvent` | All window events |
| `on_window_open/1` | `WindowEvent` (`:opened`) | Open only |
| `on_window_close/1` | `WindowEvent` (`:close_requested`) | Close only |
| `on_window_resize/1` | `WindowEvent` (`:resized`) | Resize only |
| `on_window_focus/1` | `WindowEvent` (`:focused`) | Focus only |
| `on_window_unfocus/1` | `WindowEvent` (`:unfocused`) | Unfocus only |
| `on_window_move/1` | `WindowEvent` (`:moved`) | Move only |

`on_window_event/1` is a superset that delivers all window event types.
**If you subscribe to both `on_window_event` and a specific variant
(e.g. `on_window_resize`), matching events are delivered twice.** Use
one or the other, not both.

### Mouse

| Function | Event delivered |
|---|---|
| `on_mouse_move/1` | `Plushie.Event.MouseEvent` |
| `on_mouse_button/1` | `Plushie.Event.MouseEvent` |
| `on_mouse_scroll/1` | `Plushie.Event.MouseEvent` |

Mouse subscriptions are global. They deliver events regardless of
which widget is under the cursor. For widget-specific mouse handling,
use `pointer_area` instead.

### Other

| Function | Event delivered |
|---|---|
| `on_touch/1` | `Plushie.Event.TouchEvent` |
| `on_ime/1` | `Plushie.Event.ImeEvent` |
| `on_theme_change/1` | `Plushie.Event.SystemEvent` |
| `on_animation_frame/1` | `Plushie.Event.SystemEvent` |
| `on_file_drop/1` | `Plushie.Event.WindowEvent` |

`on_animation_frame/1` delivers vsync ticks for SDK-side animation via
`Plushie.Animation.Tween`. Renderer-side transitions (`transition()`,
`spring()`, `loop()`) do not require this subscription. They run
independently in the renderer.

### Catch-all

`on_event/1` subscribes to **all** renderer events: every widget
event, keyboard event, mouse event, window event, and system event.
Use it for debugging or logging, not as a primary event source. It
delivers a lot of traffic.

## All subscription constructors

Every subscription constructor takes a tag atom as the first argument
and an optional keyword list:

```elixir
Plushie.Subscription.on_key_press(:keys)
Plushie.Subscription.on_key_press(:keys, max_rate: 30)
Plushie.Subscription.on_mouse_move(:mouse, max_rate: 60)
Plushie.Subscription.every(1000, :tick)
```

The tag identifies the subscription for diffing. Two subscriptions with
the same type and tag are considered identical, so only one is active.

## Rate limiting

`max_rate/2` throttles high-frequency renderer events. The renderer
coalesces intermediate events, delivering only the latest state at each
interval:

```elixir
Plushie.Subscription.on_mouse_move(:mouse)
|> Plushie.Subscription.max_rate(30)
```

Or inline:

```elixir
Plushie.Subscription.on_mouse_move(:mouse, max_rate: 30)
```

`max_rate/2` returns a modified subscription struct. It works on
renderer subscriptions only. Timer subscriptions control their
frequency via the interval argument.

A rate of `0` means "capture but never emit." The subscription is
active (the renderer tracks the state) but no events are delivered.
Useful when you need capture tracking without event processing.

### Three-level hierarchy

Rate limiting applies at three levels, from most to least specific:

1. **Per-widget** - `event_rate:` prop on individual widgets
2. **Per-subscription** - `max_rate` on subscription specs
3. **Global** - `default_event_rate` in `c:Plushie.App.settings/0`

More specific settings override less specific ones. See the
[Configuration reference](configuration.md#app-settings-callback) for
the global setting.

## Window scoping

Scope subscriptions to a specific window in multi-window apps:

```elixir
Plushie.Subscription.for_window("settings", [
  Plushie.Subscription.on_key_press(:settings_keys)
])
```

Without window scoping, key events from any window are delivered.
With scoping, only events from the named window arrive.

## Conditional subscriptions

Because `subscribe/1` is a function of the model, you activate
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

When `auto_save` becomes false or the dirty flag clears, the timer
disappears from the list. The runtime stops it. When the conditions
are met again, the timer starts. No manual start/stop logic needed.

**Performance**: returning the same list every cycle is nearly free.
The runtime generates a sorted key set from the list and short-circuits
if it hasn't changed since the last cycle. Only `max_rate` changes are
checked. When the list does change, the diff is efficient: MapSet
operations identify added and removed subscriptions.

## Diffing lifecycle

The runtime calls `subscribe/1` after every update cycle and diffs the
result against active subscriptions:

1. Generate a key for each spec using `Plushie.Subscription.key/1`:
   - Timer: `{:every, interval, tag}`
   - Renderer: `{type, tag}`
2. Sort and compare keys against the previous cycle's key set.
3. **Short-circuit**: if the sorted key set is unchanged, only check
   for `max_rate` changes on existing subscriptions.
4. **New keys**: start timers (`Process.send_after`) or send subscribe
   messages to the renderer.
5. **Removed keys**: cancel timers (`Process.cancel_timer`) or send
   unsubscribe messages.
6. **Changed max_rate**: re-send the subscribe message with the new
   rate.

Subscriptions are idempotent. The same spec list produces no work.
Different lists trigger precise add/remove operations.

## Widget-scoped subscriptions

Custom widgets with a `subscribe/2` callback get namespaced
subscriptions. Tags are automatically wrapped in
`{:__widget__, window_id, widget_id, inner_tag}` to prevent collisions
between widget instances and app subscriptions.

Timer events matching this structure are intercepted and routed through
the widget's `handle_event/2` callback, not the app's `update/2`. The
widget sees only the inner tag in the event.

Multiple instances of the same widget each get independent subscriptions.
See the [Custom Widgets reference](custom-widgets.md#widget-scoped-subscriptions)
for details.

## See also

- `Plushie.Subscription` - module docs with full specs and examples
- [Subscriptions guide](../guides/10-subscriptions.md) - keyboard
  shortcuts, timers, and auto-save applied to the pad
- [Events reference](events.md) - the event structs delivered by
  subscriptions
- [Configuration reference](configuration.md) - `default_event_rate`
  and `settings/0`
- [Custom Widgets reference](custom-widgets.md) - widget-scoped
  subscriptions
