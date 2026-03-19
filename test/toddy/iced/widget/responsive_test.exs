defmodule Toddy.Iced.Widget.ResponsiveTest do
  use ExUnit.Case, async: true

  alias Toddy.Iced.Widget.Responsive

  describe "new/2" do
    test "creates a struct with the given id" do
      r = Responsive.new("r1")
      assert %Responsive{id: "r1"} = r
    end

    test "defaults optional fields to nil and children to empty list" do
      r = Responsive.new("r1")
      assert r.width == nil
      assert r.height == nil
      assert r.children == []
    end

    test "accepts keyword options" do
      r = Responsive.new("r1", width: :fill, height: 300)
      assert r.width == :fill
      assert r.height == 300
    end
  end

  describe "width/2" do
    test "sets the width field" do
      r = Responsive.new("r1") |> Responsive.width(:fill)
      assert r.width == :fill
    end
  end

  describe "height/2" do
    test "sets the height field" do
      r = Responsive.new("r1") |> Responsive.height(200)
      assert r.height == 200
    end
  end

  describe "push/2" do
    test "appends a child" do
      child = %{id: "c1", type: "text", props: %{}, children: []}
      r = Responsive.new("r1") |> Responsive.push(child)
      assert r.children == [child]
    end

    test "preserves order across multiple pushes" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      r = Responsive.new("r1") |> Responsive.push(c1) |> Responsive.push(c2)
      assert r.children == [c2, c1]
      node = Responsive.build(r)
      assert node.children == [c1, c2]
    end
  end

  describe "extend/2" do
    test "appends multiple children at once" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      r = Responsive.new("r1") |> Responsive.extend([c1, c2])
      assert r.children == [c2, c1]
      node = Responsive.build(r)
      assert node.children == [c1, c2]
    end
  end

  describe "build/1" do
    test "returns a ui_node map with correct type and id" do
      node = Responsive.new("r1") |> Responsive.build()
      assert node.id == "r1"
      assert node.type == "responsive"
    end

    test "includes non-nil props" do
      node = Responsive.new("r1", width: :fill, height: 100) |> Responsive.build()
      assert node.props["width"] == "fill"
      assert node.props["height"] == 100
    end

    test "omits nil props" do
      node = Responsive.new("r1") |> Responsive.build()
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "height")
    end

    test "converts children to nodes" do
      child = %{id: "c1", type: "text", props: %{}, children: []}
      node = Responsive.new("r1") |> Responsive.push(child) |> Responsive.build()
      assert length(node.children) == 1
      assert hd(node.children).id == "c1"
    end

    test "empty children produces empty list" do
      node = Responsive.new("r1") |> Responsive.build()
      assert node.children == []
    end
  end

  describe "with_options/2" do
    test "routes all known options" do
      r = Responsive.new("r1", width: :fill, height: 400)
      assert r.width == :fill
      assert r.height == 400
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:min_width/, fn ->
        Responsive.new("r1", min_width: 100)
      end
    end
  end
end
