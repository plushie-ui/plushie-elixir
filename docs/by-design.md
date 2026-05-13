# By-design decisions

A persistent record of decisions the project has made about choices that
look like bugs or omissions but are deliberate. When an audit finding,
review comment, or proposal surfaces something already decided, the
response is a one-line link to the relevant section here.

Each section follows this pattern:

- Statement of the decision
- What this rules out (specific recommendations that have been declined)
- What is still in scope (things that are NOT declined under this section)
- Revisit when (the boundary condition for reconsideration)

## Pre-1.0: zero backcompat obligation

The right design wins. Renames happen. API shapes change. Hex package
consumers expect breaking changes in pre-1.0 minor bumps.

**Rules out:** Backwards compatibility work, deprecation annotations,
migration guides, compatibility shims for removed APIs. Any work
preserving an API shape that should change.

**Still in scope:** Breaking changes that break without clear benefit
(e.g. renaming for style alone when the current name is clear and
cross-SDK aligned).

**Revisit when:** The project declares 1.0. At that point, a single
planned stability sweep replaces all piecemeal hardening.

## API hardening is a single 1.0 sweep, not piecemeal work

`@deprecated` annotations, sealed callback lists, documented
compatibility windows, public/internal module audits, `@doc false`
audits, and similar stability hardening all land in a single planned
sweep at the 1.0 cut.

**Rules out:** Individual PRs adding `@deprecated`, sealing module
boundaries, or auditing public surface as standalone work.

**Still in scope:** Adding missing `@spec` or `@doc` as part of a fix
that already touches the function. Correctness improvements to existing
specs that are wrong.

**Revisit when:** The 1.0 sweep is scheduled.

## Mocking the renderer for speed is declined

The default test backend (`:mock`) already runs the real binary with
real wire and real Core, just no GPU rendering. A pure-Elixir mock of
the renderer would be faster only at the cost of the exact class of
bugs the integration spine is designed to catch.

**Rules out:** Any proposal to replace real-binary tests with
pure-Elixir stubs for speed.

**Still in scope:** Stubs for forced crash simulation, malformed wire
bytes, direct `update/2` return-shape tests, and test infrastructure
itself, per `docs/stewardship/test-discipline.md`.

**Revisit when:** The integration spine demonstrates that the mock
backend's real-binary overhead is a measurable bottleneck for developer
workflow.

## Coverage targets as a metric are declined

Test discipline is "exercise real surfaces through the renderer," not
"hit a percentage." See `docs/stewardship/test-discipline.md`.

**Rules out:** Coverage percentage targets, coverage-driven test
writing, CI gates on coverage numbers.

**Still in scope:** Identifying untested code paths that correspond to
real failure modes. Adding tests for resilience features that have zero
coverage.

**Revisit when:** Never. This is a philosophical position, not a
timing question.

## Refactoring without a forcing function is declined

Module size or file length alone is not a reason to refactor. The
trigger is a real change that the existing structure cannot accommodate
cleanly.

**Rules out:** Extracting helpers, splitting modules, renaming for
brevity, or restructuring without a concrete change that needs it.

**Still in scope:** Restructuring that unblocks a real feature or fix.
Consolidation of genuinely redundant traversals (per performance-bar.md).

**Revisit when:** A real change cannot land cleanly in the current
structure.

## Per-Elixir ergonomics that diverge from cross-SDK shape

plushie-elixir is the canonical API-shape reference. "More idiomatic in
Elixir" alone is not sufficient to justify an API shape that differs
from the cross-SDK consensus. The shape question routes through the
parity workflow. See `docs/stewardship/posture.md`.

**Rules out:** Elixir-specific naming, parameter ordering, or return
shapes that differ from the cross-SDK standard for ergonomic reasons.

**Still in scope:** Within-language idiom on syntax (e.g. keyword lists
vs positional args) where the concept and ordering match.

**Revisit when:** The parity workflow identifies that the cross-SDK
shape itself should change.

## Normal-return specs do not enumerate exits

Public specs describe values returned on the normal path. Linked
process exits, `GenServer.call/3` exits for missing processes, and
similar BEAM control-flow exits are not expanded into every wrapper's
return type.

**Rules out:** Widening a wrapper spec from `:ok` to include values that
the delegated function does not normally return, or treating possible
process exits as ordinary return values.

**Still in scope:** Documenting meaningful failure behavior when it is
part of the user-facing contract. Returning `{:error, reason}` for
recoverable conditions where the implementation actually returns that
shape.

**Revisit when:** A public API intentionally converts an exit into a
regular return value.

## Batch helper names stay cross-SDK aligned

Batch helpers are named `batch` across the SDKs that expose them. In
Elixir, invalid inputs to constructors and normalizers may raise through
guards, pattern matching, or explicit validation without requiring a
bang suffix.

**Rules out:** Renaming `Subscription.batch/1` or `Command.batch/1` to a
bang form solely because invalid input raises.

**Still in scope:** Clear docs, specs, and tests for the validation each
batch helper performs. A parity-routed rename if the shared SDK shape
changes.

**Revisit when:** The parity workflow changes the shared helper name or
Elixir grows a distinct success/failure pair where the bang convention
would carry real information.

## Typespecs do not replace runtime validation

Typespecs document the intended shape for tools and readers. They do
not enforce runtime input, especially for public APIs called from user
code.

**Rules out:** Removing guards or validations solely because the spec
already says the accepted type. Treating validation as dead code only
because well-typed callers would not hit it.

**Still in scope:** Fixing inaccurate specs so they describe the
validated surface. Removing checks that are impossible because a
surrounding invariant, not just a spec, makes them unreachable.

**Revisit when:** A validation is proven unreachable from construction
invariants rather than from typespec assumptions.

## Binary architecture validation is best effort

`Plushie.Binary.validate_architecture!/1` raises when it can detect a
binary architecture mismatch. If the platform lacks the `file` command
or the architecture cannot be recognized, resolution proceeds.

**Rules out:** Treating an inconclusive architecture check as a hard
startup failure.

**Still in scope:** Raising on a detected mismatch. Improving detection
for additional architectures or platforms when the implementation stays
clear.

**Revisit when:** Binary resolution gains a portable architecture
metadata source that does not depend on host tools.

## Scoped ID parsing is structural

`Plushie.ScopedId.parse/1` parses canonical wire ID structure into
window, scope, and local ID components. It is not the validator for
user-authored widget IDs.

**Rules out:** Rejecting parseable wire strings only because their local
ID would be illegal in a user-authored tree node.

**Still in scope:** Validating user-authored widget IDs during tree
normalization. Fixing reconstruction helpers such as `from_event/1`
when they build an incorrect canonical ID from already-decoded event
fields.

**Revisit when:** `ScopedId.parse/1` becomes a user-input validation API
rather than a structural parser.
