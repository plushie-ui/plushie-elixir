defmodule Toddy.Widget.ColumnTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.Column

  describe "new/2" do
    test "creates a column with the given id and empty defaults" do
      col = Column.new("col1")
      assert col.id == "col1"
      assert col.spacing == nil
      assert col.padding == nil
      assert col.width == nil
      assert col.height == nil
      assert col.max_width == nil
      assert col.align_x == nil
      assert col.clip == nil
      assert col.wrap == nil
      assert col.children == []
    end

    test "accepts keyword options" do
      col = Column.new("col1", spacing: 10, padding: 5)
      assert col.spacing == 10
      assert col.padding == 5
    end
  end

  describe "builder functions" do
    test "spacing/2 sets the spacing field" do
      col = Column.new("col1") |> Column.spacing(8)
      assert col.spacing == 8
    end

    test "padding/2 sets the padding field" do
      col = Column.new("col1") |> Column.padding(16)
      assert col.padding == 16
    end

    test "width/2 sets the width field" do
      col = Column.new("col1") |> Column.width(:fill)
      assert col.width == :fill
    end

    test "height/2 sets the height field" do
      col = Column.new("col1") |> Column.height(200)
      assert col.height == 200
    end

    test "max_width/2 sets the max_width field" do
      col = Column.new("col1") |> Column.max_width(600)
      assert col.max_width == 600
    end

    test "align_x/2 sets the align_x field" do
      col = Column.new("col1") |> Column.align_x(:center)
      assert col.align_x == :center
    end

    test "clip/2 sets the clip field" do
      col = Column.new("col1") |> Column.clip(true)
      assert col.clip == true
    end

    test "wrap/2 sets the wrap field" do
      col = Column.new("col1") |> Column.wrap(true)
      assert col.wrap == true
    end
  end

  describe "push/2 and extend/2" do
    test "push/2 appends a single child" do
      child = %{id: "child1", type: "text", props: %{}, children: []}
      col = Column.new("col1") |> Column.push(child)
      assert length(col.children) == 1
      assert hd(col.children) == child
    end

    test "extend/2 appends multiple children" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      col = Column.new("col1") |> Column.extend([c1, c2])
      assert length(col.children) == 2
    end

    test "push/2 preserves existing children" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      col = Column.new("col1") |> Column.push(c1) |> Column.push(c2)
      assert length(col.children) == 2
    end
  end

  describe "build/1" do
    test "returns a ui_node map with correct type and id" do
      node = Column.new("col1") |> Column.build()
      assert node.type == "column"
      assert node.id == "col1"
      assert node.children == []
    end

    test "includes non-nil props" do
      node = Column.new("col1", spacing: 10, clip: true) |> Column.build()
      assert node.props[:spacing] == 10
      assert node.props[:clip] == true
    end

    test "omits nil props" do
      node = Column.new("col1") |> Column.build()
      refute Map.has_key?(node.props, "spacing")
      refute Map.has_key?(node.props, "padding")
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "align_x")
      refute Map.has_key?(node.props, "clip")
      refute Map.has_key?(node.props, "wrap")
    end

    test "preserves false values in props" do
      node = Column.new("col1") |> Column.clip(false) |> Column.build()
      assert node.props[:clip] == false
    end
  end

  describe "with_options/2" do
    test "routes all options correctly" do
      col =
        Column.new("col1")
        |> Column.with_options(
          spacing: 5,
          padding: 10,
          width: :fill,
          height: 300,
          max_width: 800,
          align_x: :right,
          clip: true,
          wrap: true
        )

      assert col.spacing == 5
      assert col.padding == 10
      assert col.width == :fill
      assert col.height == 300
      assert col.max_width == 800
      assert col.align_x == :right
      assert col.clip == true
      assert col.wrap == true
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:bogus/, fn ->
        Column.new("col1", bogus: true)
      end
    end
  end
end
