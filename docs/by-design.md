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

## Type cast callbacks are boolean validators

`Plushie.Type.cast/1` callbacks use the shared `{:ok, value} | :error`
contract. They validate and normalize values for generated setters and
type machinery. User-facing builder functions are the diagnostic
boundary and should raise clear `ArgumentError`s for invalid fields.

**Rules out:** Changing individual `cast/1` callbacks to raise detailed
errors, or treating `:error` from a cast callback as lost diagnostics.

**Still in scope:** Improving public builders so invalid user input
raises useful messages. Fixing casts that accept values the renderer
cannot handle, or casts that reject values the type explicitly supports.

**Revisit when:** The unified type behaviour grows a diagnostic return
shape across all SDKs.

## Type casts reject unknown structured fields

Structured type casts reject maps with unknown keys instead of dropping
them. Dropping unknown keys hides typos and can make user-authored
configuration appear to work while silently losing intent.

**Rules out:** Making structured casts lenient about extra keys solely
because the input came from a dynamic map.

**Still in scope:** Accepting partial maps when the type supports
partial values. Improving error messages on public builders. Adding a
separate tolerant importer if a real external data source needs one.

**Revisit when:** The SDK gains a deliberate external configuration
loader where unknown-field tolerance is part of that loader's contract.

## Decode mirrors wire shapes, not every cast shape

The decode path is for renderer wire data. It accepts the shapes emitted
by JSON and MessagePack, then applies type coercions needed for wire
representations such as enum strings and tuple lists. `cast/1` may
accept host-language conveniences that the wire never emits.

**Rules out:** Teaching record-map decode to accept keyword lists, or
list decode to accept tuples, solely to make decode as permissive as
cast.

**Still in scope:** Decoding all valid renderer wire shapes. Fixing
decode when the renderer changes a wire representation. Keeping cast
ergonomic for host-authored values.

**Revisit when:** A public API starts using decode for non-wire input.

## Composite enum decode uses error at the public boundary

Composite enum decode returns `:error` for non-matching values. Union
variant probing converts `:error` to an internal no-match sentinel while
trying later variants, but the public composite decode boundary keeps
the shared `{:ok, value} | :error` shape.

**Rules out:** Returning `nil` from public composite enum decode for a
non-match.

**Still in scope:** Returning `nil` inside private union probing helpers
where "try the next variant" is the local control-flow signal.

**Revisit when:** The type behaviour changes its public failure shape.

## Tiny tuple decode length checks stay explicit

Composite tuple decode checks list length with `length/1`. Tuple specs
are small fixed field groups, and the explicit length check keeps the
decode clauses easy to read.

**Rules out:** Rewriting tuple decode only to avoid an O(n) check for
small tuple-shaped wire arrays.

**Still in scope:** Reworking tuple decode if profiling shows tuple
length checks as a measured decode cost, or if a clearer single-pass
implementation falls out of another change.

**Revisit when:** Real renderer traffic shows large tuple specs or
decode profiling identifies this path as material.

## Struct encoders encode the current struct contract

Encoders for fixed structs encode the fields that exist on that struct
today. Future fields should be added together with their encoding logic
when the struct changes, not guarded by speculative unknown-field checks.

**Rules out:** Adding future-proof unknown-field validation to fixed
struct encoders solely in case the struct gains fields later.

**Still in scope:** Updating encoders as part of the same change that
adds a field. Rejecting unknown fields on map-shaped user inputs where
typos are possible today.

**Revisit when:** A type intentionally supports open-ended map inputs
at encode time.

## Color casts normalize invalid color input to error

`Plushie.Type.Color.cast/1` converts invalid hex strings and unknown
color names to `:error`. That is the intended validation shape for the
type machinery. Builder functions that accept colors are responsible
for turning that result into contextual `ArgumentError`s.

**Rules out:** Letting invalid color parse exceptions escape from
`Color.cast/1`.

**Still in scope:** Tightening builder diagnostics when a bad color is
provided through a public styling API.

**Revisit when:** The type cast contract grows structured diagnostics.

## MapSet dialyzer suppressions are documented limitations

Dialyzer flags structs that contain `MapSet.t()` because `MapSet.t()` is
opaque. The suppressions in `.dialyzer_ignore.exs` cover that known
limitation for modules that store sets while only using the public
`MapSet` API.

**Rules out:** Treating each `:contract_with_opaque` suppression for a
`MapSet` field as an unsound type contract.

**Still in scope:** Removing suppressions when the struct no longer
contains a `MapSet`, or when Dialyzer can verify the contract without
ignoring it.

**Revisit when:** The code starts inspecting `MapSet` internals or
Dialyzer's opaque handling changes.

## Zero damping remains a valid spring shape

Spring damping of zero is a valid damped-oscillator parameter, even
though SDK-side tweens with zero damping may not settle without an
external redirect or stop. The Rust APIs also allow zero damping, so a
restriction here would be a cross-SDK behavior change.

**Rules out:** Rejecting zero damping only in Elixir as a local guard
against long-running spring animations.

**Still in scope:** Rejecting non-numeric damping. Rejecting invalid
mass values that make the solver divide by zero. Adding a parity-routed
change if all SDKs decide zero damping should be disallowed.

**Revisit when:** The parity workflow changes the shared spring
configuration contract.

## Cubic bezier validation stays cross-SDK aligned

Custom cubic bezier easing accepts numeric control points. Restricting
the x control points to the CSS `0..1` range would be a cross-SDK
behavior change because the Rust decoder and SDK-side easing currently
accept numeric points without that range check.

**Rules out:** Adding an Elixir-only x-control range guard for cubic
bezier easing.

**Still in scope:** Validating that all cubic bezier control points are
numeric. Routing a stricter CSS-compatible range rule through the
cross-SDK parity workflow.

**Revisit when:** The parity workflow changes the shared cubic bezier
contract.

## Renderer-side animation targets stay generic

Renderer-side `Spring` and `Transition` descriptors can target numbers,
colors, vectors, and other field-specific types. The descriptor carries
the target value, while the field setter and renderer decode path decide
whether that value is valid for the animated property.

**Rules out:** Requiring renderer-side `Spring.to` or `Transition.to` to
be numeric at descriptor construction time.

**Still in scope:** Numeric validation for SDK-side `Tween`, whose
solver performs arithmetic locally. Field-level validation for animated
properties. Renderer decode failures for values that do not match the
field type.

**Revisit when:** Renderer-side animation descriptors become specialized
per target type in the public API.

## Data sort does not infer numeric meaning across types

`Plushie.Data` sorts values naturally when both records have the same
basic type. Mixed-type values fall back to deterministic string
comparison rather than guessing that a string should be parsed as a
number, atom, date, or another domain type.

**Rules out:** Coercing mixed number and string values into numeric
comparison inside the generic query helper.

**Still in scope:** Callers can normalize records before sorting, or
provide consistently typed sort fields. A future custom comparator API
could support domain-specific mixed-type ordering if a real use case
needs it.

**Revisit when:** `Plushie.Data` grows explicit typed schemas or custom
sort comparators.

## Undo coalescing uses a rolling activity window

Undo coalescing compares each command to the current top entry and
updates that entry's timestamp when commands merge. This makes the
window an idle-gap threshold for continuous activity, which matches
typing behavior: a long uninterrupted burst remains one undo entry until
the user pauses beyond the window.

**Rules out:** Freezing the coalescing timestamp at the first command in
the burst solely to impose an absolute maximum burst duration.

**Still in scope:** Adding a separate maximum coalesced duration if real
editor usage shows long bursts should split even without an idle gap.

**Revisit when:** Product behavior needs both an idle-gap threshold and
an absolute burst cap.

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
bounding for renderer-parent exec belongs to the renderer process that chose
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

## Diagnostic mailbox draining uses tail recursion

`Plushie.Test.DiagnosticCollector.flush/0` drains telemetry messages with
a tail-recursive receive loop. Tail-call optimization keeps this from
growing the BEAM stack, so mailbox size affects runtime work and memory,
not call depth.

**Rules out:** Replacing the loop solely because it is recursive or
treating it as a stack-exhaustion bug.

**Still in scope:** Adding batching, limits, or backpressure if
diagnostic volume becomes a measured test-infra problem.

**Revisit when:** The collector is used for a high-volume telemetry
stream rather than sparse diagnostics from error and validation paths.

## Port transport handles framing, not bridge JSON state

`Plushie.Transport.Port` returns transport data and closure events. The
bridge owns JSON buffering and the `discard_next_eol` flag because that
state is shared across port, stdio, and iostream delivery paths.

**Rules out:** Adding bridge JSON-buffer fields to the port transport
state or treating port closure handlers as responsible for resetting
bridge-owned buffering flags.

**Still in scope:** Resetting bridge buffer state in bridge restart and
shutdown paths. Fixing any port handler that leaves its own transport
state inconsistent.

**Revisit when:** JSON line buffering moves from the bridge into the
transport behaviour.

## Socket adapter active mode matches the transport shape

`Plushie.SocketAdapter` uses active sockets so it can translate TCP or
Unix socket messages into the same iostream protocol that the bridge
already consumes. The renderer normally sends data in response to host
requests, and the adapter enforces frame size caps before forwarding.

**Rules out:** Replacing active sockets with a demand-driven receive
loop solely for speculative mailbox backpressure concerns.

**Still in scope:** Moving to active-once or explicit receive if real
usage shows adapter mailbox growth, or if the socket adapter starts
handling unsolicited high-volume streams.

**Revisit when:** Socket transports become a primary production path
with measured mailbox pressure.

## Tree hot-path clarity bounds micro-optimization

Tree normalization and diffing avoid clearly redundant work when the
replacement stays readable. They keep small explicit passes or pipelines
when consolidation would mix separate semantics or make the hot path
harder to audit.

**Rules out:** Rewriting a11y defaulting into a dense single-pass map
builder solely to reduce intermediate maps. Replacing safe
`String.to_existing_atom/1` conversion with an atom cache or other
global lookup table solely to avoid rescue on manually authored unknown
string keys. Reworking memo dependency canonicalization without a
measured memo-key cost.

**Still in scope:** Local consolidations that preserve intent, such as
sharing a set already built on the diff path, avoiding repeated tuple
conversion, or combining tree collection passes that gather independent
facts without changing semantics.

**Revisit when:** Profiling shows a specific tree hot path where the
clear implementation is a measured bottleneck.

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

## Runtime command builders validate runtime keyword data

Generated native-widget command functions are ordinary runtime
functions. Optional command fields arrive as keyword data, and unknown
keys are rejected where the command value is built.

**Rules out:** Adding a separate macro-only command invocation form
solely to reject unknown keyword keys at compile time. The DSL
discipline reserves new macro forms for recurring bug classes where the
generated code stays clearer than the hand-written runtime call.

**Still in scope:** Clear `ArgumentError` messages from generated
command functions. Compile-time validation of the command declarations
themselves, including field types and event shape.

**Revisit when:** Unknown command option keys become a recurring user
bug that runtime validation does not diagnose clearly.

## Internal generated helpers may remain public and undocumented

Some helpers generated for protocols or macro expansion must be public
so generated implementations in protocol modules can call them, but they
are still internal when marked `@doc false`.

**Rules out:** Treating every public `@doc false` generated helper as a
user-facing API that needs standalone documentation before the 1.0
public-surface sweep.

**Still in scope:** Adding docs or narrowing visibility when a helper is
already being changed for a correctness reason. Fixing inaccurate specs
on generated helpers.

**Revisit when:** The 1.0 API sweep decides which generated helper
modules are public API.

## Field types include animation descriptors because setters accept them

Generated field types include renderer-side animation descriptors for
every field because every generated setter accepts transition, spring,
and sequence descriptors and validates their target values against the
declared field type.

**Rules out:** Removing animation descriptors from field specs solely
because a given renderer widget currently reads only some props through
animated accessors.

**Still in scope:** Tightening renderer-side support or diagnostics for
props that cannot be interpolated. Adding SDK-side validation if
plushie-rust exposes a stable animatable-prop manifest.

**Revisit when:** Animatable prop metadata becomes part of the renderer
contract.

## Setter specs describe the generated function, not each clause

Generated setters may have a nil-specific clause followed by animation
and value clauses. The `@spec` describes the function's accepted public
input shape across those clauses; it is not a per-clause guard
description.

**Rules out:** Removing `nil` from a setter spec only because the
non-nil value clause has a guard that excludes nil while another clause
handles nil.

**Still in scope:** Fixing setter specs when the generated function has
no nil clause and nil is not a valid normal input.

**Revisit when:** Generated setters move to a shape where each public
input category has a separate documented function.

## Generated setter specs rely on cast validators

Generated setters for `Plushie.Type` modules without guard callbacks
accept their argument at the function head and validate it through the
shared `cast/1` encoder. The spec describes the intended accepted input
shape for readers and Dialyzer, while the cast is the runtime boundary
for user input.

**Rules out:** Adding broad guards that duplicate every `cast/1`
callback, or weakening specs solely because validation happens inside
the generated function body.

**Still in scope:** Clear `ArgumentError` messages from generated
setters, accurate specs for the intended value shape, and explicit
guards for types that do not provide `cast/1`.

**Revisit when:** The unified type behaviour grows a generated guard
for every type without duplicating cast logic.

## Non-cast field modules validate through generated guards

Field modules that do not export `cast/1` are expected to provide their
validation through generated guards. The encoder for those modules is a
passthrough because the function head already rejects invalid values for
guarded setters.

**Rules out:** Treating the passthrough encoder as a missing validation
layer for modules whose validation is intentionally guard-based.

**Still in scope:** Adding a guard to any field module that lacks both
`cast/1` and a meaningful generated guard. Raising a compile-time error
if a field declaration cannot produce either a cast validator or a guard.

**Revisit when:** A field type without `cast/1` is found to generate no
useful setter guard.

## Element nil IDs are auto-ID sentinels

Canvas and table elements may carry `id: nil` until their parent
container assigns a positional runtime ID. This is how programmatic
shape helpers and canvas-scope auto IDs compose.

**Rules out:** Applying widget ID validation to nil element IDs. Widgets
require explicit non-empty IDs; elements use nil as an internal
auto-assignment marker.

**Still in scope:** Rejecting an explicit empty string ID. Ensuring
container conversion assigns IDs before element nodes reach the renderer.

**Revisit when:** Canvas and table element construction stops using
parent-assigned IDs.

## Quoted `__MODULE__` in generated code resolves at the use site

Quoted generated functions intentionally refer to `__MODULE__` inside
the quoted body. When that body is injected into a widget or element
module, error messages name the generated module, not the codegen helper
module that produced the quote.

**Rules out:** Replacing quoted `__MODULE__` with an explicit module
argument solely to avoid a resolution problem that does not occur.

**Still in scope:** Passing an explicit module when generated code is
evaluated outside the target module. Tests that confirm user-facing
errors name the widget or element being called.

**Revisit when:** A generated function is moved to a context where
quoted `__MODULE__` no longer resolves to the user's module.

## Alias expansion leaves validation to the type resolver

Event and command declaration macros expand alias syntax enough to
normalize valid module aliases. Unknown or invalid types are then
reported by the shared type validation path, which can name the event
or field context.

**Rules out:** Adding a separate unresolved-alias validation layer
around `Macro.expand/2` when the same bug is caught by the type
resolver.

**Still in scope:** Improving the type validation message when an
unknown expanded module produces a vague error.

**Revisit when:** Alias expansion starts raising before the type
validation path can produce a user-facing `CompileError`.

## Case expressions have no `else` branch

Container and canvas scope handling rewrites supported Elixir control
flow forms. `case` and `cond` bodies are represented by `do:` clauses;
`else:` handling belongs to `with`, `if`, `unless`, and comprehensions.

**Rules out:** Adding unreachable `else:` handling to `case` scope
rewrites.

**Still in scope:** Fixing scope rewriting for real AST forms produced
by supported Elixir control flow.

**Revisit when:** Elixir adds `else:` support to `case`.

## Download install path is stable

`mix plushie.download` selects a platform-specific release artifact, but
installs it into the project as `bin/plushie-renderer` (or
`bin/plushie-renderer.exe` on Windows). The local filename is the
authoritative path used by the SDK and by package scripts.

**Rules out:** Creating symlinks only to hide platform-specific release
artifact names from project-local tooling.

**Still in scope:** Raising on failed download, checksum mismatch,
unusable configured binary paths, or any failure that prevents
`Plushie.Binary.path!/0` from resolving the installed renderer. Improving
the symlink path or adding a portable stable-path mechanism when the
implementation stays clear.

**Revisit when:** The stable symlink becomes a documented contract rather
than a convenience, or binary resolution starts depending on it.

## Mix task CLI overrides may update application env

Mix tasks run in the same VM as the app they start. Flags such as
`mix plushie.gui --watch` and `--no-watch` update
`config :plushie, :code_reloader` so downstream startup code observes
the same value that the CLI selected.

**Rules out:** Treating the application-env write as a leak merely
because it persists for the lifetime of the Mix VM.

**Still in scope:** Making flag resolution clearer, rejecting invalid
flag values, and avoiding application-env writes when the selected
behavior is only local to the task.

**Revisit when:** Mix tasks start multiple apps with independent
reloader settings in the same VM, or code reloader configuration stops
flowing through application env.

## Protocol tests target invariants, not test style

The protocol suite uses examples, round trips, malformed payload cases,
and parity checks where those expose real codec contracts. Property tests
are welcome when they express a useful invariant, but the absence of
`StreamData` in a specific file is not itself a defect.

**Rules out:** Adding property-based protocol tests solely because the
dependency exists or because a test file currently uses only example
tests.

**Still in scope:** Property tests for concrete invariants such as
codec round trips over a well-defined value domain, key normalization
idempotence, or binary field preservation. Focused example tests remain
appropriate for wire shapes with small closed vocabularies.

**Revisit when:** A protocol bug would have been naturally caught by a
compact generated-input invariant rather than by a clearer targeted
case.

## Protocol handshake errors live in the protocol namespace

`ProtocolVersionMismatchError` is raised by the bridge, but it describes
the renderer's advertised wire protocol version and the SDK's expected
version. The protocol namespace is the right home for that structured
error even though the bridge is the component that observes it during
startup.

**Rules out:** Moving protocol-version handshake exceptions into
`Plushie.Bridge` solely because the bridge performs the check.

**Still in scope:** Moving the error if protocol version negotiation
stops being a wire-protocol concern, or if a broader startup-error
hierarchy emerges with a real caller-facing need.

**Revisit when:** More bridge-only startup errors need shared structured
exception handling and the current namespace becomes misleading in use.

## Protocol version is read from the public protocol boundary

`Plushie.Protocol.protocol_version/0` is the source of truth for the
wire protocol version. `Plushie.Protocol.Encode` reads that public
boundary into a module attribute so encoded settings carry the same value
that bridge startup checks use.

**Rules out:** Introducing a separate constant module or file solely to
avoid the encoder referencing `Plushie.Protocol.protocol_version/0`.

**Still in scope:** Moving the version source if multiple packages must
generate it, if the value stops being a compile-time constant, or if
compiler ordering becomes an observed problem.

**Revisit when:** Protocol versioning is generated from the renderer
contract or the SDK needs multi-version negotiation.

## Runtime sync is a caller-ordered barrier

`Plushie.Runtime.sync/1` is a GenServer call used after the caller has
sent work to the runtime, especially through `Runtime.dispatch/2`.
Because BEAM message ordering is per sender, work sent by the same
caller before `sync/1` is processed before the sync reply.

**Rules out:** Replacing `sync/1` with a mailbox-draining loop that
attempts to wait for unrelated senders or future messages.

**Still in scope:** Fixing a path where a documented same-caller
operation can race its following `sync/1`. Clarifying docs when the
barrier wording overstates what GenServer can promise.

**Revisit when:** Runtime gains a multi-producer transaction API that
needs a cross-sender quiescence guarantee.

## Runtime termination does not synthesize app events

When the runtime process terminates, its model and in-flight state are
going away with the process. The termination callback cancels timers and
lets linked callers observe the process exit; it does not run app
`update/2` to manufacture effect-result events during shutdown.

**Rules out:** Dispatching synthetic `EffectEvent` values or calling
`GenServer.reply/2` for every pending renderer request from
`terminate/2` as if the process were continuing.

**Still in scope:** Flushing pending effects and stub acknowledgements
on renderer restart, where the runtime process remains alive and can
preserve model semantics. Cancelling timers and releasing resources
during termination.

**Revisit when:** Runtime shutdown becomes stateful handoff to a new
runtime process rather than ordinary process termination.

## MapSet opaque suppressions stay narrow

Dialyzer treats `MapSet.t()` as opaque and can flag structs that carry
MapSet fields even when the implementation only uses the public MapSet
API. The ignore file keeps those warnings narrow and documented.

**Rules out:** Replacing MapSet with a less clear data structure solely
to satisfy Dialyzer, or treating the existing narrow suppressions as
evidence of a runtime bug.

**Still in scope:** Removing a suppression when Dialyzer no longer
needs it. Fixing any concrete MapSet misuse found by code review or a
test.

**Revisit when:** The warning can be eliminated without obscuring the
window or registry state shape.

## Runtime catch-all messages are warnings

Unexpected messages delivered directly to `Plushie.Runtime` indicate
that a caller bypassed the supported event path or that runtime message
shape drifted. The runtime logs the message at warning level and keeps
running.

**Rules out:** Suppressing or downgrading the catch-all solely because a
test sent an unsupported message. Tests that intentionally exercise the
warning should capture logs.

**Still in scope:** Adding explicit clauses for real runtime messages.
Reclassifying a specific message once it becomes expected behavior.

**Revisit when:** A legitimate runtime integration produces unavoidable
out-of-band messages that are not programming errors.

## View telemetry is model-scoped

`view/1` is a pure function of the model. Runtime view telemetry records
the app and view work, not the event that happened to precede the render.
Some renders have no triggering event, such as startup, forced reload,
dev overlay changes, or renderer resync.

**Rules out:** Threading an optional triggering event through every
render path solely to attach it to `[:plushie, :view]` telemetry.

**Still in scope:** Adding telemetry around update or command execution,
where the triggering event is the work under measurement. Adding a
separate correlation mechanism if profiling shows it is needed.

**Revisit when:** View performance investigations need event-model
correlation that cannot be recovered from adjacent update telemetry.

## Runtime plumbing tests may use the internal bridge

Runtime state-machine tests that assert local runtime behavior and bridge
casts may use `Plushie.Test.InternalMockBridge`. This stub is test
infrastructure for the runtime itself, not an application test backend
and not a replacement for the real renderer integration spine.

**Rules out:** Rewriting runtime plumbing tests solely to avoid the
internal bridge when the behavior under test is the runtime's own local
state and outbound bridge calls.

**Still in scope:** User-facing behavior tests, widget integration
tests, automation tests, codec tests, and renderer lifecycle tests that
can run through `Plushie.Test.Case` and the real binary. Moving a
runtime test onto the integration spine when the current stub would hide
the bug class under test.

**Revisit when:** The internal bridge starts duplicating renderer
behavior instead of only recording runtime calls.

## Widget builder tests may stay pure

Widget builder modules have focused tests for constructor routing,
setter validation, child conversion, and built node shape. Those tests
may use `ExUnit.Case` because they do not claim renderer behavior and do
not replace the integration spine.

**Rules out:** Converting every widget builder test to
`Plushie.Test.Case` solely because the widget eventually renders.
Adding renderer interaction tests for every prop combination without a
specific renderer or wire failure mode.

**Still in scope:** Renderer-backed tests for event dispatch, disabled
behavior, wire shape drift, automation behavior, and regressions that a
pure builder test would hide. Builder tests should still normalize
through `Plushie.Tree` when the failure mode is scoped IDs or encoded
props.

**Revisit when:** Builder tests start making renderer-behavior claims,
or repeated renderer regressions show that a widget family needs a
dedicated integration suite.

## Renderer compatibility aliases are not host API

The renderer may accept compatibility prop names that are not part of
the host SDK API shape. Host SDKs expose the canonical cross-SDK field
name and should not add duplicate aliases only because the renderer
still accepts an older or lower-level prop name.

**Rules out:** Adding `Button.content` beside `Button.label` only
because the renderer accepts `content` as a fallback.

**Still in scope:** Routing a canonical field rename through the
cross-SDK parity workflow if the SDK shape itself should change. Keeping
renderer compatibility paths as long as the renderer needs to accept old
wire data.

**Revisit when:** The parity workflow chooses `content` as the shared
button text field, or the renderer fallback becomes the only supported
wire field.

## Animation descriptor recognition is explicit

`Plushie.Widget.Build.animation_descriptor?/1` recognizes the closed set
of renderer-side animation descriptor structs supported by the public
animation API. Adding a new descriptor type is a public API change and
must update the places that distinguish descriptors from ordinary field
values.

**Rules out:** Replacing explicit descriptor clauses with a speculative
open-ended protocol solely to avoid updating the helper for future
animation types.

**Still in scope:** Adding a descriptor clause as part of the same
change that introduces a new animation struct. Improving diagnostics
when a descriptor is used with a field type that cannot accept its
target.

**Revisit when:** Animation descriptors become an intentionally open
extension point.

## Slider dimensions are orientation-specific

Horizontal and vertical sliders use dimension names according to the
renderer contract. For a horizontal slider, `width` is the layout length
and `height` is the track thickness. For a vertical slider, `height` is
the layout length and `width` is the track thickness.

**Rules out:** Changing vertical slider `width` to a layout `Length`
only to mirror the horizontal slider's `width` field name.

**Still in scope:** Cross-SDK parity changes if the renderer contract
renames these fields or exposes separate layout and track-thickness
properties.

**Revisit when:** The renderer exposes orientation-neutral slider size
props or measured user confusion warrants a parity-routed rename.

## Scrollable status events are runtime-internal

Renderer `status` events are a low-level interaction signal used by the
runtime for focus tracking. The runtime absorbs raw status events and
emits app-facing `focused` or `blurred` events when the focus state
changes.

**Rules out:** Adding `event :status` to `Scrollable` or other widgets
only so apps can observe raw renderer status strings.

**Still in scope:** Exposing a deliberate app-facing interaction event
when a real use case needs more than focus and blur. Fixing status
decode or runtime focus tracking when renderer behavior changes.

**Revisit when:** The public event model intentionally exposes raw
widget status values rather than derived semantic events.

## Window lifecycle props are runtime-owned

Window nodes carry lifecycle props such as title, size, position, and
decorations so the runtime can open and update native windows through
window operations. The renderer's window widget only consumes layout
props needed to render the content container.

**Rules out:** Treating lifecycle props on `Plushie.Widget.Window` as
dead wire fields just because `plushie-rust` does not read them in
`WindowWidget`.

**Still in scope:** Adding renderer-consumed layout props to the window
widget. Fixing runtime window prop extraction when a lifecycle prop is
missing from window operations.

**Revisit when:** Window lifecycle synchronization moves out of the
runtime and into renderer-side widget props.

## Text editor key bindings stay renderer-shaped

Text editor key bindings are declarative renderer rules. Host SDKs pass
lists of map-shaped rules through to the renderer rather than
re-implementing the renderer's binding parser in every language.

**Rules out:** Adding an Elixir-only `Plushie.Type.KeyBinding` that
validates the full key binding object shape while sibling SDKs keep the
same prop as renderer-shaped maps.

**Still in scope:** Rejecting non-map list entries through the existing
field type. Adding a shared typed key binding builder through the
cross-SDK parity workflow. Improving renderer diagnostics for malformed
binding maps.

**Revisit when:** The parity workflow defines a shared host-side key
binding type or malformed key binding maps become a recurring user bug
that renderer diagnostics do not catch.

## Manual tree maps preserve unknown string prop keys

Tree normalization accepts manually constructed maps in tests and low
level APIs. Known string keys are converted to existing atoms so normal
post-processing can run, while unknown string keys are preserved rather
than interned as new atoms.

**Rules out:** Creating atoms for arbitrary prop keys, or rejecting a
manual tree solely because it carries an unknown string prop.

**Still in scope:** Tightening user-facing DSL and widget builders so
known properties are validated before normalization. Fixing any
post-processing path that fails to handle the known string key it
accepts.

**Revisit when:** Manual tree maps become a documented public input
surface with a closed prop schema.

## Pending effect restart flush preserves event semantics

When the renderer restarts while effects are pending, the runtime
delivers one `EffectEvent` per pending effect through the ordinary
`update/2` path. This preserves the same event semantics as successful,
failed, cancelled, and timed-out effects.

**Rules out:** Batching renderer-restarted effect results into a new
event shape solely to reduce rerenders on a rare recovery path.

**Still in scope:** Deferring renders while preserving per-event
`update/2` semantics, if renderer restart with many pending effects
becomes a measured cost. Clearing stale pending effects on restart.

**Revisit when:** A real application produces enough pending effects
during renderer restart for this path to show up in profiling.

## Effect result decoding is not version negotiation

The protocol decoder rejects unknown effect response statuses before
they reach `Plushie.Effect.Result.decode/3`. The effect result fallback
is a local robustness backstop for direct calls or internal drift, not
the renderer version-mismatch signal.

**Rules out:** Raising from `Effect.Result.decode/3` for unknown status
values solely to detect future renderer versions.

**Still in scope:** Keeping protocol decode strict for renderer-supplied
statuses. Improving protocol-version mismatch diagnostics at the bridge
handshake.

**Revisit when:** The wire protocol intentionally allows extensible
effect statuses and apps need a typed unknown-status result.
