# 0011: Composition patterns over composite widgets

## Status

Accepted.

## Context

Julep removed dedicated composite widgets (tabs, nav, modal, card, panel,
form, split_pane) from Julep.UI because they were speculative abstractions
encoding too many opinions. The framework provides 28+ primitive widgets that
can be composed freely. However, without style maps (ADR 0009), composition
produced results that looked like default-styled buttons and containers --
technically correct but visually unpolished. With style maps now available,
users need clear guidance on how to build common UI patterns from primitives.

Additionally, one targeted primitive addition is needed: `mouse_area` cursor
prop (iced's `mouse_area.interaction()` method) to change cursor on hover,
which is essential for polished interactive composition.

## Decision

1. **No dedicated composite widgets.** The library provides primitives and
   style maps. Users compose them. A comprehensive composition patterns guide
   (`docs/composition-patterns.md`) shows how to build common patterns.

2. **mouse_area cursor prop.** Wire through iced's
   `mouse_area.interaction(Interaction)` as a `cursor` prop. Values include
   `:pointer`, `:grab`, `:grabbing`, `:crosshair`, `:text`, `:move`,
   `:not_allowed`, `:progress`, `:wait`, `:help`, `:cell`, `:copy`, etc.

3. **Patterns documented.** Tab bar, sidebar/nav, toolbar, modal, card, split
   panel, breadcrumb, badge/chip. Each pattern includes full Elixir code using
   style maps, explanation, and visual description.

4. **Why not composite widgets?** A tab bar has many valid variations
   (horizontal/vertical, closeable, scrollable, icon-only, badge counts). A
   generic Tab widget would either be too simple to be useful or too complex
   to be maintainable. Primitives + style maps + examples lets users build
   exactly what they need.

## Consequences

- Users get copy-pasteable recipes for common patterns without the library
  shipping opinionated composite widgets.
- No maintenance burden from composite widgets that try to anticipate every
  variation.
- Style maps (ADR 0009) are the critical enabling dependency.
- `mouse_area` cursor prop makes hover interactions feel native.
- If a pattern turns out to need a new primitive, the pattern doc reveals the
  gap naturally -- patterns drive primitive additions, not the other way around.
