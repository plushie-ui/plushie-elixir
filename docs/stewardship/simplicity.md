# Simplicity

The bar code in plushie-elixir has to clear, and the recurring
tradeoffs about structure and abstraction that decide what earns
its place. The other stewardship docs (`performance-bar.md`,
`resilience.md`, `test-discipline.md`, `dsl-discipline.md`) each carry
a flavor of this implicitly; this doc states it directly so
questions about "should we extract this" or "is this clear
enough" have an explicit reference.

This is not a style guide. Naming, formatting, lint rules, and
language-specific idioms live in `mix format`, Credo, and the
project's `.formatter.exs`. This doc is about the posture above
those: when to add complexity, when to refuse it, what clarity
costs, and what readability buys.

## Clarity is a constraint, not an aspiration

Code in plushie-elixir has to read clearly to an Elixir engineer
who has not been in this codebase before. "It works" is the floor;
"it can be understood without context" is the bar.

Every reader pays the cost of obscure code. The author writes it
once; many readers will read it. Small clarity wins compound
across hundreds of files; small obscurity losses compound the
other way. Same compounding argument that drives the lightweight-
by-default stance in `performance-bar.md`, applied to reader
cost instead of CPU cost.

The bar is not negotiable. Optimizations, abstractions,
defensive layers, refactors, and macro additions all have to
clear it; the readability test wins ties.

## Abstraction has to earn its place

Extracting a helper, a module, a behaviour, a macro, a protocol:
each carries cost. A reader has to follow the indirection, hold
the abstraction's contract in their head, and decide whether what
the call site shows reflects what the abstraction does inside.
The benefit has to clearly outweigh that cost.

Working rules:

- **Three similar lines is better than a premature abstraction.**
  Two pieces of code that look similar today might diverge
  tomorrow; extracting them now locks them together for reasons
  that may not survive contact with future requirements.
- **By the third use of a similar pattern, the abstraction
  earns consideration.** Not commitment, consideration. The
  question is whether the three uses are the same concept or
  three coincidentally similar ones.
- **An abstraction with one user is a costume, not an
  abstraction.** Single-use indirection is overhead. A protocol
  with one impl, a behaviour with one module, a macro that
  wraps one call site.
- **"We might need this someday" is a reason not to extract.**
  Generic code written for hypothetical future users is the
  recurring source of half-built abstractions that nobody fully
  understands later. The DSL is especially vulnerable here; see
  `dsl-discipline.md`.
- **Generic where specific would do is harder to read.** A
  concrete struct beats a parameterized one when the
  parameterization does not have at least two real uses.

These are working positions, not absolute rules. The burden is
on the proposed abstraction to push against them.

## Local complexity over global complexity

A 200-line function that does one thing clearly is preferable to
the same logic spread across five files in pursuit of "smaller
functions." Locality is a feature: a reader can hold the whole
thing in view. Following control flow across ten indirections
costs more than reading a longer linear sequence.

Module size on its own is not a problem. A large module is not
an invitation to split unless a real change is forced to bend
around its existing shape. Refactoring without a forcing
function is a non-goal (`goals-and-non-goals.md`); this is one
of the places that rule shows up most often. The runtime is
large because the runtime does a lot; that is fine.

Files split for the sake of "smaller files" frequently end up
with cross-file dependencies that obscure the same logic the
single file made obvious. Cohesion across a file beats brevity
of any one file.

## Functional flavor

The codebase is functional-first; Elixir's natural fit. The
Elm-architecture pattern (`init/update/view`) is the SDK's
structural backbone for a reason. The recurring choices that
follow:

- **Pure functions where possible.** Side effects push to the
  edges (Bridge owns I/O, command execution wraps effectful
  calls, the rest of the runtime is functional). `update/2` is
  pure: it returns a new model and commands; the runtime
  performs the commands.
- **Immutable data.** Elixir is immutable by default, and the
  codebase keeps it that way. ETS, agents, and process state
  are used where they belong, not as ergonomics for "just
  mutate this."
- **Pattern matching over branching.** Multi-clause function
  heads, destructuring binds, and guards beat nested
  `if`/`case` chains where the shapes are stable. When the
  shapes are not stable, a single `case` is clearer than
  pattern-matched dispatch the reader has to reconstruct.
- **Sum types over flag-based state machines.** A union of
  named structs (`%KeyEvent{}`, `%WidgetEvent{}`,
  `%WindowEvent{}`, etc.) beats a generic event map with three
  booleans and an unwritten rule about which combinations are
  valid. `@enforce_keys` is part of this; it makes invalid
  shapes unconstructable.
- **Errors as values.** `{:ok, value}` / `{:error, reason}` for
  recoverable conditions; raise for invariant violations only
  (see `resilience.md`). `with` for chained value-returning
  steps where the early-exit shape is the point.
- **Pipelines where they read top-down.** A pipe that flows
  through transformations is clearer than nested calls; a pipe
  that requires the reader to mentally re-thread arguments is
  not. The threshold is the reader, not the line count.
- **Composition over inheritance-shaped patterns.** Behaviours
  define a contract; modules implement it. Protocols dispatch
  on type. There is no `extend`, no `super`, no inheritance.
  Composition through smaller modules with explicit
  dependencies is the shape that scales.

Elixir idiom prevails on syntax (snake_case, atom keys,
`{:ok, _}` tuples, `with` blocks, pipelines). The concept-
level patterns above converge with the rest of the project
ecosystem (see `posture.md` on the cross-SDK story).

## Comments earn their place too

Code should explain itself. Comments answer questions the code
cannot:

- A non-obvious constraint or invariant the surrounding code
  holds.
- A surprising or subtle behavior a reader might trip on.
- A workaround for a specific external issue that the reader
  needs to understand to evaluate the code.

Comments are not for explaining what the next line does. If a
comment is needed to explain what, the code itself usually
wants to be clearer.

`@moduledoc` and `@doc` are documentation, not comments; they
have a different purpose and a different bar. Public modules
and callbacks have docstrings that read as user-facing
documentation. Internal modules use `@moduledoc false` rather
than empty docstrings.

## Implications

- Abstractions added without justifying use are declined, even
  when technically correct.
- Refactors that fragment a coherent module into smaller files
  without a forcing function are declined.
- Half-built abstractions (extracted but only partially
  applied, or extracted with planned consumers never arriving)
  are bug-class. Either complete the application or fold the
  abstraction back into the call sites.
- Reviewer comments of the form "I had to re-read this three
  times" are first-class and earn a rewrite, regardless of
  whether the code is correct as written.
- Typespecs use the verbose `name :: type()` parameter form for
  clarity; dialyzer suppression for type mismatches is a
  signal the type is wrong, not a tool for silencing it.
