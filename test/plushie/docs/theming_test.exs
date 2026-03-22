defmodule Plushie.Docs.ThemingTest do
  use ExUnit.Case, async: true

  alias Plushie.Type.Border
  alias Plushie.Type.Shadow
  alias Plushie.Type.StyleMap
  alias Plushie.Type.Theme

  # -- Setting a theme via themer widget --------------------------------------

  test "theming_settings_theme_test" do
    import Plushie.UI

    tree =
      Plushie.Tree.normalize(
        window "main", title: "My App" do
          themer "theme", theme: :catppuccin_mocha do
            column do
              text("Themed content")
            end
          end
        end
      )

    assert tree.type == "window"
    assert tree.id == "main"
    assert [themer_node] = tree.children
    assert themer_node.type == "themer"
    assert themer_node.props[:theme] == "catppuccin_mocha"
  end

  # -- Custom theme via palette map ------------------------------------------

  test "theming_custom_theme_test" do
    theme =
      Theme.custom("my_app",
        background: "#1e1e2e",
        text: "#cdd6f4",
        primary: "#89b4fa",
        success: "#a6e3a1",
        danger: "#f38ba8",
        warning: "#f9e2af"
      )

    assert theme.name == "my_app"
    assert theme.background == "#1e1e2e"
    assert theme.text == "#cdd6f4"
    assert theme.primary == "#89b4fa"
  end

  # -- Extended palette shade overrides --------------------------------------

  test "theming_custom_theme_shade_overrides_test" do
    theme =
      Theme.custom("branded",
        background: "#1a1a2e",
        text: "#e0e0e0",
        primary: "#0f3460",
        primary_strong: "#1a5276",
        primary_strong_text: "#ffffff",
        background_weakest: "#0d0d1a"
      )

    assert theme.name == "branded"
    assert theme.primary_strong == "#1a5276"
    assert theme.primary_strong_text == "#ffffff"
    assert theme.background_weakest == "#0d0d1a"
  end

  # -- Style map: basic background + text_color ------------------------------

  test "theming_style_map_basic_test" do
    sm =
      StyleMap.new()
      |> StyleMap.background("#ffffff")
      |> StyleMap.text_color("#1a1a1a")

    assert sm.background == "#ffffff"
    assert sm.text_color == "#1a1a1a"
  end

  # -- Style map: with border ------------------------------------------------

  test "theming_style_map_with_border_test" do
    b =
      Border.new()
      |> Border.rounded(8)
      |> Border.width(1)
      |> Border.color("#e0e0e0")

    sm =
      StyleMap.new()
      |> StyleMap.border(b)

    assert %Border{radius: 8, width: 1, color: "#e0e0e0"} = sm.border
  end

  # -- Style map: with shadow ------------------------------------------------

  test "theming_style_map_with_shadow_test" do
    s =
      Shadow.new()
      |> Shadow.color("#00000020")
      |> Shadow.offset(0, 2)
      |> Shadow.blur_radius(8)

    sm =
      StyleMap.new()
      |> StyleMap.shadow(s)

    assert %Shadow{color: "#00000020", offset_x: 0, offset_y: 2, blur_radius: 8} = sm.shadow
  end

  # -- Status overrides ------------------------------------------------------

  test "theming_style_map_status_overrides_test" do
    sm =
      StyleMap.new()
      |> StyleMap.background("#00000000")
      |> StyleMap.text_color("#cccccc")
      |> StyleMap.hovered(%{background: "#333333", text_color: "#ffffff"})
      |> StyleMap.pressed(%{background: "#222222"})
      |> StyleMap.disabled(%{text_color: "#666666"})

    assert sm.hovered.background == "#333333"
    assert sm.hovered.text_color == "#ffffff"
    assert sm.pressed.background == "#222222"
    assert sm.disabled.text_color == "#666666"
  end

  # -- System theme setting --------------------------------------------------

  test "theming_system_theme_setting_test" do
    import Plushie.UI

    tree =
      Plushie.Tree.normalize(
        window "main", title: "My App" do
          themer "sys_theme", theme: :system do
            text("content")
          end
        end
      )

    assert [themer_node] = tree.children
    assert themer_node.props[:theme] == "system"
  end
end
