defmodule Toddy.Widget.GridTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.Grid

  describe "new/2" do
    test "creates a grid with the given id and nil defaults" do
      g = Grid.new("g1")
      assert g.id == "g1"
      assert g.columns == nil
      assert g.spacing == nil
      assert g.width == nil
      assert g.height == nil
      assert g.children == []
    end

    test "accepts keyword options" do
      g = Grid.new("g1", columns: 3, spacing: 10)
      assert g.columns == 3
      assert g.spacing == 10
    end
  end

  describe "builder functions" do
    test "columns/2 sets the columns field" do
      g = Grid.new("g1") |> Grid.columns(4)
      assert g.columns == 4
    end

    test "spacing/2 sets the spacing field" do
      g = Grid.new("g1") |> Grid.spacing(8)
      assert g.spacing == 8
    end

    test "width/2 sets the width field" do
      g = Grid.new("g1") |> Grid.width(600)
      assert g.width == 600
    end

    test "height/2 sets the height field" do
      g = Grid.new("g1") |> Grid.height(400)
      assert g.height == 400
    end
  end

  describe "push/2 and extend/2" do
    test "push/2 appends a single child" do
      child = %{id: "c1", type: "text", props: %{}, children: []}
      g = Grid.new("g1") |> Grid.push(child)
      assert length(g.children) == 1
      assert hd(g.children) == child
    end

    test "extend/2 appends multiple children" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      c3 = %{id: "c3", type: "text", props: %{}, children: []}
      g = Grid.new("g1") |> Grid.extend([c1, c2, c3])
      assert length(g.children) == 3
    end

    test "push/2 preserves existing children order" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      g = Grid.new("g1") |> Grid.push(c1) |> Grid.push(c2)
      # Internal list is reversed; build restores order
      node = Grid.build(g)
      assert Enum.at(node.children, 0) == c1
      assert Enum.at(node.children, 1) == c2
    end
  end

  describe "build/1" do
    test "returns a ui_node map with correct type and id" do
      node = Grid.new("g1") |> Grid.build()
      assert node.type == "grid"
      assert node.id == "g1"
      assert node.children == []
    end

    test "includes non-nil props" do
      node = Grid.new("g1", columns: 2, spacing: 5, width: 300) |> Grid.build()
      assert node.props["columns"] == 2
      assert node.props["spacing"] == 5
      assert node.props["width"] == 300
    end

    test "omits nil props" do
      node = Grid.new("g1") |> Grid.build()
      refute Map.has_key?(node.props, "columns")
      refute Map.has_key?(node.props, "spacing")
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "height")
    end

    test "converts children through the widget protocol" do
      child = %{id: "c1", type: "text", props: %{"content" => "hi"}, children: []}
      node = Grid.new("g1") |> Grid.push(child) |> Grid.build()
      assert length(node.children) == 1
    end
  end

  describe "with_options/2" do
    test "routes all options correctly" do
      g =
        Grid.new("g1")
        |> Grid.with_options(columns: 5, spacing: 12, width: 800, height: 600)

      assert g.columns == 5
      assert g.spacing == 12
      assert g.width == 800
      assert g.height == 600
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:bogus/, fn ->
        Grid.new("g1", bogus: true)
      end
    end
  end
end
