defmodule Julep.TreeTest do
  use ExUnit.Case, async: true

  alias Julep.Tree

  # ---------------------------------------------------------------------------
  # normalize/1
  # ---------------------------------------------------------------------------

  describe "normalize/1 -- nil and empty inputs" do
    test "normalize(nil) returns empty container" do
      result = Tree.normalize(nil)
      assert result.id == "root"
      assert result.type == "container"
      assert result.props == %{}
      assert result.children == []
    end

    test "normalize([]) returns empty container" do
      result = Tree.normalize([])
      assert result.id == "root"
      assert result.type == "container"
      assert result.props == %{}
      assert result.children == []
    end
  end

  describe "normalize/1 -- single node" do
    test "normalizes and returns a single node map" do
      node = %{id: "btn", type: "button", props: %{label: "Click"}, children: []}
      result = Tree.normalize(node)
      assert result.id == "btn"
      assert result.type == "button"
    end

    test "single-element list normalizes to that node directly (not wrapped)" do
      node = %{id: "x", type: "text", props: %{}, children: []}
      result = Tree.normalize([node])
      assert result.id == "x"
      assert result.type == "text"
    end

    test "ensures node has all required keys" do
      result = Tree.normalize(%{id: "a", type: "text"})
      assert Map.has_key?(result, :id)
      assert Map.has_key?(result, :type)
      assert Map.has_key?(result, :props)
      assert Map.has_key?(result, :children)
    end

    test "missing props defaults to empty map" do
      result = Tree.normalize(%{id: "a", type: "text"})
      assert result.props == %{}
    end

    test "missing children defaults to empty list" do
      result = Tree.normalize(%{id: "a", type: "text"})
      assert result.children == []
    end

    test "missing type defaults to \"container\"" do
      result = Tree.normalize(%{id: "a"})
      assert result.type == "container"
    end

    test "missing id defaults to \"unknown\"" do
      result = Tree.normalize(%{type: "button"})
      assert result.id == "unknown"
    end
  end

  describe "normalize/1 -- list of nodes" do
    test "list of multiple nodes wraps in root container" do
      nodes = [
        %{id: "a", type: "text", props: %{}, children: []},
        %{id: "b", type: "button", props: %{}, children: []}
      ]

      result = Tree.normalize(nodes)
      assert result.id == "root"
      assert result.type == "container"
      assert length(result.children) == 2
    end

    test "children in wrapped container are individually normalized" do
      nodes = [
        %{id: "a", type: "text"},
        %{id: "b", type: "button"}
      ]

      result = Tree.normalize(nodes)
      [child_a, child_b] = result.children
      assert child_a.id == "a"
      assert Map.has_key?(child_a, :props)
      assert Map.has_key?(child_a, :children)
      assert child_b.id == "b"
    end
  end

  describe "normalize/1 -- prop key stringification" do
    test "converts atom keys in props to string keys" do
      node = %{id: "btn", type: "button", props: %{label: "Click", style: :primary}, children: []}
      result = Tree.normalize(node)
      assert Map.has_key?(result.props, "label")
      assert Map.has_key?(result.props, "style")
      refute Map.has_key?(result.props, :label)
    end

    test "string keys in props are preserved as-is" do
      node = %{id: "t", type: "text", props: %{"content" => "hello"}, children: []}
      result = Tree.normalize(node)
      assert result.props["content"] == "hello"
    end

    test "handles mixed atom and string keys in props" do
      node = %{id: "m", type: "text", props: %{:color => "red", "size" => 14}, children: []}
      result = Tree.normalize(node)
      assert result.props["color"] == "red"
      assert result.props["size"] == 14
      refute Map.has_key?(result.props, :color)
    end
  end

  describe "normalize/1 -- recursion into children" do
    test "recurses into children and normalizes them" do
      node = %{
        id: "parent",
        type: "column",
        props: %{},
        children: [
          %{id: "child", type: "text", props: %{content: "hello"}}
        ]
      }

      result = Tree.normalize(node)
      [child] = result.children
      assert child.id == "child"
      assert child.props["content"] == "hello"
      assert Map.has_key?(child, :children)
    end

    test "deeply nested children are normalized recursively" do
      node = %{
        id: "root",
        type: "column",
        props: %{},
        children: [
          %{
            id: "mid",
            type: "row",
            props: %{},
            children: [
              %{id: "leaf", type: "button", props: %{label: "Go"}, children: []}
            ]
          }
        ]
      }

      result = Tree.normalize(node)
      [mid] = result.children
      [leaf] = mid.children
      assert leaf.id == "leaf"
      assert leaf.props["label"] == "Go"
    end
  end

  # ---------------------------------------------------------------------------
  # find/2
  # ---------------------------------------------------------------------------

  describe "find/2" do
    setup do
      tree = %{
        id: "root",
        type: "container",
        props: %{},
        children: [
          %{
            id: "col",
            type: "column",
            props: %{},
            children: [
              %{id: "btn", type: "button", props: %{"label" => "Save"}, children: []},
              %{id: "txt", type: "text", props: %{"content" => "hello"}, children: []}
            ]
          }
        ]
      }

      %{tree: tree}
    end

    test "find returns the root node when id matches root", %{tree: tree} do
      assert Tree.find(tree, "root") == tree
    end

    test "find returns a direct child node by id", %{tree: tree} do
      col = Tree.find(tree, "col")
      assert col != nil
      assert col.id == "col"
      assert col.type == "column"
    end

    test "find returns a deeply nested node by id", %{tree: tree} do
      btn = Tree.find(tree, "btn")
      assert btn != nil
      assert btn.id == "btn"
      assert btn.props["label"] == "Save"
    end

    test "find returns nil when id is not found", %{tree: tree} do
      assert Tree.find(tree, "nonexistent") == nil
    end

    test "find returns nil for empty string id not in tree", %{tree: tree} do
      assert Tree.find(tree, "") == nil
    end

    test "find searches children recursively and returns first match" do
      tree = %{
        id: "root",
        type: "container",
        props: %{},
        children: [
          %{id: "a", type: "column", props: %{}, children: [
            %{id: "target", type: "text", props: %{}, children: []}
          ]},
          %{id: "b", type: "column", props: %{}, children: []}
        ]
      }

      result = Tree.find(tree, "target")
      assert result.id == "target"
    end
  end

  # ---------------------------------------------------------------------------
  # find_all/2
  # ---------------------------------------------------------------------------

  describe "find_all/2" do
    setup do
      tree = %{
        id: "root",
        type: "container",
        props: %{},
        children: [
          %{id: "btn1", type: "button", props: %{}, children: []},
          %{
            id: "col",
            type: "column",
            props: %{},
            children: [
              %{id: "btn2", type: "button", props: %{}, children: []},
              %{id: "txt", type: "text", props: %{}, children: []}
            ]
          }
        ]
      }

      %{tree: tree}
    end

    test "find_all returns all nodes matching predicate", %{tree: tree} do
      buttons = Tree.find_all(tree, fn node -> node.type == "button" end)
      assert length(buttons) == 2
      ids = Enum.map(buttons, & &1.id)
      assert "btn1" in ids
      assert "btn2" in ids
    end

    test "find_all returns empty list when no nodes match", %{tree: tree} do
      result = Tree.find_all(tree, fn node -> node.type == "image" end)
      assert result == []
    end

    test "find_all with always-true predicate returns all nodes", %{tree: tree} do
      all = Tree.find_all(tree, fn _node -> true end)
      # root + btn1 + col + btn2 + txt
      assert length(all) == 5
    end

    test "find_all includes root if predicate matches it", %{tree: tree} do
      result = Tree.find_all(tree, fn node -> node.id == "root" end)
      assert length(result) == 1
      assert hd(result).id == "root"
    end
  end

  # ---------------------------------------------------------------------------
  # stringify_keys/1
  # ---------------------------------------------------------------------------

  describe "stringify_keys/1" do
    test "converts atom keys to string keys" do
      result = Tree.stringify_keys(%{foo: 1, bar: 2})
      assert result == %{"foo" => 1, "bar" => 2}
    end

    test "leaves string keys unchanged" do
      result = Tree.stringify_keys(%{"foo" => 1, "bar" => 2})
      assert result == %{"foo" => 1, "bar" => 2}
    end

    test "handles mixed atom and string keys" do
      result = Tree.stringify_keys(%{:atom_key => "a", "string_key" => "b"})
      assert result["atom_key"] == "a"
      assert result["string_key"] == "b"
    end

    test "recurses into nested maps" do
      result = Tree.stringify_keys(%{outer: %{inner: "value"}})
      assert result["outer"]["inner"] == "value"
    end

    test "does not recurse into list values" do
      result = Tree.stringify_keys(%{colors: [:red, :green, :blue]})
      assert result["colors"] == [:red, :green, :blue]
    end

    test "preserves non-map scalar values" do
      result = Tree.stringify_keys(%{n: 42, b: true, s: "text"})
      assert result["n"] == 42
      assert result["b"] == true
      assert result["s"] == "text"
    end

    test "returns empty map for empty input" do
      assert Tree.stringify_keys(%{}) == %{}
    end
  end
end
