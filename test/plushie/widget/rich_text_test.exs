defmodule Plushie.Widget.RichTextTest do
  use ExUnit.Case, async: true

  alias Plushie.Widget.RichText

  describe "new/2" do
    test "creates a struct with the given id and nil defaults" do
      rt = RichText.new("rt1")
      assert %RichText{id: "rt1"} = rt
      assert rt.spans == nil
      assert rt.width == nil
      assert rt.height == nil
      assert rt.size == nil
      assert rt.font == nil
      assert rt.color == nil
      assert rt.line_height == nil
    end

    test "accepts keyword options" do
      rt = RichText.new("rt1", size: 16, width: :fill)
      assert rt.size == 16
      assert rt.width == :fill
    end
  end

  describe "spans/2" do
    test "sets the spans field" do
      spans = [%{text: "hello", size: 14}, %{text: "world", color: "#ff0000"}]
      rt = RichText.new("rt1") |> RichText.spans(spans)
      assert rt.spans == spans
    end
  end

  describe "width/2" do
    test "sets the width field" do
      rt = RichText.new("rt1") |> RichText.width(:fill)
      assert rt.width == :fill
    end
  end

  describe "height/2" do
    test "sets the height field" do
      rt = RichText.new("rt1") |> RichText.height(200)
      assert rt.height == 200
    end
  end

  describe "size/2" do
    test "sets the default font size" do
      rt = RichText.new("rt1") |> RichText.size(18)
      assert rt.size == 18
    end
  end

  describe "font/2" do
    test "sets the default font" do
      rt = RichText.new("rt1") |> RichText.font("Monospace")
      assert rt.font == "Monospace"
    end
  end

  describe "color/2" do
    test "sets the default color via Color.cast" do
      rt = RichText.new("rt1") |> RichText.color(:red)
      assert is_binary(rt.color)
    end

    test "accepts hex string directly" do
      rt = RichText.new("rt1") |> RichText.color("#abcdef")
      assert rt.color == "#abcdef"
    end
  end

  describe "line_height/2" do
    test "sets the line height" do
      rt = RichText.new("rt1") |> RichText.line_height(1.5)
      assert rt.line_height == 1.5
    end
  end

  describe "build/1" do
    test "returns a ui_node map with correct type and id" do
      node = RichText.new("rt1") |> RichText.build()
      assert node.id == "rt1"
      assert node.type == "rich_text"
      assert node.children == []
    end

    test "includes non-nil props" do
      spans = [%{text: "hi"}]

      node =
        RichText.new("rt1")
        |> RichText.spans(spans)
        |> RichText.size(14)
        |> RichText.width(:fill)
        |> RichText.build()

      assert node.props[:spans] == spans
      assert node.props[:size] == 14
      assert node.props[:width] == :fill
    end

    test "omits nil props" do
      node = RichText.new("rt1") |> RichText.build()
      refute Map.has_key?(node.props, "spans")
      refute Map.has_key?(node.props, "size")
      refute Map.has_key?(node.props, "font")
      refute Map.has_key?(node.props, "color")
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "height")
      refute Map.has_key?(node.props, "line_height")
    end
  end

  describe "with_options/2" do
    test "routes all known options" do
      spans = [%{text: "x"}]

      rt =
        RichText.new("rt1",
          spans: spans,
          width: :fill,
          height: 100,
          size: 12,
          font: "Serif",
          color: "#000000",
          line_height: 1.2
        )

      assert rt.spans == spans
      assert rt.width == :fill
      assert rt.height == 100
      assert rt.size == 12
      assert rt.font == "Serif"
      assert rt.color == "#000000"
      assert rt.line_height == 1.2
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:bogus/, fn ->
        RichText.new("rt1", bogus: true)
      end
    end
  end
end
