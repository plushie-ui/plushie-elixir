# Goals and non-goals

The objectives plushie-elixir optimizes for, and the explicit
non-objectives it declines work against. The lists are deliberately
short; they earn their place by being recurring decision criteria,
not by enumerating every aspiration.

## Goals

Testable shipping criteria. Findings that improve any of these are
real work.

- **Wire protocol fidelity on the host side.** Messages encode
  and decode identically against every other SDK and the
  renderer; the codec stays in lockstep with the renderer's spec
  (authority lives in plushie-rust); values round-trip through
  MessagePack and JSONL without coercion drift.
- **Cross-SDK concept parity.** Concepts (event shapes, widget
  props, command structures, subscription types) converge with
  the other host SDKs at the semantic level. plushie-elixir is
  the shape tiebreaker; see `posture.md`.
- **Elm-architecture purity.** `init/update/view` is the user's
  contract. Return shapes are validated; commands are pure data;
  effects push to the edges; `view/1` is a pure function of
  model. The runtime preserves these invariants. See
  `elm-invariants.md`.
- **Lightweight runtime.** Idle apps do no measurable work. No
  polling, no per-frame walking when nothing changed, no
  spinning subscription threads. Tree diffs are minimal (LIS for
  reorders). See `performance-bar.md`.
- **Fault tolerance across the wire.** Renderer crash is detected
  by the bridge, which restarts the binary, replays settings, and
  re-syncs the tree from a fresh full snapshot. App exception in
  `init/update/view` reverts to the last good state and surfaces
  the error. Neither side takes the other down. See
  `resilience.md`.
- **Macro DSL clarity.** The DSL is the largest surface in the
  codebase. It is held to the same readability bar as runtime
  code: generated functions read like hand-written ones,
  compile-time validation produces clear messages, scope checks
  point at the offending call site. See `dsl-discipline.md`.

## Non-goals

Explicit non-objectives. Findings or proposals that push the
project toward them get declined; they are not candidates that
lost a priority contest.

- **Backwards compatibility before 1.0.** The right design wins;
  the rename happens. Hex package consumers expect breaking
  changes in pre-1.0 minor bumps; the CHANGELOG names them.
- **Per-Elixir API ergonomics that diverge from cross-SDK shape.**
  See `posture.md`. "More idiomatic in Elixir" alone is not
  sufficient; the shape question routes through the parity
  workflow.
- **API stability hardening before 1.0.** `@deprecated`, sealed
  callback lists, documented compatibility windows, public/
  internal module audits, `@doc false` audits. These happen in a
  single planned sweep at the 1.0 cut, not piecemeal during normal
  development.
- **Coverage targets as a metric.** Test discipline is "exercise
  real surfaces through the renderer," not "hit a percentage."
  See `test-discipline.md`.
- **Mocking the renderer for speed.** mock-mode in the real
  binary is already fast (microseconds to milliseconds per
  test); a pure-Elixir mock is faster only at the cost of the
  exact bug class the integration spine catches.
- **Micro-optimization at the cost of readability.** Clever
  encoding, lookup, or layout schemes in hot paths need to earn
  the obscurity with measurement. Optimizations that look clean
  and do not damage readability are welcome; see
  `performance-bar.md`.
- **Refactoring without a forcing function.** Module size or
  file length alone is not a reason to refactor. The trigger is
  a real change that the existing structure cannot accommodate
  cleanly.
- **DSL extensions for hypothetical future widgets.** A new
  macro, a new field shape, a new event spec form earns its
  place when at least two real users would benefit. "We might
  want this someday" is a reason not to extend the DSL.
- **Defending against speculative deployment shapes.** Untrusted
  multi-tenant runtimes, browser-as-arbitrary-host, sandboxed
  user apps inside other Elixir runtimes. None of these are
  current goals. Defenses against them are out of scope unless
  and until the shape is taken up.
