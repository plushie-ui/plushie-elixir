defmodule Toddy.Widget.KeyedColumnTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.KeyedColumn

  describe "new/2" do
    test "creates a keyed column with the given id and nil defaults" do
      kc = KeyedColumn.new("kc1")
      assert kc.id == "kc1"
      assert kc.spacing == nil
      assert kc.padding == nil
      assert kc.width == nil
      assert kc.height == nil
      assert kc.max_width == nil
      assert kc.children == []
    end

    test "accepts keyword options" do
      kc = KeyedColumn.new("kc1", spacing: 8, width: :fill)
      assert kc.spacing == 8
      assert kc.width == :fill
    end
  end

  describe "builder functions" do
    test "spacing/2 sets the spacing field" do
      kc = KeyedColumn.new("kc1") |> KeyedColumn.spacing(12)
      assert kc.spacing == 12
    end

    test "padding/2 sets the padding field" do
      kc = KeyedColumn.new("kc1") |> KeyedColumn.padding(16)
      assert kc.padding == 16
    end

    test "width/2 sets the width field" do
      kc = KeyedColumn.new("kc1") |> KeyedColumn.width(:fill)
      assert kc.width == :fill
    end

    test "height/2 sets the height field" do
      kc = KeyedColumn.new("kc1") |> KeyedColumn.height(500)
      assert kc.height == 500
    end

    test "max_width/2 sets the max_width field" do
      kc = KeyedColumn.new("kc1") |> KeyedColumn.max_width(900)
      assert kc.max_width == 900
    end
  end

  describe "push/2 and extend/2" do
    test "push/2 appends a single child" do
      child = %{id: "item1", type: "text", props: %{}, children: []}
      kc = KeyedColumn.new("kc1") |> KeyedColumn.push(child)
      assert length(kc.children) == 1
      assert hd(kc.children) == child
    end

    test "extend/2 appends multiple children" do
      c1 = %{id: "item1", type: "text", props: %{}, children: []}
      c2 = %{id: "item2", type: "text", props: %{}, children: []}
      kc = KeyedColumn.new("kc1") |> KeyedColumn.extend([c1, c2])
      assert length(kc.children) == 2
    end

    test "push/2 preserves existing children order" do
      c1 = %{id: "item1", type: "text", props: %{}, children: []}
      c2 = %{id: "item2", type: "text", props: %{}, children: []}
      kc = KeyedColumn.new("kc1") |> KeyedColumn.push(c1) |> KeyedColumn.push(c2)
      # Internal list is reversed; build restores order
      node = KeyedColumn.build(kc)
      assert Enum.at(node.children, 0) == c1
      assert Enum.at(node.children, 1) == c2
    end
  end

  describe "build/1" do
    test "returns a ui_node map with correct type and id" do
      node = KeyedColumn.new("kc1") |> KeyedColumn.build()
      assert node.type == "keyed_column"
      assert node.id == "kc1"
      assert node.children == []
    end

    test "includes non-nil props" do
      node =
        KeyedColumn.new("kc1", spacing: 5, padding: 10, max_width: 600)
        |> KeyedColumn.build()

      assert node.props["spacing"] == 5
      assert node.props["padding"] == 10
      assert node.props["max_width"] == 600
    end

    test "omits nil props" do
      node = KeyedColumn.new("kc1") |> KeyedColumn.build()
      refute Map.has_key?(node.props, "spacing")
      refute Map.has_key?(node.props, "padding")
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "height")
      refute Map.has_key?(node.props, "max_width")
    end

    test "converts children through the widget protocol" do
      child = %{id: "item1", type: "text", props: %{"content" => "hello"}, children: []}
      node = KeyedColumn.new("kc1") |> KeyedColumn.push(child) |> KeyedColumn.build()
      assert length(node.children) == 1
    end
  end

  describe "with_options/2" do
    test "routes all options correctly" do
      kc =
        KeyedColumn.new("kc1")
        |> KeyedColumn.with_options(
          spacing: 4,
          padding: 8,
          width: :fill,
          height: 300,
          max_width: 1000
        )

      assert kc.spacing == 4
      assert kc.padding == 8
      assert kc.width == :fill
      assert kc.height == 300
      assert kc.max_width == 1000
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:bogus/, fn ->
        KeyedColumn.new("kc1", bogus: true)
      end
    end
  end
end
