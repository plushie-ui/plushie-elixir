defmodule PlushieUITestHelper do
  @moduledoc false
  import Plushie.UI

  def simple_column do
    column do
      text("hello")
      text("world")
    end
  end

  def column_with_for do
    items = ["a", "b", "c"]

    column do
      for item <- items do
        text(item)
      end
    end
  end

  def column_with_if(show?) do
    column do
      text("always")

      if show? do
        text("sometimes")
      end
    end
  end

  def nested do
    window "main", title: "Test" do
      column padding: 16 do
        text("hello")

        row do
          button("btn1", "One")
          button("btn2", "Two")
        end
      end
    end
  end
end

defmodule PlushieUICanvasTestHelper do
  @moduledoc false
  import Plushie.UI

  def canvas_do_block do
    canvas "chart" do
      layer "grid" do
        rect(0, 0, 400, 300, fill: "#eee")
      end

      layer "data" do
        rect(10, 10, 50, 200, fill: "#3498db")
      end
    end
  end

  def canvas_opts_do_block do
    canvas "chart", width: 400, height: 300 do
      layer "main" do
        circle(50, 50, 25, fill: "#f00")
      end
    end
  end

  def canvas_with_for(bars) do
    canvas "chart", width: 400, height: 300 do
      layer "bars" do
        for bar <- bars do
          rect(bar.x, bar.y, bar.w, bar.h, fill: bar.color)
        end
      end
    end
  end

  def canvas_empty_do_block do
    canvas "empty" do
    end
  end
end

defmodule PlushieUIBlockFormHelper do
  @moduledoc false
  import Plushie.UI

  def button_block_form do
    button "save", "Save" do
      style(:primary)
      padding(%{top: 10, bottom: 10, left: 20, right: 20})
    end
  end

  def button_keyword_form do
    button("save", "Save", style: :primary)
  end

  def text_input_block_form do
    text_input "email", "test@example.com" do
      placeholder("you@example.com")
      width(:fill)
    end
  end

  def checkbox_block_form do
    checkbox "agree", true do
      label("I agree")
    end
  end

  def slider_block_form do
    slider "vol", {0, 100}, 50 do
      step(5)
      width(:fill)
    end
  end

  def text_block_form do
    text "greeting", "Hello" do
      size(18)
      color("#333")
    end
  end
end

defmodule PlushieUICanvasShapeHelper do
  @moduledoc false
  import Plushie.UI

  def rect_block_form do
    rect 0, 0, 100, 50 do
      fill("#ff0000")
      opacity(0.5)
    end
  end

  def circle_keyword do
    circle(50, 50, 25, fill: "#00ff00")
  end

  def canvas_with_group_interactive do
    canvas "chart" do
      layer "main" do
        group x: 4, y: 4 do
          interactive "btn" do
            on_click(true)
            hover_style(%{fill: "#ddd"})
          end

          rect(0, 0, 32, 32, fill: "#ccc")
        end
      end
    end
  end

  def canvas_with_text_rewrite do
    canvas "chart" do
      layer "labels" do
        text(10, 20, "Hello", fill: "#000")
      end
    end
  end

  def group_standalone do
    group do
      rect(0, 0, 50, 50, fill: "#f00")
      circle(25, 25, 10, fill: "#0f0")
    end
  end

  def layer_standalone do
    layer "grid" do
      rect(0, 0, 400, 300, fill: "#eee")
    end
  end

  def interactive_keyword_directive do
    group do
      interactive "btn", on_click: true, hover_style: %{fill: "#ddd"}
      rect(0, 0, 100, 40)
    end
  end

  def interactive_pipe_form do
    rect(0, 0, 100, 40, fill: "#3498db")
    |> Plushie.Canvas.Shape.interactive(id: "btn", on_click: true)
  end

  def canvas_with_for do
    canvas "chart" do
      layer "bars" do
        for x <- [10, 20, 30] do
          rect(x, 0, 8, 50, fill: "#3498db")
        end
      end
    end
  end

  def canvas_with_if(show?) do
    canvas "chart" do
      layer "main" do
        rect(0, 0, 100, 100, fill: "#eee")

        if show? do
          circle(50, 50, 20, fill: "#f00")
        end
      end
    end
  end
end

defmodule PlushieUIContainerPropsHelper do
  @moduledoc false
  import Plushie.UI

  def column_inline_props do
    column do
      spacing(8)
      padding(16)
      width(:fill)

      text("Hello")
      button("save", "Save")
    end
  end

  def column_mixed_opts do
    column spacing: 8 do
      padding(16)
      text("Hello")
    end
  end

  def container_with_border_shadow do
    container "styled" do
      background("#fff")

      border do
        width(1)
        color("#ddd")
        rounded(4)
      end

      shadow do
        color("#00000022")
        offset_y(2)
        blur_radius(4)
      end

      text("Styled content")
    end
  end

  def column_with_padding_block do
    column do
      padding do
        top(16)
        bottom(16)
        left(20)
        right(20)
      end

      text("Padded")
    end
  end

  def column_with_a11y_block do
    column do
      a11y do
        role(:list)
        label("Item list")
      end

      text("Item 1")
    end
  end

  def button_with_style_block do
    button "save", "Save" do
      style do
        background("#0066ff")
        text_color("#ffffff")

        border do
          rounded(4)
        end
      end

      padding do
        top(10)
        bottom(10)
        left(20)
        right(20)
      end
    end
  end

  def column_with_conditional_props(compact?) do
    column do
      if compact? do
        spacing(4)
      else
        spacing(16)
      end

      if compact? do
        padding(8)
      else
        padding(24)
      end

      text("Content")
    end
  end

  def interactive_with_nested_blocks do
    group do
      interactive "btn" do
        on_click

        hover_style do
          fill("#ddd")
          opacity(0.8)
        end

        drag_bounds do
          min_x(0)
          max_x(400)
        end

        a11y do
          role(:button)
          label("Click me")
        end
      end

      rect(0, 0, 100, 40, fill: "#3498db")
    end
  end
end

defmodule PlushieUIEdgeCaseHelper do
  @moduledoc false
  import Plushie.UI

  # Empty do-blocks
  def empty_column_block do
    column do
    end
  end

  # Same key in keyword AND block (block wins)
  def mixed_key_override do
    column spacing: 8 do
      spacing(16)
      text("Hello")
    end
  end

  # Boolean bare-name props
  def boolean_bare_prop do
    column do
      clip
      text("Clipped")
    end
  end

  # Props interleaved with children
  def interleaved_props do
    column do
      text("First")
      spacing(8)
      text("Second")
      padding(16)
    end
  end

  # Multi-expression if with props (control flow bug fix)
  def multi_expr_if_props do
    column do
      if true do
        spacing(4)
        padding(8)
      end

      text("Hello")
    end
  end

  # Multi-expression if with children in layer
  def multi_expr_if_children do
    canvas "chart" do
      layer "main" do
        if true do
          rect(0, 0, 50, 50, fill: "#f00")
          rect(50, 50, 50, 50, fill: "#0f0")
        end
      end
    end
  end

  # Window with inline props
  def window_inline_props do
    window "main" do
      title("My App")
      resizable

      column do
        text("Hello")
      end
    end
  end

  # Space with do-block
  def space_block do
    space do
      width(:fill)
      height(20)
    end
  end

  # Rule with do-block
  def rule_block do
    rule do
      width(200)
    end
  end

  # Variable values in block props
  def variable_prop_value(spacing_val) do
    column do
      spacing(spacing_val)
      text("Dynamic")
    end
  end

  # For comprehension in container with multiple shapes per iteration
  # (explicit list wrapping required since for returns the last expression)
  def for_with_shapes_in_layer do
    canvas "chart" do
      layer "data" do
        for i <- [1, 2, 3] do
          [
            rect(i * 40, 0, 30, 100, fill: "#3498db"),
            circle(i * 40 + 15, 50, 10, fill: "#fff")
          ]
        end
      end
    end
  end
end

defmodule Plushie.UITest do
  use ExUnit.Case, async: true

  import Plushie.UI

  # ---------------------------------------------------------------------------
  # button/2,3
  # ---------------------------------------------------------------------------

  describe "button/2" do
    test "produces correct node shape" do
      node = button("save", "Save")
      assert node.id == "save"
      assert node.type == "button"
      assert node.props[:label] == "Save"
      assert node.children == []
    end

    test "props contains label as atom key" do
      node = button("b", "Label")
      assert Map.has_key?(node.props, :label)
      refute Map.has_key?(node.props, "label")
    end
  end

  describe "button/3 with opts" do
    test "extra opts become atom-keyed props" do
      node = button("save", "Save", style: :primary, disabled: true)
      assert node.props[:style] == :primary
      assert node.props[:disabled] == true
    end

    test "reserved keys are not included in props" do
      node = button("b", "B", id: "override", children: [], do: nil)
      refute Map.has_key?(node.props, "id")
      refute Map.has_key?(node.props, "children")
      refute Map.has_key?(node.props, "do")
    end

    test "label is still present alongside extra props" do
      node = button("b", "Click", width: 120)
      assert node.props[:label] == "Click"
      assert node.props[:width] == 120
    end
  end

  # ---------------------------------------------------------------------------
  # text_input/2,3
  # ---------------------------------------------------------------------------

  describe "text_input/2" do
    test "produces correct node shape" do
      node = text_input("name", "Alice")
      assert node.id == "name"
      assert node.type == "text_input"
      assert node.props[:value] == "Alice"
      assert node.children == []
    end
  end

  describe "text_input/3 with opts" do
    test "extra opts become atom-keyed props" do
      node = text_input("name", "Alice", placeholder: "Enter name")
      assert node.props[:placeholder] == "Enter name"
      assert node.props[:value] == "Alice"
    end
  end

  # ---------------------------------------------------------------------------
  # checkbox/2,3
  # ---------------------------------------------------------------------------

  describe "checkbox/2" do
    test "produces correct node shape with checked: true" do
      node = checkbox("agree", true)
      assert node.id == "agree"
      assert node.type == "checkbox"
      assert node.props[:checked] == true
      assert node.children == []
    end

    test "produces correct node shape with checked: false" do
      node = checkbox("agree", false)
      assert node.props[:checked] == false
    end
  end

  describe "checkbox/3 with opts" do
    test "extra opts become atom-keyed props" do
      node = checkbox("agree", true, label: "I agree")
      assert node.props[:label] == "I agree"
      assert node.props[:checked] == true
    end
  end

  # ---------------------------------------------------------------------------
  # text/1,2,3 macro
  # ---------------------------------------------------------------------------

  describe "text/1" do
    test "produces a text node with content prop" do
      node = text("hello")
      assert node.type == "text"
      assert node.props[:content] == "hello"
      assert node.children == []
    end

    test "auto-generates an id containing the module name" do
      node = text("hello")
      assert String.starts_with?(node.id, "auto:")
      assert String.contains?(node.id, "Plushie.UITest")
    end

    test "auto-generated id is a string" do
      node = text("hello")
      assert is_binary(node.id)
    end
  end

  describe "text/2 with explicit id" do
    test "sets explicit id" do
      node = text("my-label", "hello")
      assert node.id == "my-label"
      assert node.props[:content] == "hello"
    end
  end

  describe "text/3 with id and opts" do
    test "extra opts become atom-keyed props" do
      node = text("my-label", "hello", size: 18, color: :red)
      assert node.props[:size] == 18
      assert node.props[:color] == "#ff0000"
    end

    test "content prop is always present alongside extra props" do
      node = text("my-label", "world", size: 12)
      assert node.props[:content] == "world"
    end
  end

  # ---------------------------------------------------------------------------
  # column/0,1 macro
  # ---------------------------------------------------------------------------

  describe "column/0" do
    test "produces a column node" do
      node = column()
      assert node.type == "column"
      assert node.children == []
    end

    test "auto-generates a string id" do
      node = column()
      assert is_binary(node.id)
      assert String.starts_with?(node.id, "auto:")
    end

    test "props is an empty map when no opts" do
      node = column()
      assert node.props == %{}
    end
  end

  describe "column/1 with opts" do
    test "opts become atom-keyed props" do
      node = column(padding: 8, spacing: 4)
      assert node.props[:padding] == 8
      assert node.props[:spacing] == 4
    end

    test "children opt is not included in props" do
      child = button("b", "B")
      node = column(children: [child])
      refute Map.has_key?(node.props, "children")
      assert node.children == [child]
    end
  end

  describe "column do...end" do
    test "collects children from do block" do
      node = PlushieUITestHelper.simple_column()
      assert node.type == "column"
      assert length(node.children) == 2
      [first, second] = node.children
      assert first.props[:content] == "hello"
      assert second.props[:content] == "world"
    end
  end

  describe "column opts do...end" do
    test "has both props and children" do
      node =
        column padding: 16, spacing: 8 do
          button("b", "Go")
        end

      assert node.props[:padding] == 16
      assert node.props[:spacing] == 8
      assert length(node.children) == 1
      assert hd(node.children).id == "b"
    end
  end

  # ---------------------------------------------------------------------------
  # row do...end
  # ---------------------------------------------------------------------------

  describe "row/0" do
    test "produces a row node with no children" do
      node = row()
      assert node.type == "row"
      assert node.children == []
    end
  end

  describe "row do...end" do
    test "collects children from do block" do
      node =
        row do
          button("yes", "Yes")
          button("no", "No")
        end

      assert node.type == "row"
      assert length(node.children) == 2
      ids = Enum.map(node.children, & &1.id)
      assert ids == ["yes", "no"]
    end
  end

  describe "row opts do...end" do
    test "has both props and children" do
      node =
        row spacing: 4 do
          button("ok", "OK")
        end

      assert node.props[:spacing] == 4
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # window macro
  # ---------------------------------------------------------------------------

  describe "window/1" do
    test "produces a window node with given id" do
      node = window("main")
      assert node.id == "main"
      assert node.type == "window"
      assert node.children == []
      assert node.props == %{}
    end
  end

  describe "window/2 with opts" do
    test "opts become atom-keyed props" do
      node = window("app", title: "My App")
      assert node.id == "app"
      assert node.props[:title] == "My App"
    end
  end

  describe "window id do...end" do
    test "collects children" do
      node =
        window "main" do
          button("b", "Go")
        end

      assert node.id == "main"
      assert node.type == "window"
      assert length(node.children) == 1
      assert hd(node.children).id == "b"
    end
  end

  describe "window id, opts do...end" do
    test "has both props and children" do
      node =
        window "app", title: "Test" do
          button("b", "Go")
        end

      assert node.id == "app"
      assert node.props[:title] == "Test"
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # container macro
  # ---------------------------------------------------------------------------

  describe "container/1" do
    test "produces a container node with given id" do
      node = container("hero")
      assert node.id == "hero"
      assert node.type == "container"
      assert node.children == []
    end
  end

  describe "container id do...end" do
    test "collects children" do
      node =
        container "hero" do
          text("Welcome")
        end

      assert node.id == "hero"
      assert length(node.children) == 1
      assert hd(node.children).props[:content] == "Welcome"
    end
  end

  describe "container id, opts do...end" do
    test "has both props and children" do
      node =
        container "hero", padding: 16 do
          text("Hello")
        end

      assert node.props[:padding] == 16
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # scrollable macro
  # ---------------------------------------------------------------------------

  describe "scrollable/1" do
    test "produces a scrollable node" do
      node = scrollable("feed")
      assert node.id == "feed"
      assert node.type == "scrollable"
      assert node.children == []
    end
  end

  describe "scrollable id do...end" do
    test "collects children" do
      node =
        scrollable "feed" do
          text("Item 1")
          text("Item 2")
        end

      assert node.id == "feed"
      assert length(node.children) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # stack macro
  # ---------------------------------------------------------------------------

  describe "stack/0" do
    test "produces a stack node" do
      node = stack()
      assert node.type == "stack"
      assert node.children == []
    end
  end

  describe "stack do...end" do
    test "collects children" do
      node =
        stack do
          container("bg")
          container("overlay")
        end

      assert node.type == "stack"
      assert length(node.children) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # space macro
  # ---------------------------------------------------------------------------

  describe "space/0" do
    test "produces a space node with no children" do
      node = space()
      assert node.type == "space"
      assert node.children == []
    end

    test "auto-generates an id" do
      node = space()
      assert is_binary(node.id)
      assert String.starts_with?(node.id, "auto:")
    end
  end

  describe "space/1 with opts" do
    test "opts become props" do
      node = space(width: :fill)
      assert node.props[:width] == :fill
    end
  end

  # ---------------------------------------------------------------------------
  # rule macro
  # ---------------------------------------------------------------------------

  describe "rule/0" do
    test "produces a rule node with no children" do
      node = rule()
      assert node.type == "rule"
      assert node.children == []
    end

    test "auto-generates an id" do
      node = rule()
      assert is_binary(node.id)
      assert String.starts_with?(node.id, "auto:")
    end
  end

  describe "rule/1 with opts" do
    test "explicit id is used when given" do
      node = rule(id: "divider")
      assert node.id == "divider"
    end
  end

  # ---------------------------------------------------------------------------
  # do block with for comprehension
  # ---------------------------------------------------------------------------

  describe "for comprehension inside do block" do
    test "flattens list children produced by for" do
      node = PlushieUITestHelper.column_with_for()
      assert node.type == "column"
      assert length(node.children) == 3
      contents = Enum.map(node.children, & &1.props[:content])
      assert contents == ["a", "b", "c"]
    end
  end

  # ---------------------------------------------------------------------------
  # do block with if/nil filtering
  # ---------------------------------------------------------------------------

  describe "if/nil filtering inside do block" do
    test "nil children are filtered out (show? = false)" do
      node = PlushieUITestHelper.column_with_if(false)
      assert node.type == "column"
      assert length(node.children) == 1
      assert hd(node.children).props[:content] == "always"
    end

    test "non-nil children are included (show? = true)" do
      node = PlushieUITestHelper.column_with_if(true)
      assert length(node.children) == 2
      contents = Enum.map(node.children, & &1.props[:content])
      assert "always" in contents
      assert "sometimes" in contents
    end
  end

  # ---------------------------------------------------------------------------
  # Nested do blocks
  # ---------------------------------------------------------------------------

  describe "nested do blocks" do
    test "produces correct tree shape" do
      node = PlushieUITestHelper.nested()

      assert node.id == "main"
      assert node.type == "window"
      assert node.props[:title] == "Test"

      assert length(node.children) == 1
      col = hd(node.children)
      assert col.type == "column"
      assert col.props[:padding] == 16

      # column has text + row
      assert length(col.children) == 2
      [txt, row_node] = col.children
      assert txt.type == "text"
      assert txt.props[:content] == "hello"

      assert row_node.type == "row"
      assert length(row_node.children) == 2
      [btn1, btn2] = row_node.children
      assert btn1.id == "btn1"
      assert btn2.id == "btn2"
    end
  end

  # ---------------------------------------------------------------------------
  # find/2 delegates to Tree.find
  # ---------------------------------------------------------------------------

  describe "find/2" do
    test "finds a node by id in the tree" do
      tree =
        window "app" do
          button("save", "Save")
        end

      result = Plushie.UI.find(tree, "save")
      assert result != nil
      assert result.id == "save"
      assert result.type == "button"
    end

    test "returns nil when id is not in the tree" do
      tree = window("app")
      assert Plushie.UI.find(tree, "ghost") == nil
    end
  end

  # ---------------------------------------------------------------------------
  # toggler/2,3
  # ---------------------------------------------------------------------------

  describe "toggler/2" do
    test "produces correct node shape" do
      node = toggler("dark_mode", true)
      assert node.id == "dark_mode"
      assert node.type == "toggler"
      assert node.props[:is_toggled] == true
      assert node.children == []
    end

    test "works with false value" do
      node = toggler("dark_mode", false)
      assert node.props[:is_toggled] == false
    end
  end

  describe "toggler/3 with opts" do
    test "extra opts become atom-keyed props" do
      node = toggler("dark_mode", true, label: "Dark mode", spacing: 8)
      assert node.props[:label] == "Dark mode"
      assert node.props[:spacing] == 8
      assert node.props[:is_toggled] == true
    end
  end

  # ---------------------------------------------------------------------------
  # radio/3,4
  # ---------------------------------------------------------------------------

  describe "radio/3" do
    test "produces correct node shape" do
      node = radio("size_large", "large", "small")
      assert node.id == "size_large"
      assert node.type == "radio"
      assert node.props[:value] == "large"
      assert node.props[:selected] == "small"
      assert node.children == []
    end

    test "selected can be nil" do
      node = radio("size_large", "large", nil)
      assert node.props[:selected] == nil
    end
  end

  describe "radio/4 with opts" do
    test "extra opts become atom-keyed props" do
      node = radio("size_large", "large", "large", label: "Large", spacing: 4)
      assert node.props[:label] == "Large"
      assert node.props[:spacing] == 4
    end
  end

  # ---------------------------------------------------------------------------
  # slider/3,4
  # ---------------------------------------------------------------------------

  describe "slider/3" do
    test "produces correct node shape" do
      node = slider("volume", {0, 100}, 50)
      assert node.id == "volume"
      assert node.type == "slider"
      assert node.props[:range] == {0, 100}
      assert node.props[:value] == 50
      assert node.children == []
    end
  end

  describe "slider/4 with opts" do
    test "extra opts become atom-keyed props" do
      node = slider("volume", {0, 100}, 50, step: 5, width: :fill)
      assert node.props[:step] == 5
      assert node.props[:width] == :fill
      assert node.props[:range] == {0, 100}
    end
  end

  # ---------------------------------------------------------------------------
  # vertical_slider/3,4
  # ---------------------------------------------------------------------------

  describe "vertical_slider/3" do
    test "produces correct node shape" do
      node = vertical_slider("brightness", {0, 255}, 128)
      assert node.id == "brightness"
      assert node.type == "vertical_slider"
      assert node.props[:range] == {0, 255}
      assert node.props[:value] == 128
      assert node.children == []
    end
  end

  describe "vertical_slider/4 with opts" do
    test "extra opts become atom-keyed props" do
      node = vertical_slider("brightness", {0, 255}, 128, step: 1, width: 20)
      assert node.props[:step] == 1
      assert node.props[:width] == 20
    end
  end

  # ---------------------------------------------------------------------------
  # pick_list/3,4
  # ---------------------------------------------------------------------------

  describe "pick_list/3" do
    test "produces correct node shape" do
      node = pick_list("country", ["UK", "US", "DE"], "UK")
      assert node.id == "country"
      assert node.type == "pick_list"
      assert node.props[:options] == ["UK", "US", "DE"]
      assert node.props[:selected] == "UK"
      assert node.children == []
    end

    test "selected can be nil" do
      node = pick_list("country", ["UK", "US"], nil)
      assert node.props[:selected] == nil
    end
  end

  describe "pick_list/4 with opts" do
    test "extra opts become atom-keyed props" do
      node = pick_list("country", ["UK", "US"], "UK", placeholder: "Choose...", width: :fill)
      assert node.props[:placeholder] == "Choose..."
      assert node.props[:width] == :fill
    end
  end

  # ---------------------------------------------------------------------------
  # combo_box/3,4
  # ---------------------------------------------------------------------------

  describe "combo_box/3" do
    test "produces correct node shape" do
      node = combo_box("lang", ["Elixir", "Rust", "Go"], "Elixir")
      assert node.id == "lang"
      assert node.type == "combo_box"
      assert node.props[:options] == ["Elixir", "Rust", "Go"]
      assert node.props[:selected] == "Elixir"
      assert node.children == []
    end
  end

  describe "combo_box/4 with opts" do
    test "extra opts become atom-keyed props" do
      node = combo_box("lang", ["Elixir", "Rust"], "Elixir", placeholder: "Type...", width: 200)
      assert node.props[:placeholder] == "Type..."
      assert node.props[:width] == 200
    end
  end

  # ---------------------------------------------------------------------------
  # text_editor/2,3
  # ---------------------------------------------------------------------------

  describe "text_editor/2" do
    test "produces correct node shape" do
      node = text_editor("notes", "Hello world")
      assert node.id == "notes"
      assert node.type == "text_editor"
      assert node.props[:content] == "Hello world"
      assert node.children == []
    end
  end

  describe "text_editor/3 with opts" do
    test "extra opts become atom-keyed props" do
      node = text_editor("notes", "Hello", width: :fill, height: 200)
      assert node.props[:width] == :fill
      assert node.props[:height] == 200
      assert node.props[:content] == "Hello"
    end
  end

  # ---------------------------------------------------------------------------
  # image/2,3
  # ---------------------------------------------------------------------------

  describe "image/2" do
    test "produces correct node shape" do
      node = image("logo", "/assets/logo.png")
      assert node.id == "logo"
      assert node.type == "image"
      assert node.props[:source] == "/assets/logo.png"
      assert node.children == []
    end
  end

  describe "image/3 with opts" do
    test "extra opts become atom-keyed props" do
      node = image("logo", "/assets/logo.png", width: 200, height: 100, content_fit: :cover)
      assert node.props[:width] == 200
      assert node.props[:height] == 100
      assert node.props[:content_fit] == :cover
    end
  end

  # ---------------------------------------------------------------------------
  # svg/2,3
  # ---------------------------------------------------------------------------

  describe "svg/2" do
    test "produces correct node shape" do
      node = svg("icon", "/assets/icon.svg")
      assert node.id == "icon"
      assert node.type == "svg"
      assert node.props[:source] == "/assets/icon.svg"
      assert node.children == []
    end
  end

  describe "svg/3 with opts" do
    test "extra opts become atom-keyed props" do
      node = svg("icon", "/assets/icon.svg", width: 24, height: 24, content_fit: :contain)
      assert node.props[:width] == 24
      assert node.props[:height] == 24
      assert node.props[:content_fit] == :contain
    end
  end

  # ---------------------------------------------------------------------------
  # markdown/1,2,3 macro
  # ---------------------------------------------------------------------------

  describe "markdown/1" do
    test "produces a markdown node with content prop" do
      node = markdown("# Hello")
      assert node.type == "markdown"
      assert node.props[:content] == "# Hello"
      assert node.children == []
    end

    test "auto-generates an id" do
      node = markdown("# Hello")
      assert is_binary(node.id)
      assert String.starts_with?(node.id, "auto:")
    end
  end

  describe "markdown/2 with explicit id" do
    test "sets explicit id" do
      node = markdown("my-md", "# Hello")
      assert node.id == "my-md"
      assert node.props[:content] == "# Hello"
    end
  end

  describe "markdown/3 with id and opts" do
    test "extra opts become atom-keyed props" do
      node = markdown("my-md", "# Hello", text_size: 14)
      assert node.props[:text_size] == 14
      assert node.props[:content] == "# Hello"
    end
  end

  # ---------------------------------------------------------------------------
  # tooltip macro
  # ---------------------------------------------------------------------------

  describe "tooltip id, tip do...end" do
    test "collects children with tip" do
      node =
        tooltip "tip1", "Help text" do
          button("save", "Save")
        end

      assert node.id == "tip1"
      assert node.type == "tooltip"
      assert node.props[:tip] == "Help text"
      assert length(node.children) == 1
      assert hd(node.children).id == "save"
    end
  end

  describe "tooltip id, tip, opts do...end" do
    test "has tip, options, and children" do
      node =
        tooltip "tip1", "Save your work", position: :top do
          button("save", "Save")
        end

      assert node.props[:tip] == "Save your work"
      assert node.props[:position] == :top
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # canvas/1,2
  # ---------------------------------------------------------------------------

  describe "canvas/1" do
    test "produces a canvas node with given id" do
      node = canvas("drawing")
      assert node.id == "drawing"
      assert node.type == "canvas"
      assert node.props == %{}
      assert node.children == []
    end
  end

  describe "canvas/2 with opts" do
    test "opts become atom-keyed props" do
      shapes = [%{type: "rect", x: 0, y: 0, w: 100, h: 50}]
      node = canvas("drawing", shapes: shapes, width: 800, height: 600, background: "#000")

      assert node.props[:shapes] == shapes
      assert node.props[:width] == 800
      assert node.props[:height] == 600
      assert node.props[:background] == "#000000"
      assert node.children == []
    end
  end

  # ---------------------------------------------------------------------------
  # table/1,2 macro
  # ---------------------------------------------------------------------------

  describe "table/1" do
    test "produces a table node with given id" do
      node = table("users")
      assert node.id == "users"
      assert node.type == "table"
      assert node.children == []
    end
  end

  describe "table/2 with opts" do
    test "columns and rows become atom-keyed props" do
      cols = [%{key: "name", label: "Name", width: 200}]
      rows = [%{name: "Alice"}, %{name: "Bob"}]
      node = table("users", columns: cols, rows: rows)

      assert node.props[:columns] == cols
      assert node.props[:rows] == rows
      assert node.children == []
    end
  end

  describe "table id do...end" do
    test "collects children from do block" do
      node =
        table "users" do
          text("custom footer")
        end

      assert node.id == "users"
      assert node.type == "table"
      assert length(node.children) == 1
      assert hd(node.children).props[:content] == "custom footer"
    end
  end

  describe "table id, opts do...end" do
    test "has both props and children" do
      cols = [%{key: "name", label: "Name", width: 200}]
      rows = [%{name: "Alice"}]

      node =
        table "users", columns: cols, rows: rows do
          text("row template")
        end

      assert node.props[:columns] == cols
      assert node.props[:rows] == rows
      assert length(node.children) == 1
      assert hd(node.children).props[:content] == "row template"
    end
  end

  # ---------------------------------------------------------------------------
  # canvas edge cases
  # ---------------------------------------------------------------------------

  describe "canvas with empty shapes" do
    test "canvas with explicit empty shapes list" do
      node = canvas("cv", shapes: [])
      assert node.type == "canvas"
      assert node.props[:shapes] == []
    end

    test "canvas with no shapes prop at all" do
      node = canvas("cv")
      refute Map.has_key?(node.props, "shapes")
    end

    test "canvas with all shape types" do
      shapes = [
        %{type: "rect", x: 0, y: 0, w: 100, h: 50},
        %{type: "circle", cx: 50, cy: 50, r: 25},
        %{type: "line", x1: 0, y1: 0, x2: 100, y2: 100},
        %{type: "text", x: 10, y: 10, content: "hello"}
      ]

      node = canvas("cv", shapes: shapes, width: 800, height: 600)
      assert length(node.props[:shapes]) == 4
      types = Enum.map(node.props[:shapes], & &1.type)
      assert types == ["rect", "circle", "line", "text"]
    end
  end

  # ---------------------------------------------------------------------------
  # table edge cases
  # ---------------------------------------------------------------------------

  describe "table with empty rows" do
    test "table with columns but empty rows list" do
      cols = [%{key: "name", label: "Name", width: 200}]
      node = table("t", columns: cols, rows: [])
      assert node.props[:columns] == cols
      assert node.props[:rows] == []
    end
  end

  describe "table with empty columns" do
    test "table with rows but empty columns list" do
      rows = [%{name: "Alice"}]
      node = table("t", columns: [], rows: rows)
      assert node.props[:columns] == []
      assert node.props[:rows] == rows
    end
  end

  describe "table with no data props" do
    test "table with no columns or rows at all" do
      node = table("t")
      refute Map.has_key?(node.props, "columns")
      refute Map.has_key?(node.props, "rows")
    end
  end

  # ---------------------------------------------------------------------------
  # canvas do-block form
  # ---------------------------------------------------------------------------

  describe "canvas id do...end" do
    test "collects layers from do block" do
      node = PlushieUICanvasTestHelper.canvas_do_block()
      assert node.id == "chart"
      assert node.type == "canvas"
      assert is_map(node.props[:layers])
      assert Map.has_key?(node.props[:layers], "grid")
      assert Map.has_key?(node.props[:layers], "data")
      assert length(node.props[:layers]["grid"]) == 1
      assert length(node.props[:layers]["data"]) == 1
    end

    test "merges opts with layers from do block" do
      node = PlushieUICanvasTestHelper.canvas_opts_do_block()
      assert node.id == "chart"
      assert node.props[:width] == 400
      assert node.props[:height] == 300
      assert is_map(node.props[:layers])
      assert length(node.props[:layers]["main"]) == 1
    end

    test "layer with for comprehension" do
      bars = [
        %{x: 0, y: 0, w: 30, h: 100, color: "#f00"},
        %{x: 40, y: 0, w: 30, h: 80, color: "#0f0"},
        %{x: 80, y: 0, w: 30, h: 60, color: "#00f"}
      ]

      node = PlushieUICanvasTestHelper.canvas_with_for(bars)
      assert length(node.props[:layers]["bars"]) == 3
    end

    test "empty do block produces empty layers" do
      node = PlushieUICanvasTestHelper.canvas_empty_do_block()
      assert node.id == "empty"
      assert node.type == "canvas"
      assert node.props[:layers] == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # Counter example view produces expected tree shape
  # ---------------------------------------------------------------------------

  describe "Counter example view shape" do
    test "root node is a window" do
      tree = Counter.view(%{count: 0})
      assert tree.type == "window"
      assert tree.id == "main"
    end

    test "contains increment and decrement buttons" do
      tree = Counter.view(%{count: 0})
      inc = Plushie.UI.find(tree, "increment")
      dec = Plushie.UI.find(tree, "decrement")
      assert inc != nil
      assert inc.type == "button"
      assert dec != nil
      assert dec.type == "button"
    end

    test "contains a text node with the current count" do
      tree = Counter.view(%{count: 0})

      text_nodes = Plushie.Tree.find_all(tree, fn node -> node.type == "text" end)
      count_node = Enum.find(text_nodes, fn n -> n.props[:content] == "Count: 0" end)
      assert count_node != nil
    end
  end

  # ---------------------------------------------------------------------------
  # Block-form leaf widgets
  # ---------------------------------------------------------------------------

  describe "block-form leaf widgets" do
    test "button with do-block produces same node as keyword form for shared props" do
      block_node = PlushieUIBlockFormHelper.button_block_form()
      keyword_node = PlushieUIBlockFormHelper.button_keyword_form()
      assert block_node.id == keyword_node.id
      assert block_node.type == keyword_node.type
      assert block_node.props.label == keyword_node.props.label
      assert block_node.props.style == keyword_node.props.style
      # block form also includes padding from the do-block
      assert block_node.props.padding == %{top: 10, bottom: 10, left: 20, right: 20}
    end

    test "text_input with do-block" do
      node = PlushieUIBlockFormHelper.text_input_block_form()
      assert node.id == "email"
      assert node.props.placeholder == "you@example.com"
    end

    test "checkbox with do-block" do
      node = PlushieUIBlockFormHelper.checkbox_block_form()
      assert node.id == "agree"
      assert node.props.label == "I agree"
    end

    test "slider with do-block" do
      node = PlushieUIBlockFormHelper.slider_block_form()
      assert node.id == "vol"
      assert node.props.step == 5
    end

    test "text display macro with do-block" do
      node = PlushieUIBlockFormHelper.text_block_form()
      assert node.id == "greeting"
      assert node.props.size == 18
    end
  end

  # ---------------------------------------------------------------------------
  # Canvas shape macros
  # ---------------------------------------------------------------------------

  describe "canvas shape macros" do
    test "rect with do-block" do
      result = PlushieUICanvasShapeHelper.rect_block_form()
      assert %Plushie.Canvas.Shape.Rect{fill: "#ff0000", opacity: 0.5} = result
    end

    test "circle with keyword opts" do
      result = PlushieUICanvasShapeHelper.circle_keyword()
      assert %Plushie.Canvas.Shape.Circle{fill: "#00ff00"} = result
    end
  end

  # ---------------------------------------------------------------------------
  # Group macro
  # ---------------------------------------------------------------------------

  describe "group macro" do
    test "group with do-block produces Group struct" do
      result = PlushieUICanvasShapeHelper.group_standalone()
      assert %Plushie.Canvas.Shape.Group{} = result
      assert length(result.children) == 2
    end

    test "group with interactive directive" do
      node = PlushieUICanvasShapeHelper.canvas_with_group_interactive()
      assert node.type == "canvas"
      shapes = node.props[:layers]["main"]
      [group] = shapes
      assert %Plushie.Canvas.Shape.Group{} = group
      assert %Plushie.Canvas.Shape.Interactive{id: "btn", on_click: true} = group.interactive
    end
  end

  # ---------------------------------------------------------------------------
  # Layer macro
  # ---------------------------------------------------------------------------

  describe "layer macro" do
    test "layer produces {name, shapes} tuple" do
      {name, shapes} = PlushieUICanvasShapeHelper.layer_standalone()
      assert name == "grid"
      assert [%Plushie.Canvas.Shape.Rect{}] = shapes
    end
  end

  # ---------------------------------------------------------------------------
  # Interactive directive
  # ---------------------------------------------------------------------------

  describe "interactive directive" do
    test "keyword form in group" do
      result = PlushieUICanvasShapeHelper.interactive_keyword_directive()
      assert %Plushie.Canvas.Shape.Group{} = result
      assert result.interactive.id == "btn"
      assert result.interactive.on_click == true
    end

    test "pipe form on shape" do
      result = PlushieUICanvasShapeHelper.interactive_pipe_form()
      assert %Plushie.Canvas.Shape.Rect{} = result
      assert result.interactive.id == "btn"
    end
  end

  # ---------------------------------------------------------------------------
  # Canvas scope text rewriting
  # ---------------------------------------------------------------------------

  describe "canvas_scope text rewriting" do
    test "text/4 inside canvas layer is rewritten to canvas shape" do
      node = PlushieUICanvasShapeHelper.canvas_with_text_rewrite()
      assert node.type == "canvas"
      shapes = node.props[:layers]["labels"]
      assert [%Plushie.Canvas.Shape.CanvasText{x: 10, y: 20, content: "Hello"}] = shapes
    end
  end

  # ---------------------------------------------------------------------------
  # Canvas scope control flow
  # ---------------------------------------------------------------------------

  describe "canvas_scope control flow" do
    test "for inside canvas layer" do
      node = PlushieUICanvasShapeHelper.canvas_with_for()
      shapes = node.props[:layers]["bars"]
      assert length(shapes) == 3
      assert Enum.all?(shapes, &match?(%Plushie.Canvas.Shape.Rect{}, &1))
    end

    test "if inside canvas layer" do
      node = PlushieUICanvasShapeHelper.canvas_with_if(true)
      shapes = node.props[:layers]["main"]
      assert length(shapes) == 2

      node = PlushieUICanvasShapeHelper.canvas_with_if(false)
      shapes = node.props[:layers]["main"]
      assert length(shapes) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # Canvas scope compile errors
  # ---------------------------------------------------------------------------

  describe "canvas_scope compile errors" do
    test "text/1 in canvas raises" do
      assert_raise CompileError, ~r/text\/1 is not valid here/, fn ->
        Code.compile_string("""
        import Plushie.UI
        canvas "x" do
          layer "l" do
            text("Hello")
          end
        end
        """)
      end
    end

    test "button in canvas raises" do
      assert_raise CompileError, ~r/button is not valid here/, fn ->
        Code.compile_string("""
        import Plushie.UI
        canvas "x" do
          layer "l" do
            button("save", "Save")
          end
        end
        """)
      end
    end

    test "rect directly in canvas (not in layer) raises" do
      assert_raise CompileError, ~r/rect is not valid here/, fn ->
        Code.compile_string("""
        import Plushie.UI
        canvas "x" do
          rect(0, 0, 100, 50)
        end
        """)
      end
    end

    test "interactive in layer (not group) raises" do
      assert_raise CompileError, ~r/interactive is not valid here/, fn ->
        Code.compile_string("""
        import Plushie.UI
        canvas "x" do
          layer "l" do
            interactive "btn" do
              on_click true
            end
          end
        end
        """)
      end
    end

    test "layer inside layer raises" do
      assert_raise CompileError, ~r/layer is not valid here/, fn ->
        Code.compile_string("""
        import Plushie.UI
        canvas "x" do
          layer "outer" do
            layer "inner" do
              rect(0, 0, 50, 50)
            end
          end
        end
        """)
      end
    end

    test "interactive do-block without id raises" do
      assert_raise CompileError, ~r/interactive requires an id/, fn ->
        Code.compile_string("""
        import Plushie.UI
        group do
          interactive do
            on_click true
          end
        end
        """)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # text/3 numeric literal guard
  # ---------------------------------------------------------------------------

  describe "text/3 numeric literal guard" do
    test "text with numeric first args outside canvas raises" do
      assert_raise CompileError, ~r/text\/3 is not valid here/, fn ->
        Code.compile_string("""
        import Plushie.UI
        text(10, 20, "Hello")
        """)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Container inline props
  # ---------------------------------------------------------------------------

  describe "container inline props" do
    test "column with inline spacing/padding/width" do
      node = PlushieUIContainerPropsHelper.column_inline_props()
      assert node.type == "column"
      assert node.props.spacing == 8
      assert node.props.padding == 16
      assert node.props.width == :fill
      assert length(node.children) == 2
    end

    test "mixed keyword and inline opts" do
      node = PlushieUIContainerPropsHelper.column_mixed_opts()
      assert node.type == "column"
      assert node.props.spacing == 8
      assert node.props.padding == 16
      assert length(node.children) == 1
    end

    test "conditional inline props" do
      compact = PlushieUIContainerPropsHelper.column_with_conditional_props(true)
      assert compact.props.spacing == 4
      assert compact.props.padding == 8

      spacious = PlushieUIContainerPropsHelper.column_with_conditional_props(false)
      assert spacious.props.spacing == 16
      assert spacious.props.padding == 24
    end
  end

  # ---------------------------------------------------------------------------
  # Nested struct do-blocks
  # ---------------------------------------------------------------------------

  describe "nested struct do-blocks" do
    test "padding with do-block" do
      node = PlushieUIContainerPropsHelper.column_with_padding_block()
      assert node.type == "column"
      padding = node.props.padding
      assert padding.top == 16
      assert padding.bottom == 16
      assert padding.left == 20
      assert padding.right == 20
    end

    test "a11y with do-block" do
      node = PlushieUIContainerPropsHelper.column_with_a11y_block()
      a11y = node.props.a11y
      assert a11y.role == :list
      assert a11y.label == "Item list"
    end

    test "container with border and shadow do-blocks" do
      node = PlushieUIContainerPropsHelper.container_with_border_shadow()
      assert node.props.background == "#ffffff"
      border = node.props.border
      assert border.width == 1
      assert border.color == "#dddddd"
      shadow = node.props.shadow
      assert shadow.color == "#00000022"
      assert shadow.blur_radius == 4
    end

    test "button with nested style do-block" do
      node = PlushieUIContainerPropsHelper.button_with_style_block()
      style = node.props.style
      assert style.background == "#0066ff"
      assert style.text_color == "#ffffff"
      padding = node.props.padding
      assert padding.top == 10
    end

    test "interactive with nested hover_style and drag_bounds do-blocks" do
      result = PlushieUIContainerPropsHelper.interactive_with_nested_blocks()
      assert %Plushie.Canvas.Shape.Group{} = result
      interactive = result.interactive
      assert interactive.id == "btn"
      assert interactive.on_click == true
      assert interactive.hover_style.fill == "#ddd"
      assert interactive.hover_style.opacity == 0.8
      assert interactive.drag_bounds.min_x == 0
      assert interactive.drag_bounds.max_x == 400
      assert interactive.a11y.role == :button
    end
  end

  # ---------------------------------------------------------------------------
  # Container scope compile errors
  # ---------------------------------------------------------------------------

  describe "container_scope compile errors" do
    test "spacing in container (wrong container) raises" do
      assert_raise CompileError, ~r/spacing is not a valid option for container/, fn ->
        Code.compile_string("""
        import Plushie.UI
        container "x" do
          spacing(8)
          text("Hello")
        end
        """)
      end
    end

    test "direction in column (wrong container) raises" do
      assert_raise CompileError, ~r/direction is not a valid option for column/, fn ->
        Code.compile_string("""
        import Plushie.UI
        column do
          direction(:horizontal)
          text("Hello")
        end
        """)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Edge cases: empty blocks
  # ---------------------------------------------------------------------------

  describe "edge cases: empty blocks" do
    test "empty column do-block" do
      node = PlushieUIEdgeCaseHelper.empty_column_block()
      assert node.type == "column"
      assert node.children == []
    end
  end

  # ---------------------------------------------------------------------------
  # Edge cases: prop override
  # ---------------------------------------------------------------------------

  describe "edge cases: prop override" do
    test "block prop overrides keyword prop" do
      node = PlushieUIEdgeCaseHelper.mixed_key_override()
      assert node.props.spacing == 16
    end
  end

  # ---------------------------------------------------------------------------
  # Edge cases: boolean bare props
  # ---------------------------------------------------------------------------

  describe "edge cases: boolean bare props" do
    test "bare name in container sets true" do
      node = PlushieUIEdgeCaseHelper.boolean_bare_prop()
      assert node.props.clip == true
    end
  end

  # ---------------------------------------------------------------------------
  # Edge cases: interleaved props and children
  # ---------------------------------------------------------------------------

  describe "edge cases: interleaved props and children" do
    test "props and children order preserved" do
      node = PlushieUIEdgeCaseHelper.interleaved_props()
      assert node.props.spacing == 8
      assert node.props.padding == 16
      assert length(node.children) == 2
      assert hd(node.children).props.content == "First"
    end
  end

  # ---------------------------------------------------------------------------
  # Edge cases: multi-expression control flow
  # ---------------------------------------------------------------------------

  describe "edge cases: multi-expression control flow" do
    test "multiple props in if body all take effect" do
      node = PlushieUIEdgeCaseHelper.multi_expr_if_props()
      assert node.props.spacing == 4
      assert node.props.padding == 8
    end

    test "multiple children in if body in canvas layer" do
      node = PlushieUIEdgeCaseHelper.multi_expr_if_children()
      shapes = node.props.layers["main"]
      assert length(shapes) == 2
      assert Enum.all?(shapes, &match?(%Plushie.Canvas.Shape.Rect{}, &1))
    end

    test "for with multiple shapes per iteration" do
      node = PlushieUIEdgeCaseHelper.for_with_shapes_in_layer()
      shapes = node.props.layers["data"]
      assert length(shapes) == 6
    end
  end

  # ---------------------------------------------------------------------------
  # Edge cases: window inline props
  # ---------------------------------------------------------------------------

  describe "edge cases: window inline props" do
    test "window with inline title and resizable" do
      node = PlushieUIEdgeCaseHelper.window_inline_props()
      assert node.type == "window"
      assert node.props.title == "My App"
      assert node.props.resizable == true
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # Edge cases: space and rule do-blocks
  # ---------------------------------------------------------------------------

  describe "edge cases: space and rule do-blocks" do
    test "space with do-block options" do
      node = PlushieUIEdgeCaseHelper.space_block()
      assert node.type == "space"
      assert node.props.width == :fill
      assert node.props.height == 20
    end

    test "rule with do-block options" do
      node = PlushieUIEdgeCaseHelper.rule_block()
      assert node.type == "rule"
      assert node.props.width == 200
    end
  end

  # ---------------------------------------------------------------------------
  # Edge cases: variable values
  # ---------------------------------------------------------------------------

  describe "edge cases: variable values" do
    test "variable in block prop" do
      node = PlushieUIEdgeCaseHelper.variable_prop_value(42)
      assert node.props.spacing == 42
    end
  end

  # ---------------------------------------------------------------------------
  # Edge cases: leaf widget compile errors
  # ---------------------------------------------------------------------------

  describe "edge cases: leaf widget compile errors" do
    test "unknown option in button block" do
      assert_raise CompileError, ~r/unknwn is not a valid option for button/, fn ->
        Code.compile_string("""
        import Plushie.UI
        button "save", "Save" do
          unknwn("value")
        end
        """)
      end
    end
  end
end
