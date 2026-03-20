defmodule Toddy.Widget.MarkdownTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.Markdown

  describe "new/3" do
    test "creates a struct with id and content" do
      md = Markdown.new("md1", "# Hello")
      assert %Markdown{id: "md1", content: "# Hello"} = md
    end

    test "defaults optional fields to nil" do
      md = Markdown.new("md1", "text")
      assert md.width == nil
      assert md.text_size == nil
      assert md.h1_size == nil
      assert md.h2_size == nil
      assert md.h3_size == nil
      assert md.code_size == nil
      assert md.spacing == nil
    end

    test "accepts keyword options" do
      md = Markdown.new("md1", "text", text_size: 14, spacing: 8)
      assert md.text_size == 14
      assert md.spacing == 8
    end
  end

  describe "builder functions" do
    test "width/2 sets the width" do
      md = Markdown.new("md1", "x") |> Markdown.width(:fill)
      assert md.width == :fill
    end

    test "text_size/2 sets the base text size" do
      md = Markdown.new("md1", "x") |> Markdown.text_size(16)
      assert md.text_size == 16
    end

    test "h1_size/2 sets heading 1 size" do
      md = Markdown.new("md1", "x") |> Markdown.h1_size(32)
      assert md.h1_size == 32
    end

    test "h2_size/2 sets heading 2 size" do
      md = Markdown.new("md1", "x") |> Markdown.h2_size(24)
      assert md.h2_size == 24
    end

    test "h3_size/2 sets heading 3 size" do
      md = Markdown.new("md1", "x") |> Markdown.h3_size(20)
      assert md.h3_size == 20
    end

    test "code_size/2 sets code block text size" do
      md = Markdown.new("md1", "x") |> Markdown.code_size(13)
      assert md.code_size == 13
    end

    test "spacing/2 sets spacing between elements" do
      md = Markdown.new("md1", "x") |> Markdown.spacing(10)
      assert md.spacing == 10
    end
  end

  describe "build/1" do
    test "returns a ui_node map with correct type and id" do
      node = Markdown.new("md1", "# Title") |> Markdown.build()
      assert node.id == "md1"
      assert node.type == "markdown"
      assert node.children == []
    end

    test "includes content in props" do
      node = Markdown.new("md1", "# Title") |> Markdown.build()
      assert node.props[:content] == "# Title"
    end

    test "includes non-nil props" do
      node =
        Markdown.new("md1", "text", text_size: 14, h1_size: 28, spacing: 6)
        |> Markdown.build()

      assert node.props[:text_size] == 14
      assert node.props[:h1_size] == 28
      assert node.props[:spacing] == 6
    end

    test "omits nil props" do
      node = Markdown.new("md1", "text") |> Markdown.build()
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "text_size")
      refute Map.has_key?(node.props, "h1_size")
      refute Map.has_key?(node.props, "h2_size")
      refute Map.has_key?(node.props, "h3_size")
      refute Map.has_key?(node.props, "code_size")
      refute Map.has_key?(node.props, "spacing")
    end
  end

  describe "with_options/2" do
    test "routes all known options" do
      md =
        Markdown.new("md1", "x",
          width: 400,
          text_size: 14,
          h1_size: 32,
          h2_size: 24,
          h3_size: 20,
          code_size: 13,
          spacing: 8
        )

      assert md.width == 400
      assert md.text_size == 14
      assert md.h1_size == 32
      assert md.h2_size == 24
      assert md.h3_size == 20
      assert md.code_size == 13
      assert md.spacing == 8
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:nope/, fn ->
        Markdown.new("md1", "x", nope: true)
      end
    end
  end
end
