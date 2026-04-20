# App Lifecycle

A Plushie app implements the [Elm architecture](https://guide.elm-lang.org/architecture/):
`init` produces a model, `update` handles events, `view` returns a UI
tree. The runtime manages the loop, the Bridge manages the renderer
process, and the supervision tree ties them together.

This reference covers the full lifecycle: callbacks, supervision,
startup, the update cycle, error recovery, and window management.

## Callbacks

Every Plushie app implements the `Plushie.App` behaviour. Three
callbacks are required; four are optional.

| Callback | Signature | Return | Required |
|---|---|---|---|
| `init/1` | `init(opts)` | `model \| {model, command}` | yes |
| `update/2` | `update(model, event)` | `model \| {model, command}` | yes |
| `view/1` | `view(model)` | window node(s) | yes |
| `subscribe/1` | `subscribe(model)` | `[Subscription.t()]` | no |
| `settings/0` | `settings()` | `map()` | no |
| `window_config/1` | `window_config(model)` | `map()` | no |
| `handle_renderer_exit/2` | `handle_renderer_exit(model, %RendererExitError{})` | `model` | no |

Where `command` is `Plushie.Command.t()` or `[Plushie.Command.t()]`.

### init/1

Called once at startup with the `app_opts` keyword list from
`Plushie.start_link/2` (default `[]`). Returns the initial model,
optionally paired with commands to execute after the first render.

The return value is validated: it must be a bare model, a
`{model, %Command{}}` tuple, or a `{model, [%Command{}]}` tuple.
Anything else raises `ArgumentError` immediately. This catches bugs
like returning `{model, :ok}` at startup rather than silently
corrupting state.

### update/2

Called for every event. Receives the current model and the event,
returns the next model (optionally with commands). The same return
validation applies as `init/1`.

Always include a catch-all clause:

```elixir
def update(model, _event), do: model
```

Without one, unhandled events crash the update cycle. The runtime
catches the exception and reverts the model (see
[error recovery](#error-recovery)), but the error noise is avoidable.

### view/1

Called after every successful `update/2`. Returns one or more `window`
nodes describing the current UI. The runtime diffs the new tree against
the previous one and sends only the changes to the renderer.

`view/1` runs after every successful update, even if the model
hasn't changed. There is no model-equality check that skips it. The
optimisation happens at the diff stage: if the new tree is identical
to the old one, no patch is sent and no wire traffic occurs. When
`update/2` raises an exception, `view/1` is skipped entirely and the
previous tree is preserved.

### subscribe/1

Called after each update cycle. Returns a list of active subscription
specs (timers, keyboard, mouse, window events). The runtime diffs this
list against the currently active subscriptions: new specs start, removed
specs stop. Subscriptions are a function of the model. Return different
lists based on model state to conditionally activate them.

Default: `[]` (no subscriptions).

See the [Subscriptions reference](subscriptions.md) for subscription
types and rate limiting.

### settings/0

Called once during startup to configure renderer-level defaults (font,
text size, theme, antialiasing, event rate). Sent to the renderer
before the first snapshot.

Default: `%{}` (renderer uses its own defaults).

See the [Configuration reference](configuration.md#app-settings-callback)
for the full key table.

### window_config/1

Called when new windows are opened or reopened after a renderer restart.
Returns a base settings map that is merged with per-window props from the
view tree. The merged result is sent to the renderer as a window open
operation.

Supported keys: `title`, `size`, `width`, `height`, `position`,
`min_size`, `max_size`, `maximized`, `fullscreen`, `visible`,
`resizable`, `closeable`, `minimizable`, `decorations`, `transparent`,
`blur`, `level`, `exit_on_close_request`.

Default: `%{}` (only per-window props from the tree apply).

### handle_renderer_exit/2

Called when the renderer process crashes or is restarted (e.g. during
Rust hot reload). Receives the current model and a `%Plushie.RendererExitError{}`
struct with `:type` (`:crash`, `:shutdown`, `:heartbeat_timeout`, or
`:connection_lost`), `:message`, and `:details`.
Returns a potentially adjusted model.

This is your opportunity to reset state that depends on renderer-side
resources (e.g. clear animation progress, reset scroll positions). The
runtime re-renders and sends a fresh snapshot to the new renderer after
this callback returns.

Default: model returned unchanged. If the handler raises, the exception
is logged and the model reverts to its pre-exit state.

## Supervision tree

`Plushie` is a `Supervisor` using the `:rest_for_one` strategy with
`auto_shutdown: :any_significant`.

Children start in order:

1. **`Plushie.Bridge`** - opens the renderer port (`:spawn`) or
   attaches to the transport (`:stdio`, `{:iostream, pid}`). Owns the
   wire connection. Marked `:transient` + `:significant`.
2. **`Plushie.Runtime`** - owns the app model and runs the update loop.
   Marked `:transient` + `:significant`.
3. **`Plushie.Dev.DevServer`** - (optional) file watcher and recompiler.
   Started only when `:code_reloader` is enabled. Marked `:transient`.

**`:rest_for_one`** means if Bridge crashes, Runtime restarts too (it
depends on Bridge). If Runtime crashes alone, Bridge stays running and
Runtime re-syncs by sending settings and a full snapshot to the
existing Bridge.

**`auto_shutdown: :any_significant`** means when any significant child
(Bridge or Runtime) exits normally, the entire supervision tree shuts
down. This is how closing the last window exits the app: the runtime
stops normally, which triggers auto_shutdown.

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

The full sequence from `Plushie.start_link/2` to a rendered window:

1. Supervisor starts Bridge, then Runtime
2. Runtime calls `init/1`, producing initial model and optional commands
3. `handle_continue(:initial_render)` fires:
   a. Settings from `settings/0` sent to renderer
   b. `view/1` called with initial model; full snapshot sent to renderer
   c. Widget handler registry derived from the tree
   d. **Init commands execute** (after the first snapshot, not before)
   e. Subscriptions synced via `subscribe/1`
   f. Window state synced (opens windows detected in the tree)

Init commands execute **after** the first snapshot is sent. This means
async commands from `init/1` queue their results for the next update
cycle. The user sees the initial UI immediately; command results arrive
as events in subsequent updates.

## Update cycle

On each event:

1. **`update/2`** - event + current model -> new model + commands
2. **Execute commands** - synchronous commands run immediately; async
   commands spawn tasks; effect commands go to the renderer
3. **`view/1`** - new model -> new tree (runs unconditionally)
4. **Diff and patch** - new tree compared against previous tree. If
   different, a patch is sent to the renderer. If identical, no wire
   traffic. A full snapshot (instead of a patch) is sent when the
   previous tree is `nil` (startup, renderer restart).
5. **`subscribe/1`** - diff active subscriptions, start new ones, stop
   removed ones
6. **Sync windows** - detect new/removed/changed windows in the tree,
   send open/close/update operations to the renderer

Steps 3-6 happen inside `render_and_sync/1`. The entire cycle is
synchronous within the Runtime GenServer. There are no concurrent updates.

### Window sync

The runtime extracts window nodes from the view tree and compares them
against the previous set:

- **New windows** (ID in new tree but not old): calls `window_config/1`
  for base settings, merges with per-window props from the tree, sends
  an open operation to the renderer.
- **Removed windows** (ID in old tree but not new): sends a close
  operation.
- **Changed windows** (ID in both, props differ): sends an update
  operation with only the changed props.

Window IDs must be stable strings. If a window ID changes between
renders, the runtime sees it as a close + open, not an update. The
renderer closes the old window and opens a new one.

## Error recovery

### update/2 exceptions

If `update/2` raises, the model reverts to its pre-exception state.
The UI stays on the previous successful render. Log levels escalate
by consecutive error count to prevent log flooding:

| Consecutive errors | Log behavior |
|---|---|
| 1-10 | `:error` level with full stacktrace |
| 11-100 | `:debug` level with stacktrace |
| 101 | `:warning` suppression notice |
| 102+ | silent, with `:warning` reminders every 1000 errors |

The counter resets to zero on the next successful `update/2` call.
This escalation prevents a hot loop of errors from filling disk with
logs while still making the first errors highly visible.

### view/1 exceptions

If `view/1` raises, the previous tree is preserved (no patch sent).
The error is logged at `:error` level. A consecutive view error counter
tracks failures: at 5 consecutive errors, a `:warning` is logged
indicating the UI is stale. The counter resets on the next successful
render.

### Return value validation

Both `init/1` and `update/2` returns are validated immediately. Valid
shapes:

- `model` - bare model, no commands
- `{model, %Command{}}` - model + single command
- `{model, [%Command{}, ...]}` - model + command list

Invalid shapes raise `ArgumentError` with a descriptive message:

- `{model, :not_a_command}` - second element must be a Command
- `{model, commands, extra}` - tuples with more than 2 elements
- `{model, [valid_cmd, :invalid]}` - all list elements must be Commands

This catches bugs at the source rather than producing confusing errors
downstream.

### Renderer crash

`Plushie.Bridge` manages renderer restart with exponential backoff:

- Formula: `min(restart_delay * 2^attempt, max_backoff)`
- Default restart delay: 100ms
- Max backoff: 5000ms
- Default max restarts: 5

On successful reconnection (renderer sends `{:hello, _}`), the restart
counter resets to zero. If the limit is exhausted, Bridge stops with
`{:max_restarts_reached, reason}`, which triggers supervision tree
shutdown.

### State re-sync after renderer restart

When the renderer restarts successfully:

1. `handle_renderer_exit/2` called (opportunity to adjust model)
2. Settings re-sent to the new renderer process
3. `view/1` re-evaluated with a fresh tree diff baseline (`nil`),
   causing a full snapshot instead of a patch
4. Widget handler registry re-derived
5. Subscriptions re-synced
6. Window state re-synced (all windows re-opened)

Elixir-side widget state (managed by the Runtime) is preserved across
restarts. Renderer-side widget state (scroll offsets, cursor positions,
text editor state) resets because the new renderer process has no
memory of the old one.

## Daemon mode

Pass `daemon: true` to `Plushie.start_link/2`.

In both modes, closing all windows delivers
`%SystemEvent{type: :all_windows_closed}` to `update/2`. The
difference is what happens after:

| Mode | After last window closes |
|---|---|
| Normal (default) | `update/2` runs (for cleanup), then runtime shuts down |
| Daemon | `update/2` runs, runtime continues. Open new windows by returning them from `view/1`. |

Daemon mode is useful for tray-style apps, menu bar utilities, or apps
that re-open windows based on external events.

## See also

- `Plushie.App` - callback typespecs and examples
- `Plushie.Runtime` - update loop internals, `get_model/1`,
  `get_tree/1`, `sync/1`
- `Plushie.Bridge` - wire protocol, transport modes, restart logic
- `Plushie.Command` - command types returned from `init/1` and
  `update/2`
- `Plushie.Subscription` - subscription specs returned from
  `subscribe/1`
- [Configuration reference](configuration.md) - environment variables,
  app config, and `settings/0` key table
- [Events reference](events.md) - all event types delivered to
  `update/2`
- [Guide: Getting Started](../guides/02-getting-started.md) - the Elm
  loop in practice
