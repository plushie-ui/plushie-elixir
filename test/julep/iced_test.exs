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

      assert node == %{
               id: "btn1",
               type: "button",
               props: %{"label" => "Click me", "style" => :primary},
               children: []
             }
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
    test "returns correct node shape with tip" do
      child = Iced.button("btn", %{label: "?"})
      node = Iced.tooltip("tip1", %{position: :top, gap: 4}, [child], "Help text")

      assert node.type == "tooltip"
      assert node.props["tip"] == "Help text"
      assert node.props["position"] == :top
      assert node.props["gap"] == 4
      assert node.children == [child]
    end

    test "works with default props and children" do
      node = Iced.tooltip("tip2", "Just a tip")
      assert node.props == %{"tip" => "Just a tip"}
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
  # Canvas & data widgets
  # ===========================================================================

  describe "canvas/2" do
    test "returns correct node shape with defaults" do
      node = Iced.canvas("cv1")
      assert node == %{id: "cv1", type: "canvas", props: %{}, children: []}
    end

    test "passes shapes and dimension props through" do
      shapes = [%{type: "circle", x: 10, y: 20, r: 5}]
      node = Iced.canvas("cv1", %{shapes: shapes, width: 400, height: 300, background: "white"})

      assert node.type == "canvas"
      assert node.props["shapes"] == shapes
      assert node.props["width"] == 400
      assert node.props["height"] == 300
      assert node.props["background"] == "white"
      assert node.children == []
    end
  end

  describe "table/2" do
    test "returns correct node shape with defaults" do
      node = Iced.table("tbl1")
      assert node == %{id: "tbl1", type: "table", props: %{}, children: []}
    end

    test "passes columns, rows, header, and sortable props through" do
      cols = [%{key: "name", label: "Name", width: 200}]
      rows = [%{name: "Alice"}, %{name: "Bob"}]
      node = Iced.table("tbl1", %{columns: cols, rows: rows, header: true, sortable: false})

      assert node.type == "table"
      assert node.props["columns"] == cols
      assert node.props["rows"] == rows
      assert node.props["header"] == true
      assert node.props["sortable"] == false
      assert node.children == []
    end
  end

  # ===========================================================================
  # Canvas & table edge cases
  # ===========================================================================

  describe "canvas edge cases" do
    test "canvas with empty shapes list" do
      node = Iced.canvas("cv1", %{shapes: [], width: 400, height: 300})
      assert node.props["shapes"] == []
      assert node.props["width"] == 400
    end

    test "canvas with multiple shape types" do
      shapes = [
        %{type: "rect", x: 0, y: 0, w: 50, h: 50},
        %{type: "circle", cx: 25, cy: 25, r: 10},
        %{type: "line", x1: 0, y1: 0, x2: 100, y2: 100}
      ]

      node = Iced.canvas("cv2", %{shapes: shapes})
      assert length(node.props["shapes"]) == 3
    end

    test "canvas with no props has empty props map" do
      node = Iced.canvas("cv3")
      assert node.props == %{}
    end
  end

  describe "table edge cases" do
    test "table with empty rows" do
      cols = [%{key: "id", label: "ID", width: 100}]
      node = Iced.table("tbl2", %{columns: cols, rows: []})
      assert node.props["columns"] == cols
      assert node.props["rows"] == []
    end

    test "table with empty columns" do
      node = Iced.table("tbl3", %{columns: [], rows: [%{x: 1}]})
      assert node.props["columns"] == []
      assert node.props["rows"] == [%{x: 1}]
    end

    test "table with both empty columns and rows" do
      node = Iced.table("tbl4", %{columns: [], rows: []})
      assert node.props["columns"] == []
      assert node.props["rows"] == []
    end

    test "table with many rows" do
      rows = for i <- 1..100, do: %{id: i, name: "item_#{i}"}
      node = Iced.table("tbl5", %{rows: rows})
      assert length(node.props["rows"]) == 100
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
      for builder <- [
            &Iced.column/1,
            &Iced.row/1,
            &Iced.container/1,
            &Iced.scrollable/1,
            &Iced.stack/1
          ] do
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

    test "encode/1 passes custom theme maps through unchanged" do
      custom = %{"name" => "Mine", "primary" => "#ff0000", "background" => "#000000"}
      assert Theme.encode(custom) == custom
    end

    test "custom/2 builds a map with name and provided options" do
      result = Theme.custom("Tokyo Remix", primary: "#7aa2f7", danger: "#f7768e")
      assert result == %{"name" => "Tokyo Remix", "primary" => "#7aa2f7", "danger" => "#f7768e"}
    end

    test "custom/2 omits nil options" do
      result = Theme.custom("Minimal")
      assert result == %{"name" => "Minimal"}
    end

    test "custom/2 includes base theme as string" do
      result = Theme.custom("Nord+", base: :nord, primary: "#88c0d0")
      assert result == %{"name" => "Nord+", "base" => "nord", "primary" => "#88c0d0"}
    end

    test "custom/2 accepts string base" do
      result = Theme.custom("Foo", base: "dracula", text: "#ffffff")
      assert result == %{"name" => "Foo", "base" => "dracula", "text" => "#ffffff"}
    end

    test "custom/2 supports all palette fields" do
      result =
        Theme.custom("Full",
          base: :dark,
          background: "#111111",
          text: "#eeeeee",
          primary: "#0000ff",
          success: "#00ff00",
          danger: "#ff0000"
        )

      assert result == %{
               "name" => "Full",
               "base" => "dark",
               "background" => "#111111",
               "text" => "#eeeeee",
               "primary" => "#0000ff",
               "success" => "#00ff00",
               "danger" => "#ff0000"
             }
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

    test "encodes all weight variants" do
      weights = [
        :thin,
        :extra_light,
        :light,
        :normal,
        :medium,
        :semi_bold,
        :bold,
        :extra_bold,
        :black
      ]

      expected = [
        "Thin",
        "ExtraLight",
        "Light",
        "Normal",
        "Medium",
        "SemiBold",
        "Bold",
        "ExtraBold",
        "Black"
      ]

      for {weight, exp} <- Enum.zip(weights, expected) do
        result = Font.encode(%{family: "Test", weight: weight})

        assert result["weight"] == exp,
               "expected weight #{inspect(weight)} to encode as #{inspect(exp)}, got #{inspect(result["weight"])}"
      end
    end

    test "encodes all style variants" do
      for {style, expected} <- [{:normal, "Normal"}, {:italic, "Italic"}, {:oblique, "Oblique"}] do
        result = Font.encode(%{family: "Test", style: style})
        assert result["style"] == expected
      end
    end

    test "encodes font with only family (no weight or style)" do
      result = Font.encode(%{family: "Roboto"})
      assert result == %{"family" => "Roboto"}
      refute Map.has_key?(result, "weight")
      refute Map.has_key?(result, "style")
    end

    test "encodes font with weight only (no style)" do
      result = Font.encode(%{family: "Roboto", weight: :bold})
      assert result == %{"family" => "Roboto", "weight" => "Bold"}
      refute Map.has_key?(result, "style")
    end

    test "encodes font with style only (no weight)" do
      result = Font.encode(%{family: "Roboto", style: :italic})
      assert result == %{"family" => "Roboto", "style" => "Italic"}
      refute Map.has_key?(result, "weight")
    end
  end

  # ===========================================================================
  # Padding edge cases
  # ===========================================================================

  describe "Padding edge cases" do
    test "encodes zero padding" do
      assert Padding.encode(0) == %{"top" => 0, "right" => 0, "bottom" => 0, "left" => 0}
    end

    test "encodes float padding" do
      result = Padding.encode(4.5)
      assert result == %{"top" => 4.5, "right" => 4.5, "bottom" => 4.5, "left" => 4.5}
    end

    test "encodes asymmetric tuple with zero" do
      assert Padding.encode({0, 16}) == %{"top" => 0, "right" => 16, "bottom" => 0, "left" => 16}
    end
  end

  # ===========================================================================
  # Length edge cases
  # ===========================================================================

  describe "Length edge cases" do
    test "encodes zero as a fixed number" do
      assert Length.encode(0) == 0
    end

    test "rejects negative number with ArgumentError" do
      assert_raise ArgumentError, ~r/non-negative/, fn -> Length.encode(-1) end
      assert_raise ArgumentError, ~r/non-negative/, fn -> Length.encode(-0.5) end
    end

    test "fill_portion rejects non-positive" do
      assert_raise FunctionClauseError, fn -> Length.encode({:fill_portion, 0}) end
      assert_raise FunctionClauseError, fn -> Length.encode({:fill_portion, -1}) end
    end

    test "fill_portion rejects float" do
      assert_raise FunctionClauseError, fn -> Length.encode({:fill_portion, 1.5}) end
    end
  end
end
