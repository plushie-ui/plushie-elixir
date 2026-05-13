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

## Stdio transport does not own renderer process environment

The `:stdio` transport attaches the bridge to the BEAM process's existing
stdin and stdout. It does not spawn the renderer, so there is no child
process environment for `Plushie.RendererEnv` to filter. Environment
bounding for `plushie --exec` belongs to the renderer process that chose
to start the host.

**Rules out:** Applying the renderer environment whitelist to `:stdio`
mode as if the host SDK were spawning a new renderer child.

**Still in scope:** Applying `Plushie.RendererEnv` to `:spawn` mode,
where the bridge actually owns the child process environment.

**Revisit when:** The host SDK gains a stdio mode that launches a child
process instead of attaching to inherited file descriptors.

## Bridge restart budget is per crash burst

The bridge resets `restart_count` after the runtime finishes resync. The
limit bounds consecutive renderer restart attempts before a successful
resync, not the lifetime total for a long-running application.

**Rules out:** Treating a successful resync followed by a later crash as
part of the previous crash burst.

**Still in scope:** Clear module documentation for the restart state
machine. Changing the restart policy if resilience requirements move
from burst containment to lifetime containment.

**Revisit when:** The resilience posture calls for cumulative lifetime
restart limits.

## GenServer late replies are safe

`GenServer.reply/2` may be called after the original caller exits or
times out. The reply is a message send through the `from` token; it does
not crash the replying GenServer when the caller is gone.

**Rules out:** Wrapping every `GenServer.reply/2` solely to defend
against exited callers.

**Still in scope:** Tracking pending calls when late replies would block
future work or could be misrouted to a newer caller.

**Revisit when:** A call path uses a reply token in a way that can raise
for reasons other than the caller exiting.

## Circle radius and rectangle corner radius are different concepts

Canvas circles use the positional `r` field for their geometric radius.
Canvas rectangles use the optional `radius` field for rounded corners.
Those names are intentionally not mirrored because a circle has no
corner-radius option.

**Rules out:** Adding a `radius:` option to `circle/4` to mirror
`rect/5` rounded-corner options.

**Still in scope:** Renaming the circle positional field through the
cross-SDK parity workflow if the shared canvas shape vocabulary changes.

**Revisit when:** Canvas gains a new circle-like shape with a separate
corner or smoothing radius.

## Command constructors are the command validation boundary

Commands are host-authored pure data. The runtime's unknown-command
catch-all is a programming-error backstop for manually constructed or
corrupted internal command structs, not a renderer-to-host wire boundary.

**Rules out:** Adding runtime rate limiting or malformed-wire tests for
unknown command structs as if they were adversarial renderer input.

**Still in scope:** Tightening public command constructors so malformed
command data is harder to produce through the SDK API. Testing malformed
renderer-to-host protocol messages in protocol decode tests.

**Revisit when:** Commands become accepted input from an untrusted
external source.

## Narrow command runtime tests may use explicit tree maps

Some runtime command integration tests construct small window trees
directly to keep the test focused on command execution. These tests still
exercise the real runtime, bridge, renderer binary, and wire protocol.

**Rules out:** Rewriting command-focused tests solely to exercise the DSL
when the DSL is not the behavior under test.

**Still in scope:** DSL tests and user-facing integration tests should
use the DSL path. Command tests should still return valid window nodes.

**Revisit when:** A command test depends on widget DSL behavior or misses
a bug because its hand-built tree differs from normalized DSL output.

## Pending effect tag lookup stays simple

Pending effects are keyed by wire ID, and cancelling by tag scans the
small pending-effects map. The realistic profile is one pending effect
per user action, so the linear scan keeps state shape simple without a
measured cost.

**Rules out:** Adding a secondary tag index for pending effects based on
big-O concern alone.

**Still in scope:** Replacing the scan if measured contention or a real
workflow shows many concurrent pending effects with tag cancellation.

**Revisit when:** Pending effect cancellation appears in a measured hot
path or an application pattern creates many simultaneous effects.

## Command DSL specs are generated source

Modules that use `use Plushie.Command` declare command functions through
the command DSL. Their specs are generated from the same declarations as
the functions, so explicit duplicate `@spec` lines in each module would
add drift risk rather than clarity.

**Rules out:** Adding hand-written specs beside command DSL declarations
solely because generated specs are not visible in the source file.

**Still in scope:** Testing and fixing DSL spec generation itself.
Adding explicit specs for hand-written command functions.

**Revisit when:** The generated specs become hard to inspect in docs or
Dialyzer output shows a concrete mismatch.

## Test support modules may live outside the test file

Tests can use modules defined under `test/support/` when the helper is
shared, isolates a dependency, or keeps the test body focused on the
behavior under assertion. A reference to such a module from a test file
is not missing code just because the module is not defined inline.

**Rules out:** Treating test helper modules as undefined without checking
`test/support/` and the test compilation path.

**Still in scope:** Removing dead test helpers, renaming confusing test
helpers when a real test change touches them, or inlining a helper when
the separate module no longer carries its weight.

**Revisit when:** A support module is no longer loaded by the test
environment or becomes a single-use abstraction that obscures the test.

## Examples may show defaulted call arities

Elixir functions with default arguments intentionally expose multiple
call arities. Reference examples may use the shorter, common call form
when the omitted trailing arguments have defaults and the surrounding
text names how to pass options.

**Rules out:** Treating a valid example such as a function call without
optional trailing options as an API mismatch solely because the generated
spec lists the full arity.

**Still in scope:** Correcting tables that claim a non-existent function
name, adding text that explains optional options, or showing the full
arity when the optional argument is the subject being documented.

**Revisit when:** A short example hides a required argument or users need
the omitted option to understand the feature.
