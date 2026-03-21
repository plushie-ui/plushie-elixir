# Accessibility

Toddy provides built-in accessibility support via
[accesskit](https://github.com/AccessKit/accesskit), a cross-platform
accessibility toolkit. The default renderer build includes accessibility,
activating native platform APIs automatically: VoiceOver on macOS,
AT-SPI/Orca on Linux, and UI Automation/NVDA/JAWS on Windows.

Screen reader users, keyboard-only users, and other AT users interact with
the same widgets and receive the same events as mouse users. No special
event handling is needed in your `update/2` -- AT actions produce the same
`%Widget{type: :click, id: id}`, `%Widget{type: :input, id: id, value: val}`, etc. events as direct interaction.


## How it works

Iced's fork (`v0.14.0-a11y-accesskit` branch) provides native accessibility
support. Three pieces work together:

1. **iced widgets report `Accessible` metadata** -- each widget implements
   the `Accessible` trait via iced's `operate()` mechanism. Widgets declare
   their role, label, and state to the accessibility system automatically.

2. **TreeBuilder assembles the accesskit tree** -- `iced_winit::a11y`
   contains a `TreeBuilder` that walks the widget tree during `operate()`,
   collecting `Accessible` metadata and building an accesskit `TreeUpdate`.
   This happens natively inside iced -- toddy does not build the tree.

3. **AT actions become native iced events** -- when an AT triggers an action
   (e.g. a screen reader user activates a button), iced translates it to a
   native event. The renderer maps it to a standard toddy event and sends it
   to Elixir over the wire protocol.

```
Host (Elixir)             Renderer (iced)               Platform AT
   |                         |                              |
   |--- UI tree (a11y) ----->|                              |
   |                         |-- operate() + TreeBuilder -->|
   |                         |-- TreeUpdate --------------->|
   |                         |                              |
   |                         |<-- AT Action (Click) --------|
   |                         |   (native iced event)        |
   |<-- %Widget{:click} -----|                              |
```

### toddy's role

toddy does not build its own accesskit tree. Iced handles tree building,
AT actions, and platform integration natively. toddy's contribution is the
`A11yOverride` wrapper widget (`a11y_widget.rs` in toddy) that
intercepts `operate()` to apply Elixir-side overrides from the `a11y` prop.

This means:

- **Standard widgets** get correct accessibility semantics automatically
  from iced's own `Accessible` implementations.
- **Extension widgets** get free a11y support without any code -- they are
  already iced `Element`s that participate in `operate()`.
- **The `a11y` prop** lets Elixir override or augment the inferred semantics
  when auto-inference is insufficient.
- **`HiddenInterceptor`** is a companion wrapper that excludes widgets from
  the AT tree when `hidden: true` is set.

Accessibility is compiled unconditionally -- there are no feature flags to
toggle it.


## Auto-inference

Most widgets get correct accessibility semantics without any annotation.
Iced automatically reports roles, labels, and state from widget types and
existing props via the `Accessible` trait.

### Role mapping

Every widget type maps to an accesskit role:

| Widget type | Role | Notes |
|---|---|---|
| `button` | Button | |
| `text`, `rich_text` | Label | |
| `text_input` | TextInput | |
| `text_editor` | MultilineTextInput | |
| `checkbox` | CheckBox | |
| `toggler` | Switch | |
| `radio` | RadioButton | |
| `slider`, `vertical_slider` | Slider | |
| `pick_list`, `combo_box` | ComboBox | |
| `progress_bar` | ProgressIndicator | |
| `scrollable` | ScrollView | |
| `container`, `column`, `row`, `stack` | GenericContainer | Also: `keyed_column`, `grid`, `float`, `pin`, `responsive`, `space`, `themer`, `mouse_area`, `sensor`, `overlay` |
| `window` | Window | |
| `image`, `svg`, `qr_code` | Image | |
| `canvas` | Canvas | |
| `table` | Table | |
| `tooltip` | Tooltip | |
| `markdown` | Document | |
| `pane_grid` | Group | |
| `rule` | Splitter | |

### Labels

Labels are the accessible name announced by screen readers. They are
extracted from the prop that makes sense for each widget type:

| Widget type | Label source |
|---|---|
| `button`, `checkbox`, `toggler`, `radio` | `label` prop |
| `text`, `rich_text` | `content` prop |
| `image`, `svg` | `alt` prop |
| `text_input` | `placeholder` prop (as description, not label) |

If a widget has no auto-inferred label and no `a11y` label override, the
screen reader sees the role with no name. This is fine for structural
containers but not for interactive widgets -- always give buttons, inputs,
and toggles either a visible label or an `a11y` label.

### State

Widget state is extracted from existing props automatically:

| State | Source | Widgets |
|---|---|---|
| Disabled | `disabled: true` | Any widget |
| Toggled | `checked` prop | `checkbox` |
| Toggled | `is_toggled` prop | `toggler` |
| Toggled | `selected` prop (boolean) | `radio` |
| Numeric value | `value` prop (number) | `slider`, `progress_bar` |
| Min/max | `range` prop (`[min, max]`) | `slider`, `progress_bar` |
| String value | `value` prop (string) | `text_input` |
| Selected item | `selected` prop (string) | `pick_list` |


## The a11y prop

For cases where auto-inference is insufficient, every widget accepts an
`a11y` prop -- a `Toddy.Type.A11y` struct (or bare map) of fields that
override or augment the inferred semantics.

### Fields

| Field | Type | Description |
|---|---|---|
| `role` | `atom()` | Override the inferred role (see [available roles](#available-roles)) |
| `label` | `String.t()` | Accessible name (what the screen reader announces) |
| `description` | `String.t()` | Longer description (secondary announcement) |
| `live` | `:off \| :polite \| :assertive` | Live region -- AT announces content changes |
| `hidden` | `boolean()` | Exclude from accessibility tree entirely |
| `expanded` | `boolean()` | Expanded/collapsed state (menus, disclosures) |
| `required` | `boolean()` | Mark form field as required |
| `level` | `pos_integer()` | Heading level (1-6, only meaningful with `:heading` role) |
| `busy` | `boolean()` | Loading/processing state (AT announces when done) |
| `invalid` | `boolean()` | Form validation failure |
| `modal` | `boolean()` | Dialog is modal (AT restricts navigation to this container) |
| `read_only` | `boolean()` | Can be read but not edited |
| `mnemonic` | `String.t()` | Alt+letter keyboard shortcut (single character) |
| `toggled` | `boolean()` | Toggled/checked state (for custom toggle widgets) |
| `selected` | `boolean()` | Selected state (for custom selectable widgets) |
| `value` | `String.t()` | Current value as a string (for custom value-displaying widgets) |
| `orientation` | `:horizontal \| :vertical` | Orientation hint for AT navigation |
| `labelled_by` | `String.t()` | ID of the widget that labels this one |
| `described_by` | `String.t()` | ID of the widget that describes this one |
| `error_message` | `String.t()` | ID of the widget showing the error message |
| `disabled` | `boolean()` | Override disabled state for AT (e.g., mark a custom widget as unavailable) |
| `position_in_set` | `non_neg_integer()` | 1-based position in a set ("Item 3 of 7") |
| `size_of_set` | `non_neg_integer()` | Total items in the set |
| `has_popup` | `String.t()` | Popup type: `"listbox"`, `"menu"`, `"dialog"`, `"tree"`, `"grid"` |

The type is defined in `Toddy.Type.A11y`. All fields are optional -- only
include what you need. Both structs and bare maps are accepted; bare maps
are normalized via `A11y.cast/1`.

### Using the a11y prop

With `Toddy.UI` (do-block syntax):

```elixir
import Toddy.UI

# Headings
text("title", "Welcome to MyApp", a11y: %A11y{role: :heading, level: 1})
text("settings_heading", "Settings", a11y: %A11y{role: :heading, level: 2})

# Icon buttons that need a label for screen readers
button("close", "X", a11y: %A11y{label: "Close dialog"})

# Landmark regions
container "search_results", a11y: %A11y{role: :region, label: "Search results"} do
  # ...
end

# Live regions -- AT announces changes automatically
text("save_status", "#{model.saved_count} items saved", a11y: %A11y{live: :polite})

# Decorative elements hidden from AT
rule(a11y: %A11y{hidden: true})
image("divider", "/images/decorative-line.png", a11y: %A11y{hidden: true})

# Disclosure / expandable sections
container "details", a11y: %A11y{expanded: model.expanded, role: :group, label: "Advanced options"} do
  if model.expanded do
    # ...
  end
end

# Required form fields
text_input("email", model.email, a11y: %A11y{required: true, label: "Email address"})
```

Bare maps also work (normalized via `A11y.cast/1`):

```elixir
# These are equivalent:
button("close", "X", a11y: %A11y{label: "Close dialog"})
button("close", "X", a11y: %{label: "Close dialog"})
```

With the typed widget builder API (`Toddy.Widget.*`):

```elixir
alias Toddy.Type.A11y
alias Toddy.Widget.{Button, Text, TextInput}

Button.new("close", "X")
|> Button.a11y(%A11y{label: "Close dialog"})
|> Button.build()

Text.new("Welcome")
|> Text.a11y(%A11y{role: :heading, level: 1})
|> Text.build()

TextInput.new("email", model.email)
|> TextInput.a11y(%A11y{required: true, label: "Email address"})
|> TextInput.build()
```

### Available roles

The `role` field accepts atoms. Use them to override the auto-inferred role
when a widget is semantically different from its type (e.g. a `text` that's
actually a heading, or a `container` that's a navigation landmark).

**Interactive:**
`:button`, `:checkbox` / `:check_box`, `:combo_box` / `:combobox`,
`:link`, `:menu_item`, `:radio` / `:radio_button`, `:slider`,
`:switch`, `:tab`, `:text_input`, `:multiline_text_input` /
`:text_editor`, `:tree_item`

**Structure:**
`:generic_container` / `:generic` / `:container`, `:group`,
`:heading`, `:label`, `:list`, `:list_item`, `:row`,
`:cell`, `:column_header`, `:row_header`, `:table`, `:tree`

**Landmarks:**
`:navigation`, `:region`, `:search`

**Status:**
`:alert`, `:alert_dialog` / `:alertdialog`, `:dialog`, `:status`,
`:timer`, `:meter`, `:progress_indicator` / `:progressbar`

**Other:**
`:document`, `:image`, `:menu`, `:menu_bar`, `:scroll_view`,
`:separator`, `:tab_list`, `:tab_panel`, `:toolbar`, `:tooltip`,
`:window`

Unknown role atoms are accepted but mapped to `Unknown`.


## Patterns and best practices

### Every interactive widget needs a name

Screen readers announce a widget's role and its label. A button with no
label is announced as just "button" -- useless. Make sure every button,
input, checkbox, and toggle has either:

- A visible label prop that auto-inference picks up, or
- An `a11y: %A11y{label: "..."}` override

```elixir
# Good -- label is auto-inferred from the button's label prop
button("save", "Save document")

# Good -- terse label with explicit a11y override for clarity
button("close", "X", a11y: %A11y{label: "Close dialog"})

# Bad -- screen reader just announces "button" with no name
button("do_thing", "")
```

### Use headings to create structure

Screen reader users navigate by headings. Use the `a11y` prop to mark
section titles:

```elixir
def view(model) do
  window "main", title: "MyApp" do
    column do
      text("page_title", "Dashboard", a11y: %A11y{role: :heading, level: 1})

      text("h_recent", "Recent activity", a11y: %A11y{role: :heading, level: 2})
      # ... activity list ...

      text("h_actions", "Quick actions", a11y: %A11y{role: :heading, level: 2})
      # ... action buttons ...
    end
  end
end
```

### Use landmarks for page regions

Landmarks let screen reader users jump between major sections. Wrap
significant regions in containers with landmark roles:

```elixir
column do
  container "nav", a11y: %A11y{role: :navigation, label: "Main navigation"} do
    row do
      button("home", "Home")
      button("settings", "Settings")
      button("help", "Help")
    end
  end

  container "main_content", a11y: %A11y{role: :region, label: "Main content"} do
    # ...
  end

  container "search_area", a11y: %A11y{role: :search, label: "Search"} do
    text_input("query", model.query, placeholder: "Search...")
    button("go", "Search")
  end
end
```

### Live regions for dynamic content

When content changes and you want the screen reader to announce it
without the user navigating to it, use live regions:

- `:polite` -- announced after the current speech finishes (status
  messages, save confirmations, non-urgent updates)
- `:assertive` -- interrupts current speech (errors, urgent alerts)

```elixir
# Status bar that announces changes
text("status", model.status_message, a11y: %A11y{live: :polite})

# Error message that interrupts
if model.error do
  text("error", model.error,
    a11y: %A11y{live: :assertive, role: :alert}
  )
end

# Counter value announced on change
text("counter", "Count: #{model.count}", a11y: %A11y{live: :polite})
```

**Tip:** Only mark the element that changes as live, not its parent
container. Marking a large container as live causes the entire container's
text to be re-announced on every change.

### Forms

Label your inputs, mark required fields, and provide clear error feedback:

```elixir
column spacing: 12 do
  text("form_heading", "Create account", a11y: %A11y{role: :heading, level: 1})

  column spacing: 4 do
    text("Username")
    text_input("username", model.username,
      a11y: %A11y{required: true, label: "Username"}
    )
  end

  column spacing: 4 do
    text("Email")
    text_input("email", model.email,
      a11y: %A11y{required: true, label: "Email address"}
    )
    if model.email_error do
      text("email_error", model.email_error,
        a11y: %A11y{live: :assertive, role: :alert}
      )
    end
  end

  button("submit", "Create account")
end
```

**Why the explicit `a11y: %A11y{label: "Username"}` when there's a visible
`text("Username")` above?** Because toddy doesn't automatically associate
a text label with the input below it. The visible text and the input are
separate widgets in the tree. The `a11y` label connects them for AT users.

#### Cross-widget relationships

Instead of duplicating label text in the `a11y` prop, you can point to
another widget by ID using `labelled_by`, `described_by`, and
`error_message`. The renderer resolves these to accesskit node
references so the screen reader follows the relationship automatically.

```elixir
column spacing: 12 do
  text("form_heading", "Create account", a11y: %A11y{role: :heading, level: 1})

  column spacing: 4 do
    text("email-label", "Email")
    text("email-help", "We'll send a confirmation link")
    text_input("email", model.email,
      a11y: %A11y{
        labelled_by: "email-label",
        described_by: "email-help",
        error_message: "email-error"
      }
    )
    if model.email_error do
      text("email-error", model.email_error,
        a11y: %A11y{role: :alert, live: :assertive}
      )
    end
  end

  button("submit", "Create account")
end
```

When the user focuses the email input, the screen reader announces the
label text from the `email-label` widget and the description from
`email-help`. If the field is invalid, it also announces the error text
from `email-error`.

Use `labelled_by` instead of `label` when a visible text widget already
provides the label -- it avoids duplicating the string and keeps the
label in sync if you change the visible text.

### Hiding decorative content

Decorative elements that add no information should be hidden from AT:

```elixir
# Decorative dividers
rule(a11y: %A11y{hidden: true})

# Decorative images
image("hero", "/images/banner.png", a11y: %A11y{hidden: true})

# Spacing elements
space(a11y: %A11y{hidden: true})
```

Don't hide functional elements. If an image conveys information, give it
an `alt` prop instead:

```elixir
image("status_icon", icon_path, alt: "Status: online")
```

### Canvas widgets

Canvas draws arbitrary shapes -- accesskit can't infer anything from raw
geometry. Always provide alternative text:

```elixir
# Static chart -- describe the content
canvas("chart",
  layers: %{"data" => chart_shapes},
  a11y: %A11y{role: :image, label: "Sales chart: Q1 revenue up 15%, Q2 flat"}
)

# Interactive canvas -- describe the interaction model
canvas("drawing",
  layers: %{"shapes" => shapes},
  a11y: %A11y{role: :image, label: "Drawing canvas, #{length(shapes)} shapes"}
)
```

For complex interactive canvases, consider whether the canvas is the right
choice for AT users, or whether an alternative text-based representation
would work better.

### Interactive canvas shapes

When a canvas contains shapes with the `interactive` field, each
shape becomes a separate accessible node. The canvas widget itself
is the container; individual shapes are focusable children. Tab and
Arrow keys navigate between shapes. Enter/Space activates the focused
shape.

This is how you build accessible custom widgets from canvas
primitives. Without interactive shapes, a canvas is a single opaque
"image" node to screen readers.

```elixir
import Toddy.Canvas.Shape  # needed here: shapes built in a helper outside canvas blocks

canvas("color-picker", width: 200, height: 100,
  layers: %{"options" => Enum.map(Enum.with_index(colors), fn {color, i} ->
    rect(0, i * 32, 200, 32, fill: color.hex)
    |> interactive(
      id: "color-#{i}",
      on_click: true,
      hover_style: %{stroke: "#000", stroke_width: 2},
      a11y: %{
        role: :radio,
        label: color.name,
        selected: color == model.selected,
        position_in_set: i + 1,
        size_of_set: length(colors)
      }
    )
  end)}
)
```

Screen reader: "Red, radio button, 1 of 5, selected."

The `position_in_set` and `size_of_set` fields tell screen readers
where each shape sits in the group. Without them, the reader
announces each shape individually with no positional context.

### Custom widgets with state

When building custom widgets with canvas or other primitives, use `toggled`,
`selected`, `value`, and `orientation` to expose their state to AT users.
Without these, screen readers have no way to know the state of a custom
control drawn with raw shapes.

```elixir
# Custom toggle switch built with canvas
canvas("dark-mode-switch", layers: [...],
  a11y: %A11y{
    role: :switch,
    label: "Dark mode",
    toggled: model.dark_mode
  })

# Custom gauge showing percentage
canvas("cpu-gauge", layers: [...],
  a11y: %A11y{
    role: :meter,
    label: "CPU usage",
    value: "#{model.cpu_percent}%",
    orientation: :horizontal
  })
```

`toggled` and `selected` are booleans. Use `toggled` for on/off controls
(switches, checkboxes) and `selected` for selection state (list items, tabs).
`value` is a string describing the current value in human-readable form.
`orientation` tells AT users whether a control is horizontal or vertical,
which affects how they navigate it.

### Set position and popup hints

Use `position_in_set` / `size_of_set` when building composite widgets
from primitives (custom lists, tab bars, radio groups). Without these,
screen readers cannot announce position context like "Item 3 of 7".

```elixir
# Radio group with position context
container "colors", a11y: %A11y{role: :group, label: "Favorite color"} do
  for {color, idx} <- Enum.with_index(colors, 1) do
    radio("color_#{color}", color, model.selected_color,
      a11y: %A11y{
        position_in_set: idx,
        size_of_set: length(colors)
      }
    )
  end
end

# Custom tab bar
row do
  for {tab, idx} <- Enum.with_index(model.tabs, 1) do
    button("tab_#{tab.id}", tab.label,
      a11y: %A11y{
        role: :tab,
        selected: tab.id == model.active_tab,
        position_in_set: idx,
        size_of_set: length(model.tabs)
      }
    )
  end
end
```

Use `has_popup` to tell screen readers that activating a widget opens
a popup of a specific type:

```elixir
# Dropdown button
button("menu_btn", "Options",
  a11y: %A11y{has_popup: "menu", expanded: model.menu_open}
)

# Combo box with listbox popup
text_input("search", model.query,
  a11y: %A11y{has_popup: "listbox", expanded: model.suggestions_visible}
)
```

Use `disabled` to override the disabled state for AT when a widget
is visually disabled via custom styling but doesn't use the standard
`disabled` prop:

```elixir
button("submit", "Submit",
  a11y: %A11y{disabled: !model.form_valid}
)
```

### Expanded/collapsed state

For disclosure widgets, toggleable panels, and dropdown menus:

```elixir
def view(model) do
  column do
    button("toggle_details",
      if(model.show_details, do: "Hide details", else: "Show details"),
      a11y: %A11y{expanded: model.show_details}
    )

    if model.show_details do
      container "details", a11y: %A11y{role: :region, label: "Details"} do
        # detail content
      end
    end
  end
end
```

The `expanded` field tells AT whether the control is currently
expanded or collapsed, so screen readers can announce "Show details,
button, collapsed" or "Hide details, button, expanded".


## Widget-specific accessibility props

Some widgets accept accessibility props directly as top-level fields,
outside the `a11y` object. The Rust renderer reads these and maps them
to the appropriate accesskit node properties. They are simpler to use
than the full `a11y` struct for common cases.

### alt

An accessible label string. Used on visual content widgets where the
content itself is not textual. The renderer auto-populates the
accesskit label from this prop.

| Widget | Prop | Type |
|---|---|---|
| `image` | `alt` | `String.t()` |
| `svg` | `alt` | `String.t()` |
| `qr_code` | `alt` | `String.t()` |
| `canvas` | `alt` | `String.t()` |

```elixir
image("logo", "/images/logo.png", alt: "Company logo")
svg("icon", "/icons/search.svg", alt: "Search")
qr_code("invite", invite_url, alt: "QR code for invite link")
canvas("chart", layers: %{"data" => shapes}, alt: "Revenue chart")
```

### label

An accessible label string for interactive widgets that don't have a
visible text label prop. The renderer auto-populates the accesskit
label from this prop.

| Widget | Prop | Type |
|---|---|---|
| `slider` | `label` | `String.t()` |
| `vertical_slider` | `label` | `String.t()` |
| `progress_bar` | `label` | `String.t()` |

```elixir
slider("volume", {0, 100}, model.volume, label: "Volume")
vertical_slider("brightness", {0, 100}, model.brightness, label: "Brightness")
progress_bar("upload", {0, 100}, model.progress, label: "Upload progress")
```

### description

An extended accessible description string. Announced as secondary
information after the label. Useful for providing additional context
that doesn't fit in a short label.

| Widget | Prop | Type |
|---|---|---|
| `image` | `description` | `String.t()` |
| `svg` | `description` | `String.t()` |
| `qr_code` | `description` | `String.t()` |
| `canvas` | `description` | `String.t()` |

```elixir
image("photo", path, alt: "Team photo", description: "The engineering team at the 2025 offsite")
canvas("chart", layers: layers, alt: "Sales chart", description: "Q1 up 15%, Q2 flat, Q3 down 8%")
```

### decorative

A boolean that hides visual content from assistive technology entirely.
Use this for images and SVGs that are purely decorative and convey no
information. This is a shorthand -- the equivalent using the `a11y`
prop would be `a11y: %A11y{hidden: true}`.

| Widget | Prop | Type |
|---|---|---|
| `image` | `decorative` | `boolean()` |
| `svg` | `decorative` | `boolean()` |

```elixir
image("divider", "/images/decorative-line.png", decorative: true)
svg("flourish", "/icons/flourish.svg", decorative: true)
```

### Relationship to the a11y prop

These widget-specific props and the `a11y` prop are complementary. The
widget-specific props are read directly by the Rust renderer as
top-level node properties. The `a11y` prop provides the full set of
accesskit overrides via the `A11yOverride` wrapper widget.

If both are set (e.g. `alt: "Photo"` and `a11y: %A11y{label: "Team photo"}`),
the `a11y` override takes precedence for the accesskit label since
`A11yOverride` runs after the widget's own `Accessible` implementation.


## Action handling

When an AT triggers an action, iced translates it to a native event. The
renderer maps it to a standard toddy event:

| AT action | Toddy event | Notes |
|---|---|---|
| Click | `%Widget{type: :click, id: id}` | Screen reader activate, switch press |
| SetValue | `%Widget{type: :input, id: id, value: val}` | AT sets an input value directly |
| Focus | (internal) | Focus tracking, no event emitted |
| Other | `{:a11y_action, id, action_name}` | Scroll, dismiss, etc. |

Your `update/2` already handles `%Widget{type: :click, ...}` and `%Widget{type: :input, ...}` --
AT actions produce identical events. The `{:a11y_action, ...}` event is
a catch-all for actions without a direct widget equivalent:

```elixir
def update(model, {:a11y_action, _id, "scroll_down"}), do: scroll(model, :down)
def update(model, {:a11y_action, _id, "dismiss"}), do: close_dialog(model)
def update(model, {:a11y_action, _id, _action}), do: model
```


## Testing accessibility

The test framework provides assertions for verifying accessibility
semantics without running a screen reader.

### assert_role

Checks the inferred role for an element. This mirrors the role mapping,
so it catches mismatches between your widget type and the intended role:

```elixir
use Toddy.Test.Case, app: MyApp

test "heading has correct role" do
  assert_role("#page_title", "heading")
end

test "nav container is a navigation landmark" do
  assert_role("#nav", "navigation")
end
```

`assert_role` accounts for `a11y` role overrides -- if the element has
`a11y: %A11y{role: :heading}`, that takes precedence over the widget type.

### assert_a11y

Checks specific fields in the `a11y` prop:

```elixir
test "email field is required and labelled" do
  assert_a11y("#email", %{"required" => true, "label" => "Email address"})
end

test "status has live region" do
  assert_a11y("#status", %{"live" => "polite"})
end

test "decorative image is hidden" do
  assert_a11y("#hero_image", %{"hidden" => true})
end
```

Note: `assert_a11y` checks the raw `a11y` prop on the element -- it
doesn't verify auto-inferred values (those come from iced's `Accessible`
trait). If the element has no `a11y` prop set, the assertion fails with a
clear message.

### Element helpers

`Toddy.Test.Element` provides lower-level accessors:

```elixir
test "element accessors" do
  el = find!("#heading")

  # Get the raw a11y prop map
  assert %{"role" => "heading", "level" => 1} = Element.a11y(el)

  # Get the inferred role (checks a11y override, then widget type)
  assert Element.inferred_role(el) == "heading"
end
```

### Testing patterns

**Test the semantics, not the implementation.** Focus on what AT users
experience:

```elixir
test "todo app is accessible" do
  # Headings provide structure
  assert_role("#title", "heading")

  # Interactive widgets are labelled
  assert_a11y("#new_todo", %{"label" => "New todo"})

  # Status updates are announced
  type_text("#new_todo", "Buy milk")
  submit("#new_todo")
  assert_a11y("#todo_count", %{"live" => "polite"})

  # Form validation errors are assertive
  submit("#new_todo")  # empty submit
  assert_a11y("#error", %{"live" => "assertive"})
end
```


## Building

Accessibility is included by default in both precompiled binaries
(`mix toddy.download`) and source builds (`mix toddy.build`).

The renderer uses an iced fork (`v0.14.0-a11y-accesskit` branch) that adds
native accessibility support. The fork is referenced via `[patch.crates-io]`
in the renderer's `Cargo.toml`. No vendored crates or local path overrides
are needed.

Accessibility support is provided by:

| Component | What it provides |
|---|---|
| toddy-iced fork | accesskit + accesskit_winit, TreeBuilder, per-window adapter management |
| `toddy-core` | `A11yOverride` wrapper widget, `HiddenInterceptor`, AT action handling |


## Platform support

| Platform | AT | API | Status |
|---|---|---|---|
| Linux | Orca | AT-SPI2 | Supported |
| macOS | VoiceOver | NSAccessibility | Supported |
| Windows | NVDA, JAWS, Narrator | UI Automation | Supported |

All three platforms are supported via accesskit. The iced fork's a11y
integration creates platform adapters via accesskit_winit.


## Testing with a screen reader

To manually verify accessibility with a real screen reader:

### Linux (Orca)

```bash
# Build the renderer (a11y is included by default)
mix toddy.build

# Start Orca (usually Super+Alt+S, or from accessibility settings)
orca &

# Run your app
mix toddy.gui MyApp
```

Orca should announce widget roles and labels as you navigate with Tab.
Activate buttons with Enter or Space.

### macOS (VoiceOver)

```bash
# Build the renderer (a11y is included by default)
mix toddy.build

# Toggle VoiceOver: Cmd+F5
# Run your app
mix toddy.gui MyApp
```

Use VoiceOver keys (Ctrl+Option + arrow keys) to navigate. VoiceOver
should announce each widget's role and label.

### Windows (NVDA)

```bash
# Build the renderer (a11y is included by default)
mix toddy.build

# Start NVDA
# Run your app
mix toddy.gui MyApp
```

Tab between widgets. NVDA should announce roles, labels, and state
(checked, disabled, expanded, etc.).


## Architecture details

For contributors working on the accessibility internals:

### iced fork (`v0.14.0-a11y-accesskit` branch)

The iced fork adds native accessibility support. Key additions:

- **`Accessible` trait** -- widgets implement this to report their role,
  label, and state to accesskit. Most built-in widgets already implement it.
- **`TreeBuilder`** in `iced_winit` -- walks the widget tree via `operate()`,
  collecting `Accessible` metadata and building an accesskit `TreeUpdate`.
- **Per-window adapters** -- each window gets an accesskit adapter connecting
  to the platform's AT layer.
- **AT action routing** -- AT actions are translated to native iced events,
  which the renderer maps to toddy wire events.

The fork is referenced via `[patch.crates-io]` in the renderer's
`Cargo.toml`.

### A11yOverride wrapper widget

`a11y_widget.rs` in toddy contains two wrapper widgets:

- **`A11yOverride`** -- wraps any iced `Element` and intercepts `operate()`
  to apply Elixir-side overrides from the `a11y` prop (role, label,
  description, live, expanded, required, level, busy, invalid, modal,
  read_only, mnemonic, toggled, selected, value, orientation, labelled_by,
  described_by, error_message).
- **`HiddenInterceptor`** -- wraps an `Element` and suppresses it from the
  accessibility tree when `hidden: true` is set.

These wrappers are applied automatically by the renderer when building the
iced widget tree from toddy's UI tree. No manual wrapping is needed from
Elixir.

### Renderer integration

When the renderer builds the iced widget tree from a toddy snapshot or
patch, it checks each node's `a11y` prop. If present (and not just
`hidden: true`), the rendered widget is wrapped in `A11yOverride`. If
`hidden: true`, it's wrapped in `HiddenInterceptor`. Nodes without an
`a11y` prop are rendered as-is -- iced's native `Accessible` trait provides
their baseline accessibility semantics.
