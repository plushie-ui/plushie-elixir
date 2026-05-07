# Resilience

plushie-elixir is meant to behave predictably when things go wrong:
an exception in the user's `update/2`, a malformed wire message
from the renderer, the renderer process crashing, a broken pipe,
a `view/1` that raises, a subscription source that explodes.
Resilience here is graceful behavior under those conditions, not
hardening against an attacker; that distinction lives in
`trust-model.md`.

The user-facing promise is the host SDK's half of the broader
plushie promise: a renderer crash auto-recovers with state
re-sync, an app exception reverts to the last good state, neither
side takes the other down. This doc describes how plushie-elixir
holds up that half.

## What resilience means here

- **App exception revert.** Exceptions in `init/1`, `update/2`,
  and `view/1` are caught by the runtime, logged, and the model
  reverts to its pre-call state. The user does not need to wrap
  callbacks in `try/rescue`. After a flood threshold the runtime
  suppresses further log lines; the next clean call clears the
  suppression.
- **View-error tracking with frozen-UI overlay.** Consecutive
  `view/1` failures are tracked. After the warn threshold the
  runtime injects a frozen-UI overlay into the tree so the user
  can see the app is degraded rather than staring at a stale UI.
  The overlay clears on the next successful render.
  `Plushie.Runtime.health/1` reports `:degraded` while frozen.
- **Renderer crash auto-recovery.** The bridge owns the Port. On
  unexpected exit it sends `Plushie.RendererExitError` to the
  runtime, restarts the renderer process, replays settings, and
  the runtime sends a fresh full snapshot to re-sync the tree.
  The user's `handle_renderer_exit/2` callback can adjust the
  model before re-sync (e.g., reset transient UI state). Restart
  is unconditional: there is no backoff loop. If the binary
  cannot start, the supervisor lets the bridge crash and
  `:rest_for_one` brings down the runtime; the supervising
  parent decides recovery.
- **Bridge/Runtime supervision.** `:rest_for_one`. If Bridge
  crashes, Runtime restarts too (fresh start). If Runtime
  crashes alone, only Runtime restarts; it re-sends settings
  and snapshot to the still-running Bridge. The Task supervisor
  starts before both so async commands always have a parent.
  See `concurrency-shape.md`.
- **Defensive parsing on the wire.** The codec assumes its input
  could be wrong: malformed MessagePack, unknown event variants,
  missing required fields, type-coercion mismatches. Rejection
  with `Plushie.Protocol.Error` is the right outcome; crashing
  is not.
- **Return-shape validation.** `init/1` and `update/2` must
  return a bare model, `{model, %Command{}}`, or
  `{model, [%Command{}]}`. Anything else raises `ArgumentError`
  immediately rather than silently corrupting state. See
  `elm-invariants.md`.
- **Subscription failure isolation.** A subscription source that
  raises does not take the runtime down. The error surfaces as
  a structured event through the normal dispatch path; the
  runtime's update loop survives.

## What is appropriate to fail fast on

Some conditions are not recoverable at the framework level and
should fail fast rather than degrade:

- **Programming errors that violate runtime invariants.** Wrong
  return shape from `init`/`update`, a widget struct with no
  registered `Tree.Node` impl, a leaked DSL metadata tuple in
  the rendered tree. The right behavior is a clear error,
  not silent fallback.
- **Unrecoverable bridge startup.** If `:spawn` mode cannot find
  the renderer binary, the bridge raises with a clear message at
  startup. Attempting to operate without a renderer is not a
  degraded mode worth supporting.
- **Wire framing corruption.** A truncated or unparseable frame
  on the bridge's input is not a recoverable condition; the
  bridge surfaces it and exits, the supervisor restarts.

The line: degrade gracefully on user-facing conditions (app code
errors, parse errors, transport hiccups, renderer crashes). Fail
fast on framework-level invariant violations.

## Patterns in the codebase

Worth maintaining as the project evolves:

- `try/rescue` around `init/1`, `update/2`, `view/1` calls in
  the runtime; revert-and-log on exception.
- Wire-edge validation in `Plushie.Protocol.Decode` and
  `Plushie.Protocol.Parsers`; structured errors, never silent
  passthrough of malformed input.
- Effect request tracking with timeout timers; stale responses
  dropped, in-flight responses correlated by wire ID.
- Bridge restart with fresh snapshot re-sync rather than
  attempting to replay buffered events.
- Coalescable event handling for high-frequency sources (mouse
  moves, scroll, slider drags) so a flooding renderer cannot
  overwhelm the runtime's mailbox.
- Suppression of repeated error logs after a flood threshold,
  with auto-clear on the next clean call.

## What resilience is not

- **Not adversarial-input hardening.** The threat model is
  "things go wrong," not "attacker is trying to crash." Findings
  framed as the latter are usually misframed; see
  `trust-model.md`.
- **Not perfectionism.** The runtime does not try to fix the
  user's logic for them; it reverts and logs. The macro DSL does
  not invent placeholder widgets for missing types; it raises.
- **Not retry-at-any-cost.** A failed command surfaces a
  structured `CommandError` event; the user's `update` decides
  whether to retry. The runtime does not retry on its own.
- **Not defense against impossible states.** Adding a defensive
  branch for a condition that cannot occur given the surrounding
  invariants is accidental complexity, not resilience. The bar
  for "cannot occur" is reading the surrounding code and being
  confident in the invariant, not exhaustive proof.

## Implications

- A real things-go-wrong path producing an ungraceful failure
  (an unhandled exception in the runtime loop, a missing revert
  on view error, a stale effect tag delivering to the wrong
  handler, a bridge that hangs instead of crashing on broken
  pipe) is in scope today and earns priority.
- Inconsistency between resilience patterns (one site reverts on
  error, another swallows; one source logs and retries, another
  logs and gives up) is itself a resilience bug because future
  maintainers cannot predict behavior.
- Defensive layers for conditions that cannot occur given the
  surrounding invariants are out of scope; they add accidental
  complexity without reducing real failure modes.
- Aborting on conditions where graceful degradation is the right
  answer ("this should panic on bad event content") is the wrong
  direction; the established pattern is reject-and-report.
