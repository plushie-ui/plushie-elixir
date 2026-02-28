# Composition patterns

Julep provides primitives, not pre-built composites. There is no `TabBar`
widget, no `Modal` widget, no `Card` widget. Instead, you compose the same
building blocks -- `row`, `column`, `container`, `stack`, `button`, `text`,
`rule`, `mouse_area`, `space` -- with `StyleMap` to build any UI pattern you
need.

This guide shows how. Every pattern is copy-pasteable and produces a polished
result. All examples use `Julep.UI` macros and assume you have the following
at the top of your view function:

```elixir
import Julep.UI
alias Julep.Iced.StyleMap
alias Julep.Iced.Border
alias Julep.Iced.Shadow
```

---

## 1. Tab bar

A horizontal row of buttons where the active tab is visually distinct from
the inactive ones. Common at the top of a content area to switch between
views.

### Code

```elixir
defmodule TabApp do
  @behaviour Julep.App

  alias Julep.Iced.StyleMap
  alias Julep.Iced.Border

  def init(_opts), do: %{active_tab: :overview}

  def update(model, {:click, "tab:" <> name}) do
    %{model | active_tab: String.to_existing_atom(name)}
  end

  def update(model, _event), do: model

  def view(model) do
    import Julep.UI

    tabs = [:overview, :details, :settings]

    window "main", title: "Tab Demo" do
      column width: :fill do
        row spacing: 0 do
          for tab <- tabs do
            button(
              "tab:#{tab}",
              tab |> Atom.to_string() |> String.capitalize(),
              style: tab_style(model.active_tab == tab),
              padding: %{top: 10, bottom: 10, left: 20, right: 20}
            )
          end
        end

        # Bottom border under the tab bar
        rule()

        # Content area
        container "content", padding: 20, width: :fill, height: :fill do
          text("Content for #{model.active_tab}")
        end
      end
    end
  end

  defp tab_style(true = _active?) do
    StyleMap.new()
    |> StyleMap.background("#ffffff")
    |> StyleMap.text_color("#1a1a1a")
    |> StyleMap.border(
      Border.new()
      |> Border.color("#0066ff")
      |> Border.width(2)
      |> Border.rounded(0)
    )
  end

  defp tab_style(false = _active?) do
    StyleMap.new()
    |> StyleMap.background("#f0f0f0")
    |> StyleMap.text_color("#666666")
    |> StyleMap.hovered(%{background: "#e0e0e0"})
  end
end
```

### How it works

Each tab is a `button` with a `StyleMap` driven by whether it matches the
active tab. The active style uses a solid background and a blue border to
create the "selected" indicator. Inactive tabs get a flat grey look with a
hover state for feedback. The `for` comprehension inside the `row` do-block
generates one button per tab.

The `rule()` below the row acts as a full-width horizontal divider, visually
anchoring the tab bar to the content below.

### What it looks like

A horizontal row of flat buttons flush against each other. The active tab
has a white background with a blue bottom border. Inactive tabs are light
grey and lighten on hover. Below the tabs, a thin horizontal line separates
the bar from the content area.

---

## 2. Sidebar navigation

A dark column on the left side of the window containing navigation items
that highlight on hover. The selected item has an accent background.

### Code

```elixir
defmodule SidebarApp do
  @behaviour Julep.App

  alias Julep.Iced.StyleMap

  @nav_items [
    {:inbox, "Inbox"},
    {:sent, "Sent"},
    {:drafts, "Drafts"},
    {:trash, "Trash"}
  ]

  def init(_opts), do: %{page: :inbox}

  def update(model, {:click, "nav:" <> name}) do
    %{model | page: String.to_existing_atom(name)}
  end

  def update(model, _event), do: model

  def view(model) do
    import Julep.UI

    window "main", title: "Sidebar Demo" do
      row width: :fill, height: :fill do
        # Sidebar
        container "sidebar", width: 200, height: :fill, background: "#1e1e2e", padding: 8 do
          column spacing: 4, width: :fill do
            text("Navigation", size: 12, color: "#888888")
            space(height: 8)

            for {id, label} <- @nav_items do
              button(
                "nav:#{id}",
                label,
                style: nav_item_style(model.page == id),
                width: :fill,
                padding: %{top: 8, bottom: 8, left: 12, right: 12}
              )
            end
          end
        end

        # Main content
        container "main", width: :fill, height: :fill, padding: 24 do
          text("#{model.page |> Atom.to_string() |> String.capitalize()} page", size: 20)
        end
      end
    end
  end

  defp nav_item_style(true = _selected?) do
    StyleMap.new()
    |> StyleMap.background("#3366ff")
    |> StyleMap.text_color("#ffffff")
    |> StyleMap.hovered(%{background: "#4477ff"})
  end

  defp nav_item_style(false = _selected?) do
    StyleMap.new()
    |> StyleMap.background("#1e1e2e")
    |> StyleMap.text_color("#cccccc")
    |> StyleMap.hovered(%{background: "#2a2a3e", text_color: "#ffffff"})
  end
end
```

### How it works

The outer `row` splits the window into two areas: a fixed-width sidebar and
a fill-width content area. The sidebar is a `container` with a dark
background colour. Inside it, nav items are `button` widgets spanning the
full sidebar width.

The selected item uses `StyleMap` with a blue background and white text.
Unselected items match the sidebar background so they appear invisible until
hovered, when they brighten slightly. This gives the classic "highlight on
hover, solid on select" sidebar feel.

### What it looks like

A dark panel (200px wide) on the left. Four text labels stacked vertically
inside it. The active item has a blue background. Hovering over other items
reveals a subtle lighter background. The rest of the window is the content
area.

---

## 3. Toolbar

A compact horizontal bar with grouped icon-style buttons separated by
vertical rules. Toolbars typically sit at the top of an editor or document
view.

### Code

```elixir
defmodule ToolbarApp do
  @behaviour Julep.App

  alias Julep.Iced.StyleMap
  alias Julep.Iced.Border

  def init(_opts), do: %{bold: false, italic: false, underline: false}

  def update(model, {:click, "tool:bold"}), do: %{model | bold: !model.bold}
  def update(model, {:click, "tool:italic"}), do: %{model | italic: !model.italic}
  def update(model, {:click, "tool:underline"}), do: %{model | underline: !model.underline}
  def update(model, _event), do: model

  def view(model) do
    import Julep.UI

    window "main", title: "Toolbar Demo" do
      column width: :fill do
        # Toolbar
        container "toolbar", width: :fill, background: "#f5f5f5", padding: 4 do
          row spacing: 2, align_y: :center do
            # File group
            button("tool:new", "New", style: tool_style(false), padding: 6)
            button("tool:open", "Open", style: tool_style(false), padding: 6)
            button("tool:save", "Save", style: tool_style(false), padding: 6)

            # Separator
            rule(direction: :vertical, height: 20)

            # Format group
            button("tool:bold", "B", style: tool_style(model.bold), padding: 6)
            button("tool:italic", "I", style: tool_style(model.italic), padding: 6)
            button("tool:underline", "U", style: tool_style(model.underline), padding: 6)

            # Separator
            rule(direction: :vertical, height: 20)

            # Spacer pushes trailing items to the right
            space(width: :fill)

            button("tool:help", "?", style: tool_style(false), padding: 6)
          end
        end

        rule()

        # Editor area
        container "editor", width: :fill, height: :fill, padding: 16 do
          text("Editor content goes here")
        end
      end
    end
  end

  defp tool_style(true = _toggled?) do
    StyleMap.new()
    |> StyleMap.background("#d0d0d0")
    |> StyleMap.text_color("#1a1a1a")
    |> StyleMap.border(Border.new() |> Border.color("#b0b0b0") |> Border.width(1) |> Border.rounded(3))
    |> StyleMap.hovered(%{background: "#c0c0c0"})
  end

  defp tool_style(false = _toggled?) do
    StyleMap.new()
    |> StyleMap.background("#f5f5f5")
    |> StyleMap.text_color("#333333")
    |> StyleMap.hovered(%{background: "#e0e0e0"})
    |> StyleMap.pressed(%{background: "#d0d0d0"})
  end
end
```

### How it works

The toolbar is a `container` with a light background wrapping a `row`. Button
groups are visually separated by vertical `rule` widgets. A `space(width:
:fill)` between the main group and the help button pushes the help button to
the far right -- a common toolbar layout technique.

Toggle-style buttons (bold, italic, underline) pass their current state to
`tool_style/1`. When toggled on, they get a depressed look via a darker
background and a subtle border. The `pressed` status override on untoggled
buttons gives tactile click feedback.

### What it looks like

A light grey horizontal bar at the top. Three button groups separated by
thin vertical lines. "New | Open | Save", then "B | I | U", then a "?"
button pushed to the far right. Toggled buttons appear slightly sunken.

---

## 4. Modal dialog

A full-screen overlay with a centered dialog box on top. Uses `stack` to
layer the overlay behind the dialog. The overlay is a semi-transparent
container that dims the background.

### Code

```elixir
defmodule ModalApp do
  @behaviour Julep.App

  alias Julep.Iced.StyleMap
  alias Julep.Iced.Border
  alias Julep.Iced.Shadow

  def init(_opts), do: %{show_modal: false, confirmed: false}

  def update(model, {:click, "open_modal"}), do: %{model | show_modal: true}
  def update(model, {:click, "confirm"}), do: %{model | show_modal: false, confirmed: true}
  def update(model, {:click, "cancel"}), do: %{model | show_modal: false}
  def update(model, _event), do: model

  def view(model) do
    import Julep.UI

    window "main", title: "Modal Demo" do
      stack width: :fill, height: :fill do
        # Layer 0: main content (always visible)
        container "main", width: :fill, height: :fill, padding: 24, center: true do
          column spacing: 12, align_x: :center do
            text("Main application content", size: 20)

            if model.confirmed do
              text("Action confirmed.", color: "#22aa44")
            end

            button("open_modal", "Open Dialog", style: :primary)
          end
        end

        # Layer 1: modal overlay + dialog (conditionally rendered)
        if model.show_modal do
          # Semi-transparent backdrop
          container "overlay", width: :fill, height: :fill, background: "#00000088", center: true do
            # Dialog card
            container "dialog",
              max_width: 400,
              padding: 24,
              background: "#ffffff",
              border: Border.new() |> Border.color("#dddddd") |> Border.width(1) |> Border.rounded(8),
              shadow: Shadow.new() |> Shadow.color("#00000040") |> Shadow.offset(0, 4) |> Shadow.blur_radius(16) do
              column spacing: 16 do
                text("Confirm action", size: 18, color: "#1a1a1a")
                text("Are you sure you want to proceed? This cannot be undone.",
                  color: "#555555",
                  wrapping: :word
                )

                row spacing: 8, align_x: :end do
                  button("cancel", "Cancel", style: :secondary)
                  button("confirm", "Confirm", style: :primary)
                end
              end
            end
          end
        end
      end
    end
  end
end
```

### How it works

`stack` layers its children front-to-back. The main content is layer 0.
When `show_modal` is true, the overlay container appears as layer 1 on top.

The overlay is a full-size container with `background: "#00000088"` -- the
last two hex digits (`88`) set ~53% opacity, dimming everything behind it.
Setting `center: true` on the overlay centres its single child: the dialog
card.

The dialog card is a container with a white background, rounded border, and
a drop shadow. The shadow offset `(0, 4)` with a 16px blur gives a natural
"floating above" appearance.

When `show_modal` is false, the `if` returns nil, which `stack` filters out.
The overlay and dialog simply do not exist in the tree.

### What it looks like

A centred page with a button. Clicking the button dims the entire window
behind a dark translucent overlay. A white rounded card appears in the
centre with a title, message text, and Cancel/Confirm buttons. The card has
a soft drop shadow.

---

## 5. Card

A container with rounded corners, a border, an optional shadow, and an
optional header section. The simplest composition pattern -- it is just a
styled container.

### Code

```elixir
defmodule CardApp do
  @behaviour Julep.App

  alias Julep.Iced.Border
  alias Julep.Iced.Shadow

  def init(_opts), do: %{}
  def update(model, _event), do: model

  def view(model) do
    import Julep.UI

    window "main", title: "Card Demo" do
      column padding: 24, spacing: 16, width: :fill do
        # Simple card
        card("info", "System status", fn ->
          [
            text("All services operational", color: "#22aa44"),
            text("Last checked: 2 minutes ago", size: 12, color: "#888888")
          ]
        end)

        # Card with action
        container "promo",
          width: :fill,
          padding: 0,
          border: Border.new() |> Border.color("#e0e0e0") |> Border.width(1) |> Border.rounded(8),
          shadow: Shadow.new() |> Shadow.color("#00000020") |> Shadow.offset(0, 2) |> Shadow.blur_radius(8),
          background: "#ffffff",
          clip: true do
          column width: :fill do
            # Header band
            container "promo_header", width: :fill, padding: 12, background: "#3366ff" do
              text("Upgrade available", size: 14, color: "#ffffff")
            end

            # Body
            container "promo_body", width: :fill, padding: 16 do
              column spacing: 12 do
                text("Version 2.0 brings new features and performance improvements.")
                button("upgrade", "Upgrade now", style: :primary)
              end
            end
          end
        end
      end
    end
  end

  # Reusable card helper. Returns a container node.
  defp card(id, title, body_fn) do
    import Julep.UI

    border = Border.new() |> Border.color("#e0e0e0") |> Border.width(1) |> Border.rounded(8)
    shadow = Shadow.new() |> Shadow.color("#00000020") |> Shadow.offset(0, 2) |> Shadow.blur_radius(8)

    container id,
      width: :fill,
      padding: 16,
      background: "#ffffff",
      border: border,
      shadow: shadow do
      column spacing: 8 do
        text(title, size: 16, color: "#1a1a1a")
        rule()

        for node <- body_fn.() do
          node
        end
      end
    end
  end
end
```

### How it works

A card is a `container` with four visual properties: `background` for the
fill colour, `border` with a rounded radius for the outline, `shadow` for
depth, and `padding` for internal spacing. That is the entire pattern.

The `card/3` helper extracts this into a reusable function. It takes an id,
a title string, and a zero-arity function that returns a list of child
nodes. The function form avoids issues with macro expansion -- you build the
child nodes inside the lambda, and the `for` comprehension splices them into
the card body.

The "promo" card demonstrates a header band: a nested container with a
coloured background and `clip: true` on the outer card so the header's
background respects the rounded corners.

### What it looks like

Rounded white rectangles with subtle borders and soft shadows. The first
card has a title, a divider line, and body text. The second has a blue
header band spanning the full width, body text below, and a primary-styled
button.

---

## 6. Split panel

Two content areas side by side with a draggable divider between them. The
divider is a vertical `rule` wrapped in a `mouse_area` that changes the
cursor to a horizontal resize indicator.

### Code

```elixir
defmodule SplitApp do
  @behaviour Julep.App

  alias Julep.Iced.Border

  def init(_opts), do: %{left_width: 300}

  # In a real app, you would track mouse drag events to resize.
  # This example shows the static layout and cursor feedback.
  def update(model, {:click, "divider"}), do: model
  def update(model, _event), do: model

  def view(model) do
    import Julep.UI

    window "main", title: "Split Panel Demo" do
      row width: :fill, height: :fill do
        # Left panel
        container "left_panel",
          width: model.left_width,
          height: :fill,
          padding: 16,
          background: "#fafafa" do
          column spacing: 8 do
            text("Left panel", size: 16)
            text("File browser, outline, or any sidebar content.", color: "#666666")
          end
        end

        # Draggable divider
        mouse_area "divider", cursor: :resizing_horizontally do
          container "divider_track",
            width: 5,
            height: :fill,
            background: "#e0e0e0" do
            rule(direction: :vertical)
          end
        end

        # Right panel
        container "right_panel",
          width: :fill,
          height: :fill,
          padding: 16 do
          column spacing: 8 do
            text("Right panel", size: 16)
            text("Main editor or content area.", color: "#666666")
          end
        end
      end
    end
  end
end
```

### How it works

The outer `row` holds three children: left panel, divider, right panel. The
left panel has a fixed pixel width. The right panel uses `width: :fill` to
take the remaining space.

The divider is a `mouse_area` wrapping a thin container. The `cursor:
:resizing_horizontally` prop changes the mouse cursor to the standard
horizontal resize indicator when the user hovers over the divider, giving
clear affordance that it is draggable.

In a production app you would handle `{:click, "divider"}` (press) and
`{:click, "divider:release"}` (release) events along with mouse move
tracking to update `left_width` dynamically. The static layout pattern is
the same regardless.

### What it looks like

Two panels side by side filling the window. A thin grey vertical bar between
them. Hovering over the bar changes the cursor to a horizontal resize arrow.

---

## 7. Breadcrumb

A horizontal trail of clickable path segments separated by ">" characters.
The last segment is plain text (not clickable) representing the current
location.

### Code

```elixir
defmodule BreadcrumbApp do
  @behaviour Julep.App

  alias Julep.Iced.StyleMap

  def init(_opts), do: %{path: ["Home", "Projects", "Julep", "Docs"]}

  def update(model, {:click, "crumb:" <> index_str}) do
    index = String.to_integer(index_str)
    %{model | path: Enum.take(model.path, index + 1)}
  end

  def update(model, _event), do: model

  def view(model) do
    import Julep.UI

    window "main", title: "Breadcrumb Demo" do
      column padding: 16, spacing: 16, width: :fill do
        row spacing: 4, align_y: :center do
          for {segment, index} <- Enum.with_index(model.path) do
            last? = index == length(model.path) - 1

            if last? do
              # Current location: plain text, not clickable
              text(segment, size: 14, color: "#1a1a1a")
            else
              [
                button("crumb:#{index}", segment,
                  style: crumb_style(),
                  padding: %{top: 2, bottom: 2, left: 4, right: 4}
                ),
                text(">", size: 14, color: "#999999")
              ]
            end
          end
        end

        rule()

        text("Viewing: #{List.last(model.path)}", size: 18)
      end
    end
  end

  defp crumb_style do
    StyleMap.new()
    |> StyleMap.background("#00000000")
    |> StyleMap.text_color("#3366ff")
    |> StyleMap.hovered(%{text_color: "#1144cc", background: "#f0f0ff"})
    |> StyleMap.pressed(%{text_color: "#0033aa"})
  end
end
```

### How it works

The breadcrumb is a `row` containing an interleaved sequence of buttons and
separator text nodes. The `for` comprehension iterates over the path
segments with their index. For every segment except the last, it emits a
two-element list: a clickable button and a ">" separator. Lists inside `do`
blocks are flattened, so this works seamlessly.

The last segment is rendered as plain `text` -- no click handler, no hover
state. This signals "you are here" without needing a disabled button.

The crumb buttons use a fully transparent background (`#00000000`) so they
look like plain text links. The hover state adds a subtle blue tint and
changes the text colour, mimicking a hyperlink.

Clicking a breadcrumb truncates the path to that index, navigating "up".

### What it looks like

A horizontal line of text: "Home > Projects > Julep > Docs". Everything
except "Docs" is blue and clickable. Hovering over a segment highlights it
with a light blue background. "Docs" is plain dark text.

---

## 8. Badge / chip

A small container with a coloured background and fully rounded corners. Used
for tags, counts, status indicators, or filter chips.

### Code

```elixir
defmodule BadgeApp do
  @behaviour Julep.App

  alias Julep.Iced.StyleMap
  alias Julep.Iced.Border

  @tags ["elixir", "rust", "iced", "desktop"]

  def init(_opts), do: %{selected: MapSet.new(["elixir"])}

  def update(model, {:click, "tag:" <> name}) do
    selected =
      if MapSet.member?(model.selected, name) do
        MapSet.delete(model.selected, name)
      else
        MapSet.put(model.selected, name)
      end

    %{model | selected: selected}
  end

  def update(model, _event), do: model

  def view(model) do
    import Julep.UI

    window "main", title: "Badge Demo" do
      column padding: 24, spacing: 16, width: :fill do
        # Status badges (display only)
        row spacing: 8, align_y: :center do
          text("Status:", size: 14)
          badge("online", "Online", "#22aa44", "#ffffff")
          badge("count", "3 new", "#3366ff", "#ffffff")
          badge("warn", "Deprecated", "#ff8800", "#ffffff")
        end

        rule()

        # Filter chips (clickable)
        text("Filter by tag:", size: 14)
        row spacing: 6 do
          for tag <- @tags do
            selected? = MapSet.member?(model.selected, tag)

            button("tag:#{tag}", tag,
              style: chip_style(selected?),
              padding: %{top: 4, bottom: 4, left: 10, right: 10}
            )
          end
        end

        text("Selected: #{model.selected |> Enum.sort() |> Enum.join(", ")}", color: "#666666")
      end
    end
  end

  # Display-only badge: a small container with pill shape.
  defp badge(id, label, bg_color, text_color) do
    import Julep.UI

    container id,
      padding: %{top: 2, bottom: 2, left: 8, right: 8},
      background: bg_color,
      border: Border.new() |> Border.rounded(999) do
      text(label, size: 11, color: text_color)
    end
  end

  # Clickable chip style: pill-shaped button with toggle state.
  defp chip_style(true = _selected?) do
    StyleMap.new()
    |> StyleMap.background("#3366ff")
    |> StyleMap.text_color("#ffffff")
    |> StyleMap.border(Border.new() |> Border.color("#3366ff") |> Border.width(1) |> Border.rounded(999))
    |> StyleMap.hovered(%{background: "#4477ff"})
  end

  defp chip_style(false = _selected?) do
    StyleMap.new()
    |> StyleMap.background("#f0f0f0")
    |> StyleMap.text_color("#333333")
    |> StyleMap.border(Border.new() |> Border.color("#cccccc") |> Border.width(1) |> Border.rounded(999))
    |> StyleMap.hovered(%{background: "#e4e4e4"})
  end
end
```

### How it works

A badge is a `container` with a high `border` radius (999 creates a pill
shape by ensuring the radius exceeds the container height) and a coloured
background. The text inside is small and tightly padded.

The `badge/4` helper encapsulates this as a display-only element. It returns
a container node with the given background colour, text colour, and label.

Filter chips reuse the same pill-shape concept but as clickable `button`
widgets. The `chip_style/1` function returns a `StyleMap` with rounded
borders. Selected chips have a solid blue fill; unselected chips have a
grey outline. Clicking toggles the tag in a `MapSet`.

### What it looks like

A row of small coloured pills: green "Online", blue "3 new", orange
"Deprecated". Below that, a row of rounded filter buttons. Selected filters
are solid blue; others are grey-outlined. Clicking a chip toggles its
selection state.

---

## General techniques

These patterns share a few recurring techniques worth calling out:

**Style functions over style constants.** Most patterns define a private
function like `tab_style(active?)` or `chip_style(selected?)` that returns
a `StyleMap`. This keeps style logic next to the view, makes it easy to
derive styles from model state, and avoids module attributes for something
that varies per render.

**`space(width: :fill)` as a flex pusher.** Inserting a space with
`width: :fill` inside a row pushes everything after it to the right edge.
This is the flexbox `margin-left: auto` equivalent and is used in toolbars,
headers, and nav bars.

**`border` radius 999 for pills.** Setting a border radius larger than the
element can possibly be tall creates a perfect pill shape. The renderer
clamps the radius to the available space.

**Transparent backgrounds for link-style buttons.** Using `#00000000` (fully
transparent) as a button background makes it look like a text link. Add a
hover state with a subtle background tint for affordance.

**`if` without `else` in do-blocks.** Layout macros filter out `nil` values
from their children list. An `if` without `else` returns `nil` when the
condition is false, so the child simply does not appear in the tree. This is
how the modal overlay conditionally renders.

**Lists in do-blocks are flattened.** Returning a list from inside a
do-block (via `for`, or by writing a literal `[a, b]` expression) works
because children are flattened one level. The breadcrumb pattern relies on
this to emit a button and separator as a pair.

**Helper functions for repeated compositions.** Extract common patterns into
private functions (like `card/3` or `badge/4`) that return node trees. Keep
them in the same module or a dedicated view helpers module. They are plain
functions returning plain maps -- no macros needed.
