# Performance bar

plushie-elixir is meant to feel lightweight in use and lightweight
in the process listing. That is a baseline expectation, not an
optimization target chased after the fact.

The runtime sits between every event and every render. Work it
does on a hot path is paid by every interaction in every app.
Idle apps that draw CPU draw battery; runtimes that walk the tree
six times per update are felt on larger trees even when each walk
profiles cleanly. The whole point of going native through a typed
wire is that the host should feel lighter than what it replaces;
a runtime that pegs CPU loses that on its own merits.

## Working principle

Lightweight is achieved by not doing unnecessary work in the first
place. Optimizing a hot path after the fact is sometimes
necessary; far more of the win comes from never letting the work
appear.

Each piece of work has a cost. Individually most of them are
cheap; the cost compounds across a frame, an interaction, an
app's lifetime, the user's battery. A tree walk that runs in
0.3ms looks fine in isolation; six of them per update on a
medium tree is visible latency. Watch the compounding, not just
the individual microbenchmark.

The canonical example to keep in mind: tree normalization
threading a `NormalizeCtx` through a single traversal that
accumulates widget handlers, event registries, scope chains, and
window IDs all at once, instead of multiple post-hoc walks. None
of the alternative walks would have flagged as a hotspot in a
profile of a small app. The consolidation was correct work
because the redundant work was unnecessary, the change made the
code clearer rather than worse, and the aggregate cost mattered
for larger apps and edge cases. That is the shape of performance
work that earns its place without a benchmark.

## Readability is the bound

Optimizations that obscure intent trade a forever cost (every
future reader) against a one-time benefit. Decline that trade
by default.

Worth doing without a benchmark because the win is obvious in
shape and readability is preserved or improved:

- Consolidating redundant traversals, dispatches, or
  serialization passes.
- Picking the right data structure for a known access pattern
  (map-by-id over list-scan; ETS only when GenServer state genuinely
  is the wrong fit).
- Avoiding a clearly unnecessary allocation, copy, or `Enum`
  pass that another function on the same data already did.
- Localized refactors where the optimized form is also the
  cleaner form.
- Removing per-frame work that does not depend on per-frame
  inputs (move it to startup, to subscription diff, or to the
  edge where the input changes).

Need a benchmark, profile, or repro before they land, because
the readability cost is real:

- Clever encoding, lookup, or layout schemes that change how the
  code reads.
- Big-O claims of the form "this is O(n) on a hot path" without
  realistic N. Many such claims have N in the dozens, where the
  constant factor of `Map.get/2` or `Enum.find/2` is worse than a
  linear scan over a list.
- Optimizations on idle or rarely-hit paths (startup, settings
  parsing, error paths, dev-mode overlays).
- Anything that asks the reader to look up a comment to
  understand what the code is doing.
- ETS over GenServer state where there is no measured contention
  problem.

Measurement is a tiebreaker for the second list, not a gate on
the first.

## What lightweight looks like

Numeric direction for the realistic application profile (a few
hundred to about a thousand active tree nodes, dozens of images,
one to five fonts):

- **Frame budget.** 16.67ms (60fps) for a single update cycle
  end-to-end (event arrival, app `update/2`, `view/1`, tree
  diff, wire emit). Most of that budget belongs to the renderer;
  the SDK side should be a small slice.
- **Event-to-update.** Visible by the next frame.
  Sub-millisecond wire round-trip on a local pipe.
- **Idle CPU.** When nothing is happening, the runtime does no
  measurable work. No periodic polling, no animation tick when
  no animation is active, no spinning subscription threads, no
  per-frame walks when the tree has not changed.
- **Subscription cost.** Subscribing to a high-frequency source
  is the user's choice; the runtime applies coalescing
  (`default_event_rate`, per-subscription `max_rate`) so the cost
  is bounded by what the user opts into.
- **Resident memory.** A few tens of MiB for an idle small app
  process tree. Memory grows with widget state and tree size, not
  with runtime bookkeeping. Internal caches (memo, widget view
  cache, normalize caches) bound their size.

These are direction, not contracts. There is no benchmark
infrastructure in the repo today; numbers should be tightened
or relaxed when measurement disagrees.

## Compile-time work is not free either

The macro DSL does substantial work at compile time (codegen,
field validation, scope checks). Cheap at runtime, but every
addition to the DSL costs compilation seconds across every
project that depends on plushie. Adding compile-time validation
is welcome when it catches a real class of bugs; adding it
because "we could check this at compile time" without a real
class of bugs is the same kind of compounding cost the runtime
side worries about. See `macro-dsl.md`.

## Tree diff is the load-bearing piece

`Plushie.Tree.Diff` is the hot path that runs every cycle the
view tree changes. Worth preserving:

- Single-pass diff with LIS-based child reorder. The cost of an
  unnecessary full re-emit on a large tree is far worse than the
  cost of computing minimal moves.
- Memo-based skipping (`memo/2`) for expensive subtrees with
  stable cache keys.
- Per-widget view cache so deferred composite widgets do not
  re-render when neither props nor state changed.

Changes to the diff path that look like cleanups but actually
inflate work per node (extra map lookups, redundant key
stringification, repeated `Map.get/2` chains where a destructure
would do) get caught here because the compounding is most
visible.
