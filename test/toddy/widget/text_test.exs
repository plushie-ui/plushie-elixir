defmodule Toddy.Widget.TextTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.Text

  describe "new/2" do
    test "creates text with content and id" do
      txt = Text.new("t1", "Hello")
      assert %Text{} = txt
      assert txt.id == "t1"
      assert txt.content == "Hello"
    end

    test "all optional fields default to nil" do
      txt = Text.new("t1", "Hi")
      assert txt.size == nil
      assert txt.color == nil
      assert txt.font == nil
      assert txt.width == nil
      assert txt.height == nil
      assert txt.line_height == nil
      assert txt.align_x == nil
      assert txt.align_y == nil
      assert txt.wrapping == nil
      assert txt.shaping == nil
      assert txt.style == nil
    end

    test "accepts keyword opts" do
      txt = Text.new("t1", "Hi", size: 24, style: :primary)
      assert txt.size == 24
      assert txt.style == :primary
    end
  end

  describe "size/2" do
    test "sets the size field" do
      txt = Text.new("t", "X") |> Text.size(18)
      assert txt.size == 18
    end
  end

  describe "color/2" do
    test "sets the color field via Color.cast" do
      txt = Text.new("t", "X") |> Text.color(:red)
      # Color.cast normalizes named atoms to hex strings
      assert is_binary(txt.color)
    end

    test "accepts hex string" do
      txt = Text.new("t", "X") |> Text.color("#ff0000")
      assert txt.color == "#ff0000"
    end
  end

  describe "font/2" do
    test "sets the font field" do
      txt = Text.new("t", "X") |> Text.font("Monospace")
      assert txt.font == "Monospace"
    end
  end

  describe "width/2" do
    test "sets the width field" do
      txt = Text.new("t", "X") |> Text.width(:fill)
      assert txt.width == :fill
    end
  end

  describe "height/2" do
    test "sets the height field" do
      txt = Text.new("t", "X") |> Text.height(100)
      assert txt.height == 100
    end
  end

  describe "line_height/2" do
    test "sets the line_height field" do
      txt = Text.new("t", "X") |> Text.line_height(1.5)
      assert txt.line_height == 1.5
    end
  end

  describe "align_x/2" do
    test "sets the align_x field" do
      txt = Text.new("t", "X") |> Text.align_x(:center)
      assert txt.align_x == :center
    end
  end

  describe "align_y/2" do
    test "sets the align_y field" do
      txt = Text.new("t", "X") |> Text.align_y(:bottom)
      assert txt.align_y == :bottom
    end
  end

  describe "wrapping/2" do
    test "sets the wrapping field" do
      txt = Text.new("t", "X") |> Text.wrapping(:word)
      assert txt.wrapping == :word
    end
  end

  describe "shaping/2" do
    test "sets the shaping field" do
      txt = Text.new("t", "X") |> Text.shaping(:advanced)
      assert txt.shaping == :advanced
    end
  end

  describe "style/2" do
    test "sets the style field" do
      txt = Text.new("t", "X") |> Text.style(:danger)
      assert txt.style == :danger
    end
  end

  describe "build/1" do
    test "returns a map with correct type and id" do
      node = Text.new("t1", "Hello") |> Text.build()
      assert node.type == "text"
      assert node.id == "t1"
      assert node.children == []
    end

    test "includes content in props" do
      node = Text.new("t1", "Hello world") |> Text.build()
      assert node.props[:content] == "Hello world"
    end

    test "includes non-nil props" do
      node =
        Text.new("t1", "Hi")
        |> Text.size(20)
        |> Text.wrapping(:word)
        |> Text.align_x(:center)
        |> Text.build()

      assert node.props[:size] == 20
      assert node.props[:wrapping] == "word"
      assert node.props[:align_x] == "center"
    end

    test "shaping encodes as text_shaping in props" do
      node = Text.new("t1", "Hi") |> Text.shaping(:advanced) |> Text.build()
      assert node.props[:text_shaping] == "advanced"
      refute Map.has_key?(node.props, "shaping")
    end

    test "omits nil props" do
      node = Text.new("t1", "Hi") |> Text.build()
      refute Map.has_key?(node.props, "size")
      refute Map.has_key?(node.props, "color")
      refute Map.has_key?(node.props, "font")
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "height")
      refute Map.has_key?(node.props, "line_height")
      refute Map.has_key?(node.props, "align_x")
      refute Map.has_key?(node.props, "align_y")
      refute Map.has_key?(node.props, "wrapping")
      refute Map.has_key?(node.props, "text_shaping")
      refute Map.has_key?(node.props, "style")
    end
  end

  describe "with_options/2" do
    test "routes all supported options" do
      txt =
        Text.new("t", "X", size: 14, width: :fill, height: 30, align_x: :left, style: :secondary)

      assert txt.size == 14
      assert txt.width == :fill
      assert txt.height == 30
      assert txt.align_x == :left
      assert txt.style == :secondary
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:nope/, fn ->
        Text.new("t", "X", nope: true)
      end
    end
  end
end
