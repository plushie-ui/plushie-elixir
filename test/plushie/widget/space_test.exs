defmodule Plushie.Widget.SpaceTest do
  use ExUnit.Case, async: true

  alias Plushie.Widget.Space

  describe "new/1" do
    test "creates space with id" do
      space = Space.new("s1")
      assert %Space{} = space
      assert space.id == "s1"
    end

    test "all optional fields default to nil" do
      space = Space.new("s1")
      assert space.width == nil
      assert space.height == nil
    end

    test "accepts keyword opts" do
      space = Space.new("s1", width: :fill, height: 20)
      assert space.width == :fill
      assert space.height == 20
    end
  end

  describe "width/2" do
    test "sets the width field" do
      space = Space.new("s") |> Space.width(:fill)
      assert space.width == :fill
    end
  end

  describe "height/2" do
    test "sets the height field" do
      space = Space.new("s") |> Space.height(50)
      assert space.height == 50
    end
  end

  describe "build/1" do
    test "returns a map with correct type and id" do
      node = Space.new("s1") |> Space.build()
      assert node.type == "space"
      assert node.id == "s1"
      assert node.children == []
    end

    test "includes non-nil props" do
      node = Space.new("s1") |> Space.width(:fill) |> Space.height(30) |> Space.build()
      assert node.props[:width] == :fill
      assert node.props[:height] == 30
    end

    test "omits nil props" do
      node = Space.new("s1") |> Space.build()
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "height")
    end

    test "props map is empty when no options set" do
      node = Space.new("s1") |> Space.build()
      assert node.props == %{}
    end
  end

  describe "with_options/2" do
    test "routes all supported options" do
      space = Space.new("s", width: 100, height: 200)
      assert space.width == 100
      assert space.height == 200
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:padding/, fn ->
        Space.new("s", padding: 10)
      end
    end
  end
end
