defmodule Julep.IcedTest do
  use ExUnit.Case, async: true

  alias Julep.Iced
  alias Julep.Iced.{Alignment, Font, Length, Padding, Theme}

  # ===========================================================================
  # Layout widgets
  # ===========================================================================

  describe "column/3" do
    test "returns correct node shape with defaults" do
      node = Iced.column("col1")
      assert node == %{id: "col1", type: "column", props: %{}, children: []}
    end

    test "passes props and children through" do
      child = Iced.text("t1", %{content: "hi"})
      node = Iced.column("col1", %{spacing: 8, padding: 16}, [child])

      assert node.props == %{"spacing" => 8, "padding" => 16}
      assert node.children == [child]
    end
  end

  describe "row/3" do
    test "returns correct node shape" do
      node = Iced.row("r1", %{align_y: :center})
      assert node.type == "row"
      assert node.props["align_y"] == :center
      assert node.children == []
    end
  end

  describe "container/3" do
    test "returns correct node shape" do
      node = Iced.container("c1", %{center: true}, [Iced.text("t", %{content: "x"})])
      assert node.type == "container"
      assert node.props["center"] == true
      assert length(node.children) == 1
    end
  end

  describe "scrollable/3" do
    test "returns correct node shape" do
      node = Iced.scrollable("s1")
      assert node.type == "scrollable"
      assert node.children == []
    end
  end

  describe "stack/3" do
    test "returns correct node shape" do
      node = Iced.stack("st1", %{width: :fill})
      assert node.type == "stack"
      assert node.props["width"] == :fill
    end
  end

  describe "space/2" do
    test "returns correct node shape without children" do
      node = Iced.space("sp1", %{width: 20, height: 10})
      assert node.type == "space"
      assert node.props == %{"width" => 20, "height" => 10}
      assert node.children == []
    end
  end

  # ===========================================================================
  # Input widgets
  # ===========================================================================

  describe "button/2" do
    test "returns correct node shape" do
      node = Iced.button("btn1", %{label: "Click me", style: :primary})
      assert node == %{id: "btn1", type: "button", props: %{"label" => "Click me", "style" => :primary}, children: []}
    end
  end

  describe "text_input/2" do
    test "returns correct node shape" do
      node = Iced.text_input("ti1", %{value: "hello", placeholder: "Type..."})
      assert node.type == "text_input"
      assert node.props["value"] == "hello"
      assert node.props["placeholder"] == "Type..."
    end
  end

  describe "checkbox/2" do
    test "returns correct node shape" do
      node = Iced.checkbox("cb1", %{is_checked: true, label: "Accept"})
      assert node.type == "checkbox"
      assert node.props["is_checked"] == true
    end
  end

  describe "toggler/2" do
    test "returns correct node shape" do
      node = Iced.toggler("tog1", %{is_toggled: false, label: "Dark mode"})
      assert node.type == "toggler"
      assert node.props["is_toggled"] == false
    end
  end

  describe "radio/2" do
    test "returns correct node shape" do
      node = Iced.radio("rad1", %{value: "a", selected: "a", label: "Option A"})
      assert node.type == "radio"
      assert node.props["selected"] == "a"
    end
  end

  describe "slider/2" do
    test "returns correct node shape" do
      node = Iced.slider("sl1", %{range: {0, 100}, value: 50, step: 1})
      assert node.type == "slider"
      assert node.props["value"] == 50
    end
  end

  describe "vertical_slider/2" do
    test "returns correct node shape" do
      node = Iced.vertical_slider("vsl1", %{range: {0, 100}, value: 25})
      assert node.type == "vertical_slider"
      assert node.props["range"] == {0, 100}
    end
  end

  describe "pick_list/2" do
    test "returns correct node shape" do
      node = Iced.pick_list("pl1", %{options: ["a", "b"], selected: "a"})
      assert node.type == "pick_list"
      assert node.props["options"] == ["a", "b"]
    end
  end

  describe "combo_box/2" do
    test "returns correct node shape" do
      node = Iced.combo_box("cmb1", %{options: ["x"], value: "x"})
      assert node.type == "combo_box"
    end
  end

  describe "text_editor/2" do
    test "returns correct node shape" do
      node = Iced.text_editor("te1", %{content: "some text"})
      assert node.type == "text_editor"
      assert node.props["content"] == "some text"
    end
  end

  # ===========================================================================
  # Display widgets
  # ===========================================================================

  describe "text/2" do
    test "returns correct node shape" do
      node = Iced.text("txt1", %{content: "Hello", size: 16})
      assert node.type == "text"
      assert node.props["content"] == "Hello"
      assert node.props["size"] == 16
    end

    test "empty props" do
      node = Iced.text("txt2")
      assert node.props == %{}
    end
  end

  describe "rule/2" do
    test "returns correct node shape" do
      node = Iced.rule("hr1", %{height: 2})
      assert node.type == "rule"
      assert node.props["height"] == 2
    end
  end

  describe "progress_bar/2" do
    test "returns correct node shape" do
      node = Iced.progress_bar("pb1", %{range: {0, 100}, value: 75})
      assert node.type == "progress_bar"
      assert node.props["value"] == 75
    end
  end

  describe "tooltip/4" do
    test "returns correct node shape with tip_text" do
      child = Iced.button("btn", %{label: "?"})
      node = Iced.tooltip("tip1", %{position: :top, gap: 4}, [child], "Help text")

      assert node.type == "tooltip"
      assert node.props["tip_text"] == "Help text"
      assert node.props["position"] == :top
      assert node.props["gap"] == 4
      assert node.children == [child]
    end

    test "works with default props and children" do
      node = Iced.tooltip("tip2", "Just a tip")
      assert node.props == %{"tip_text" => "Just a tip"}
      assert node.children == []
    end
  end

  describe "image/2" do
    test "returns correct node shape" do
      node = Iced.image("img1", %{source: "logo.png", content_fit: :cover})
      assert node.type == "image"
      assert node.props["source"] == "logo.png"
    end
  end

  describe "svg/2" do
    test "returns correct node shape" do
      node = Iced.svg("svg1", %{source: "icon.svg"})
      assert node.type == "svg"
      assert node.props["source"] == "icon.svg"
    end
  end

  describe "markdown/2" do
    test "returns correct node shape" do
      node = Iced.markdown("md1", %{content: "# Title"})
      assert node.type == "markdown"
      assert node.props["content"] == "# Title"
    end
  end

  # ===========================================================================
  # Cross-cutting concerns
  # ===========================================================================

  describe "prop key normalisation" do
    test "atom keys become string keys" do
      node = Iced.button("b", %{label: "Go", width: :fill})
      assert Map.keys(node.props) |> Enum.all?(&is_binary/1)
    end

    test "string keys pass through unchanged" do
      node = Iced.button("b", %{"label" => "Go"})
      assert node.props["label"] == "Go"
    end
  end

  describe "children default" do
    test "layout widgets default to empty children" do
      for builder <- [&Iced.column/1, &Iced.row/1, &Iced.container/1, &Iced.scrollable/1, &Iced.stack/1] do
        assert builder.("x").children == []
      end
    end

    test "leaf widgets have empty children" do
      for builder <- [&Iced.button/1, &Iced.text/1, &Iced.slider/1, &Iced.space/1] do
        assert builder.("x").children == []
      end
    end
  end

  # ===========================================================================
  # Type modules
  # ===========================================================================

  describe "Length.encode/1" do
    test "encodes :fill" do
      assert Length.encode(:fill) == "fill"
    end

    test "encodes :shrink" do
      assert Length.encode(:shrink) == "shrink"
    end

    test "encodes fill_portion" do
      assert Length.encode({:fill_portion, 3}) == %{"fill_portion" => 3}
    end

    test "encodes fixed number" do
      assert Length.encode(42) == 42
      assert Length.encode(3.5) == 3.5
    end
  end

  describe "Alignment.encode/1" do
    test "encodes all valid values" do
      assert Alignment.encode(:start) == "start"
      assert Alignment.encode(:center) == "center"
      assert Alignment.encode(:end) == "end"
    end

    test "rejects invalid values" do
      assert_raise FunctionClauseError, fn -> Alignment.encode(:middle) end
    end
  end

  describe "Padding.encode/1" do
    test "encodes uniform integer" do
      assert Padding.encode(8) == %{"top" => 8, "right" => 8, "bottom" => 8, "left" => 8}
    end

    test "encodes {vertical, horizontal} tuple" do
      assert Padding.encode({4, 12}) == %{"top" => 4, "right" => 12, "bottom" => 4, "left" => 12}
    end

    test "encodes explicit per-side map" do
      input = %{top: 1, right: 2, bottom: 3, left: 4}
      assert Padding.encode(input) == %{"top" => 1, "right" => 2, "bottom" => 3, "left" => 4}
    end
  end

  describe "Theme" do
    test "builtin_themes/0 returns a non-empty list" do
      themes = Theme.builtin_themes()
      assert is_list(themes)
      assert length(themes) > 10
      assert :dark in themes
      assert :catppuccin_mocha in themes
    end

    test "encode/1 converts to PascalCase" do
      assert Theme.encode(:dark) == "Dark"
      assert Theme.encode(:light) == "Light"
      assert Theme.encode(:catppuccin_mocha) == "CatppuccinMocha"
      assert Theme.encode(:solarized_light) == "SolarizedLight"
      assert Theme.encode(:tokyo_night_storm) == "TokyoNightStorm"
    end

    test "encode/1 rejects unknown themes" do
      assert_raise FunctionClauseError, fn -> Theme.encode(:neon_pink) end
    end
  end

  describe "Font.encode/1" do
    test "encodes :default" do
      assert Font.encode(:default) == "default"
    end

    test "encodes :monospace" do
      assert Font.encode(:monospace) == "monospace"
    end

    test "encodes string font name" do
      assert Font.encode("Fira Code") == %{"family" => "Fira Code"}
    end

    test "encodes full font descriptor" do
      result = Font.encode(%{family: "Inter", weight: :bold, style: :italic})
      assert result == %{"family" => "Inter", "weight" => "Bold", "style" => "Italic"}
    end

    test "encodes multi-segment weight" do
      result = Font.encode(%{family: "X", weight: :extra_bold})
      assert result["weight"] == "ExtraBold"
    end
  end
end
