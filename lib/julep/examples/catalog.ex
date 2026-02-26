defmodule Julep.Examples.Catalog do
  @moduledoc """
  Widget catalog demo exercising every widget type in Julep.UI.

  Organized as a tabbed layout with four tabs: layout, input, display, composite.
  Phase 2 gate demo.
  """

  use Julep.App

  # -- init ------------------------------------------------------------------

  def init(_opts) do
    %{
      active_tab: "layout",
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
      modal_visible: false
    }
  end

  # -- update ----------------------------------------------------------------

  # Tab switching
  def update(model, {:click, "tab_layout"}), do: %{model | active_tab: "layout"}
  def update(model, {:click, "tab_input"}), do: %{model | active_tab: "input"}
  def update(model, {:click, "tab_display"}), do: %{model | active_tab: "display"}
  def update(model, {:click, "tab_composite"}), do: %{model | active_tab: "composite"}

  # Input widgets
  def update(model, {:input, "demo_input", value}), do: %{model | text_value: value}
  def update(model, {:toggle, "demo_check", val}), do: %{model | checkbox_checked: val}
  def update(model, {:toggle, "demo_toggler", val}), do: %{model | toggler_on: val}
  def update(model, {:slide, "demo_slider", val}), do: %{model | slider_value: val}
  def update(model, {:slide, "demo_vslider", val}), do: %{model | vslider_value: val}
  def update(model, {:select, "demo_radio", val}), do: %{model | radio_selected: val}
  def update(model, {:select, "demo_pick", val}), do: %{model | pick_list_selected: val}
  def update(model, {:select, "demo_combo", val}), do: %{model | combo_value: val}
  def update(model, {:input, "demo_editor", val}), do: %{model | editor_content: val}

  # Composite widgets
  def update(model, {:click, "demo_panel"}) do
    %{model | panel_collapsed: not model.panel_collapsed}
  end

  def update(model, {:click, "show_modal"}), do: %{model | modal_visible: true}
  def update(model, {:click, "hide_modal"}), do: %{model | modal_visible: false}

  # Catch-all
  def update(model, _event), do: model

  # -- view ------------------------------------------------------------------

  def view(model) do
    import Julep.UI

    window "catalog", title: "Widget Catalog" do
      column spacing: 12, padding: 16 do
        text("Julep Widget Catalog", size: 24)
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

  defp layout_tab do
    import Julep.UI

    column spacing: 8 do
      text("Layout Widgets", size: 18)

      row spacing: 8 do
        text("Row child 1")
        text("Row child 2")
        text("Row child 3")
      end

      column spacing: 4 do
        text("Nested column child 1")
        text("Nested column child 2")
      end

      container "demo_container", padding: 12 do
        text("Inside a container")
      end

      scrollable "demo_scrollable" do
        column spacing: 4 do
          text("Scrollable item 1")
          text("Scrollable item 2")
          text("Scrollable item 3")
        end
      end

      stack do
        text("Stack layer 1")
        text("Stack layer 2")
      end

      space(height: 16)
    end
  end

  defp input_tab(model) do
    import Julep.UI

    column spacing: 8 do
      text("Input Widgets", size: 18)

      text_input("demo_input", model.text_value, placeholder: "Type here...")
      button("demo_button", "A Button")
      checkbox("demo_check", model.checkbox_checked, label: "Check me")
      toggler("demo_toggler", model.toggler_on, label: "Toggle me")

      row spacing: 8 do
        radio("demo_radio_a", "a", model.radio_selected, label: "Option A")
        radio("demo_radio_b", "b", model.radio_selected, label: "Option B")
        radio("demo_radio_c", "c", model.radio_selected, label: "Option C")
      end

      slider("demo_slider", {0, 100}, model.slider_value, step: 1)
      vertical_slider("demo_vslider", {0, 100}, model.vslider_value, step: 1)

      pick_list("demo_pick", ["Small", "Medium", "Large"], model.pick_list_selected,
        placeholder: "Pick a size..."
      )

      combo_box("demo_combo", ["Elixir", "Rust", "Go"], model.combo_value || "",
        placeholder: "Choose a language..."
      )

      text_editor("demo_editor", model.editor_content, height: 100)
    end
  end

  defp display_tab(model) do
    import Julep.UI

    column spacing: 8 do
      text("Display Widgets", size: 18)

      text("Plain text label")
      rule()
      progress_bar({0, 100}, model.progress)
      image("demo_image", "/assets/placeholder.png", width: 120, height: 80)
      svg("demo_svg", "/assets/icon.svg", width: 24, height: 24)
      markdown("## Markdown\n\nSome **bold** and *italic* text.")
    end
  end

  defp composite_tab(model) do
    import Julep.UI

    column spacing: 8 do
      text("Composite Widgets", size: 18)

      tooltip "demo_tooltip", tip: "This is a tooltip" do
        button("tooltip_target", "Hover me")
      end

      tabs "demo_tabs", active: "tab_one" do
        container "tab_one" do
          text("Tab one content")
        end

        container "tab_two" do
          text("Tab two content")
        end
      end

      nav "demo_nav", active: "nav_home" do
        button("nav_home", "Home")
        button("nav_settings", "Settings")
      end

      button("show_modal", "Show Modal")

      modal "demo_modal", visible: model.modal_visible do
        column spacing: 8 do
          text("Modal Content")
          button("hide_modal", "Close")
        end
      end

      card "demo_card", title: "Demo Card", padding: 12 do
        text("Card body content")
      end

      panel "demo_panel", title: "Collapsible Panel", collapsed: model.panel_collapsed do
        text("Panel content that can be collapsed")
      end

      form "demo_form", spacing: 8 do
        text_input("form_name", "", placeholder: "Name")
        text_input("form_email", "", placeholder: "Email")
        button("form_submit", "Submit")
      end

      split_pane "demo_split", ratio: 0.5, direction: :horizontal do
        container "split_left" do
          text("Left pane")
        end

        container "split_right" do
          text("Right pane")
        end
      end
    end
  end
end
