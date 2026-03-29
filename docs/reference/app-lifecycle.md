# App Lifecycle

Reference for the `Plushie.App` callback lifecycle, supervision
structure, startup sequence, update cycle, and error recovery.
See `Plushie.App` module docs for callback details and examples.

## Callbacks

| Callback | Signature | Return | Required |
|---|---|---|---|
| `c:Plushie.App.init/1` | `init(opts)` | `model \| {model, command}` | yes |
| `c:Plushie.App.update/2` | `update(model, event)` | `model \| {model, command}` | yes |
| `c:Plushie.App.view/1` | `view(model)` | window node(s), `nil`, or `[]` | yes |
| `c:Plushie.App.subscribe/1` | `subscribe(model)` | `[Plushie.Subscription.t()]` | no (default `[]`) |
| `c:Plushie.App.settings/0` | `settings()` | `keyword()` | no (default `[]`) |
| `c:Plushie.App.window_config/1` | `window_config(model)` | `map()` | no (default `%{}`) |
| `c:Plushie.App.handle_renderer_exit/2` | `handle_renderer_exit(model, reason)` | `model` | no (default: model unchanged) |

`command` is `Plushie.Command.t()` or `[Plushie.Command.t()]`.
See `Plushie.Command` for the full command API.

## settings/0 keys

| Key | Type | Default | Notes |
|---|---|---|---|
| `default_font` | font specification map | renderer default | same format as font props |
| `default_text_size` | number | renderer default | pixels |
| `antialiasing` | boolean | renderer default | |
| `vsync` | boolean | `true` | sync frame presentation with display refresh |
| `scale_factor` | number | `1.0` | multiplier on top of OS DPI scaling; per-window override via window node prop |
| `theme` | atom, `:system`, or palette map | renderer default | see `Plushie.Type.Theme` |
| `fonts` | list of paths | `[]` | font files to load |
| `default_event_rate` | integer | unlimited | max events/sec for coalescable types; per-subscription `max_rate` and per-widget `event_rate` override |

## Supervision tree

`Plushie` is a `Supervisor` using the `:rest_for_one` strategy with
`auto_shutdown: :any_significant`.

Children start in order:

1. `Plushie.Bridge` -- opens the renderer port (`:spawn`) or attaches
   to stdin/stdout (`:stdio`). Marked `:transient` + `:significant`.
2. `Plushie.Runtime` -- owns app state and the update loop. Marked
   `:transient` + `:significant`.
3. `Plushie.Dev.DevServer` -- (optional) file watcher and recompiler.
   Started only when `:code_reloader` is enabled. Marked `:transient`.

If Bridge crashes, Runtime restarts too (rest_for_one). If Runtime
crashes alone, it re-sends settings and a full snapshot to the
still-running Bridge. When any significant child exits normally,
the entire tree shuts down (auto_shutdown).

### Instance naming

Given `:name` option `MyApp` (default `Plushie`):

| Process | Registered name |
|---|---|
| Supervisor | `MyApp.Supervisor` |
| Bridge | `MyApp.Bridge` |
| Runtime | `MyApp.Runtime` |
| DevServer | `MyApp.DevServer` |

Use `Plushie.runtime_for/1` and `Plushie.bridge_for/1` to resolve
names programmatically.

## Startup sequence

Verified against `Plushie.Runtime.handle_continue(:initial_render)`:

1. `c:Plushie.App.init/1` -- produce initial model and optional commands
2. Send `c:Plushie.App.settings/0` to the renderer
3. `c:Plushie.App.view/1` -- render initial tree, send full snapshot
4. Derive widget handler registry from the tree
5. Execute init commands
6. Sync subscriptions
7. Sync window state (open/close/update)

## Update cycle

On each event:

1. `c:Plushie.App.update/2` -- event + current model -> new model + commands
2. Execute returned commands
3. `c:Plushie.App.view/1` -- new model -> new tree
4. Diff new tree against previous tree; send patch (or full snapshot
   if previous tree is `nil`). Snapshot resets renderer caches;
   patches preserve them.
5. `c:Plushie.App.subscribe/1` -- diff active subscriptions, start/stop as needed
6. Sync window state

## Error recovery

### update/2 exceptions

Model reverts to its pre-exception state. Log levels escalate by
consecutive error count:

| Consecutive errors | Log behavior |
|---|---|
| 1--10 | `:error` level with stacktrace |
| 11--100 | `:debug` level with stacktrace |
| 101 | `:warning` -- suppression notice |
| 102+ | silent, with `:warning` reminders every 1000th error |

The counter resets on a successful `update/2` call.

### view/1 exceptions

Previous tree is preserved. Logged at `:error` level.

### Renderer crash

`Plushie.Bridge` manages restart with exponential backoff:

- Formula: `min(restart_delay * 2^attempt, max_backoff)`
- Default `restart_delay`: 100 ms
- Max backoff: 5000 ms
- Default max restarts: 5

On successful reconnection, the restart counter resets to zero.
If the limit is exhausted, Bridge stops with
`{:max_restarts_reached, reason}`.

### State re-sync on restart

When the renderer restarts:

1. `c:Plushie.App.handle_renderer_exit/2` -- opportunity to adjust model
2. Settings re-sent to new renderer process
3. `c:Plushie.App.view/1` re-evaluated; full snapshot sent (old tree
   set to `nil`)

## Daemon mode

Pass `daemon: true` to `Plushie.start_link/2`.

| Mode | Last window closes | Behavior |
|---|---|---|
| normal (default) | dispatches `%Plushie.Event.SystemEvent{type: :all_windows_closed}` through `update/2`, then shuts down | app can run cleanup in update/2 before exit |
| daemon | dispatches `%Plushie.Event.SystemEvent{type: :all_windows_closed}` through `update/2` | runtime stays alive; app can open new windows via commands |

## See also

- `Plushie.App` -- callback docs and examples
- `Plushie.Runtime` -- update loop internals, sync queries
- `Plushie.Bridge` -- wire protocol, transport modes, restart behavior
- `Plushie.Command` -- command types and side effects
- `Plushie.Subscription` -- subscription specs
- [Getting Started](../guides/02-getting-started.md) -- first app, the Elm loop
- [Your First App](../guides/03-your-first-app.md) -- init/update/view in practice
