# DSL discipline

The macro DSL is the largest user-facing surface in plushie-elixir.
`Plushie.UI` (the import surface), `Plushie.Widget` (custom widget
authoring), `Plushie.Type` (the type system), `Plushie.Canvas.*`
(canvas elements), `Plushie.Table.*` (table elements), and the
shared `Plushie.DSL.*` codegen all sit here. It is also the
surface most prone to drift, the one most expensive to retroactively
get right, and the one with the highest readability stakes because
generated code is what users read in stack traces.

This doc describes the posture for adding to the DSL, deciding
what runs at compile time vs runtime, and keeping generated code
honest.

## What the DSL is for

A single import (`import Plushie.UI`) gives the user the full
widget vocabulary, canvas elements, container blocks, and the
typed property forms. The shape is:

- Block-form options on every widget and canvas shape:
  `text("hello", "Hello") do size(18) end`.
- Inline option declarations mixed with children inside
  containers: `column do size(:fill); button("save", "Save") end`.
- Context-aware validation: `canvas_scope` rewrites/validates
  shape calls inside canvas/layer/group blocks; `container_scope`
  validates container options at compile time and points at the
  offending call site with the supported alternatives.
- Auto-id sugar for display widgets that rarely need explicit
  IDs: `text("Hello")` works; `text("greeting", "Hello")` works
  too. Interactive widgets always require an explicit ID.

The DSL is not a backdoor for arbitrary code generation. Every
macro is a thin shape over a runtime call; what a macro
generates is what a user could have written by hand.

## When a new macro earns its place

The DSL is permissive about adding widgets (the macro that adds
a widget is `widget :name`, used by every widget; no extension
question). It is conservative about adding new macro forms (a
new declaration form, a new block scope, a new field shape, a
new event spec form).

A new macro form earns its place when:

- At least two existing or imminent users want the same shape.
- The form replaces a runtime construct that is harder to read
  or harder to validate at the call site.
- A meaningful class of bugs becomes detectable at compile time
  that runtime checks would catch only on first use.
- The generated code reads as cleanly as what the user would
  have written by hand.

A new macro form does not earn its place when:

- The argument is "we could check this at compile time."
  Compile-time work has costs (compilation seconds across every
  dependent project, harder error attribution, harder to debug);
  the bug class has to be real and recurring.
- The argument is "this would let users write less code." If
  the runtime form already reads cleanly, fewer characters is
  not the bar.
- The argument is "this would be more idiomatic in Elixir." See
  `posture.md`. Cross-SDK shape is the constraint; Elixir idiom
  is downstream of that.

A new macro form is rejected when:

- It hides indirection that a reader of the call site would not
  expect.
- The generated code reads worse than the equivalent hand-
  written form.
- The error messages it produces are vague or point at the
  wrong line.

## Compile time vs runtime

Compile-time validation is welcome when it catches a real bug
class with clear error messages:

- Widget field types resolve at compile time via
  `Plushie.Type.resolve/1`. Unknown types fail compilation with
  the offending field name and module.
- `container_scope` checks that options used inside a container
  block are supported by that container; an unsupported option
  fails compilation with the list of containers that support it.
- `canvas_scope` rewrites shape calls and rejects widget macros
  inside canvas blocks at compile time.
- DSL metadata leakage (`{:__widget_prop__}`,
  `{:__canvas_meta__}` tuples in the rendered tree) is detected
  during normalization and reported.

Compile-time validation is not welcome when:

- The check requires understanding values only available at
  runtime (event content, model shape, dynamic IDs).
- The check requires walking the entire compiled tree of the
  user's app; modules compile in isolation.
- The same bug class is catchable cleanly at runtime with a
  better error message.

Runtime validation that the DSL relies on:

- `validate_root_windows!` runs after every `view/1`; the top
  level of the tree must be window nodes.
- `Tree.normalize/2` raises with a structured error if it
  encounters a canvas shape struct in the widget tree, a leaked
  DSL metadata tuple, or a widget struct missing a `Tree.Node`
  protocol implementation.
- `Plushie.WidgetRegistry` is built from `Plushie.Tree.Node`
  protocol consolidation; native widgets that fail to register
  are caught when the renderer reports `required_widgets_missing`.

## Generated code is what users read

Stack traces from generated code show up in user error reports.
Errors raised from inside generated functions land in the user's
debugging session. The shape of generated code matters:

- Generated function bodies have stable, predictable structure.
  A user reading `MyApp.Gauge.new/2` in iex source should not
  be confused about what they are looking at.
- Generated names match user expectation. `new/2`, `with_options/2`,
  `build/1`, setter functions, `__event_specs__/0`,
  `__event_spec__/1`. No unstable internal names that change
  between versions.
- Errors from generated code name the macro context. A field
  type validation failure says "field :value in MyApp.Gauge has
  unknown type :foo," not "Plushie.Type.resolve/1 raised."

The macro authors hold this line. A change to codegen that
makes the runtime path clearer at the cost of generated-code
readability is the wrong direction.

## Type system as single behaviour

`Plushie.Type` is the unified behaviour for value coercion, wire
encoding, and compile-time field introspection. Every property
type, event field type, and primitive implements the same
callbacks:

- `cast/1` - coerce a user-provided value to the canonical
  shape.
- `encode/1` - convert to wire form.
- `fields/0` - struct field metadata for compile-time
  introspection.

Adding a new type means implementing this behaviour. No special
cases, no parallel hierarchies, no "well, this one is different
because..."

The composite type system (`{:list, T}`, `{:map, K, V}`, etc.)
is parameterized through `Plushie.Type.Composite`. New
composite forms earn their place by the same criteria as new
macro forms.

## Errors point at the call site

A macro error that points at the macro's own implementation is
broken. The user wants to know which line of their code is
wrong, not which line of plushie's codegen is doing the
checking. `__CALLER__` and explicit `quote location: :keep`
where appropriate; line tracking through nested macros where it
matters.

A useful error message:

- Names what is wrong in the user's terms (the field name, the
  widget name, the container name).
- Names what was expected (the supported types, the supported
  containers, the required form).
- Points at the user's source line, not the macro source line.

Vague error messages from the DSL are bug-class. They cost
users time and they cost us issue triage.

## What this looks like in practice

- A user proposes "let widgets declare deprecated fields with
  custom messages." Real bug class? Maybe (cross-SDK rename
  windows). Two real users? Currently no. Outcome: defer until a
  rename actually needs it; pre-1.0 we just rename.
- A user proposes "container blocks should support `for x <-
  list, do: ...` natively." Already works (the multi-expression
  control flow handling wraps the for body in a list literal).
  Outcome: document better, no new macro.
- A user proposes "auto-derive `cast/1` for new types from a
  schema." Real bug class? Field-type drift between similar types
  is a recurring issue. Two real users? Yes, every new type. The
  generated `cast/1` reads as cleanly as hand-written? Yes for
  primitive composites; no for types with custom coercion rules.
  Outcome: incremental - auto-derive for simple cases, hand-
  written for complex ones, with the line documented.
