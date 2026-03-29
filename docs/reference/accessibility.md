# Accessibility Reference

Plushie integrates with platform accessibility services (VoiceOver on macOS,
AT-SPI/Orca on Linux, UI Automation/NVDA/JAWS on Windows) via AccessKit.
Most accessibility semantics are inferred automatically from widget types.
The `a11y` prop provides explicit overrides.

## Auto-inference

The framework infers accessibility roles, labels, and state from widget
types and props. This happens Elixir-side (in `Plushie.Automation.Element`)
using a built-in role mapping.

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
| `rule` | separator |
| `window` | window |
| `markdown` | document |
| `tooltip` | tooltip |
| Containers (column, row, etc.) | generic_container |

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

Auto-inference is sufficient for most widgets. Override with the `a11y` prop
when you need different roles, additional labels, or relationship annotations.

## The a11y prop

Every widget accepts an `a11y:` prop. See `Plushie.Type.A11y` for the full
struct and field documentation.

### Key fields

| Field | Type | Description |
|---|---|---|
| `role` | atom | Widget role (overrides inferred) |
| `label` | string | Accessible name |
| `description` | string | Longer description |
| `live` | `:off`, `:polite`, `:assertive` | Live region announcement mode |
| `hidden` | boolean | Exclude from accessibility tree |
| `expanded` | boolean | Disclosure state |
| `required` | boolean | Form field requirement |
| `level` | 1--6 | Heading level |
| `busy` | boolean | Suppress announcements during updates |
| `invalid` | boolean | Validation error state |
| `modal` | boolean | Modal dialog |
| `read_only` | boolean | Non-editable content |
| `toggled` | boolean | Toggle state |
| `selected` | boolean | Selection state |
| `value` | string | Current value for AT |
| `orientation` | `:horizontal`, `:vertical` | Layout orientation |
| `disabled` | boolean | Disabled state |
| `mnemonic` | string | Keyboard mnemonic |
| `position_in_set` | integer | Position in a group (1-based) |
| `size_of_set` | integer | Total items in group |
| `has_popup` | string | Popup type: `"listbox"`, `"menu"`, `"dialog"`, `"tree"`, `"grid"` |

### Cross-references

| Field | Description |
|---|---|
| `labelled_by` | ID of widget providing the label |
| `described_by` | ID of widget providing description |
| `error_message` | ID of widget showing error message |

Cross-reference IDs are resolved relative to the current scope during tree
normalization. A bare ID like `"label"` inside scope `"form"` resolves to
`"form/label"`.

### Roles

See `Plushie.Type.A11y` for the full list of canonical roles and aliases.
Roles are organized into categories:

- **Interactive**: button, checkbox, combo_box, link, menu_item, radio_button,
  slider, switch, tab, text_input, multiline_text_input, tree_item
- **Structure**: generic_container, group, heading, label, list, list_item,
  column_header, table_row, table_cell, table, tree
- **Landmarks**: navigation, region, search
- **Status**: alert, alert_dialog, dialog, status, meter, progress_indicator
- **Other**: document, image, menu, menu_bar, scroll_view, separator,
  tab_list, tab_panel, toolbar, tooltip, window

Aliases: `cell` -> `table_cell`, `container` -> `generic_container`,
`progress_bar` -> `progress_indicator`, `radio` -> `radio_button`,
`text_editor` -> `multiline_text_input`.

## Keyboard navigation

Plushie has built-in keyboard navigation:

| Key | Behaviour |
|---|---|
| Tab / Shift+Tab | Cycle focus through focusable widgets |
| Space / Enter | Activate the focused widget |
| F6 / Shift+F6 | Cycle focus between pane_grid panes |
| Ctrl+Tab | Escape the current focus scope |
| Arrow keys | Navigate within sliders, lists, etc. |

Focus follows the **focus-visible** pattern: focus rings appear on keyboard
navigation but not on mouse clicks.

Modal dialogs trap focus -- Tab cycling stays within the modal until it is
dismissed.

## Platform notes

| Platform | AT Service | Integration |
|---|---|---|
| macOS | VoiceOver | Via AccessKit |
| Linux | AT-SPI / Orca | Via AccessKit |
| Windows | UI Automation / NVDA / JAWS | Via AccessKit |

Assistive technology actions (e.g., VoiceOver "activate") produce the same
`WidgetEvent` as direct interaction. No special handling needed in `update/2`.

## Testing accessibility

```elixir
assert_role("#save", :button)
assert_a11y("#email", %{required: true, invalid: false})
find_by_role(:button)
find_by_label("Save")
```

See the [Testing reference](testing.md) for the full assertion API.

## See also

- `Plushie.Type.A11y` -- full struct and field docs
- Accessibility is woven through guide chapters -- each widget introduction
  includes its a11y behaviour.
