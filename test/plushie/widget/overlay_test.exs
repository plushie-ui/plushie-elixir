defmodule Plushie.Widget.OverlayTest do
  use ExUnit.Case, async: true

  alias Plushie.Widget.Overlay

  describe "new/2" do
    test "creates overlay with id" do
      overlay = Overlay.new("ol1")
      assert overlay.id == "ol1"
      assert overlay.children == []
      assert overlay.position == nil
      assert overlay.gap == nil
    end

    test "accepts keyword options" do
      overlay = Overlay.new("ol1", position: :above, gap: 8)
      assert overlay.position == :above
      assert overlay.gap == 8
    end
  end

  describe "position/2" do
    test "sets the position field" do
      overlay = Overlay.new("ol1") |> Overlay.position(:right)
      assert overlay.position == :right
    end
  end

  describe "gap/2" do
    test "sets the gap field" do
      overlay = Overlay.new("ol1") |> Overlay.gap(12)
      assert overlay.gap == 12
    end
  end

  describe "offset_x/2" do
    test "sets the offset_x field" do
      overlay = Overlay.new("ol1") |> Overlay.offset_x(5.0)
      assert overlay.offset_x == 5.0
    end
  end

  describe "offset_y/2" do
    test "sets the offset_y field" do
      overlay = Overlay.new("ol1") |> Overlay.offset_y(-3.0)
      assert overlay.offset_y == -3.0
    end
  end

  describe "width/2" do
    test "sets the width field" do
      overlay = Overlay.new("ol1") |> Overlay.width(:fill)
      assert overlay.width == :fill
    end
  end

  describe "push/2" do
    test "appends a child" do
      overlay =
        Overlay.new("ol1")
        |> Overlay.push(%{id: "anchor", type: "text", props: %{}, children: []})

      assert length(overlay.children) == 1
    end
  end

  describe "extend/2" do
    test "appends multiple children" do
      anchor = %{id: "anchor", type: "text", props: %{}, children: []}
      content = %{id: "content", type: "container", props: %{}, children: []}

      overlay =
        Overlay.new("ol1")
        |> Overlay.extend([anchor, content])

      assert length(overlay.children) == 2
    end
  end

  describe "with_options/2" do
    test "applies all options" do
      overlay = Overlay.new("ol1") |> Overlay.with_options(position: :left, gap: 4, offset_x: 2)
      assert overlay.position == :left
      assert overlay.gap == 4
      assert overlay.offset_x == 2
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, fn ->
        Overlay.new("ol1") |> Overlay.with_options(bogus: true)
      end
    end
  end

  describe "build/1" do
    test "produces a ui_node map with type overlay" do
      node =
        Overlay.new("ol1", position: :below, gap: 8)
        |> Overlay.push(%{id: "a", type: "text", props: %{}, children: []})
        |> Overlay.push(%{id: "b", type: "container", props: %{}, children: []})
        |> Overlay.build()

      assert node.type == "overlay"
      assert node.id == "ol1"
      assert node.props[:position] == :below
      assert node.props[:gap] == 8
      assert length(node.children) == 2
    end

    test "omits nil props" do
      node =
        Overlay.new("ol1")
        |> Overlay.push(%{id: "a", type: "text", props: %{}, children: []})
        |> Overlay.push(%{id: "b", type: "text", props: %{}, children: []})
        |> Overlay.build()

      refute Map.has_key?(node.props, "position")
      refute Map.has_key?(node.props, "gap")
      refute Map.has_key?(node.props, "offset_x")
      refute Map.has_key?(node.props, "offset_y")
      refute Map.has_key?(node.props, "width")
    end

    test "includes offset props when set" do
      node =
        Overlay.new("ol1", offset_x: 10, offset_y: -5)
        |> Overlay.push(%{id: "a", type: "text", props: %{}, children: []})
        |> Overlay.push(%{id: "b", type: "text", props: %{}, children: []})
        |> Overlay.build()

      assert node.props[:offset_x] == 10
      assert node.props[:offset_y] == -5
    end

    test "includes width when set" do
      node =
        Overlay.new("ol1", width: :fill)
        |> Overlay.push(%{id: "a", type: "text", props: %{}, children: []})
        |> Overlay.push(%{id: "b", type: "text", props: %{}, children: []})
        |> Overlay.build()

      assert node.props[:width] == :fill
    end

    test "raises with fewer than 2 children" do
      assert_raise ArgumentError, ~r/requires exactly 2 children, got 0/, fn ->
        Overlay.new("ol1") |> Overlay.build()
      end

      assert_raise ArgumentError, ~r/requires exactly 2 children, got 1/, fn ->
        Overlay.new("ol1")
        |> Overlay.push(%{id: "a", type: "text", props: %{}, children: []})
        |> Overlay.build()
      end
    end

    test "raises with more than 2 children" do
      assert_raise ArgumentError, ~r/requires exactly 2 children, got 3/, fn ->
        Overlay.new("ol1")
        |> Overlay.push(%{id: "a", type: "text", props: %{}, children: []})
        |> Overlay.push(%{id: "b", type: "text", props: %{}, children: []})
        |> Overlay.push(%{id: "c", type: "text", props: %{}, children: []})
        |> Overlay.build()
      end
    end
  end

  describe "Widget protocol" do
    test "to_node produces same result as build" do
      overlay =
        Overlay.new("ol1", position: :above, gap: 4)
        |> Overlay.push(%{id: "a", type: "text", props: %{}, children: []})
        |> Overlay.push(%{id: "b", type: "text", props: %{}, children: []})

      assert Plushie.Widget.to_node(overlay) == Overlay.build(overlay)
    end
  end
end
