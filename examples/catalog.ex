defmodule Catalog do
  @moduledoc """
  Comprehensive widget catalog exercising every real iced widget type in Plushie.

  Organized as a column layout with tab-like navigation across four sections:
  layout, input, display, and composite. Each section demonstrates a category
  of widgets with realistic props and interactive state.

  ## Demonstrated widgets

  **Layout:** column, row, container, scrollable, stack, grid, pin, float,
  responsive, keyed_column, themer, space

  **Input:** button, text_input, checkbox, toggler, radio (with group prop),
  slider, vertical_slider, pick_list, combo_box, text_editor

  **Display:** text, rule, progress_bar, tooltip, image, svg, markdown,
  rich_text, canvas

  **Interactive/Composite:** mouse_area, sensor, pane_grid, table

  ## Key patterns shown

  - `do` blocks for layout widgets with children
  - Event handling: button clicks, input changes, slider drags, radio selects
  - Conditional rendering based on model state
  - `themer` widget overriding the theme palette for a section
  - Canvas with geometric shapes
  - PaneGrid with multiple panes containing real content
  - Markdown rendering with settings
  - Rich text with styled spans
  - Table with typed columns and data rows
  - Mouse area wrapping interactive content
  - Sensor detecting pointer events

  ## Running

      mix plushie.gui Catalog
  """

  use Plushie.App

  alias Plushie.Event.{MouseArea, Sensor, Widget}

  # -- init ------------------------------------------------------------------

  def init(_opts) do
    %{
      active_tab: "layout",
      demo_tabs_active: "tab_one",
      text_value: "",
      checkbox_checked: false,
      toggler_on: false,
      slider_value: 50,
      vslider_value: 50,
      radio_selected: "a",
      pick_list_selected: nil,
      combo_value: nil,
      editor_content: "Edit me...",
      progress: 65,
      panel_collapsed: false,
      modal_visible: false,
      click_count: 0,
      mouse_area_status: "idle",
      sensor_status: "waiting"
    }
  end

  # -- update ----------------------------------------------------------------

  # Tab switching
  def update(model, %Widget{type: :click, id: "tab_layout"}), do: %{model | active_tab: "layout"}
  def update(model, %Widget{type: :click, id: "tab_input"}), do: %{model | active_tab: "input"}

  def update(model, %Widget{type: :click, id: "tab_display"}),
    do: %{model | active_tab: "display"}

  def update(model, %Widget{type: :click, id: "tab_composite"}),
    do: %{model | active_tab: "composite"}

  # Input widgets
  def update(model, %Widget{type: :input, id: "demo_input", value: value}),
    do: %{model | text_value: value}

  def update(model, %Widget{type: :toggle, id: "demo_check", value: val}),
    do: %{model | checkbox_checked: val}

  def update(model, %Widget{type: :toggle, id: "demo_toggler", value: val}),
    do: %{model | toggler_on: val}

  def update(model, %Widget{type: :slide, id: "demo_slider", value: val}),
    do: %{model | slider_value: val}

  def update(model, %Widget{type: :slide, id: "demo_vslider", value: val}),
    do: %{model | vslider_value: val}

  def update(model, %Widget{type: :select, id: "demo_radio", value: val}),
    do: %{model | radio_selected: val}

  def update(model, %Widget{type: :select, id: "demo_pick", value: val}),
    do: %{model | pick_list_selected: val}

  def update(model, %Widget{type: :select, id: "demo_combo", value: val}),
    do: %{model | combo_value: val}

  def update(model, %Widget{type: :input, id: "demo_editor", value: val}),
    do: %{model | editor_content: val}

  # Composite section - simulated tab switching with buttons
  def update(model, %Widget{type: :click, id: "tab_one"}),
    do: %{model | demo_tabs_active: "tab_one"}

  def update(model, %Widget{type: :click, id: "tab_two"}),
    do: %{model | demo_tabs_active: "tab_two"}

  # Modal show/hide
  def update(model, %Widget{type: :click, id: "show_modal"}),
    do: %{model | modal_visible: true}

  def update(model, %Widget{type: :click, id: "hide_modal"}),
    do: %{model | modal_visible: false}

  # Panel collapse toggle
  def update(model, %Widget{type: :click, id: "demo_panel"}) do
    %{model | panel_collapsed: not model.panel_collapsed}
  end

  # Interactive widgets
  def update(model, %Widget{type: :click, id: "counter_btn"}) do
    %{model | click_count: model.click_count + 1}
  end

  def update(model, %Widget{type: :click, id: "inc_progress"}) do
    %{model | progress: min(model.progress + 5, 100)}
  end

  def update(model, %MouseArea{type: :enter, id: "demo_mouse_area"}) do
    %{model | mouse_area_status: "hovering"}
  end

  def update(model, %MouseArea{type: :exit, id: "demo_mouse_area"}) do
    %{model | mouse_area_status: "idle"}
  end

  def update(model, %Sensor{type: :resize, id: "demo_sensor"}) do
    %{model | sensor_status: "activated"}
  end

  # Catch-all
  def update(model, _event), do: model

  # -- view ------------------------------------------------------------------

  def view(model) do
    import Plushie.UI

    window "catalog", title: "Widget Catalog" do
      column spacing: 12, padding: 16 do
        text("catalog_title", "Plushie Widget Catalog", size: 24)
        rule()

        row spacing: 8 do
          button("tab_layout", "Layout")
          button("tab_input", "Input")
          button("tab_display", "Display")
          button("tab_composite", "Composite")
        end

        rule()

        case model.active_tab do
          "layout" -> layout_tab()
          "input" -> input_tab(model)
          "display" -> display_tab(model)
          "composite" -> composite_tab(model)
        end
      end
    end
  end

  # -- tab views (private) ---------------------------------------------------

  # Uses inline prop syntax (see also: keyword form in Input section)
  defp layout_tab do
    import Plushie.UI

    column do
      spacing 8

      text("layout_heading", "Layout Widgets", size: 18)

      # Row
      row spacing: 8 do
        text("Row child 1")
        text("Row child 2")
        text("Row child 3")
      end

      # Nested column
      column spacing: 4 do
        text("Nested column child 1")
        text("Nested column child 2")
      end

      # Container with padding
      container "demo_container" do
        padding 12

        text("Inside a container")
      end

      # Scrollable
      scrollable "demo_scrollable" do
        column spacing: 4 do
          text("Scrollable item 1")
          text("Scrollable item 2")
          text("Scrollable item 3")
          text("Scrollable item 4")
          text("Scrollable item 5")
        end
      end

      # Stack - layers on top of each other
      stack do
        text("Stack layer 1 (back)")
        text("Stack layer 2 (front)")
      end

      # Grid layout
      grid columns: 3, spacing: 4 do
        text("Grid 1")
        text("Grid 2")
        text("Grid 3")
        text("Grid 4")
        text("Grid 5")
        text("Grid 6")
      end

      # Pin - positioned element
      pin "demo_pin", x: 0, y: 0 do
        text("Pinned content")
      end

      # Float - floating overlay element with translation
      floating "demo_float", translate_x: 100, translate_y: 10 do
        text("Floating element")
      end

      # Responsive layout
      responsive do
        column do
          text("Responsive content adapts to width")
        end
      end

      # Keyed column - stable identity for children
      keyed_column spacing: 4 do
        text("key_a", "Keyed item A")
        text("key_b", "Keyed item B")
        text("key_c", "Keyed item C")
      end

      # Themer - overrides the theme for its subtree
      themer "demo_themer",
        theme: %{background: "#1a1a2e", text: "#e0e0e0", primary: "#0f3460"} do
        container "themed_box" do
          padding 12

          column spacing: 4 do
            text("Themed section with custom palette")
            button("themed_btn", "Themed Button")
          end
        end
      end

      # Space - explicit gap
      space(height: 16)
    end
  end

  defp input_tab(model) do
    import Plushie.UI

    column spacing: 8 do
      text("input_heading", "Input Widgets", size: 18)

      # Text input
      text_input("demo_input", model.text_value, placeholder: "Type here...")

      # Button
      button("demo_button", "A Button")

      # Checkbox
      checkbox("demo_check", model.checkbox_checked, label: "Check me")

      # Toggler
      toggler("demo_toggler", model.toggler_on, label: "Toggle me")

      # Radio group
      row spacing: 8 do
        radio("demo_radio_a", "a", model.radio_selected, label: "Option A", group: "demo_radio")
        radio("demo_radio_b", "b", model.radio_selected, label: "Option B", group: "demo_radio")
        radio("demo_radio_c", "c", model.radio_selected, label: "Option C", group: "demo_radio")
      end

      # Slider
      slider("demo_slider", {0, 100}, model.slider_value, step: 1)
      text("Slider: #{model.slider_value}")

      # Vertical slider
      vertical_slider("demo_vslider", {0, 100}, model.vslider_value, step: 1)

      # Pick list
      pick_list("demo_pick", ["Small", "Medium", "Large"], model.pick_list_selected,
        placeholder: "Pick a size..."
      )

      # Combo box
      combo_box("demo_combo", ["Elixir", "Rust", "Go"], model.combo_value || "",
        placeholder: "Choose a language..."
      )

      # Text editor
      text_editor("demo_editor", model.editor_content, height: 100)
    end
  end

  defp display_tab(model) do
    import Plushie.UI

    column spacing: 8 do
      text("display_heading", "Display Widgets", size: 18)

      # Plain text
      text("Plain text label")

      # Rule (horizontal divider)
      rule()

      # Progress bar with interactive control
      row spacing: 8 do
        progress_bar({0, 100}, model.progress)
        button("inc_progress", "+5%")
      end

      # Tooltip wrapping a button
      tooltip "demo_tooltip", "This is a tooltip", position: :top do
        button("tooltip_target", "Hover me for tooltip")
      end

      # Image
      image("demo_image", "/assets/placeholder.png", width: 120, height: 80)

      # SVG
      svg("demo_svg", "/assets/icon.svg", width: 24, height: 24)

      # Markdown with settings
      markdown(
        "demo_markdown",
        "## Markdown\n\nSome **bold** and *italic* text.\n\n- Item one\n- Item two"
      )

      # Rich text with styled spans
      rich_text("demo_rich_text",
        spans: [
          %{text: "Bold text ", weight: :bold, size: 16},
          %{text: "italic text ", style: :italic},
          %{text: "normal text "},
          %{text: "colored text", color: "#e74c3c"}
        ]
      )

      # Canvas with geometric shapes
      canvas("demo_canvas",
        width: 200,
        height: 150,
        layers: %{
          "default" => [
            %{type: "rect", x: 10, y: 10, w: 80, h: 60, fill: "#3498db"},
            %{type: "circle", x: 150, y: 75, r: 40, fill: "#e74c3c"},
            %{
              type: "line",
              x1: 10,
              y1: 130,
              x2: 190,
              y2: 130,
              stroke: %{color: "#2ecc71", width: 2}
            }
          ]
        }
      )
    end
  end

  defp composite_tab(model) do
    import Plushie.UI

    column spacing: 8 do
      text("composite_heading", "Interactive & Composite Widgets", size: 18)

      # Mouse area wrapping content -- detects hover enter/exit
      mouse_area "demo_mouse_area", on_enter: true, on_exit: true do
        container "mouse_area_box", padding: 12 do
          text("Mouse area: #{model.mouse_area_status}")
        end
      end

      # Sensor detecting pointer events
      sensor "demo_sensor" do
        container "sensor_box", padding: 12 do
          text("Sensor: #{model.sensor_status}")
        end
      end

      # Simulated tab switching using buttons and conditional content
      # Wrapped in a container with the "demo_tabs" id so tests can find it
      container "demo_tabs" do
        column spacing: 4 do
          row spacing: 4 do
            button("tab_one", "Tab One")
            button("tab_two", "Tab Two")
          end

          if model.demo_tabs_active == "tab_one" do
            text("Tab one content")
          else
            text("Tab two content")
          end
        end
      end

      # Modal simulation using container with visible prop
      button("show_modal", "Show Modal")

      if model.modal_visible do
        container "demo_modal", padding: 16 do
          column spacing: 8 do
            text("Modal Content")
            button("hide_modal", "Close")
          end
        end
      end

      # Collapsible panel simulation
      button("demo_panel", if(model.panel_collapsed, do: "Expand Panel", else: "Collapse Panel"))

      if not model.panel_collapsed do
        container "panel_content", padding: 8 do
          text("Panel content that can be collapsed")
        end
      end

      # Counter demonstrating click events updating model
      row spacing: 8 do
        button("counter_btn", "Click me")
        text("Clicked #{model.click_count} times")
      end

      # PaneGrid with multiple panes
      pane_grid "demo_panes", spacing: 2 do
        container "pane_left", padding: 8 do
          column do
            text("Left pane")
            text("Navigation or file tree")
          end
        end

        container "pane_right", padding: 8 do
          column do
            text("Right pane")
            text("Main editor area")
          end
        end
      end

      # Table with columns and rows
      table("demo_table",
        columns: [
          %{key: "name", label: "Name"},
          %{key: "lang", label: "Language"},
          %{key: "stars", label: "Stars"}
        ],
        rows: [
          %{"name" => "Phoenix", "lang" => "Elixir", "stars" => "20k"},
          %{"name" => "Iced", "lang" => "Rust", "stars" => "24k"},
          %{"name" => "React", "lang" => "JavaScript", "stars" => "220k"}
        ]
      )
    end
  end
end
