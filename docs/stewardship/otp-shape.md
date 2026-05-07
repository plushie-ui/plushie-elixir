# OTP shape

How plushie-elixir's runtime is structured under OTP, why the
parts split the way they do, and the supervision discipline that
holds them together. Other host SDKs have their own concurrency
shape; this is plushie-elixir's, and it is downstream of Elixir
and BEAM idioms rather than cross-SDK convergence.

## The Bridge/Runtime split

Two GenServers, one supervisor:

- **Bridge** owns the Port (the OS process or the `{:iostream, pid}`
  transport adapter). It owns wire framing, transport I/O,
  renderer process lifecycle, and the restart-on-crash behavior.
  It knows nothing about apps, models, views, or commands.
- **Runtime** owns the app's `init/update/view` loop, the
  current model and tree, the subscription set, the widget
  handler registry, and command execution. It knows nothing
  about the wire format or the renderer process.

Bridge speaks wire, Runtime speaks Elm. They communicate
through Erlang messages: Runtime `cast`s settings, snapshots,
patches, and effects to Bridge; Bridge sends parsed events
back to Runtime.

This split exists because the two responsibilities have
different lifetimes and different failure modes. Bridge
crashes are renderer crashes; the recovery is restart the
binary and replay state. Runtime crashes are app code
crashes; the recovery is revert to the last good model.
Mixing the two would couple recovery paths that should be
independent.

## Supervision: rest_for_one

The top-level supervisor uses `:rest_for_one`:

```
Plushie.Supervisor (rest_for_one, auto_shutdown: :any_significant)
├── Task.Supervisor      (started first)
├── Bridge               (significant, transient)
├── Runtime              (significant, transient)
└── DevServer            (dev mode only, transient)
```

The order matters:

- **Task.Supervisor** starts first so `:async` and `:stream`
  commands always have a parent. Runtime starts processing
  events before its first command, but the supervisor for those
  commands has to exist before the first command runs.
- **Bridge** starts before Runtime. Runtime's
  `handle_continue(:initial_render)` fires immediately and
  casts Settings + Snapshot to Bridge. If Bridge has not
  registered yet, those casts are lost and the renderer hangs
  on stdin.
- **Runtime** starts last. By the time it begins, both Task
  supervisor and Bridge are ready.

Supervision behavior:

- **Bridge crashes**, Runtime restarts too (rest_for_one).
  Fresh start: a new bridge spawns the renderer, Runtime sends
  Settings and a fresh Snapshot.
- **Runtime crashes alone**, only Runtime restarts. The bridge
  and renderer keep running; Runtime re-sends settings and
  snapshot to bring state back in sync.
- `:transient` means clean exits do not restart. A user app
  that closes its last window (via `Command.exit/0` or
  `:exit_on_close_request`) shuts down the supervisor cleanly.
- `:auto_shutdown: :any_significant` means a clean exit in a
  significant child tears down the tree.

## GenServer over Task for the runtime loop

The runtime is a GenServer, not a Task or a recursive process
loop. This is deliberate:

- Synchronous reads (`get_model`, `get_tree`, `health`) are the
  test framework's bedrock. A GenServer call is the right tool
  for synchronous reads from outside the process.
- Sync barriers (`Plushie.Runtime.sync/1`) are GenServer calls
  that flush the mailbox up to the call point. Tests and
  external callers need this guarantee.
- Mailbox handling for events, command results, timers, and
  subscription sources is uniform under `handle_info/2` /
  `handle_cast/2` / `handle_call/3`. A bespoke loop would have
  to reinvent the same shapes.

The runtime has substantial internal complexity (handler
registries, scope chains, view error tracking, dev overlay,
coalescing) but the GenServer shape is the same shape every
Elixir engineer expects.

## Transport behaviour

`Plushie.Transport` defines callbacks for `init/1`,
`send_data/2`, `close/1`, `handle_info/2`. Two implementations:

- `Transport.Port` - Erlang Port for `:spawn` (fork the binary)
  and `:stdio` (use the current process's stdin/stdout) modes.
  The standard production transport.
- `Transport.Iostream` - message-based adapter for
  `{:iostream, pid}`. Used by the test session pool to
  multiplex multiple test sessions over a single shared
  renderer process.

Bridge delegates all transport I/O through the behaviour. New
transport modes (a future TLS transport, a future named-pipe
transport) implement the behaviour without touching Bridge
internals.

This is the kind of small, well-justified abstraction that
earns its place: two real implementations from day one, the
shared shape (init, send, close, handle messages) is genuinely
the same concept, and the Bridge code reads cleanly against
the behaviour.

## SessionPool architecture

The test framework runs sessions through a pool:

- **Multiplexed pool** (`SessionPool.Multiplexed`) for `:mock`
  and `:headless` backends. One renderer process started with
  `--max-sessions N`; each test gets a session ID. Wire
  messages are tagged with the session ID; the renderer routes
  to per-session state internally. Session startup is
  microseconds; renderer startup is amortized across the
  suite.
- **Windowed pool** (`SessionPool.Windowed`) for the
  `:windowed` backend. One renderer process per session
  because real iced windows do not multiplex cleanly. Slower;
  used when window lifecycle matters.

The pool wraps the production `Plushie.Bridge` and `Plushie.Runtime`;
it is not a separate runtime. Tests use `Plushie.Test.Case`
which sets up a session and gives the test a runtime PID to
talk to. The runtime itself is the production runtime.

## What's not used

- **No `:sys` debug functions.** `:sys.get_state/1`,
  `:sys.replace_state/2`, `:sys.get_status/1`, etc. are debug
  tools, not production APIs. Tests use `Runtime.sync/1`,
  `Runtime.get_model/1`, `Runtime.get_tree/1`. See
  `test-discipline.md`.
- **No registry-based dynamic supervision for runtimes.** The
  runtime is registered by name (`Plushie.Runtime` or a custom
  name); a project that wants multiple Plushie instances passes
  `:name` and gets `<name>.Runtime`, `<name>.Bridge`, etc. There
  is no use case for hundreds of dynamically-spawned plushie
  instances; if one appears, the shape can be revisited.
- **No GenStage/Flow/Broadway in the event path.** The runtime
  processes events serially. Event coalescing for high-frequency
  sources happens at message arrival, not through a stage
  pipeline. Streams are simpler and the runtime's mailbox is
  not a bottleneck at the rates we target.
- **No Phoenix.PubSub or distributed messaging.** plushie-elixir
  is a desktop runtime. Distribution is not in scope.
- **No `Application.start/0` / `application :mod` registration.**
  The user starts plushie under their own supervisor (or directly
  via `Plushie.start_link/2`); we are a library, not an OTP
  application. Apps are application code; libraries that
  auto-start runtimes are a known anti-pattern.

## Process registration

Names are derived from the `:name` opt:

- `<name>.Supervisor` - the top-level supervisor.
- `<name>.Bridge` - the bridge GenServer.
- `<name>.Runtime` - the runtime GenServer.
- `<name>.TaskSupervisor` - the Task supervisor.
- `<name>.DevServer` - the dev file watcher (dev mode only).

`Plushie.runtime_for/1` and `Plushie.bridge_for/1` resolve
names for callers that need the registered atom.

## Implications

- A change that introduces a new long-lived process gets a
  supervision-level question first: where does it fit in the
  rest_for_one chain, what is its restart strategy, what is
  its transient-or-permanent posture, what does its crash mean
  for the rest of the tree.
- A change that makes Bridge or Runtime do something the other
  one already does is suspect. Wire framing in Runtime is wrong;
  app state in Bridge is wrong.
- A change that calls `:sys` functions in production code or
  tests is rewritten to use the public Runtime API.
- Tests that rely on internal process structure (assuming a
  specific name, peeking at supervisor children) are brittle
  and get rewritten to use the public test framework.
