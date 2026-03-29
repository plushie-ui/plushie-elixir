# Subscriptions Reference

Subscriptions are declarative event sources managed by the runtime. You
return a list of subscription specs from `c:Plushie.App.subscribe/1` and
the runtime handles starting, stopping, and diffing them each cycle.

See `Plushie.Subscription` for the full module API.

## Timer subscriptions

| Function | Event delivered | Tag in event? |
|---|---|---|
| `Plushie.Subscription.every/2` | `Plushie.Event.Timer` | Yes -- `%Timer{tag: tag}` |

Timer subscriptions run in the runtime process. The tag you provide is
embedded in the `%Timer{}` event, so you match on it:

```elixir
def update(model, %Timer{tag: :auto_save}), do: ...
```

## Renderer subscriptions

Renderer subscriptions are forwarded to the renderer binary. The tag is
for management only (diffing, starting, stopping) -- it does **not** appear
in the delivered event.

| Function | Event delivered |
|---|---|
| `Plushie.Subscription.on_key_press/1` | `Plushie.Event.Key` |
| `Plushie.Subscription.on_key_release/1` | `Plushie.Event.Key` |
| `Plushie.Subscription.on_modifiers_changed/1` | `Plushie.Event.Modifiers` |
| `Plushie.Subscription.on_window_close/1` | `Plushie.Event.WindowEvent` |
| `Plushie.Subscription.on_window_event/1` | `Plushie.Event.WindowEvent` |
| `Plushie.Subscription.on_window_open/1` | `Plushie.Event.WindowEvent` |
| `Plushie.Subscription.on_window_resize/1` | `Plushie.Event.WindowEvent` |
| `Plushie.Subscription.on_window_focus/1` | `Plushie.Event.WindowEvent` |
| `Plushie.Subscription.on_window_unfocus/1` | `Plushie.Event.WindowEvent` |
| `Plushie.Subscription.on_window_move/1` | `Plushie.Event.WindowEvent` |
| `Plushie.Subscription.on_mouse_move/1` | `Plushie.Event.Mouse` |
| `Plushie.Subscription.on_mouse_button/1` | `Plushie.Event.Mouse` |
| `Plushie.Subscription.on_mouse_scroll/1` | `Plushie.Event.Mouse` |
| `Plushie.Subscription.on_touch/1` | `Plushie.Event.Touch` |
| `Plushie.Subscription.on_ime/1` | `Plushie.Event.Ime` |
| `Plushie.Subscription.on_theme_change/1` | `Plushie.Event.SystemEvent` |
| `Plushie.Subscription.on_animation_frame/1` | `Plushie.Event.SystemEvent` |
| `Plushie.Subscription.on_file_drop/1` | `Plushie.Event.WindowEvent` |
| `Plushie.Subscription.on_event/1` | Various (catch-all) |

## Rate limiting

`Plushie.Subscription.max_rate/2` throttles high-frequency events. The
renderer coalesces intermediate events, delivering only the latest state
at each interval.

```elixir
Plushie.Subscription.on_mouse_move(:mouse, max_rate: 30)
```

Rate `0` means "capture but never emit" -- useful for tracking interaction
without generating events.

### Three-level hierarchy

Rate limiting applies at three levels, from most to least specific:

1. **Per-widget** -- `event_rate:` prop on individual widgets
2. **Per-subscription** -- `max_rate` on subscription specs
3. **Global** -- `default_event_rate` in `c:Plushie.App.settings/0`

More specific settings override less specific ones.

## Window scoping

Scope subscriptions to a specific window:

```elixir
Plushie.Subscription.for_window("settings", [
  Plushie.Subscription.on_key_press(:settings_keys)
])
```

## Diffing lifecycle

The runtime calls `subscribe/1` after every update cycle and diffs the
result against the active subscriptions:

1. Generate a key for each spec: `{:every, interval, tag}` for timers,
   `{type, tag}` for renderer subscriptions.
2. **Short-circuit**: if the sorted key set is unchanged, only check for
   `max_rate` changes.
3. **New keys**: start timers or send subscribe messages to the renderer.
4. **Removed keys**: cancel timers or send unsubscribe messages.
5. **Changed max_rate**: re-send the subscribe message with the new rate.

This means subscriptions are idempotent. Returning the same spec list every
cycle costs almost nothing.

## Widget-scoped subscriptions

Custom widgets with a `subscribe/2` callback get namespaced subscriptions.
Tags are automatically prefixed with `{:__widget__, window_id, widget_id, tag}`
to prevent collisions. Timer events are routed through the widget's
`handle_event/2` callback, not the app's `update/2`.

See the [Custom Widgets guide](../guides/12-custom-widgets.md) for details.

## See also

- `Plushie.Subscription` -- module docs with specs and examples
- [Subscriptions guide](../guides/09-subscriptions.md) -- keyboard shortcuts, timers, auto-save
- [Events reference](events.md) -- the event structs delivered by subscriptions
