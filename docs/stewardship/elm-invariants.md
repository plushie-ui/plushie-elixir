# Elm-architecture invariants

The contract between user apps and the runtime. These invariants
hold across every plushie-elixir app; the runtime enforces them
and the test framework relies on them. Other host SDKs implement
the same shape (modulo language idiom); plushie-elixir is the
canonical reference per `posture.md`.

## The three callbacks

A Plushie app implements `Plushie.App`:

- `init(opts) :: model | {model, command}` - called once at
  startup. Returns the initial model, optionally with commands
  to dispatch (load initial data, configure UI).
- `update(model, event) :: model | {model, command}` - called
  for every event. Returns the next model, optionally with
  commands.
- `view(model) :: window_node | [window_node] | nil` - called
  after every update. Returns a window or list of windows. Pure
  function of model.

Optional callbacks: `subscribe/1`, `handle_renderer_exit/2`,
`window_config/1`, `settings/0`. Defaults are provided by
`use Plushie.App`.

## Return-shape validation

`init/1` and `update/2` must return one of:

- A bare model (no side effects needed).
- `{model, %Plushie.Command{}}` (single command).
- `{model, [%Plushie.Command{}]}` (list of commands; can be
  empty).

`unwrap_result/1` in the runtime enforces this. Anything else
raises `ArgumentError` immediately:

- A two-tuple where the second element is neither a `Command`
  nor a list of `Command`s raises with the offending shape.
- A larger tuple (e.g., `{model, command, extra}`) raises with
  the tuple size and the expected shapes listed.
- A list inside the command list that contains a non-Command
  raises with the offending element.

This is fail-fast on purpose. A misshapen return silently
corrupting state is harder to debug than an immediate raise.
The error message names the function (`init/1` or `update/2`)
and shows what was returned, so the user can correct the call
site without further investigation.

There is no `{model, command, opts}` shape, no
`{:noreply, model}` shape, no implicit list-flatten, no shape
that returns "no change." A bare model is the no-change shape.

## Commands are pure data

A command is a `%Plushie.Command{type: atom, payload: term}`
struct. The runtime executes it; user code never executes a
command directly. This is what makes `update/2` testable
without going through I/O: the test asserts the command was
returned; the runtime is what would have run it.

Categories (`Plushie.Command`):

- Async work: `:async`, `:stream`, `:cancel`, `:done`.
- Widget operations: `:focus`, `:scroll`, `:select`, `:cursor`,
  `:widget_op`.
- Window operations: `:close_window`, `:window_op`,
  `:window_query`.
- Effects: `:effect` (file dialogs, clipboard, notifications).
- Lifecycle: `:send_after`, `:exit`, `:batch`.
- Widget commands (native): `:widget_command`,
  `:widget_commands`.
- Images: `:image_op`.
- Animation: `:advance_frame`.

A user dispatching a side effect that is not a command is a
design problem with the side effect, not a request for a new
escape hatch. If a needed side effect cannot be expressed as a
command, the missing command is the work.

## View is a pure function of model

`view/1` returns the UI tree from the model. It does not access
process state, does not call out to other GenServers, does not
read ETS, does not perform I/O. The runtime calls `view/1`
after every update; it must be deterministic from the model
alone.

Pure-Elixir composite widgets defined via `use Plushie.Widget`
that take internal state (`state` declarations, `view/3`) are
the exception, but the state is owned by the runtime and
threaded into `view/3` deterministically; the widget body is
still pure with respect to the inputs it receives.

The top level of the view must be a window node or a list of
window nodes (or `nil`/`[]` for an app with no open windows).
`validate_root_windows!` enforces this; a bare `column` or
`row` at the top level is an error.

## Subscriptions are declarative

`subscribe(model) :: [Plushie.Subscription.t()]` returns the
list of active subscriptions. The runtime diffs this list each
cycle, starts new subscriptions and stops removed ones. The
user does not start or stop subscriptions imperatively; they
return the list and the runtime reconciles.

Timer subscriptions run in the runtime process. Other
subscriptions (key, mouse, window events) are forwarded to the
bridge as wire messages. Subscription failures surface as
events through the normal dispatch path.

## Widget event flow

Events from the renderer arrive at the runtime, flow through
widget event interception, and reach `update/2`:

1. Event arrives from bridge.
2. Runtime walks the widget handler scope chain (innermost
   first) for handlers registered for this event family/id.
3. Each handler's `handle_event/2` returns one of:
   - `:ignored` - handler did not capture; continue to next.
   - `:consumed` - captured, no output; stop the chain.
   - `{:update_state, new_state}` - captured, persist widget
     state; stop.
   - `{:emit, family, data}` - captured, replace the event with
     the emitted one; continue with the new event up the
     chain.
   - `{:emit, family, data, new_state}` - emit + persist state.
4. If the chain returns an event (or the original was not
   captured), it reaches `update/2`.

Canvas-internal events (`:canvas_element_*`) that no handler
captures are auto-consumed by the runtime; they never reach
`update/2`. View-only widgets (no events, no state) are
transparent; events pass through.

This matches iced's captured/ignored model on the renderer side
and is part of the cross-SDK shape.

## Scoped IDs

Wire IDs use the canonical format `window#scope/path/id`:

- `"main#form/email"` - widget `email` inside scope `form`
  inside window `main`.
- `"main"` - the window itself.

Events on the runtime side carry split fields: `id` (local),
`scope` (reversed ancestor chain, immediate parent first),
`window_id` (window). This shape is what user pattern matching
operates on:

```elixir
def update(model, %WidgetEvent{id: "save", scope: ["form" | _]}), do: ...
def update(model, %WidgetEvent{id: "done", scope: [item_id | _]}), do: ...
```

Commands use forward-order path strings:
`Command.focus("form/email")`.
`Plushie.Event.target/1` reconstructs the full path from an
event when needed.

Auto-ID containers (no explicit ID, ID generated by the DSL) do
not create a scope. Window nodes do not create a scope; they
are the window component of the wire ID. `"/"` is forbidden in
user-provided IDs.

`Plushie.ScopedId` parses and constructs the canonical form.

## What these invariants buy

- **Tests can be written.** A pure `update/2` plus pure data
  commands plus a pure `view/1` is exercisable through the
  integration spine without elaborate setup. The user never
  needs to "wait for an effect" in their tests; they assert on
  what was returned.
- **The runtime can revert on exception.** Because `update/2`
  is a pure function that returns the new model, the runtime
  can keep the previous model and recover by reverting. Same
  for `view/1`: a previous tree is preserved and used as the
  fallback.
- **The bridge can re-sync after a renderer crash.** The
  current model is enough to regenerate the full tree and
  re-establish state. The renderer holds no app state the
  runtime cannot reconstruct.
- **Cross-SDK parity is meaningful.** "What does plushie-elixir
  do here" has a precise answer; other SDKs implement the same
  contract.
