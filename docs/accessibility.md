# Accessibility

Accessibility is not implemented in v1. This doc captures the intended
approach so it is designed for rather than bolted on.

## What iced provides

Iced integrates with [accesskit](https://github.com/AccessKit/accesskit)
for platform accessibility APIs. Built-in widgets automatically provide:

- Roles (button, text input, checkbox, etc.)
- Labels and descriptions
- State (checked, disabled, focused, expanded)
- Actions (click, toggle, set value)
- Keyboard navigation (tab order, focus management)

This means any app built with standard iced widgets gets baseline
accessibility for free. Screen readers can read labels, announce state
changes, and navigate the widget tree.

## What julep needs to do

Since julep drives iced via the wire protocol, the accessibility story depends on
how well the renderer maps tree nodes to accessible widgets:

1. **Direct iced widgets (text, button, checkbox, etc.) should work
   automatically.** The renderer constructs real iced widgets, which
   carry accesskit semantics natively. No extra work needed.

2. **Composite widgets (tabs, nav, modal, card, etc.) need explicit
   accessibility annotations.** These are assembled from primitives and
   may not automatically convey the right roles and relationships. The
   renderer must set appropriate roles (tab, tablist, dialog, navigation)
   and ARIA-like properties.

3. **Custom content (canvas, shader) has no automatic accessibility.**
   Apps using these widgets must provide alternative text or descriptions
   via props.

## Planned approach

### Phase 1: automatic from iced widgets

Do nothing special. Direct widget mapping gives us iced's built-in
accessibility. Verify it works with screen readers on each platform.

### Phase 2: composite widget roles

Add role annotations to composite widgets in the renderer:

| Composite widget | Accessible role |
|---|---|
| tabs | `tablist` + `tab` + `tabpanel` |
| nav | `navigation` |
| modal | `dialog` |
| card | `group` or `article` |
| panel | `group` with `expanded`/`collapsed` |
| form | `form` |
| table | `table` + `row` + `cell` |

### Phase 3: app-level annotations

Expose accessibility props in the tree for apps that need custom
semantics:

```elixir
container "search_results", a11y: %{role: "region", label: "Search results"} do
  ...
end

button("close", "X", a11y: %{label: "Close dialog"})
```

The `a11y` prop would be passed through to the renderer's accesskit node.

## What we are NOT doing

- Building our own accessibility tree separate from iced's. Iced already
  handles this via accesskit. We use it.
- Implementing ARIA in the wire protocol. The renderer maps props to
  accesskit attributes. Elixir does not need to know about accesskit
  internals.
- Blocking v1 on accessibility. The foundation (iced + accesskit) is
  solid. We build on it incrementally.

## Testing accessibility

When we implement accessibility:

- Verify screen reader output on macOS (VoiceOver), Windows (NVDA/JAWS),
  and Linux (Orca).
- Add integration tests that assert on the accessibility tree (accesskit
  provides introspection APIs).
- Test keyboard navigation: tab order, focus trapping in modals, escape
  to close.

## Resources

- [accesskit](https://github.com/AccessKit/accesskit) -- the cross-platform
  accessibility toolkit iced uses
- [WAI-ARIA roles](https://www.w3.org/TR/wai-aria-1.2/#role_definitions) --
  reference for role semantics
- [iced accessibility PR history](https://github.com/iced-rs/iced/pulls?q=accessibility) --
  iced's accessibility implementation progress
