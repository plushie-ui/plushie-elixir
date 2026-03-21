defmodule Plushie.TreeTest do
  use ExUnit.Case, async: true

  alias Plushie.Tree

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

    test "missing id generates unique unknown_ prefix" do
      result = Tree.normalize(%{type: "button"})
      assert String.starts_with?(result.id, "unknown_")
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

  describe "normalize/1 -- prop key handling" do
    test "keeps atom keys in props as atoms" do
      node = %{id: "btn", type: "button", props: %{label: "Click", style: :primary}, children: []}
      result = Tree.normalize(node)
      assert Map.has_key?(result.props, :label)
      assert Map.has_key?(result.props, :style)
      refute Map.has_key?(result.props, "label")
    end

    test "converts string keys in props to atoms" do
      node = %{id: "t", type: "text", props: %{"content" => "hello"}, children: []}
      result = Tree.normalize(node)
      assert result.props[:content] == "hello"
      refute Map.has_key?(result.props, "content")
    end

    test "handles mixed atom and string keys in props" do
      node = %{id: "m", type: "text", props: %{:color => "red", "size" => 14}, children: []}
      result = Tree.normalize(node)
      assert result.props[:color] == "red"
      assert result.props[:size] == 14
      refute Map.has_key?(result.props, "size")
    end

    test "encodes struct-valued props (StyleMap) without raising" do
      style =
        Plushie.Type.StyleMap.new()
        |> Plushie.Type.StyleMap.background("#1b2435")
        |> Plushie.Type.StyleMap.text_color("#eaf0fb")

      node = %{id: "c", type: "container", props: %{style: style}, children: []}
      result = Tree.normalize(node)

      # StyleMap is encoded to an atom-keyed map by encode_prop_values
      assert result.props[:style][:background] == "#1b2435"
      assert result.props[:style][:text_color] == "#eaf0fb"
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
      assert child.id == "parent/child"
      assert child.props[:content] == "hello"
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
      assert leaf.id == "root/mid/leaf"
      assert leaf.props[:label] == "Go"
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
              %{id: "btn", type: "button", props: %{label: "Save"}, children: []},
              %{id: "txt", type: "text", props: %{content: "hello"}, children: []}
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
      assert btn.props[:label] == "Save"
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
          %{
            id: "a",
            type: "column",
            props: %{},
            children: [
              %{id: "target", type: "text", props: %{}, children: []}
            ]
          },
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
  # exists?/2
  # ---------------------------------------------------------------------------

  describe "exists?/2" do
    test "returns true for existing node" do
      tree = %{
        id: "root",
        type: "column",
        props: %{},
        children: [
          %{id: "child", type: "text", props: %{}, children: []}
        ]
      }

      assert Tree.exists?(tree, "root")
      assert Tree.exists?(tree, "child")
    end

    test "returns false for non-existing node" do
      tree = %{id: "root", type: "column", props: %{}, children: []}
      refute Tree.exists?(tree, "nope")
    end

    test "returns false for nil tree" do
      refute Tree.exists?(nil, "anything")
    end
  end

  # ---------------------------------------------------------------------------
  # ids/1
  # ---------------------------------------------------------------------------

  describe "ids/1" do
    test "returns all IDs depth-first" do
      tree = %{
        id: "a",
        type: "column",
        props: %{},
        children: [
          %{id: "b", type: "text", props: %{}, children: []},
          %{
            id: "c",
            type: "row",
            props: %{},
            children: [
              %{id: "d", type: "text", props: %{}, children: []}
            ]
          }
        ]
      }

      assert Tree.ids(tree) == ["a", "b", "c", "d"]
    end

    test "returns empty list for nil" do
      assert Tree.ids(nil) == []
    end
  end

  # ---------------------------------------------------------------------------
  # find_all/2 with predicate (additional coverage)
  # ---------------------------------------------------------------------------

  describe "find_all/2 with predicate" do
    test "finds all nodes matching predicate" do
      tree = %{
        id: "root",
        type: "column",
        props: %{},
        children: [
          %{id: "t1", type: "text", props: %{}, children: []},
          %{id: "b1", type: "button", props: %{}, children: []},
          %{id: "t2", type: "text", props: %{}, children: []}
        ]
      }

      texts = Tree.find_all(tree, fn node -> node.type == "text" end)
      assert length(texts) == 2
      assert Enum.map(texts, & &1.id) == ["t1", "t2"]
    end
  end

  # ---------------------------------------------------------------------------
  # stringify_keys/1
  # ---------------------------------------------------------------------------

  describe "stringify_keys/1" do
    test "converts atom keys to string keys" do
      result = Plushie.Protocol.Encode.stringify_keys(%{foo: 1, bar: 2})
      assert result == %{"foo" => 1, "bar" => 2}
    end

    test "leaves string keys unchanged" do
      result = Plushie.Protocol.Encode.stringify_keys(%{"foo" => 1, "bar" => 2})
      assert result == %{"foo" => 1, "bar" => 2}
    end

    test "handles mixed atom and string keys" do
      result = Plushie.Protocol.Encode.stringify_keys(%{:atom_key => "a", "string_key" => "b"})
      assert result["atom_key"] == "a"
      assert result["string_key"] == "b"
    end

    test "recurses into nested maps" do
      result = Plushie.Protocol.Encode.stringify_keys(%{outer: %{inner: "value"}})
      assert result["outer"]["inner"] == "value"
    end

    test "converts atoms inside list values to strings" do
      result = Plushie.Protocol.Encode.stringify_keys(%{colors: [:red, :green, :blue]})
      assert result["colors"] == ["red", "green", "blue"]
    end

    test "preserves non-map scalar values" do
      result = Plushie.Protocol.Encode.stringify_keys(%{n: 42, b: true, s: "text"})
      assert result["n"] == 42
      assert result["b"] == true
      assert result["s"] == "text"
    end

    test "returns empty map for empty input" do
      assert Plushie.Protocol.Encode.stringify_keys(%{}) == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # diff/2
  # ---------------------------------------------------------------------------

  describe "diff/2 -- nil inputs" do
    test "both nil returns empty list" do
      assert Tree.diff(nil, nil) == []
    end

    test "nil to tree returns replace_node at root" do
      tree = %{id: "root", type: "container", props: %{}, children: []}
      assert Tree.diff(nil, tree) == [%{op: "replace_node", path: [], node: tree}]
    end

    test "tree to nil returns remove_child at root" do
      tree = %{id: "root", type: "container", props: %{}, children: []}
      assert Tree.diff(tree, nil) == [%{op: "remove_child", path: [], index: 0}]
    end
  end

  describe "diff/2 -- identical trees" do
    test "returns empty list for identical trees" do
      tree = %{
        id: "root",
        type: "container",
        props: %{padding: 10},
        children: [
          %{id: "btn", type: "button", props: %{label: "OK"}, children: []}
        ]
      }

      assert Tree.diff(tree, tree) == []
    end
  end

  describe "diff/2 -- replaced root" do
    test "different root IDs produce replace_node" do
      old = %{id: "root-a", type: "container", props: %{}, children: []}
      new = %{id: "root-b", type: "container", props: %{}, children: []}
      assert Tree.diff(old, new) == [%{op: "replace_node", path: [], node: new}]
    end
  end

  describe "diff/2 -- changed props" do
    test "changed prop value emits update_props with only changed keys" do
      old = %{
        id: "root",
        type: "container",
        props: %{color: "red", size: 14},
        children: []
      }

      new = %{
        id: "root",
        type: "container",
        props: %{color: "blue", size: 14},
        children: []
      }

      ops = Tree.diff(old, new)
      assert ops == [%{op: "update_props", path: [], props: %{color: "blue"}}]
    end

    test "added prop emits update_props" do
      old = %{id: "root", type: "container", props: %{}, children: []}
      new = %{id: "root", type: "container", props: %{visible: true}, children: []}

      ops = Tree.diff(old, new)
      assert ops == [%{op: "update_props", path: [], props: %{visible: true}}]
    end

    test "removed prop emits update_props with nil value" do
      old = %{id: "root", type: "container", props: %{color: "red"}, children: []}
      new = %{id: "root", type: "container", props: %{}, children: []}

      ops = Tree.diff(old, new)
      assert ops == [%{op: "update_props", path: [], props: %{color: nil}}]
    end
  end

  describe "diff/2 -- added child" do
    test "new child emits insert_child" do
      old = %{id: "root", type: "container", props: %{}, children: []}
      child = %{id: "btn", type: "button", props: %{label: "Go"}, children: []}
      new = %{id: "root", type: "container", props: %{}, children: [child]}

      ops = Tree.diff(old, new)
      assert ops == [%{op: "insert_child", path: [], index: 0, node: child}]
    end
  end

  describe "diff/2 -- removed child" do
    test "missing child emits remove_child" do
      child = %{id: "btn", type: "button", props: %{label: "Go"}, children: []}
      old = %{id: "root", type: "container", props: %{}, children: [child]}
      new = %{id: "root", type: "container", props: %{}, children: []}

      ops = Tree.diff(old, new)
      assert ops == [%{op: "remove_child", path: [], index: 0}]
    end
  end

  describe "diff/2 -- multiple changes" do
    test "remove + insert + update in a single diff" do
      old_child_a = %{id: "a", type: "text", props: %{content: "hello"}, children: []}
      old_child_b = %{id: "b", type: "text", props: %{content: "world"}, children: []}
      new_child_a = %{id: "a", type: "text", props: %{content: "hi"}, children: []}
      new_child_c = %{id: "c", type: "button", props: %{label: "New"}, children: []}

      old = %{id: "root", type: "container", props: %{}, children: [old_child_a, old_child_b]}
      new = %{id: "root", type: "container", props: %{}, children: [new_child_a, new_child_c]}

      ops = Tree.diff(old, new)

      # b removed at index 1, a updated at index 0, c inserted at index 1
      assert [remove, update, insert] = ops
      assert remove == %{op: "remove_child", path: [], index: 1}
      assert update == %{op: "update_props", path: [0], props: %{content: "hi"}}
      assert insert == %{op: "insert_child", path: [], index: 1, node: new_child_c}
    end

    test "multiple removes are ordered high index to low" do
      child_a = %{id: "a", type: "text", props: %{}, children: []}
      child_b = %{id: "b", type: "text", props: %{}, children: []}
      child_c = %{id: "c", type: "text", props: %{}, children: []}

      old = %{id: "root", type: "container", props: %{}, children: [child_a, child_b, child_c]}
      new = %{id: "root", type: "container", props: %{}, children: []}

      ops = Tree.diff(old, new)

      assert [r1, r2, r3] = ops
      assert r1.index == 2
      assert r2.index == 1
      assert r3.index == 0
    end

    test "insert before existing sibling keeps update path on original child" do
      old_child_a = %{id: "a", type: "text", props: %{content: "old"}, children: []}
      old_child_b = %{id: "b", type: "text", props: %{content: "b"}, children: []}
      old = %{id: "root", type: "container", props: %{}, children: [old_child_a, old_child_b]}

      new_child_x = %{id: "x", type: "text", props: %{content: "x"}, children: []}
      new_child_a = %{id: "a", type: "text", props: %{content: "new"}, children: []}

      new = %{
        id: "root",
        type: "container",
        props: %{},
        children: [new_child_x, new_child_a, old_child_b]
      }

      ops = Tree.diff(old, new)

      assert [update, insert] = ops
      assert update == %{op: "update_props", path: [0], props: %{content: "new"}}
      assert insert == %{op: "insert_child", path: [], index: 0, node: new_child_x}
    end

    test "reordered children emit replace_node to preserve correct order" do
      child_a = %{id: "a", type: "text", props: %{content: "A"}, children: []}
      child_b = %{id: "b", type: "text", props: %{content: "B"}, children: []}
      child_c = %{id: "c", type: "text", props: %{content: "C"}, children: []}

      old = %{id: "root", type: "container", props: %{}, children: [child_a, child_b, child_c]}
      new = %{id: "root", type: "container", props: %{}, children: [child_c, child_b, child_a]}

      assert Tree.diff(old, new) == [%{op: "replace_node", path: [], node: new}]
    end
  end

  describe "diff/2 -- nested changes" do
    test "changed prop on nested child has correct path" do
      inner = %{id: "inner", type: "text", props: %{content: "old"}, children: []}
      outer = %{id: "outer", type: "column", props: %{}, children: [inner]}
      old = %{id: "root", type: "container", props: %{}, children: [outer]}

      inner_new = %{id: "inner", type: "text", props: %{content: "new"}, children: []}
      outer_new = %{id: "outer", type: "column", props: %{}, children: [inner_new]}
      new = %{id: "root", type: "container", props: %{}, children: [outer_new]}

      ops = Tree.diff(old, new)
      assert ops == [%{op: "update_props", path: [0, 0], props: %{content: "new"}}]
    end

    test "insert deep in the tree has correct path" do
      outer = %{id: "outer", type: "column", props: %{}, children: []}
      old = %{id: "root", type: "container", props: %{}, children: [outer]}

      new_child = %{id: "leaf", type: "button", props: %{}, children: []}
      outer_new = %{id: "outer", type: "column", props: %{}, children: [new_child]}
      new = %{id: "root", type: "container", props: %{}, children: [outer_new]}

      ops = Tree.diff(old, new)
      assert ops == [%{op: "insert_child", path: [0], index: 0, node: new_child}]
    end
  end
end
