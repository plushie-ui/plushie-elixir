# Accessibility

Julep provides built-in accessibility support via
[accesskit](https://github.com/AccessKit/accesskit), a cross-platform
accessibility toolkit. The default renderer build includes accessibility,
activating native platform APIs automatically: VoiceOver on macOS,
AT-SPI/Orca on Linux, and UI Automation/NVDA/JAWS on Windows.

Screen reader users, keyboard-only users, and other AT users interact with
the same widgets and receive the same events as mouse users. No special
event handling is needed in your `update/2` -- AT actions produce the same
`{:click, id}`, `{:input, id, value}`, etc. events as direct interaction.


## How it works

Iced 0.14 has no accesskit integration. Julep bridges the gap with three
pieces:

1. **Vendored iced_winit** -- a patched copy (in a separate repository) that
   manages per-window accesskit adapters behind an `a11y` feature flag. Each
   window gets its own `Adapter` that connects to the platform's AT layer.

2. **Tree-to-accesskit conversion** (`julep-core/accessibility.rs`) -- after
   every tree update (snapshot or patch), the renderer walks the UI tree
   and builds an accesskit `TreeUpdate`. Widget types are mapped to roles,
   props are mapped to labels/state/values, and `a11y` overrides are applied.

3. **Action routing** -- when an AT triggers an action (e.g. a screen reader
   user activates a button), the renderer translates it to a standard julep
   event and sends it to Elixir over the wire protocol.

```
Elixir app                Renderer                      Platform AT
   |                         |                              |
   |--- UI tree (a11y) ----->|                              |
   |                         |-- TreeUpdate --------------->|
   |                         |                              |
   |                         |<-- ActionRequest (Click) ----|
   |<-- {:click, id} --------|                              |
```

The `a11y` feature is included in the default build. It can be disabled for
a smaller binary, but all functionality works identically either way. The
accessibility code is gated behind `#[cfg(feature = "a11y")]` in the Rust
source.


## Auto-inference

Most widgets get correct accessibility semantics without any annotation.
The renderer automatically infers roles, labels, and state from widget types
and existing props.

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

Labels are the accessible name announced by screen readers. They're
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
`a11y` prop -- a map of fields that override or augment the inferred
semantics.

### Fields

| Field | Type | Description |
|---|---|---|
| `role` | `String.t()` | Override the inferred role (see [available roles](#available-roles)) |
| `label` | `String.t()` | Accessible name (what the screen reader announces) |
| `description` | `String.t()` | Longer description (secondary announcement) |
| `live` | `:off \| :polite \| :assertive` | Live region -- AT announces content changes |
| `hidden` | `boolean()` | Exclude from accessibility tree entirely |
| `expanded` | `boolean()` | Expanded/collapsed state (menus, disclosures) |
| `required` | `boolean()` | Mark form field as required |
| `level` | `pos_integer()` | Heading level (1-6, only meaningful with `"heading"` role) |

The type is defined in `Julep.Iced.A11y`. All fields are optional -- only
include what you need.

### Using the a11y prop

With `Julep.UI` (do-block syntax):

```elixir
import Julep.UI

# Headings
text("Welcome to MyApp", id: "title", a11y: %{role: "heading", level: 1})
text("Settings", id: "settings_heading", a11y: %{role: "heading", level: 2})

# Icon buttons that need a label for screen readers
button("close", "X", a11y: %{label: "Close dialog"})

# Landmark regions
container "search_results", a11y: %{role: "region", label: "Search results"} do
  # ...
end

# Live regions -- AT announces changes automatically
text("#{model.saved_count} items saved", a11y: %{live: :polite})

# Decorative elements hidden from AT
rule(a11y: %{hidden: true})
image("divider", "/images/decorative-line.png", a11y: %{hidden: true})

# Disclosure / expandable sections
container "details", a11y: %{expanded: model.expanded, role: "group", label: "Advanced options"} do
  if model.expanded do
    # ...
  end
end

# Required form fields
text_input("email", model.email, a11y: %{required: true, label: "Email address"})
```

With the typed widget builder API (`Julep.Iced.Widget.*`):

```elixir
alias Julep.Iced.Widget.{Button, Text, TextInput}

Button.new("close", "X")
|> Button.a11y(%{label: "Close dialog"})
|> Button.build()

Text.new("Welcome")
|> Text.a11y(%{role: "heading", level: 1})
|> Text.build()

TextInput.new("email", model.email)
|> TextInput.a11y(%{required: true, label: "Email address"})
|> TextInput.build()
```

### Available roles

The `role` field accepts any of these strings. Use them to override the
auto-inferred role when a widget is semantically different from its type
(e.g. a `text` that's actually a heading, or a `container` that's a
navigation landmark).

**Interactive:**
`"button"`, `"checkbox"` / `"check_box"`, `"combo_box"` / `"combobox"`,
`"link"`, `"menu_item"`, `"radio"` / `"radio_button"`, `"slider"`,
`"switch"`, `"tab"`, `"text_input"`, `"multiline_text_input"` /
`"text_editor"`, `"tree_item"`

**Structure:**
`"generic_container"` / `"generic"` / `"container"`, `"group"`,
`"heading"`, `"label"`, `"list"`, `"list_item"`, `"row"`,
`"cell"`, `"column_header"`, `"row_header"`, `"table"`, `"tree"`

**Landmarks:**
`"navigation"`, `"region"`, `"search"`

**Status:**
`"alert"`, `"alert_dialog"` / `"alertdialog"`, `"dialog"`, `"status"`,
`"timer"`, `"meter"`, `"progress_indicator"` / `"progressbar"`

**Other:**
`"document"`, `"image"`, `"menu"`, `"menu_bar"`, `"scroll_view"`,
`"separator"`, `"tab_list"`, `"tab_panel"`, `"toolbar"`, `"tooltip"`,
`"window"`

Unknown role strings are accepted but mapped to `Unknown`.


## Patterns and best practices

### Every interactive widget needs a name

Screen readers announce a widget's role and its label. A button with no
label is announced as just "button" -- useless. Make sure every button,
input, checkbox, and toggle has either:

- A visible label prop that auto-inference picks up, or
- An `a11y: %{label: "..."}` override

```elixir
# Good -- label is auto-inferred from the button's label prop
button("save", "Save document")

# Good -- terse label with explicit a11y override for clarity
button("close", "X", a11y: %{label: "Close dialog"})

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
      text("Dashboard", id: "page_title", a11y: %{role: "heading", level: 1})

      text("Recent activity", id: "h_recent", a11y: %{role: "heading", level: 2})
      # ... activity list ...

      text("Quick actions", id: "h_actions", a11y: %{role: "heading", level: 2})
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
  container "nav", a11y: %{role: "navigation", label: "Main navigation"} do
    row do
      button("home", "Home")
      button("settings", "Settings")
      button("help", "Help")
    end
  end

  container "main_content", a11y: %{role: "region", label: "Main content"} do
    # ...
  end

  container "search_area", a11y: %{role: "search", label: "Search"} do
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
text(model.status_message, id: "status", a11y: %{live: :polite})

# Error message that interrupts
if model.error do
  text(model.error, id: "error",
    a11y: %{live: :assertive, role: "alert"}
  )
end

# Counter value announced on change
text("Count: #{model.count}", id: "counter", a11y: %{live: :polite})
```

**Tip:** Only mark the element that changes as live, not its parent
container. Marking a large container as live causes the entire container's
text to be re-announced on every change.

### Forms

Label your inputs, mark required fields, and provide clear error feedback:

```elixir
column spacing: 12 do
  text("Create account", id: "form_heading", a11y: %{role: "heading", level: 1})

  column spacing: 4 do
    text("Username")
    text_input("username", model.username,
      a11y: %{required: true, label: "Username"}
    )
  end

  column spacing: 4 do
    text("Email")
    text_input("email", model.email,
      a11y: %{required: true, label: "Email address"}
    )
    if model.email_error do
      text(model.email_error, id: "email_error",
        a11y: %{live: :assertive, role: "alert"}
      )
    end
  end

  button("submit", "Create account")
end
```

**Why the explicit `a11y: %{label: "Username"}` when there's a visible
`text("Username")` above?** Because julep doesn't automatically associate
a text label with the input below it. The visible text and the input are
separate widgets in the tree. The `a11y` label connects them for AT users.

### Hiding decorative content

Decorative elements that add no information should be hidden from AT:

```elixir
# Decorative dividers
rule(a11y: %{hidden: true})

# Decorative images
image("hero", "/images/banner.png", a11y: %{hidden: true})

# Spacing elements
space(a11y: %{hidden: true})
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
  a11y: %{role: "image", label: "Sales chart: Q1 revenue up 15%, Q2 flat"}
)

# Interactive canvas -- describe the interaction model
canvas("drawing",
  layers: %{"shapes" => shapes},
  a11y: %{role: "image", label: "Drawing canvas, #{length(shapes)} shapes"}
)
```

For complex interactive canvases, consider whether the canvas is the right
choice for AT users, or whether an alternative text-based representation
would work better.

### Expanded/collapsed state

For disclosure widgets, toggleable panels, and dropdown menus:

```elixir
def view(model) do
  column do
    button("toggle_details",
      if(model.show_details, do: "Hide details", else: "Show details"),
      a11y: %{expanded: model.show_details}
    )

    if model.show_details do
      container "details", a11y: %{role: "region", label: "Details"} do
        # detail content
      end
    end
  end
end
```

The `expanded` field tells AT whether the control is currently
expanded or collapsed, so screen readers can announce "Show details,
button, collapsed" or "Hide details, button, expanded".


## Action handling

When an AT triggers an action, the renderer translates it to a standard
julep event:

| AT action | Julep event | Notes |
|---|---|---|
| Click | `{:click, id}` | Screen reader activate, switch press |
| SetValue | `{:input, id, value}` | AT sets an input value directly |
| Focus | (internal) | Focus tracking, no event emitted |
| Other | `{:a11y_action, id, action_name}` | Scroll, dismiss, etc. |

Your `update/2` already handles `{:click, ...}` and `{:input, ...}` --
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

Checks the inferred role for an element. This mirrors the Rust-side role
mapping, so it catches mismatches between your widget type and the
intended role:

```elixir
use Julep.Test.Case, app: MyApp

test "heading has correct role" do
  assert_role("#page_title", "heading")
end

test "nav container is a navigation landmark" do
  assert_role("#nav", "navigation")
end
```

`assert_role` accounts for `a11y` role overrides -- if the element has
`a11y: %{role: "heading"}`, that takes precedence over the widget type.

### assert_a11y

Checks specific fields in the `a11y` prop map:

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
doesn't verify auto-inferred values (those are tested on the Rust side).
If the element has no `a11y` prop set, the assertion fails with a clear
message.

### Element helpers

`Julep.Test.Element` provides lower-level accessors:

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

Accessibility is enabled by default. A standard `cargo build` includes it:

```bash
cd ../julep-renderer
cargo build --release
```

To build _without_ accessibility (smaller binary, no accesskit dependency):

```bash
cargo build --release --no-default-features --features builtin-all,dialogs,clipboard,notifications
```

The `a11y` feature flag controls:

| Crate | What it enables |
|---|---|
| `iced_winit` (vendored) | accesskit + accesskit_winit deps, per-window adapter management |
| `julep-core` | `accessibility` module (tree-to-accesskit conversion) |
| `julep-renderer` | Tree update pushes, AT action handling |

Without the feature, the `a11y` prop is still accepted in UI trees (it's
just a map in props) but has no effect.


## Platform support

| Platform | AT | API | Status |
|---|---|---|---|
| Linux | Orca | AT-SPI2 | Supported |
| macOS | VoiceOver | NSAccessibility | Supported |
| Windows | NVDA, JAWS, Narrator | UI Automation | Supported |

All three platforms are supported via accesskit 0.18. The vendored
iced_winit creates platform adapters using accesskit_winit 0.24, which
requires winit 0.30+ (iced 0.14 uses winit 0.30.12).


## Testing with a screen reader

To manually verify accessibility with a real screen reader:

### Linux (Orca)

```bash
# Build the renderer (a11y is included by default)
cd ../julep-renderer && cargo build

# Start Orca (usually Super+Alt+S, or from accessibility settings)
orca &

# Run your app
mix julep.gui MyApp
```

Orca should announce widget roles and labels as you navigate with Tab.
Activate buttons with Enter or Space.

### macOS (VoiceOver)

```bash
# Build the renderer (a11y is included by default)
cd ../julep-renderer && cargo build

# Toggle VoiceOver: Cmd+F5
# Run your app
mix julep.gui MyApp
```

Use VoiceOver keys (Ctrl+Option + arrow keys) to navigate. VoiceOver
should announce each widget's role and label.

### Windows (NVDA)

```bash
# Build the renderer (a11y is included by default)
cd ../julep-renderer && cargo build

# Start NVDA
# Run your app
mix julep.gui MyApp
```

Tab between widgets. NVDA should announce roles, labels, and state
(checked, disabled, expanded, etc.).


## Architecture details

For contributors working on the accessibility internals:

### Vendored iced_winit

Lives in a separate repository (not in the julep tree). Referenced via
`[patch.crates-io]` in `.cargo/config.toml` (gitignored -- each developer
sets up the local path). See
[ADR-0013](decisions/0013-accessibility-via-vendored-iced-winit.md) for
the rationale.

The patch adds an `a11y` module to iced_winit with:

- **Global adapter registry** -- `FxHashMap<WindowId, (Arc<Window>, Adapter)>`
  behind a `Mutex`, managing one accesskit adapter per window.
- **`register_window`** -- called when iced creates a window. Creates the
  adapter with activation/action/deactivation handlers.
- **`unregister_window`** -- called when a window closes. Drops the adapter.
- **`process_event`** -- called for every `WindowEvent`. Forwards to the
  adapter so accesskit can track focus and window state.
- **`update_tree`** -- public API for pushing `TreeUpdate` to a window's
  adapter. Called by julep-renderer after tree changes.
- **`drain_action_requests`** -- returns queued AT action requests for
  processing by the renderer.

### Tree conversion

`julep-core/accessibility.rs` contains the pure conversion logic:

- `build_tree_update(root, focused_id)` -- walks the tree recursively,
  building accesskit `Node` objects with roles, labels, and state.
- `role_for_type(type_name)` -- maps widget type strings to accesskit
  `Role` enum values.
- `node_id_from_str(id)` -- hashes julep string IDs to accesskit
  `NodeId` (stable within a process, not across restarts).
- `role_from_string(s)` -- parses role name strings from the `a11y` prop
  into accesskit `Role` values. Accepts ARIA-style names and snake_case.

Hidden nodes (with `a11y: %{hidden: true}`) are excluded from the tree
entirely -- they don't appear in the `TreeUpdate` and their children
are removed from the parent's child list.

### Renderer integration

In `julep-renderer/renderer.rs`:

- `push_accessibility_updates()` -- called after every tree change (both
  snapshots and patches). Clones the root, builds a `TreeUpdate`, pushes
  it via `iced_winit::a11y::update_tree()`. Also maintains a reverse map
  (`NodeId -> String`) for routing AT actions back to julep widget IDs.
- `handle_a11y_action_requests()` -- called in the message loop. Drains
  queued action requests and translates them to julep events.
- `focused_id` -- tracks the currently focused node (set by AT Focus
  actions). Cleared when the focused node is removed from the tree.
