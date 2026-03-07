defmodule Julep.Iced.Widget.PinTest do
  use ExUnit.Case, async: true

  alias Julep.Iced.Widget.Pin

  describe "new/2" do
    test "creates a pin with the given id and nil defaults" do
      p = Pin.new("p1")
      assert p.id == "p1"
      assert p.x == nil
      assert p.y == nil
      assert p.width == nil
      assert p.height == nil
      assert p.children == []
    end

    test "accepts keyword options" do
      p = Pin.new("p1", x: 100, y: 200)
      assert p.x == 100
      assert p.y == 200
    end
  end

  describe "builder functions" do
    test "x/2 sets the x field" do
      p = Pin.new("p1") |> Pin.x(50)
      assert p.x == 50
    end

    test "y/2 sets the y field" do
      p = Pin.new("p1") |> Pin.y(75)
      assert p.y == 75
    end

    test "width/2 sets the width field" do
      p = Pin.new("p1") |> Pin.width(:fill)
      assert p.width == :fill
    end

    test "height/2 sets the height field" do
      p = Pin.new("p1") |> Pin.height(300)
      assert p.height == 300
    end
  end

  describe "push/2 and extend/2" do
    test "push/2 appends a single child" do
      child = %{id: "c1", type: "text", props: %{}, children: []}
      p = Pin.new("p1") |> Pin.push(child)
      assert length(p.children) == 1
      assert hd(p.children) == child
    end

    test "extend/2 appends multiple children" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      p = Pin.new("p1") |> Pin.extend([c1, c2])
      assert length(p.children) == 2
    end

    test "push/2 preserves existing children" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      p = Pin.new("p1") |> Pin.push(c1) |> Pin.push(c2)
      assert length(p.children) == 2
      # Internal list is reversed; build restores order
      node = Pin.build(p)
      assert Enum.at(node.children, 0) == c1
      assert Enum.at(node.children, 1) == c2
    end
  end

  describe "build/1" do
    test "returns a ui_node map with correct type and id" do
      node = Pin.new("p1") |> Pin.build()
      assert node.type == "pin"
      assert node.id == "p1"
      assert node.children == []
    end

    test "includes non-nil props" do
      node = Pin.new("p1", x: 10, y: 20, width: :fill, height: 100) |> Pin.build()
      assert node.props["x"] == 10
      assert node.props["y"] == 20
      assert node.props["width"] == "fill"
      assert node.props["height"] == 100
    end

    test "omits nil props" do
      node = Pin.new("p1") |> Pin.build()
      refute Map.has_key?(node.props, "x")
      refute Map.has_key?(node.props, "y")
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "height")
    end
  end

  describe "with_options/2" do
    test "routes all options correctly" do
      p =
        Pin.new("p1")
        |> Pin.with_options(x: 42, y: 84, width: 200, height: 150)

      assert p.x == 42
      assert p.y == 84
      assert p.width == 200
      assert p.height == 150
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:bogus/, fn ->
        Pin.new("p1", bogus: true)
      end
    end
  end
end
