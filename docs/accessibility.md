# Accessibility

Julep provides built-in accessibility support via
[accesskit](https://github.com/AccessKit/accesskit), a cross-platform
accessibility toolkit. When the `a11y` feature is enabled in the renderer,
native platform accessibility APIs are activated: VoiceOver on macOS,
AT-SPI/Orca on Linux, and UI Automation/NVDA/JAWS on Windows.

## Architecture

Iced 0.14 does not include accesskit integration. Julep vendors a patched
copy of `iced_winit` (in a separate repository) that adds per-window
accesskit adapter management behind an `a11y` feature flag. The renderer
(`julep-bin`) builds accesskit tree updates from the UI tree after every
snapshot or patch, and pushes them to the platform accessibility layer.

```
Elixir (a11y props) -> Wire protocol -> Renderer -> accesskit TreeUpdate -> Platform AT
                                                                           (VoiceOver, Orca, NVDA)
```

## Auto-inference

Most widgets get correct accessibility semantics automatically. The renderer
maps widget types to accesskit roles and extracts labels, descriptions, and
state from existing props:

| Widget type | Inferred role | Auto-inferred from |
|---|---|---|
| button | Button | `label` prop -> accessible name |
| text | Label | `content` prop -> accessible name |
| text_input | TextInput | `placeholder` -> description, `value` -> value |
| text_editor | MultilineTextInput | -- |
| checkbox | CheckBox | `label` -> name, `checked` -> toggled state |
| toggler | Switch | `label` -> name, `is_toggled` -> toggled state |
| radio | RadioButton | `label` -> name |
| slider, vertical_slider | Slider | `value`, `range` -> numeric value + min/max |
| pick_list, combo_box | ComboBox | `selected` -> value |
| progress_bar | ProgressIndicator | `value`, `range` -> numeric value + min/max |
| scrollable | ScrollView | -- |
| container, column, row, stack | GenericContainer | -- |
| window | Window | -- |
| image, svg | Image | `alt` prop -> accessible name |
| canvas | Canvas | -- |
| table | Table | -- |
| markdown | Document | -- |
| pane_grid | Group | -- |
| rule | Splitter | -- |
| tooltip | Tooltip | -- |

Additionally:
- `disabled: true` on any widget sets the disabled state.
- String `value` props (text_input) are exposed as the accessible value.
- Numeric `value` + `range` props (slider, progress_bar) are exposed as
  numeric value with min/max bounds.

## The a11y prop

For widgets where auto-inference is insufficient, use the `a11y` prop to
override or augment accessibility semantics:

```elixir
# Override the role
container "search_results", a11y: %{role: "region", label: "Search results"} do
  ...
end

# Add a descriptive label to an icon button
button("close", "X", a11y: %{label: "Close dialog"})

# Mark as a heading
text("Welcome", a11y: %{role: "heading", level: 1})

# Live region for status updates
text("Saved!", a11y: %{live: :polite})

# Hide decorative elements from the accessibility tree
rule(a11y: %{hidden: true})
```

### Available a11y fields

| Field | Type | Description |
|---|---|---|
| `role` | string | Override the inferred accesskit role |
| `label` | string | Accessible name (announced by screen readers) |
| `description` | string | Longer description |
| `live` | `:off` \| `:polite` \| `:assertive` | Live region semantics |
| `hidden` | boolean | Exclude from accessibility tree |
| `expanded` | boolean | Expanded/collapsed state |
| `required` | boolean | Mark form field as required |
| `level` | integer | Heading level (1-6) |

The `a11y` prop is available on every widget. It's a plain map that passes
through the wire protocol to the renderer, where it overrides auto-inferred
values.

## Canvas accessibility

Canvas widgets have no automatic accessibility -- they render arbitrary
shapes. Provide alternative text via the `a11y` prop:

```elixir
canvas("chart",
  layers: %{"data" => chart_shapes},
  a11y: %{role: "image", label: "Sales chart: Q1 revenue up 15%"}
)
```

For interactive canvases, consider wrapping in a `mouse_area` with an
appropriate `a11y` label.

## Action handling

When an assistive technology triggers an action (e.g. screen reader user
activates a button), the renderer translates it to the standard julep
event:

| AT action | Julep event |
|---|---|
| Click / Default | `{:click, id}` |
| SetValue | `{:input, id, value}` |
| Focus | (internal focus tracking) |
| Other | `{:a11y_action, id, action_name}` |

No special handling is needed in your `update/2` -- AT actions produce the
same events as direct user interaction.

## Testing accessibility

The test framework provides assertions for accessibility semantics:

```elixir
use Julep.Test.Case, app: MyApp

test "heading has correct role" do
  assert_role("#title", "heading")
end

test "search box is properly labelled" do
  assert_a11y("#search", %{"label" => "Search", "required" => true})
end
```

`assert_role/2` checks the inferred role (widget type + a11y override).
`assert_a11y/2` checks specific fields in the a11y prop map.

The `Julep.Test.Element` module also provides:
- `a11y/1` -- returns the a11y prop map
- `inferred_role/1` -- returns the role string (matching Rust-side mapping)

## Building with accessibility

The `a11y` feature is optional. To build the renderer with accessibility:

```bash
cd native/julep_gui
cargo build --features a11y
```

The feature is additive -- all existing functionality works identically
with or without it. The `a11y` feature:
- Enables accesskit in the vendored `iced_winit`
- Enables the accessibility module in `julep-core`
- Wires tree-to-accesskit conversion in `julep-bin`

## Platform support

| Platform | AT | Status |
|---|---|---|
| Linux | Orca (AT-SPI) | Supported via accesskit 0.18 |
| macOS | VoiceOver (NSAccessibility) | Supported via accesskit 0.18 |
| Windows | NVDA/JAWS (UI Automation) | Supported via accesskit 0.18 |
