# Known Issues

Tracked limitations in the current implementation. Items here are either
upstream constraints (iced/Rust ecosystem) or deliberate tradeoffs. They
should be addressed when the relevant upstream support lands or when a
clean workaround becomes available.

## Canvas LineDash segment leak

**Location:** `native/julep_gui/julep-core/src/widgets.rs`, `parse_canvas_stroke`

**Issue:** iced's `canvas::LineDash` borrows its `segments` slice as
`&'static [f32]`. Because the segments come from user-supplied JSON, we
allocate a `Vec<f32>`, convert to a boxed slice, and `Box::leak` it to
obtain the required `'static` lifetime. Every cache invalidation of a
layer that uses a dashed stroke leaks the old segments buffer.

**Impact:** Low. Cached layers only re-draw when content changes. A
canvas with a static dash pattern leaks exactly once. Dynamic canvases
that change dashed strokes frequently will accumulate small allocations
(typically 8-32 bytes each) that are never freed until the process exits.

**Fix:** Requires upstream iced to accept `Vec<f32>` or `Arc<[f32]>` in
`LineDash` instead of a borrowed `&'static [f32]`. Alternatively, we
could pool and reuse dash segment buffers, but the complexity isn't
justified given the low impact.

**Tracking:** iced upstream -- no open issue yet.

## DefaultHasher is not stable across Rust versions

**Location:** `native/julep_gui/julep-core/src/widgets.rs`, `hash_json_str`

**Issue:** Canvas layer cache invalidation uses `std::collections::hash_map::DefaultHasher`
to hash layer content. The Rust docs state that `DefaultHasher` output is
not guaranteed to be stable across compiler versions or builds.

**Impact:** None for correctness. Hashes are only used within a single
process run for cache invalidation (same content = same hash within one
session). If hashes were ever persisted to disk or compared across
process restarts, they could silently mismatch. The code has comments
warning against this.

**Fix:** Switch to a stable hasher (e.g. `ahash` with fixed seeds, or
`xxhash`) if cache persistence is ever needed. Not worth the dependency
for the current use case.

## set_icon uses base64 in both wire formats

**Location:** `lib/julep/command.ex` (`set_icon/4`), `native/julep_gui/julep-bin/src/main.rs`

**Issue:** `set_icon` embeds RGBA pixel data as a base64 string inside
the generic `WindowOp { settings: Value }` map. Unlike `ImageOp` (which
uses native msgpack binary), the `settings` field is a `serde_json::Value`
which has no binary type. The 33% base64 overhead applies to icon data
in both JSON and msgpack modes.

**Impact:** Low. `set_icon` is typically called once at app startup with
a small icon (32x32 or 64x64). The overhead on a 64x64 RGBA icon is
~5KB extra.

**Fix:** Give `set_icon` its own dedicated message type (like `ImageOp`)
instead of piggybacking on `WindowOp`. This would let it use the native
binary path. Deferred because the impact is negligible.

## progress_bar text_color maps to bar fill color

**Location:** `native/julep_gui/julep-core/src/widgets.rs`, `apply_progress_bar_fields`

**Issue:** When using a `StyleMap` on a `progress_bar`, the `text_color`
field is mapped to the bar fill color (`style.bar`), not to any text.
This is because `progress_bar::Style` has no text -- only `background`,
`bar`, and `border`. The `text_color` key was reused as the closest
semantic match for "the colored part."

**Impact:** Confusing API for style map users. Setting `text_color` on a
progress bar changes the fill color, not text.

**Fix:** Add a `bar_color` alias in `StyleMap` that maps to `style.bar`
directly, and either ignore `text_color` for progress bars or log a
warning. This requires a wire format addition and Elixir-side `StyleMap`
change.

## ensure_caches O(n) on every apply

**Location:** `native/julep_gui/julep-core/src/widgets.rs`, `ensure_caches`

**Issue:** The `ensure_caches()` function walks all nodes on every
`apply()` call to maintain widget caches (text_editor Content, combo_box
State, canvas Cache, etc.). This is O(n) in tree size. For most apps this
is negligible, but apps with thousands of stateful widgets may see
measurable overhead. Incremental cache updates (only processing changed
subtrees from patch ops) would reduce this to O(changed) but requires
significant architectural work.

**Impact:** Low for typical apps. Only relevant for very large trees with
many stateful widgets (text_editor, combo_box, canvas).

**Fix:** Track which subtrees changed via patch ops and only walk those
in `ensure_caches()`. Requires threading patch metadata through to the
cache maintenance layer, which touches Core, Tree, and the widget cache
system. Not worth the complexity until a real app hits this bottleneck.

## Child reorder triggers full subtree replacement

**Location:** `lib/julep/tree.ex`, `diff_children` / `children_reordered?`

**Issue:** When children of a node are reordered (same IDs, different
positions), the diffing algorithm detects this via `children_reordered?`
and emits a single `replace_node` operation for the entire parent subtree
rather than computing individual move operations. This means reordering
one item in a 100-element list serializes all 100 children.

**Impact:** Low for most apps. Reordering is uncommon in typical UIs.
Apps with drag-and-drop reordering of large lists may see larger-than-
necessary patches. The full replacement is always correct -- it's a
performance concern, not a correctness concern.

**Fix:** Add a `move_child` patch operation that communicates the old and
new index. The Rust side would need a corresponding `apply_move` handler.
This requires changes to the wire protocol, tree.ex diffing, and
tree.rs patching -- a non-trivial effort. Not worth doing until profiling
shows reorder patches as a bottleneck.

## Only one subscription tag per kind on the renderer

**Location:** `native/julep_gui/julep-core/src/engine.rs` (`active_subscriptions`),
`lib/julep/runtime.ex` (`sync_subscriptions`)

**Issue:** The Rust renderer stores active subscriptions in a
`HashMap<String, String>` keyed by kind (e.g. `"on_key_press"`). When
Elixir registers a subscription, the renderer does
`self.active_subscriptions.insert(kind, tag)` -- a plain HashMap insert
that overwrites any previous tag for that kind.

Elixir's runtime keys subscriptions by `{type, tag}` (or
`{:every, interval, tag}` for timers), so it considers
`on_key_press(:shortcuts)` and `on_key_press(:game_input)` to be two
distinct subscriptions. But the renderer can only store one tag per kind,
so registering both means only the last-registered tag survives on the
Rust side. The renderer will emit events tagged with whichever tag was
registered last, and events for the other tag are silently lost.

**Impact:** Low in practice. Most apps use a single subscription per
kind and dispatch within `update/2` via pattern matching. Apps that try
to register multiple subscriptions of the same kind with different tags
will see only one of them fire.

**Fix:** Change the renderer's `active_subscriptions` to
`HashMap<String, Vec<String>>` (or `HashMap<String, HashSet<String>>`)
so multiple tags can coexist per kind. The event emission code would
then iterate over all tags for the matching kind. Alternatively, document
that one subscription per kind is the supported model and have the
Elixir runtime warn or merge duplicate-kind subscriptions before sending
to the renderer.
