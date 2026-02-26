defmodule JulepUITestHelper do
  @moduledoc false
  import Julep.UI

  def simple_column do
    column do
      text("hello")
      text("world")
    end
  end

  def column_with_for do
    items = ["a", "b", "c"]

    column do
      for item <- items do
        text(item)
      end
    end
  end

  def column_with_if(show?) do
    column do
      text("always")
      if show? do
        text("sometimes")
      end
    end
  end

  def nested do
    window "main", title: "Test" do
      column padding: 16 do
        text("hello")
        row do
          button("btn1", "One")
          button("btn2", "Two")
        end
      end
    end
  end
end

defmodule Julep.UITest do
  use ExUnit.Case, async: true

  import Julep.UI

  # ---------------------------------------------------------------------------
  # button/2,3
  # ---------------------------------------------------------------------------

  describe "button/2" do
    test "produces correct node shape" do
      node = button("save", "Save")
      assert node.id == "save"
      assert node.type == "button"
      assert node.props["label"] == "Save"
      assert node.children == []
    end

    test "props contains label as string key" do
      node = button("b", "Label")
      assert Map.has_key?(node.props, "label")
      refute Map.has_key?(node.props, :label)
    end
  end

  describe "button/3 with opts" do
    test "extra opts become string-keyed props" do
      node = button("save", "Save", style: :primary, disabled: true)
      assert node.props["style"] == :primary
      assert node.props["disabled"] == true
    end

    test "reserved keys are not included in props" do
      node = button("b", "B", id: "override", children: [], do: nil)
      refute Map.has_key?(node.props, "id")
      refute Map.has_key?(node.props, "children")
      refute Map.has_key?(node.props, "do")
    end

    test "label is still present alongside extra props" do
      node = button("b", "Click", size: 14)
      assert node.props["label"] == "Click"
      assert node.props["size"] == 14
    end
  end

  # ---------------------------------------------------------------------------
  # text_input/2,3
  # ---------------------------------------------------------------------------

  describe "text_input/2" do
    test "produces correct node shape" do
      node = text_input("name", "Alice")
      assert node.id == "name"
      assert node.type == "text_input"
      assert node.props["value"] == "Alice"
      assert node.children == []
    end
  end

  describe "text_input/3 with opts" do
    test "extra opts become string-keyed props" do
      node = text_input("name", "Alice", placeholder: "Enter name")
      assert node.props["placeholder"] == "Enter name"
      assert node.props["value"] == "Alice"
    end
  end

  # ---------------------------------------------------------------------------
  # checkbox/2,3
  # ---------------------------------------------------------------------------

  describe "checkbox/2" do
    test "produces correct node shape with checked: true" do
      node = checkbox("agree", true)
      assert node.id == "agree"
      assert node.type == "checkbox"
      assert node.props["checked"] == true
      assert node.children == []
    end

    test "produces correct node shape with checked: false" do
      node = checkbox("agree", false)
      assert node.props["checked"] == false
    end
  end

  describe "checkbox/3 with opts" do
    test "extra opts become string-keyed props" do
      node = checkbox("agree", true, label: "I agree")
      assert node.props["label"] == "I agree"
      assert node.props["checked"] == true
    end
  end

  # ---------------------------------------------------------------------------
  # text/1,2 macro
  # ---------------------------------------------------------------------------

  describe "text/1" do
    test "produces a text node with content prop" do
      node = text("hello")
      assert node.type == "text"
      assert node.props["content"] == "hello"
      assert node.children == []
    end

    test "auto-generates an id containing the module name" do
      node = text("hello")
      assert String.starts_with?(node.id, "auto:")
      assert String.contains?(node.id, "Julep.UITest")
    end

    test "auto-generated id is a string" do
      node = text("hello")
      assert is_binary(node.id)
    end
  end

  describe "text/2 with opts" do
    test "explicit id overrides auto-generated id" do
      node = text("hello", id: "my-label")
      assert node.id == "my-label"
    end

    test "extra opts become string-keyed props" do
      node = text("hello", size: 18, color: "red")
      assert node.props["size"] == 18
      assert node.props["color"] == "red"
    end

    test "content prop is always present alongside extra props" do
      node = text("world", size: 12)
      assert node.props["content"] == "world"
    end
  end

  # ---------------------------------------------------------------------------
  # column/0,1 macro
  # ---------------------------------------------------------------------------

  describe "column/0" do
    test "produces a column node" do
      node = column()
      assert node.type == "column"
      assert node.children == []
    end

    test "auto-generates a string id" do
      node = column()
      assert is_binary(node.id)
      assert String.starts_with?(node.id, "auto:")
    end

    test "props is an empty map when no opts" do
      node = column()
      assert node.props == %{}
    end
  end

  describe "column/1 with opts" do
    test "opts become string-keyed props" do
      node = column(padding: 8, spacing: 4)
      assert node.props["padding"] == 8
      assert node.props["spacing"] == 4
    end

    test "children opt is not included in props" do
      child = button("b", "B")
      node = column(children: [child])
      refute Map.has_key?(node.props, "children")
      assert node.children == [child]
    end
  end

  describe "column do...end" do
    test "collects children from do block" do
      node = JulepUITestHelper.simple_column()
      assert node.type == "column"
      assert length(node.children) == 2
      [first, second] = node.children
      assert first.props["content"] == "hello"
      assert second.props["content"] == "world"
    end
  end

  describe "column opts do...end" do
    test "has both props and children" do
      node =
        column padding: 16, spacing: 8 do
          button("b", "Go")
        end

      assert node.props["padding"] == 16
      assert node.props["spacing"] == 8
      assert length(node.children) == 1
      assert hd(node.children).id == "b"
    end
  end

  # ---------------------------------------------------------------------------
  # row do...end
  # ---------------------------------------------------------------------------

  describe "row/0" do
    test "produces a row node with no children" do
      node = row()
      assert node.type == "row"
      assert node.children == []
    end
  end

  describe "row do...end" do
    test "collects children from do block" do
      node =
        row do
          button("yes", "Yes")
          button("no", "No")
        end

      assert node.type == "row"
      assert length(node.children) == 2
      ids = Enum.map(node.children, & &1.id)
      assert ids == ["yes", "no"]
    end
  end

  describe "row opts do...end" do
    test "has both props and children" do
      node =
        row spacing: 4 do
          button("ok", "OK")
        end

      assert node.props["spacing"] == 4
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # window macro
  # ---------------------------------------------------------------------------

  describe "window/1" do
    test "produces a window node with given id" do
      node = window("main")
      assert node.id == "main"
      assert node.type == "window"
      assert node.children == []
      assert node.props == %{}
    end
  end

  describe "window/2 with opts" do
    test "opts become string-keyed props" do
      node = window("app", title: "My App")
      assert node.id == "app"
      assert node.props["title"] == "My App"
    end
  end

  describe "window id do...end" do
    test "collects children" do
      node =
        window "main" do
          button("b", "Go")
        end

      assert node.id == "main"
      assert node.type == "window"
      assert length(node.children) == 1
      assert hd(node.children).id == "b"
    end
  end

  describe "window id, opts do...end" do
    test "has both props and children" do
      node =
        window "app", title: "Test" do
          button("b", "Go")
        end

      assert node.id == "app"
      assert node.props["title"] == "Test"
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # container macro
  # ---------------------------------------------------------------------------

  describe "container/1" do
    test "produces a container node with given id" do
      node = container("hero")
      assert node.id == "hero"
      assert node.type == "container"
      assert node.children == []
    end
  end

  describe "container id do...end" do
    test "collects children" do
      node =
        container "hero" do
          text("Welcome")
        end

      assert node.id == "hero"
      assert length(node.children) == 1
      assert hd(node.children).props["content"] == "Welcome"
    end
  end

  describe "container id, opts do...end" do
    test "has both props and children" do
      node =
        container "hero", padding: 16 do
          text("Hello")
        end

      assert node.props["padding"] == 16
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # scrollable macro
  # ---------------------------------------------------------------------------

  describe "scrollable/1" do
    test "produces a scrollable node" do
      node = scrollable("feed")
      assert node.id == "feed"
      assert node.type == "scrollable"
      assert node.children == []
    end
  end

  describe "scrollable id do...end" do
    test "collects children" do
      node =
        scrollable "feed" do
          text("Item 1")
          text("Item 2")
        end

      assert node.id == "feed"
      assert length(node.children) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # stack macro
  # ---------------------------------------------------------------------------

  describe "stack/0" do
    test "produces a stack node" do
      node = stack()
      assert node.type == "stack"
      assert node.children == []
    end
  end

  describe "stack do...end" do
    test "collects children" do
      node =
        stack do
          container("bg")
          container("overlay")
        end

      assert node.type == "stack"
      assert length(node.children) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # space macro
  # ---------------------------------------------------------------------------

  describe "space/0" do
    test "produces a space node with no children" do
      node = space()
      assert node.type == "space"
      assert node.children == []
    end

    test "auto-generates an id" do
      node = space()
      assert is_binary(node.id)
      assert String.starts_with?(node.id, "auto:")
    end
  end

  describe "space/1 with opts" do
    test "opts become props" do
      node = space(width: :fill)
      assert node.props["width"] == :fill
    end
  end

  # ---------------------------------------------------------------------------
  # rule macro
  # ---------------------------------------------------------------------------

  describe "rule/0" do
    test "produces a rule node with no children" do
      node = rule()
      assert node.type == "rule"
      assert node.children == []
    end

    test "auto-generates an id" do
      node = rule()
      assert is_binary(node.id)
      assert String.starts_with?(node.id, "auto:")
    end
  end

  describe "rule/1 with opts" do
    test "explicit id is used when given" do
      node = rule(id: "divider")
      assert node.id == "divider"
    end
  end

  # ---------------------------------------------------------------------------
  # do block with for comprehension
  # ---------------------------------------------------------------------------

  describe "for comprehension inside do block" do
    test "flattens list children produced by for" do
      node = JulepUITestHelper.column_with_for()
      assert node.type == "column"
      assert length(node.children) == 3
      contents = Enum.map(node.children, & &1.props["content"])
      assert contents == ["a", "b", "c"]
    end
  end

  # ---------------------------------------------------------------------------
  # do block with if/nil filtering
  # ---------------------------------------------------------------------------

  describe "if/nil filtering inside do block" do
    test "nil children are filtered out (show? = false)" do
      node = JulepUITestHelper.column_with_if(false)
      assert node.type == "column"
      assert length(node.children) == 1
      assert hd(node.children).props["content"] == "always"
    end

    test "non-nil children are included (show? = true)" do
      node = JulepUITestHelper.column_with_if(true)
      assert length(node.children) == 2
      contents = Enum.map(node.children, & &1.props["content"])
      assert "always" in contents
      assert "sometimes" in contents
    end
  end

  # ---------------------------------------------------------------------------
  # Nested do blocks
  # ---------------------------------------------------------------------------

  describe "nested do blocks" do
    test "produces correct tree shape" do
      node = JulepUITestHelper.nested()

      assert node.id == "main"
      assert node.type == "window"
      assert node.props["title"] == "Test"

      assert length(node.children) == 1
      col = hd(node.children)
      assert col.type == "column"
      assert col.props["padding"] == 16

      # column has text + row
      assert length(col.children) == 2
      [txt, row_node] = col.children
      assert txt.type == "text"
      assert txt.props["content"] == "hello"

      assert row_node.type == "row"
      assert length(row_node.children) == 2
      [btn1, btn2] = row_node.children
      assert btn1.id == "btn1"
      assert btn2.id == "btn2"
    end
  end

  # ---------------------------------------------------------------------------
  # find/2 delegates to Tree.find
  # ---------------------------------------------------------------------------

  describe "find/2" do
    test "finds a node by id in the tree" do
      tree =
        window "app" do
          button("save", "Save")
        end

      result = Julep.UI.find(tree, "save")
      assert result != nil
      assert result.id == "save"
      assert result.type == "button"
    end

    test "returns nil when id is not in the tree" do
      tree = window("app")
      assert Julep.UI.find(tree, "ghost") == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Counter example view produces expected tree shape
  # ---------------------------------------------------------------------------

  describe "Counter example view shape" do
    test "root node is a window" do
      tree = Julep.Examples.Counter.view(%{count: 0})
      assert tree.type == "window"
      assert tree.id == "main"
    end

    test "contains increment and decrement buttons" do
      tree = Julep.Examples.Counter.view(%{count: 0})
      inc = Julep.UI.find(tree, "increment")
      dec = Julep.UI.find(tree, "decrement")
      assert inc != nil
      assert inc.type == "button"
      assert dec != nil
      assert dec.type == "button"
    end

    test "contains a text node with the current count" do
      tree = Julep.Examples.Counter.view(%{count: 0})

      text_nodes = Julep.Tree.find_all(tree, fn node -> node.type == "text" end)
      count_node = Enum.find(text_nodes, fn n -> n.props["content"] == "Count: 0" end)
      assert count_node != nil
    end
  end
end
