defmodule Plushie.Docs.AccessibilityTest do
  use ExUnit.Case, async: true

  import Plushie.UI

  alias Plushie.Type.A11y
  alias Plushie.Widget.Button, as: ButtonW
  alias Plushie.Widget.Text, as: TextW
  alias Plushie.Widget.TextInput, as: TextInputW

  # After Tree.normalize/1, atoms inside the a11y map are encoded to strings
  # (role: :heading -> "heading", live: :polite -> "polite", etc.).
  # Booleans, integers, and strings pass through unchanged.

  # ---------------------------------------------------------------------------
  # Using the a11y prop (UI builder syntax)
  # ---------------------------------------------------------------------------

  test "accessibility_heading_level_1_test" do
    node =
      text("title", "Welcome to MyApp", a11y: %A11y{role: :heading, level: 1})
      |> Plushie.Tree.normalize()

    assert node.type == "text"
    assert node.props[:content] == "Welcome to MyApp"
    assert node.props[:a11y][:role] == "heading"
    assert node.props[:a11y][:level] == 1
  end

  test "accessibility_icon_button_label_test" do
    node =
      button("close", "X", a11y: %A11y{label: "Close dialog"})
      |> Plushie.Tree.normalize()

    assert node.type == "button"
    assert node.props[:a11y][:label] == "Close dialog"
  end

  test "accessibility_landmark_region_test" do
    node =
      container("search_results", a11y: %A11y{role: :region, label: "Search results"})
      |> Plushie.Tree.normalize()

    assert node.type == "container"
    assert node.props[:a11y][:role] == "region"
    assert node.props[:a11y][:label] == "Search results"
  end

  # ---------------------------------------------------------------------------
  # Typed widget builder API
  # ---------------------------------------------------------------------------

  test "accessibility_button_widget_builder_test" do
    node =
      ButtonW.new("close", "X")
      |> ButtonW.a11y(%A11y{label: "Close dialog"})
      |> ButtonW.build()
      |> Plushie.Tree.normalize()

    assert node.type == "button"
    assert node.props[:a11y][:label] == "Close dialog"
  end

  test "accessibility_text_widget_builder_test" do
    node =
      TextW.new("title", "Welcome")
      |> TextW.a11y(%A11y{role: :heading, level: 1})
      |> TextW.build()
      |> Plushie.Tree.normalize()

    assert node.type == "text"
    assert node.props[:a11y][:role] == "heading"
    assert node.props[:a11y][:level] == 1
  end

  test "accessibility_text_input_widget_builder_test" do
    node =
      TextInputW.new("email", "")
      |> TextInputW.a11y(%A11y{required: true, label: "Email address"})
      |> TextInputW.build()
      |> Plushie.Tree.normalize()

    assert node.type == "text_input"
    assert node.props[:a11y][:required] == true
    assert node.props[:a11y][:label] == "Email address"
  end

  # ---------------------------------------------------------------------------
  # Heading structure
  # ---------------------------------------------------------------------------

  test "accessibility_heading_structure_test" do
    tree =
      window "main", title: "MyApp" do
        column do
          text("page_title", "Dashboard", a11y: %A11y{role: :heading, level: 1})
          text("h_recent", "Recent activity", a11y: %A11y{role: :heading, level: 2})
          text("h_actions", "Quick actions", a11y: %A11y{role: :heading, level: 2})
        end
      end
      |> Plushie.Tree.normalize()

    assert [column] = tree.children
    assert [h1, h2a, h2b] = column.children

    assert h1.props[:a11y][:role] == "heading"
    assert h1.props[:a11y][:level] == 1

    assert h2a.props[:a11y][:role] == "heading"
    assert h2a.props[:a11y][:level] == 2

    assert h2b.props[:a11y][:role] == "heading"
    assert h2b.props[:a11y][:level] == 2
  end

  # ---------------------------------------------------------------------------
  # Landmarks
  # ---------------------------------------------------------------------------

  test "accessibility_navigation_landmark_test" do
    node =
      container "nav", a11y: %A11y{role: :navigation, label: "Main navigation"} do
        row do
          button("home", "Home")
          button("settings", "Settings")
          button("help", "Help")
        end
      end
      |> Plushie.Tree.normalize()

    assert node.props[:a11y][:role] == "navigation"
    assert node.props[:a11y][:label] == "Main navigation"
    assert length(node.children) == 1
  end

  test "accessibility_search_landmark_test" do
    node =
      container "search_area", a11y: %A11y{role: :search, label: "Search"} do
        row do
          text_input("query", "", placeholder: "Search...")
          button("go", "Search")
        end
      end
      |> Plushie.Tree.normalize()

    assert node.props[:a11y][:role] == "search"
    assert node.props[:a11y][:label] == "Search"
    assert length(node.children) == 1
    assert length(hd(node.children).children) == 2
  end

  # ---------------------------------------------------------------------------
  # Live regions
  # ---------------------------------------------------------------------------

  test "accessibility_live_polite_test" do
    node =
      text("status", "All good", a11y: %A11y{live: :polite})
      |> Plushie.Tree.normalize()

    assert node.props[:a11y][:live] == "polite"
  end

  test "accessibility_live_assertive_alert_test" do
    node =
      text("error", "Something went wrong", a11y: %A11y{live: :assertive, role: :alert})
      |> Plushie.Tree.normalize()

    assert node.props[:a11y][:live] == "assertive"
    assert node.props[:a11y][:role] == "alert"
  end

  # ---------------------------------------------------------------------------
  # Cross-widget relationships
  # ---------------------------------------------------------------------------

  test "accessibility_labelled_by_test" do
    node =
      text_input("email", "",
        a11y: %A11y{
          labelled_by: "email-label",
          described_by: "email-help",
          error_message: "email-error"
        }
      )
      |> Plushie.Tree.normalize()

    assert node.props[:a11y][:labelled_by] == "email-label"
    assert node.props[:a11y][:described_by] == "email-help"
    assert node.props[:a11y][:error_message] == "email-error"
  end

  # ---------------------------------------------------------------------------
  # Hiding decorative content
  # ---------------------------------------------------------------------------

  test "accessibility_hidden_rule_test" do
    node =
      rule(a11y: %A11y{hidden: true})
      |> Plushie.Tree.normalize()

    assert node.props[:a11y][:hidden] == true
  end

  test "accessibility_decorative_image_hidden_test" do
    node =
      image("hero", "/images/banner.png", a11y: %A11y{hidden: true})
      |> Plushie.Tree.normalize()

    assert node.props[:a11y][:hidden] == true
  end

  test "accessibility_space_hidden_test" do
    node =
      space(a11y: %A11y{hidden: true})
      |> Plushie.Tree.normalize()

    assert node.props[:a11y][:hidden] == true
  end

  # ---------------------------------------------------------------------------
  # Canvas with a11y
  # ---------------------------------------------------------------------------

  test "accessibility_canvas_a11y_test" do
    node =
      canvas("chart",
        a11y: %A11y{role: :image, label: "Sales chart: Q1 revenue up 15%, Q2 flat"}
      )
      |> Plushie.Tree.normalize()

    assert node.type == "canvas"
    assert node.props[:a11y][:role] == "image"
    assert node.props[:a11y][:label] == "Sales chart: Q1 revenue up 15%, Q2 flat"
  end

  # ---------------------------------------------------------------------------
  # Custom widgets with state
  # ---------------------------------------------------------------------------

  test "accessibility_canvas_switch_toggled_test" do
    node =
      canvas("dark-mode-switch",
        a11y: %A11y{role: :switch, label: "Dark mode", toggled: true}
      )
      |> Plushie.Tree.normalize()

    assert node.props[:a11y][:role] == "switch"
    assert node.props[:a11y][:toggled] == true
    assert node.props[:a11y][:label] == "Dark mode"
  end

  test "accessibility_canvas_meter_with_value_test" do
    node =
      canvas("cpu-gauge",
        a11y: %A11y{
          role: :meter,
          label: "CPU usage",
          value: "75%",
          orientation: :horizontal
        }
      )
      |> Plushie.Tree.normalize()

    assert node.props[:a11y][:role] == "meter"
    assert node.props[:a11y][:value] == "75%"
    assert node.props[:a11y][:label] == "CPU usage"
    assert node.props[:a11y][:orientation] == "horizontal"
  end

  # ---------------------------------------------------------------------------
  # has_popup
  # ---------------------------------------------------------------------------

  test "accessibility_has_popup_menu_test" do
    node =
      button("menu_btn", "Options", a11y: %A11y{has_popup: "menu", expanded: false})
      |> Plushie.Tree.normalize()

    assert node.props[:a11y][:has_popup] == "menu"
    assert node.props[:a11y][:expanded] == false
  end

  test "accessibility_has_popup_listbox_test" do
    node =
      text_input("search", "", a11y: %A11y{has_popup: "listbox", expanded: true})
      |> Plushie.Tree.normalize()

    assert node.props[:a11y][:has_popup] == "listbox"
    assert node.props[:a11y][:expanded] == true
  end

  # ---------------------------------------------------------------------------
  # Disabled override
  # ---------------------------------------------------------------------------

  test "accessibility_disabled_override_test" do
    node =
      button("submit", "Submit", a11y: %A11y{disabled: true})
      |> Plushie.Tree.normalize()

    assert node.props[:a11y][:disabled] == true
  end

  # ---------------------------------------------------------------------------
  # Expanded/collapsed
  # ---------------------------------------------------------------------------

  test "accessibility_expanded_button_test" do
    node =
      button("toggle_details", "Show details", a11y: %A11y{expanded: false})
      |> Plushie.Tree.normalize()

    assert node.props[:a11y][:expanded] == false
  end

  # ---------------------------------------------------------------------------
  # Widget-specific a11y props: alt, label, description, decorative
  # ---------------------------------------------------------------------------

  test "accessibility_image_alt_prop_test" do
    node =
      image("logo", "/images/logo.png", alt: "Company logo")
      |> Plushie.Tree.normalize()

    assert node.props[:alt] == "Company logo"
  end

  test "accessibility_slider_label_prop_test" do
    node =
      slider("volume", {0, 100}, 50, label: "Volume")
      |> Plushie.Tree.normalize()

    assert node.props[:label] == "Volume"
  end

  test "accessibility_progress_bar_label_prop_test" do
    node =
      progress_bar("upload", {0, 100}, 50, label: "Upload progress")
      |> Plushie.Tree.normalize()

    assert node.props[:label] == "Upload progress"
  end

  test "accessibility_image_description_prop_test" do
    node =
      image("photo", "/photo.jpg",
        alt: "Team photo",
        description: "The engineering team at the 2025 offsite"
      )
      |> Plushie.Tree.normalize()

    assert node.props[:alt] == "Team photo"
    assert node.props[:description] == "The engineering team at the 2025 offsite"
  end

  test "accessibility_image_decorative_prop_test" do
    node =
      image("divider", "/images/decorative-line.png", decorative: true)
      |> Plushie.Tree.normalize()

    assert node.props[:decorative] == true
  end

  # ---------------------------------------------------------------------------
  # A11y struct construction (standalone, not widget-attached)
  # ---------------------------------------------------------------------------

  test "accessibility_position_in_set_test" do
    a = %A11y{position_in_set: 3, size_of_set: 7}
    assert a.position_in_set == 3
    assert a.size_of_set == 7
  end

  test "accessibility_selected_state_test" do
    a = %A11y{selected: true}
    assert a.selected == true
  end

  test "accessibility_modal_and_busy_test" do
    a = %A11y{modal: true, busy: true}
    assert a.modal == true
    assert a.busy == true
  end

  test "accessibility_read_only_and_invalid_test" do
    a = %A11y{read_only: true, invalid: true}
    assert a.read_only == true
    assert a.invalid == true
  end

  test "accessibility_mnemonic_test" do
    a = %A11y{mnemonic: "S"}
    assert a.mnemonic == "S"
  end

  test "accessibility_cast_from_bare_map_test" do
    {:ok, a} = A11y.cast(%{role: :heading, level: 1})
    assert %A11y{role: :heading, level: 1} = a
  end
end
