# Triage

How proposed work gets evaluated against the stewardship docs.

Sources of proposed work are many: design proposals, refactor
ideas, library upgrades, feature requests, breaking-change calls,
"while I was in there" cleanups, cross-SDK divergence flags,
observations from review passes. The flow below applies regardless
of source. The underlying docs (`posture.md`, `goals-and-non-goals.md`,
`trust-model.md`, `resilience.md`, `performance-bar.md`,
`test-discipline.md`, `simplicity.md`, `elm-invariants.md`,
`dsl-discipline.md`, `concurrency-shape.md`) are the authority on each axis;
this file is a consolidated routing tool.

## Outcomes

For any proposed work, one of:

- **Do.** Aligned with a stated goal, addresses a real bug, or is
  plain maintenance hygiene that does not warrant a stewardship-
  level question.
- **Defer to a roadmap item.** Real concern tied to a considered
  direction not currently scheduled. Append to the relevant
  `roadmap/<item>.md` "Observations" section as context for when
  the work is taken up.
- **Decline.** Misframed against the trust model, defends against
  speculative futures or impossible states, asks for work without
  the evidence the relevant doc requires, or otherwise lands on a
  stated non-goal.
- **Route to cross-SDK parity.** Concerns parity drift or an SDK
  API shape that affects parity. Goes through the
  `plushie-sdk-parity` workflow rather than being decided here.

## Routing flow

For a piece of proposed work, run these in order. First match
wins.

1. **Cross-SDK shape.** Does the work alter or surface drift in
   an API shape, behavior name, parameter ordering, event field
   shape, or wire form across multiple SDKs? Route to the parity
   workflow. plushie-elixir is the shape tiebreaker but the
   change ripples; see `posture.md`.

2. **Elm invariants.** Does the work touch the
   `init`/`update`/`view` contract, the return-shape validation,
   command shape, subscription diffing, widget event flow, or
   scoped IDs? Treat as a deliberate decision; default to no
   unless the change is genuinely a fix to the contract. The
   contract is the cross-SDK story; see `elm-invariants.md`.

3. **Trust-model misframe.** Does the proposal assume a threat
   model the project does not currently make a claim against
   (host as adversary under an unclaimed boundary, browser-grade
   isolation of arbitrary remote hosts, wire-as-its-own-crypto)?
   Decline; reference `trust-model.md`.

4. **Renderer-to-host integrity.** Does the work touch the
   decoder in a way that loosens the closed-shape contract
   (passing through unknown event variants, opaque-blob delivery
   to user code, spoofable response correlation, an unsafe
   parser)? Treat as a deliberate decision, not a routine
   refactor; default to no.

5. **Resilience axis.** Does the work address a real things-go-
   wrong path that fails ungracefully (an unhandled exception in
   the runtime, a missed revert on view error, a stale effect tag,
   a bridge that hangs instead of crashes), or inconsistency
   between resilience patterns the codebase already uses? Do;
   reference `resilience.md`. Conversely, does the proposal add
   defensive layers for conditions that cannot occur given the
   surrounding invariants? Decline.

6. **Wire codec correctness.** Encode/decode symmetry, round-trip
   through MessagePack and JSONL, field-name drift between
   encoder and renderer. Do; stated goal.

7. **Lightweight by default.** Does the work consolidate
   redundant work, choose a data structure better suited to the
   realistic profile, remove clearly unnecessary per-call cost
   (an extra `Enum` pass, redundant key stringification, repeated
   `Map.get/2` chains), while preserving or improving readability?
   Do; reference `performance-bar.md`. Conversely, is the work
   clever-for-speed at the cost of intent, or a big-O claim
   without realistic N? Decline absent measurement.

8. **Test discipline.** Does the work move tests off the
   integration spine (mocking the renderer, replacing real
   binary tests with pure-Elixir stubs, using `:sys` debug
   functions instead of the public Runtime API)? Decline;
   reference `test-discipline.md`. Does it move tests onto the
   spine (rewriting a stub test to run through the binary)? Do.

9. **Macro DSL extension.** Does the proposal add a new macro
   form, a new field shape, a new event spec form, a new block
   scope? Run the criteria in `dsl-discipline.md` (two real users,
   real bug class, generated code reads cleanly, error messages
   point at the call site). If it does not pass, decline or
   defer.

10. **Concurrency shape change.** Does the work introduce a new
    long-lived process, change supervision strategy, alter the
    Bridge/Runtime split, add registry-based dynamic supervision,
    or move work between Bridge and Runtime? Treat as a
    stewardship-level question; reference `concurrency-shape.md`.

11. **Simplicity axis.** Single-user abstraction extracted as a
    behaviour or protocol? Module split without a forcing
    function? Premature generic where specific would do?
    Decline; reference `simplicity.md`. Conversely, three-similar-
    lines that have grown into a real concept and want to be
    abstracted? Do.

12. **Stated non-goal.** Backwards compatibility before 1.0, API
    stability hardening as standalone work, coverage milestones,
    refactoring without a forcing function, defending against a
    speculative deployment shape. Decline; reference
    `goals-and-non-goals.md`.

## Default behavior

If nothing matches and the work is plain maintenance (advisories,
portability bugs, broken examples, dead code, typo-class
corrections, obvious self-consistency restorations), the default
is to do it without a stewardship category. The flow earns its
keep on the harder cases: declining speculative defenses,
deferring to roadmap items, recognizing trust-model misframes,
distinguishing real algorithmic consolidation from speculative
micro-optimization, distinguishing real macro DSL extensions
from costume abstractions.

## When the docs need updating

If the proposed work feels stewardship-level (a real direction
question, a new constraint, a posture the docs have not yet
taken) but does not match any axis above, that is a signal the
docs are missing a category. Surface the question to the
maintainer rather than improvising a category, and update the
docs once the direction is settled.

The docs decay when every novel question gets shoehorned into
the closest existing axis. They stay useful by being explicit
about what they cover and acknowledging when they do not cover
something.
