# Project posture

What plushie-elixir is, who it is for, and the disciplines that keep
it that way.

## What plushie-elixir is

The Elixir host SDK for Plushie. An Elm-architecture app runtime
that drives a renderer subprocess (Rust binary, native windows via
iced) over a typed wire protocol on stdin/stdout. The SDK ships as
a hex package; user apps `use Plushie.App`, declare their UI with
the macro DSL, and the runtime handles diffing, command dispatch,
subscriptions, supervision, and bridge lifecycle.

This SDK is one of six host SDKs sharing the renderer (Elixir,
Rust, Gleam, Python, Ruby, TypeScript). The renderer binary is
shared; each SDK implements its own runtime against it.

## Audience

- App developers writing Plushie apps in Elixir. They see the
  `Plushie.App` behaviour, the UI macro DSL, the command and
  subscription APIs, and the test framework.
- Widget authors writing pure-Elixir composite widgets via
  `use Plushie.Widget`, or wiring native (Rust) widgets in
  through the same macro DSL with `:native_widget`.
- SDK maintainers. The DSL surface, the Bridge/Runtime split,
  the wire codecs, the test backends.

The hex package's public API is anything with a documented
`@moduledoc` and `@doc` entries. `@moduledoc false` and `@doc
false` mark internal surfaces. Submodules under
`Plushie.Runtime.*`, `Plushie.DSL.*`, the codec internals under
`Plushie.Protocol.*`, and the diff and normalization internals
under `Plushie.Tree.*` are internal regardless of their names.
The top-level `Plushie.Runtime`, `Plushie.Protocol`, and
`Plushie.Tree` plus the `Plushie.Tree.Node` protocol are public.

## Cross-SDK relationship

plushie-elixir is the canonical reference SDK for API shape.

- **API shape tiebreaker.** When a concept's name, structure, or
  parameter ordering is contested across SDKs, what plushie-elixir
  does is the answer. plushie-rust is the protocol authority (wire
  format, message variants, codec); plushie-elixir is the shape
  authority (what user-facing concepts look like).
- A rename here is a six-SDK change, not a refactor. The bar for
  renaming a widget prop, an event field, a command shape, or a
  subscription type is "is the new name actually better across
  every SDK," not "does the new name fit Elixir conventions
  better."
- Cross-SDK parity is audited via the sibling
  `plushie-sdk-parity/` repo. Findings about parity drift route
  through that workflow rather than as standalone work here.
- Within-language idiom prevails on syntax. Elixir-flavored DSL
  (do-blocks, pipelines, pattern matching, atom shortcuts), Elixir
  naming conventions (snake_case, `:atom` for type IDs), and
  Elixir's runtime shape (GenServers, supervision, message
  passing) are right and final. Concepts, names, parameter
  ordering, and behavior converge with the other SDKs.

"More idiomatic in Elixir" alone is not justification for breaking
parity. "The current shape is wrong everywhere and we are choosing
the better shape" is, and the change ripples.

## Stage

Pre-1.0. There is no backwards-compatibility obligation today.
When the best design requires renaming a callback, a field, or
restructuring a module, that is the right call. The CHANGELOG
notes breaking changes explicitly.

The 1.0 boundary is when stability obligations begin. Until then,
the priority is getting the shape right, not preserving the
current shape. Pre-1.0 is the time to settle questions about API
shape, naming, and structure that will be expensive to revisit.

API stability hardening (`@deprecated`, sealed callback lists,
documented compatibility windows) lands in a single planned sweep
at the 1.0 cut, not piecemeal during normal development.

## Disciplines

Recurring decision rules. Not negotiable on a per-ticket basis.

- **Tests run through the real renderer.** The default test
  backend runs `plushie-renderer --mock`: real binary, real wire
  protocol, real Core engine, no GPU. A test that passes against
  a pure-Elixir mock and would fail against the binary is worse
  than no test. Stubs are reserved for failure modes the binary
  cannot exhibit. See `test-discipline.md`.
- **Cross-SDK claims are verified, not assumed.** When the
  question is "does plushie-gleam do this the same way," the
  answer comes from reading source on each side. "It looks like"
  is not a verification.
- **Design before code at boundaries.** Public hex API, the
  macro DSL surface, the wire protocol on the Elixir side, the
  `Plushie.Type` behaviour, the test-backend contract. Internal
  refactors can iterate fast; boundary changes pay the design tax
  up front.
- **Clarity is the bar.** Code reads clearly to someone new to
  the file; abstractions earn their place by use, not by
  hypothesis; complexity is a cost. See `simplicity.md`.
- **No half-built features.** A feature lands fully or not at
  all. Half-built features create drift in the parity surface
  and accumulate into "the docs say it does X but three SDKs do
  not actually."
- **Local cleanup, not scope creep.** Small, low-risk
  improvements to code under active modification are welcome.
  Larger or risky adjacent improvements get noted and advocated
  for as follow-on work, not silently rolled into the current
  change.
- **No legacy or compatibility shims.** Pre-1.0; remove dead
  paths cleanly rather than preserving old behavior.
