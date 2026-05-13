defmodule Plushie.Widget.PaneGridTest do
  use ExUnit.Case, async: true

  alias Plushie.Widget.PaneGrid

  describe "new/2" do
    test "creates a struct with the given id" do
      pg = PaneGrid.new("pg1")
      assert %PaneGrid{id: "pg1"} = pg
    end

    test "defaults optional fields to nil and children to empty list" do
      pg = PaneGrid.new("pg1")
      assert pg.spacing == nil
      assert pg.width == nil
      assert pg.height == nil
      assert pg.min_size == nil
      assert pg.children == []
    end

    test "accepts keyword options" do
      pg = PaneGrid.new("pg1", spacing: 4, width: :fill)
      assert pg.spacing == 4
      assert pg.width == :fill
    end
  end

  describe "spacing/2" do
    test "sets the spacing field" do
      pg = PaneGrid.new("pg1") |> PaneGrid.spacing(8)
      assert pg.spacing == 8
    end
  end

  describe "panes/2" do
    test "coerces atom pane identifiers to strings" do
      pg = PaneGrid.new("pg1") |> PaneGrid.panes([:left, "right"])
      assert pg.panes == ["left", "right"]
    end

    test "accepts nil to unset panes" do
      pg =
        PaneGrid.new("pg1")
        |> PaneGrid.panes([:left])
        |> PaneGrid.panes(nil)

      assert pg.panes == nil
    end

    test "raises on unsupported pane identifiers" do
      assert_raise ArgumentError, ~r/pane identifiers must be strings or atoms/, fn ->
        PaneGrid.new("pg1") |> PaneGrid.panes(["left", 2])
      end
    end
  end

  describe "width/2" do
    test "sets the width field" do
      pg = PaneGrid.new("pg1") |> PaneGrid.width(:fill)
      assert pg.width == :fill
    end
  end

  describe "height/2" do
    test "sets the height field" do
      pg = PaneGrid.new("pg1") |> PaneGrid.height(500)
      assert pg.height == 500
    end
  end

  describe "min_size/2" do
    test "sets the min_size field" do
      pg = PaneGrid.new("pg1") |> PaneGrid.min_size(50)
      assert pg.min_size == 50
    end
  end

  describe "push/2" do
    test "appends a child to children" do
      child = %{id: "c1", type: "text", props: %{}, children: []}
      pg = PaneGrid.new("pg1") |> PaneGrid.push(child)
      assert pg.children == [child]
    end

    test "appends multiple children in order" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      pg = PaneGrid.new("pg1") |> PaneGrid.push(c1) |> PaneGrid.push(c2)
      assert pg.children == [c2, c1]
      node = PaneGrid.build(pg)
      assert node.children == [c1, c2]
    end
  end

  describe "extend/2" do
    test "appends multiple children at once" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      pg = PaneGrid.new("pg1") |> PaneGrid.extend([c1, c2])
      assert pg.children == [c2, c1]
      node = PaneGrid.build(pg)
      assert node.children == [c1, c2]
    end
  end

  describe "build/1" do
    test "returns a ui_node map with correct type and id" do
      node = PaneGrid.new("pg1") |> PaneGrid.build()
      assert node.id == "pg1"
      assert node.type == "pane_grid"
    end

    test "includes non-nil props" do
      node = PaneGrid.new("pg1", spacing: 5, width: :fill) |> PaneGrid.build()
      assert node.props[:spacing] == 5
      assert node.props[:width] == :fill
    end

    test "includes min_size in props when set" do
      node = PaneGrid.new("pg1", min_size: 30) |> PaneGrid.build()
      assert node.props[:min_size] == 30
    end

    test "omits nil props" do
      node = PaneGrid.new("pg1") |> PaneGrid.build()
      refute Map.has_key?(node.props, "spacing")
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "height")
      refute Map.has_key?(node.props, "min_size")
    end

    test "converts children to nodes" do
      child = %{id: "c1", type: "text", props: %{content: "hi"}, children: []}
      node = PaneGrid.new("pg1") |> PaneGrid.push(child) |> PaneGrid.build()
      assert length(node.children) == 1
      assert hd(node.children).id == "c1"
    end
  end

  describe "with_options/2" do
    test "routes all known options" do
      pg =
        PaneGrid.new("pg1",
          panes: [:left, "right"],
          spacing: 3,
          width: :fill,
          height: 400,
          min_size: 25
        )

      assert pg.panes == ["left", "right"]
      assert pg.spacing == 3
      assert pg.width == :fill
      assert pg.height == 400
      assert pg.min_size == 25
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:columns/, fn ->
        PaneGrid.new("pg1", columns: 2)
      end
    end
  end
end
