defmodule Toddy.Widget.FloatTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.Float

  describe "new/2" do
    test "creates a float with the given id and nil defaults" do
      fw = Float.new("f1")
      assert fw.id == "f1"
      assert fw.translate_x == nil
      assert fw.translate_y == nil
      assert fw.scale == nil
      assert fw.children == []
    end

    test "accepts keyword options" do
      fw = Float.new("f1", translate_x: 10, scale: 1.5)
      assert fw.translate_x == 10
      assert fw.scale == 1.5
    end
  end

  describe "builder functions" do
    test "translate_x/2 sets the translate_x field" do
      fw = Float.new("f1") |> Float.translate_x(50)
      assert fw.translate_x == 50
    end

    test "translate_y/2 sets the translate_y field" do
      fw = Float.new("f1") |> Float.translate_y(-30)
      assert fw.translate_y == -30
    end

    test "scale/2 sets the scale field" do
      fw = Float.new("f1") |> Float.scale(2.0)
      assert fw.scale == 2.0
    end
  end

  describe "push/2 and extend/2" do
    test "push/2 appends a single child" do
      child = %{id: "c1", type: "text", props: %{}, children: []}
      fw = Float.new("f1") |> Float.push(child)
      assert length(fw.children) == 1
      assert hd(fw.children) == child
    end

    test "extend/2 appends multiple children" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      fw = Float.new("f1") |> Float.extend([c1, c2])
      assert length(fw.children) == 2
    end

    test "push/2 preserves existing children" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      fw = Float.new("f1") |> Float.push(c1) |> Float.push(c2)
      assert length(fw.children) == 2
      # Internal list is reversed; build restores order
      node = Float.build(fw)
      assert Enum.at(node.children, 0) == c1
      assert Enum.at(node.children, 1) == c2
    end
  end

  describe "build/1" do
    test "returns a ui_node map with correct type and id" do
      node = Float.new("f1") |> Float.build()
      assert node.type == "float"
      assert node.id == "f1"
      assert node.children == []
    end

    test "includes non-nil props" do
      node = Float.new("f1", translate_x: 10, translate_y: 20, scale: 0.5) |> Float.build()
      assert node.props["translate_x"] == 10
      assert node.props["translate_y"] == 20
      assert node.props["scale"] == 0.5
    end

    test "omits nil props" do
      node = Float.new("f1") |> Float.build()
      refute Map.has_key?(node.props, "translate_x")
      refute Map.has_key?(node.props, "translate_y")
      refute Map.has_key?(node.props, "scale")
    end
  end

  describe "with_options/2" do
    test "routes all options correctly" do
      fw =
        Float.new("f1")
        |> Float.with_options(translate_x: 100, translate_y: -50, scale: 3.0)

      assert fw.translate_x == 100
      assert fw.translate_y == -50
      assert fw.scale == 3.0
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:bogus/, fn ->
        Float.new("f1", bogus: true)
      end
    end
  end
end
