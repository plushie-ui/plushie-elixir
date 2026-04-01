# Accessibility

Plushie integrates with platform accessibility services via
[AccessKit](https://github.com/AccessKit/accesskit): VoiceOver on macOS,
AT-SPI/Orca on Linux, UI Automation/NVDA/JAWS on Windows. Most
accessibility semantics are inferred automatically from widget types,
so you get correct roles, labels, and state without extra work.

This reference covers how auto-inference works, when to use the `a11y`
prop for explicit overrides, keyboard navigation, live regions, common
patterns, and testing.

## Accessible by default

Plushie's [vendored Iced fork](https://github.com/plushie-ui/plushie-iced)
includes extensive accessibility and keyboard navigation support built
on top of Iced's rendering architecture. Built-in widgets expose
accessibility metadata automatically: a button announces itself as a
button, a checkbox tracks its checked state, a slider exposes its
numeric value and range. Application code does not need to add
accessibility attributes for standard widgets.

When you do need overrides (custom canvas controls, widgets with
context-dependent labels, relationship annotations), the `a11y` prop
is available on every widget.

## Auto-inference

### Role mapping

| Widget type | Inferred role |
|---|---|
| `button` | button |
| `text`, `rich_text` | label |
| `text_input` | text_input |
| `text_editor` | multiline_text_input |
| `checkbox` | check_box |
| `toggler` | switch |
| `radio` | radio_button |
| `slider`, `vertical_slider` | slider |
| `pick_list`, `combo_box` | combo_box |
| `progress_bar` | progress_indicator |
| `scrollable` | scroll_view |
| `image`, `svg`, `qr_code` | image |
| `canvas` | canvas |
| `table` | table |
| `pane_grid` | group |
| `rule` | splitter |
| `window` | window |
| `markdown` | document |
| `tooltip` | tooltip |
| Containers (column, row, etc.) | generic_container |

Layout containers use `generic_container`, which is filtered from the
platform accessibility tree automatically. Screen reader users navigate
through the semantic content (buttons, text, inputs) without encountering
intermediate layout wrappers.

### Label inference

| Widget type | Prop used as label |
|---|---|
| `button`, `checkbox`, `toggler`, `radio` | `label` prop |
| `text`, `rich_text` | `content` prop |
| `image`, `svg` | `alt` prop |
| `text_input` | `placeholder` prop (as description) |

### State inference

| State | Source |
|---|---|
| Disabled | `disabled: true` on any widget |
| Toggled | `checked` (checkbox), `is_toggled` (toggler) |
| Numeric value | `value` (slider, progress_bar) |
| Range | `range: [min, max]` (slider, progress_bar) |
| String value | `value` (text_input) |
| Selected | `selected` (pick_list) |

## The a11y prop

Every widget accepts an `a11y:` prop for explicit overrides. Pass a map
or keyword list:

```elixir
button("save", "Save", a11y: %{description: "Save the current document"})

text_input("email", model.email,
  a11y: %{required: true, labelled_by: "email-label"}
)
```

See `Plushie.Type.A11y` for the full struct definition.

### Fields

| Field | Type | Purpose |
|---|---|---|
| `role` | atom | Override the inferred role |
| `label` | string | Accessible name (override inferred label) |
| `description` | string | Longer description read after the label |
| `live` | `:polite \| :assertive` | Live region announcement mode |
| `hidden` | boolean | Exclude from accessibility tree |
| `expanded` | boolean | Disclosure state (combobox, menu) |
| `required` | boolean | Form field is required |
| `level` | 1-6 | Heading level |
| `busy` | boolean | Suppress announcements during updates |
| `invalid` | boolean | Form validation error state |
| `modal` | boolean | Dialog is modal (traps focus) |
| `read_only` | boolean | Value is readable but not editable |
| `toggled` | boolean | Toggle/checked state |
| `selected` | boolean | Selection state |
| `value` | string | Current value for assistive technology |
| `orientation` | `:horizontal \| :vertical` | Layout orientation hint |
| `disabled` | boolean | Disabled state override |
| `mnemonic` | string | Keyboard mnemonic (single character) |
| `position_in_set` | integer | 1-based position in a group |
| `size_of_set` | integer | Total items in the group |
| `has_popup` | string | Popup type: `"listbox"`, `"menu"`, `"dialog"`, `"tree"`, `"grid"` |

### Cross-references

| Field | Purpose |
|---|---|
| `labelled_by` | ID of the widget that provides this widget's label |
| `described_by` | ID of the widget that provides a description |
| `error_message` | ID of the widget showing the error message |

Cross-reference IDs are resolved relative to the current scope during
tree normalisation. A bare ID like `"label"` inside scope `"form"`
resolves to `"form/label"`. See [Scoped IDs](scoped-ids.md).

### Roles

Roles are organised into categories:

**Interactive**: `button`, `check_box`, `combo_box`, `link`,
`menu_item`, `radio_button`, `slider`, `switch`, `tab`, `text_input`,
`multiline_text_input`, `tree_item`

**Structure**: `generic_container`, `group`, `heading`, `label`, `list`,
`list_item`, `column_header`, `table_row`, `table_cell`, `table`, `tree`

**Landmarks**: `navigation`, `region`, `search`

**Status**: `alert`, `alert_dialog`, `dialog`, `status`, `meter`,
`progress_indicator`

**Other**: `document`, `image`, `canvas`, `menu`, `menu_bar`,
`scroll_view`, `separator`, `tab_list`, `tab_panel`, `toolbar`,
`tooltip`, `window`

**Aliases** (normalised to canonical): `:cell` -> `:table_cell`,
`:checkbox` -> `:check_box`, `:container` / `:generic` ->
`:generic_container`, `:progress_bar` -> `:progress_indicator`,
`:radio` -> `:radio_button`, `:row` -> `:table_row`,
`:text_editor` -> `:multiline_text_input`

## Accessible name computation

When a screen reader encounters a widget, it announces the widget's
**accessible name**. Getting this right is the most common accessibility
concern. The name is determined in this order:

1. **Direct label** - if the `a11y: %{label: "..."}` prop or the
   widget's inferred label is set, that's the name.
2. **Labelled-by** - if no direct label, the framework checks
   `labelled_by`. For roles that support name-from-contents (button,
   checkbox, radio, link), descendant text content is used automatically.
3. **No name** - the screen reader announces only the role.

If a widget has no accessible name, screen readers say things like
"button" with no context. Always ensure interactive widgets have either
a label prop or a `labelled_by` reference.

## Keyboard navigation

Plushie has built-in keyboard navigation:

| Key | Behaviour |
|---|---|
| Tab / Shift+Tab | Cycle focus through focusable widgets |
| Space / Enter | Activate the focused widget |
| Arrow keys | Navigate within sliders, lists, etc. |
| F6 / Shift+F6 | Cycle focus between pane_grid panes |
| Ctrl+Tab | Escape the current focus scope |
| Escape | Close popups, dismiss modals |

Focus follows the **focus-visible** pattern: focus rings appear on
keyboard navigation but not on mouse clicks.

### Canvas keyboard navigation

Canvas interactive groups can opt into keyboard focus with
`focusable: true`:

```elixir
group "save-btn", on_click: true, focusable: true,
  a11y: %{role: :button, label: "Save"} do
  rect(0, 0, 100, 36, fill: "#3b82f6")
end
```

`focusable: true` adds the group to the Tab order. Space/Enter activates
it. Without `focusable: true`, the group responds to mouse clicks but
is invisible to keyboard navigation and screen readers.

## Live regions

The `live:` field controls how screen readers announce dynamic content
changes. Use it on widgets whose content updates while visible:

| Value | Behaviour | Use for |
|---|---|---|
| `:polite` | Announced after current speech finishes | Status messages, counters, progress updates |
| `:assertive` | Interrupts current speech immediately | Error messages, critical alerts |

```elixir
text("status", model.status_message, a11y: %{live: :polite})
text("error", model.error, a11y: %{live: :assertive, role: :alert})
```

**Use `:assertive` sparingly.** Rapid updates cause announcement storms.
Prefer `:polite` for anything that updates more than once per user
action.

Do not set `live:` on static content. The screen reader re-announces
it on every tree rebuild even when the content hasn't changed.

## Disabled vs read-only

These are semantically different:

| State | Meaning | Screen reader behaviour |
|---|---|---|
| Disabled | Not currently usable | Often skipped in Tab navigation, announced as "dimmed" or "unavailable" |
| Read-only | Has a value that can be read but not changed | Fully navigable and announced, editing commands blocked |

Use `disabled: true` for controls that become active based on other
state (e.g. a Submit button disabled until required fields are filled).
Use `read_only: true` for displaying values the user can select/copy
but not edit.

## Common patterns

### Form field labelling

Every form control needs an accessible name. Three approaches:

**Direct label** (simplest):

```elixir
text_input("email", model.email,
  placeholder: "Email address",
  a11y: %{label: "Email address"}
)
```

**Cross-widget labelled_by**:

```elixir
text("email-label", "Email address")
text_input("email", model.email,
  a11y: %{labelled_by: "email-label"}
)
```

**Description for additional context**:

```elixir
text_input("password", model.password,
  a11y: %{label: "Password", described_by: "password-hint"}
)
text("password-hint", "Must be at least 8 characters", size: 11)
```

### Grouping related controls

Use the `:group` role when controls are logically related and the
grouping helps the user understand context:

```elixir
container "shipping-options",
  a11y: %{role: :group, label: "Shipping options"} do
  radio("standard", :standard, model.shipping, label: "Standard (5-7 days)")
  radio("express", :express, model.shipping, label: "Express (1-2 days)")
end
```

Do not wrap things in groups unless the grouping adds semantic value.
Layout containers (`column`, `row`) already use `generic_container`
and are invisible to screen readers.

### Canvas accessibility

Canvas is a raw drawing surface. The renderer has no way to know
that a group of shapes is meant to be a "button." You must provide
explicit accessibility annotations:

```elixir
group "save-btn",
  on_click: true,
  cursor: :pointer,
  focusable: true,
  a11y: %{role: :button, label: "Save experiment"} do
  rect(0, 0, 100, 36, fill: "#3b82f6")
  text(50, 11, "Save", fill: "#fff", size: 14)
end
```

Without `a11y` annotations, canvas elements are invisible to screen
readers and keyboard navigation.

## Platform notes

| Platform | AT service | Integration |
|---|---|---|
| macOS | VoiceOver | Via AccessKit -> NSAccessibility |
| Linux | Orca (AT-SPI) | Via AccessKit -> AT-SPI2 |
| Windows | NVDA / JAWS | Via AccessKit -> UI Automation |

Assistive technology actions (e.g. VoiceOver "activate") produce the
same `WidgetEvent` as direct interaction. No special handling needed in
`update/2`.

### Screen reader differences

**NVDA/JAWS (Windows)** operate in two modes: *browse mode* (screen
reader intercepts keys for virtual navigation) and *focus mode* (keys
pass to the app). They auto-switch to focus mode when Tab reaches an
interactive control.

**VoiceOver (macOS)** uses a *rotor* for category-based navigation
(headings, buttons, form fields). Correct roles ensure widgets appear
in the right rotor categories.

**Orca (Linux)** provides structural navigation similar to NVDA's
browse mode. Known caveat: Wayland keyboard input is currently broken
for screen readers, so Linux screen reader users need X11.

## Testing accessibility

```elixir
# Assert role
assert_role("#save", "button")

# Assert accessibility properties
assert_a11y("#email", %{required: true, invalid: false})

# Find by accessibility attributes
find_by_role(:button)
find_by_label("Save")
```

These assertions verify the accessibility tree, not just the visual
output. They catch missing labels, wrong roles, and missing state
annotations.

See the [Testing reference](testing.md) for the full assertion API.

## See also

- `Plushie.Type.A11y` - full struct and field documentation
- [Canvas reference](canvas.md) - canvas accessibility annotations
  and interactive groups
- [Scoped IDs reference](scoped-ids.md) - how `labelled_by` and
  `described_by` IDs are resolved
- [AccessKit](https://github.com/AccessKit/accesskit) - the
  cross-platform accessibility library Plushie uses
- [WAI-ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/) -
  W3C patterns for accessible widget design
- [WCAG 2.1](https://www.w3.org/TR/WCAG21/) - Web Content
  Accessibility Guidelines (the standard Plushie targets)
