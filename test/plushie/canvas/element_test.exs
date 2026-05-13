# ---------------------------------------------------------------------------
# Test element modules
# ---------------------------------------------------------------------------

defmodule Plushie.CanvasElementTest.TestRect do
  use Plushie.Canvas.Element

  element :test_rect do
    field :x, :float
    field :y, :float
    field :w, :float
    field :h, :float
    field :fill, :string
    field :opacity, :float
    positional [:x, :y, :w, :h]
  end
end

defmodule Plushie.CanvasElementTest.TestCircle do
  use Plushie.Canvas.Element

  element :test_circle do
    field :cx, :float
    field :cy, :float
    field :r, :float
    field :fill, :string
    field :stroke, :any
    positional [:cx, :cy, :r]
  end
end

defmodule Plushie.CanvasElementTest.TestGroup do
  use Plushie.Canvas.Element

  element :test_group, container: true do
    field :opacity, :float
    field :clip, :any
  end
end

defmodule Plushie.CanvasElementTest.TestLabel do
  use Plushie.Canvas.Element

  element :test_label do
    field :text, :string
    field :size, :float, default: 14.0
  end
end

defmodule Plushie.CanvasElementTest.TestWired do
  use Plushie.Canvas.Element

  element :test_wired do
    field :value, :float
    field :display_name, :string, wire_name: :name
  end
end

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

defmodule Plushie.CanvasElementTest do
  use ExUnit.Case, async: true

  alias Plushie.CanvasElementTest.{TestCircle, TestGroup, TestLabel, TestRect, TestWired}

  describe "struct and types" do
    test "element produces a struct with id and declared fields" do
      label = TestLabel.new("lbl1")
      assert %TestLabel{id: "lbl1"} = label
      assert label.text == nil
    end

    test "positional element produces a struct with positional fields" do
      rect = TestRect.new("r1", 10.0, 20.0, 100.0, 50.0)
      assert %TestRect{id: "r1"} = rect
      assert rect.x == 10.0
      assert rect.fill == nil
    end

    test "struct has default values" do
      label = TestLabel.new("lbl")
      assert label.size == 14.0
      assert label.text == nil
    end

    test "container element has children field defaulting to empty list" do
      group = TestGroup.new("g1")
      assert group.children == []
    end
  end

  describe "new/N constructor" do
    test "keyword options set fields" do
      label = TestLabel.new("lbl", text: "hello", size: 24.0)
      assert label.text == "hello"
      assert label.size == 24.0
    end

    test "positional arguments set fields" do
      rect = TestRect.new("r1", 10.0, 20.0, 100.0, 50.0)
      assert rect.x == 10.0
      assert rect.y == 20.0
      assert rect.w == 100.0
      assert rect.h == 50.0
    end

    test "positional arguments with keyword options" do
      rect = TestRect.new("r1", 10.0, 20.0, 100.0, 50.0, fill: "#ff0000")
      assert rect.x == 10.0
      assert rect.fill == "#ff0000"
    end

    test "container new accepts children via :do option" do
      child = TestLabel.new("child")
      group = TestGroup.new("g1", do: [child])
      assert length(group.children) == 1
    end

    test "rejects unknown options" do
      assert_raise ArgumentError, ~r/unknown option/, fn ->
        TestLabel.new("lbl", bogus: true)
      end
    end
  end

  describe "auto-ID constructors" do
    test "keyword-only new creates element with nil id" do
      label = TestLabel.new(text: "hello", size: 24.0)
      assert label.id == nil
      assert label.text == "hello"
      assert label.size == 24.0
    end

    test "keyword-only new with empty opts" do
      label = TestLabel.new([])
      assert label.id == nil
      assert label.text == nil
    end

    test "positional args without id" do
      rect = TestRect.new(10.0, 20.0, 100.0, 50.0)
      assert rect.id == nil
      assert rect.x == 10.0
      assert rect.y == 20.0
      assert rect.w == 100.0
      assert rect.h == 50.0
    end

    test "positional args without id with keyword options" do
      rect = TestRect.new(10.0, 20.0, 100.0, 50.0, fill: "#ff0000")
      assert rect.id == nil
      assert rect.x == 10.0
      assert rect.fill == "#ff0000"
    end

    test "container auto-ID accepts children via :do option" do
      child = TestLabel.new("child")
      group = TestGroup.new(do: [child])
      assert group.id == nil
      assert length(group.children) == 1
    end

    test "container auto-ID with keyword options" do
      group = TestGroup.new(opacity: 0.5)
      assert group.id == nil
      assert group.opacity == 0.5
    end

    test "id-first and auto-ID coexist for keyword-only elements" do
      with_id = TestLabel.new("lbl", text: "a")
      without_id = TestLabel.new(text: "b")
      assert with_id.id == "lbl"
      assert without_id.id == nil
    end

    test "id-first and auto-ID coexist for positional elements" do
      with_id = TestCircle.new("c1", 50.0, 50.0, 25.0)
      without_id = TestCircle.new(50.0, 50.0, 25.0)
      assert with_id.id == "c1"
      assert without_id.id == nil
      assert with_id.cx == without_id.cx
    end

    test "auto-ID element produces correct node with nil id" do
      rect = TestRect.new(10.0, 20.0, 100.0, 50.0, fill: "red")
      node = Plushie.Tree.Node.to_node(rect)
      assert node.id == nil
      assert node.type == "test_rect"
      assert node.props.x == 10.0
      assert node.props.fill == "red"
      refute Map.has_key?(node.props, :id)
    end

    test "explicit empty id raises when converting to a node" do
      rect = %TestRect{id: "", x: 10.0, y: 20.0, w: 100.0, h: 50.0}

      assert_raise ArgumentError, ~r/requires a non-empty id/, fn ->
        Plushie.Tree.Node.to_node(rect)
      end
    end
  end

  describe "setter functions" do
    test "setters update fields" do
      rect =
        TestRect.new("r1", 0.0, 0.0, 0.0, 0.0)
        |> TestRect.x(10.0)
        |> TestRect.y(20.0)
        |> TestRect.fill("blue")

      assert rect.x == 10.0
      assert rect.y == 20.0
      assert rect.fill == "blue"
    end

    test "setters accept nil for optional fields" do
      rect =
        TestRect.new("r1", 0.0, 0.0, 0.0, 0.0, fill: "red")
        |> TestRect.fill(nil)

      assert rect.fill == nil
    end
  end

  describe "container helpers" do
    test "push appends a child" do
      child = TestLabel.new("lbl", text: "hello")

      group =
        TestGroup.new("g1")
        |> TestGroup.push(child)

      assert length(group.children) == 1
    end

    test "extend appends multiple children" do
      children = [TestLabel.new("a"), TestLabel.new("b")]

      group =
        TestGroup.new("g1")
        |> TestGroup.extend(children)

      assert length(group.children) == 2
    end
  end

  describe "Plushie.Tree.Node.to_node/1" do
    test "produces correct node map for leaf element" do
      rect = TestRect.new("r1", 10.0, 20.0, 100.0, 50.0, fill: "red")
      node = Plushie.Tree.Node.to_node(rect)

      assert node.id == "r1"
      assert node.type == "test_rect"
      assert node.children == []
      assert node.props.x == 10.0
      assert node.props.y == 20.0
      assert node.props.w == 100.0
      assert node.props.h == 50.0
      assert node.props.fill == "red"
    end

    test "omits nil props from node" do
      rect = TestRect.new("r1", 10.0, 20.0, 100.0, 50.0)
      node = Plushie.Tree.Node.to_node(rect)

      refute Map.has_key?(node.props, :fill)
      refute Map.has_key?(node.props, :opacity)
    end

    test "encodes atom values as strings" do
      circle = TestCircle.new("c1", 50.0, 50.0, 25.0, fill: :blue)
      node = Plushie.Tree.Node.to_node(circle)

      assert node.props.fill == "blue"
    end

    test "container element includes children as nodes" do
      child = TestLabel.new("lbl", text: "hello")

      group =
        TestGroup.new("g1")
        |> TestGroup.push(child)

      node = Plushie.Tree.Node.to_node(group)

      assert node.type == "test_group"
      assert length(node.children) == 1

      [child_node] = node.children
      assert child_node.id == "lbl"
      assert child_node.type == "test_label"
      assert child_node.props.text == "hello"
    end

    test "uses wire_name for prop keys when specified" do
      wired = TestWired.new("w1", value: 42.0, display_name: "test")
      node = Plushie.Tree.Node.to_node(wired)

      assert node.props.value == 42.0
      assert node.props.name == "test"
      refute Map.has_key?(node.props, :display_name)
    end
  end

  describe "encode/1" do
    test "produces the same shape as old shape modules" do
      rect = TestRect.new("r1", 10.0, 20.0, 100.0, 50.0, fill: "red")
      encoded = TestRect.encode(rect)

      assert encoded.type == "test_rect"
      assert encoded.x == 10.0
      assert encoded.fill == "red"
      assert encoded.id == "r1"
      refute Map.has_key?(encoded, :children)
    end

    test "omits id when nil" do
      rect = %TestRect{x: 10.0, y: 20.0, w: 100.0, h: 50.0}
      encoded = TestRect.encode(rect)

      refute Map.has_key?(encoded, :id)
    end

    test "omits nil values" do
      rect = TestRect.new("r1", 10.0, 20.0, 100.0, 50.0)
      encoded = TestRect.encode(rect)

      refute Map.has_key?(encoded, :fill)
      refute Map.has_key?(encoded, :opacity)
    end
  end

  describe "type_name/0" do
    test "returns the element type as a string" do
      assert TestRect.type_name() == "test_rect"
      assert TestCircle.type_name() == "test_circle"
      assert TestGroup.type_name() == "test_group"
    end
  end

  describe "build/1" do
    test "delegates to Tree.Node.to_node" do
      rect = TestRect.new("r1", 10.0, 20.0, 100.0, 50.0)

      assert TestRect.build(rect) == Plushie.Tree.Node.to_node(rect)
    end
  end

  describe "introspection" do
    test "__prop_names__ returns declared field names" do
      assert TestRect.__prop_names__() == [:x, :y, :w, :h, :fill, :opacity]
    end

    test "__field_keys__ returns option field names" do
      assert :x in TestRect.__field_keys__()
      assert :fill in TestRect.__field_keys__()
    end
  end
end
