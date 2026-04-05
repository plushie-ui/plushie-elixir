defmodule Plushie.ScopedIdTest do
  use ExUnit.Case, async: true

  alias Plushie.Event.WidgetEvent
  alias Plushie.Tree

  describe "Tree.normalize scoping" do
    test "named container scopes its children" do
      tree = %{
        id: "panel",
        type: "container",
        props: %{},
        children: [
          %{id: "save", type: "button", props: %{}, children: []}
        ]
      }

      normalized = Tree.normalize(tree)
      child = hd(normalized.children)
      assert child.id == "panel/save"
    end

    test "auto-ID container does not scope" do
      tree = %{
        id: "auto:MyApp:42",
        type: "column",
        props: %{},
        children: [
          %{id: "save", type: "button", props: %{}, children: []}
        ]
      }

      normalized = Tree.normalize(tree)
      child = hd(normalized.children)
      assert child.id == "save"
    end

    test "nested named containers build path" do
      tree = %{
        id: "sidebar",
        type: "container",
        props: %{},
        children: [
          %{
            id: "form",
            type: "container",
            props: %{},
            children: [
              %{id: "email", type: "text_input", props: %{}, children: []}
            ]
          }
        ]
      }

      normalized = Tree.normalize(tree)
      email = hd(hd(normalized.children).children)
      assert email.id == "sidebar/form/email"
    end

    test "window nodes do not create scope" do
      tree = %{
        id: "main",
        type: "window",
        props: %{},
        children: [
          %{
            id: "sidebar",
            type: "container",
            props: %{},
            children: [
              %{id: "save", type: "button", props: %{}, children: []}
            ]
          }
        ]
      }

      normalized = Tree.normalize(tree)
      save = hd(hd(normalized.children).children)
      assert save.id == "sidebar/save"
    end

    test "mixed auto and named containers" do
      tree = %{
        id: "panel",
        type: "container",
        props: %{},
        children: [
          %{
            id: "auto:MyApp:10",
            type: "row",
            props: %{},
            children: [
              %{id: "save", type: "button", props: %{}, children: []}
            ]
          }
        ]
      }

      normalized = Tree.normalize(tree)
      # auto row doesn't scope, but panel does
      save = hd(hd(normalized.children).children)
      assert save.id == "panel/save"
    end

    test "slash in user ID raises" do
      tree = %{id: "bad/id", type: "button", props: %{}, children: []}

      assert_raise ArgumentError, ~r/cannot contain/, fn ->
        Tree.normalize(tree)
      end
    end

    test "auto IDs with colon content are fine" do
      tree = %{id: "auto:MyApp:42", type: "column", props: %{}, children: []}
      normalized = Tree.normalize(tree)
      assert normalized.id == "auto:MyApp:42"
    end

    test "deeply nested scoping" do
      tree = %{
        id: "a",
        type: "container",
        props: %{},
        children: [
          %{
            id: "b",
            type: "container",
            props: %{},
            children: [
              %{
                id: "c",
                type: "container",
                props: %{},
                children: [
                  %{id: "widget", type: "button", props: %{}, children: []}
                ]
              }
            ]
          }
        ]
      }

      normalized = Tree.normalize(tree)
      widget = hd(hd(hd(normalized.children).children).children)
      assert widget.id == "a/b/c/widget"
    end

    test "sibling children in same scope get same prefix" do
      tree = %{
        id: "form",
        type: "container",
        props: %{},
        children: [
          %{id: "name", type: "text_input", props: %{}, children: []},
          %{id: "email", type: "text_input", props: %{}, children: []}
        ]
      }

      normalized = Tree.normalize(tree)
      [name, email] = normalized.children
      assert name.id == "form/name"
      assert email.id == "form/email"
    end

    test "root node with explicit ID does not self-scope" do
      tree = %{
        id: "root_panel",
        type: "container",
        props: %{},
        children: [
          %{id: "child", type: "button", props: %{}, children: []}
        ]
      }

      normalized = Tree.normalize(tree)
      assert normalized.id == "root_panel"
      assert hd(normalized.children).id == "root_panel/child"
    end
  end

  describe "Protocol.Decode scoped ID splitting" do
    test "simple ID has window_id as sole scope entry" do
      json = Jason.encode!(%{type: "event", family: "click", id: "save", window_id: "main"})
      event = Plushie.Protocol.Decode.decode_message(json, :json)
      assert event.id == "save"
      assert event.scope == ["main"]
    end

    test "scoped ID is split into local id and reversed scope with window_id at end" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "click",
          id: "sidebar/form/save",
          window_id: "main"
        })

      event = Plushie.Protocol.Decode.decode_message(json, :json)
      assert event.id == "save"
      assert event.scope == ["form", "sidebar", "main"]
    end

    test "single scope level" do
      json = Jason.encode!(%{type: "event", family: "click", id: "panel/save", window_id: "main"})
      event = Plushie.Protocol.Decode.decode_message(json, :json)
      assert event.id == "save"
      assert event.scope == ["panel", "main"]
    end
  end

  describe "Plushie.Event.target/1" do
    test "window_id-only scope returns bare id" do
      event = %WidgetEvent{type: :click, id: "save", scope: ["main"], window_id: "main"}
      assert Plushie.Event.target(event) == "save"
    end

    test "no scope and no window_id returns bare id" do
      event = %WidgetEvent{type: :click, id: "save", scope: []}
      assert Plushie.Event.target(event) == "save"
    end

    test "with scope and window_id strips window_id from path" do
      event = %WidgetEvent{
        type: :click,
        id: "save",
        scope: ["form", "sidebar", "main"],
        window_id: "main"
      }

      assert Plushie.Event.target(event) == "sidebar/form/save"
    end

    test "single container scope with window_id" do
      event = %WidgetEvent{type: :click, id: "save", scope: ["panel", "main"], window_id: "main"}
      assert Plushie.Event.target(event) == "panel/save"
    end

    test "scope without window_id preserves full path" do
      event = %WidgetEvent{type: :click, id: "save", scope: ["form", "sidebar"]}
      assert Plushie.Event.target(event) == "sidebar/form/save"
    end
  end

  describe "pattern matching" do
    test "match on local id only (any scope)" do
      event = %WidgetEvent{type: :click, id: "save", scope: ["form", "sidebar"]}
      assert match?(%WidgetEvent{id: "save"}, event)
    end

    test "match on id + immediate parent" do
      event = %WidgetEvent{type: :click, id: "save", scope: ["form", "sidebar"]}
      assert match?(%WidgetEvent{id: "save", scope: ["form" | _]}, event)
    end

    test "match on id + deep scope" do
      event = %WidgetEvent{type: :click, id: "save", scope: ["form", "settings", "app"]}
      assert match?(%WidgetEvent{id: "save", scope: ["form", "settings" | _]}, event)
    end

    test "bind parent scope for dynamic lists" do
      event = %WidgetEvent{type: :toggle, id: "done", scope: ["item_3", "todo_list"]}
      %WidgetEvent{id: "done", scope: [item_id | _]} = event
      assert item_id == "item_3"
    end

    test "depth-agnostic matching for reusable components" do
      shallow = %WidgetEvent{type: :input, id: "query", scope: ["search"]}
      deep = %WidgetEvent{type: :input, id: "query", scope: ["search", "sidebar", "app"]}

      assert match?(%WidgetEvent{id: "query", scope: ["search" | _]}, shallow)
      assert match?(%WidgetEvent{id: "query", scope: ["search" | _]}, deep)
    end
  end

  describe "dynamic list scoping" do
    test "items wrapped in named rows get unique scoped IDs" do
      tree =
        Tree.normalize(%{
          id: "todo_list",
          type: "column",
          props: %{},
          children: [
            %{
              id: "item_1",
              type: "row",
              props: %{},
              children: [
                %{id: "done", type: "checkbox", props: %{}, children: []},
                %{id: "delete", type: "button", props: %{}, children: []}
              ]
            },
            %{
              id: "item_2",
              type: "row",
              props: %{},
              children: [
                %{id: "done", type: "checkbox", props: %{}, children: []},
                %{id: "delete", type: "button", props: %{}, children: []}
              ]
            }
          ]
        })

      [item1, item2] = tree.children
      [done1, delete1] = item1.children
      [done2, delete2] = item2.children

      # Each item's children have unique scoped IDs
      assert done1.id == "todo_list/item_1/done"
      assert delete1.id == "todo_list/item_1/delete"
      assert done2.id == "todo_list/item_2/done"
      assert delete2.id == "todo_list/item_2/delete"

      # No collisions
      all_ids = [done1.id, delete1.id, done2.id, delete2.id]
      assert length(Enum.uniq(all_ids)) == 4
    end

    test "scope binding extracts item ID in pattern match" do
      event = %WidgetEvent{type: :toggle, id: "done", scope: ["item_3", "todo_list"]}
      %WidgetEvent{id: "done", scope: [item_id | _]} = event
      assert item_id == "item_3"
    end
  end

  describe "a11y ID reference resolution" do
    test "labelled_by is scoped to current scope" do
      tree =
        Tree.normalize(%{
          id: "form",
          type: "container",
          props: %{},
          children: [
            %{id: "name_label", type: "text", props: %{content: "Name"}, children: []},
            %{
              id: "name_input",
              type: "text_input",
              props: %{a11y: %{labelled_by: "name_label"}},
              children: []
            }
          ]
        })

      input = Enum.find(tree.children, &(&1.id == "form/name_input"))
      assert input.props[:a11y][:labelled_by] == "form/name_label"
    end

    test "described_by is scoped" do
      tree =
        Tree.normalize(%{
          id: "panel",
          type: "container",
          props: %{},
          children: [
            %{
              id: "slider",
              type: "slider",
              props: %{a11y: %{described_by: "help_text"}},
              children: []
            }
          ]
        })

      slider = hd(tree.children)
      assert slider.props[:a11y][:described_by] == "panel/help_text"
    end

    test "error_message is scoped" do
      tree =
        Tree.normalize(%{
          id: "form",
          type: "container",
          props: %{},
          children: [
            %{
              id: "email",
              type: "text_input",
              props: %{a11y: %{error_message: "email_error"}},
              children: []
            }
          ]
        })

      email = hd(tree.children)
      assert email.props[:a11y][:error_message] == "form/email_error"
    end

    test "already-scoped references (containing /) pass through" do
      tree =
        Tree.normalize(%{
          id: "form",
          type: "container",
          props: %{},
          children: [
            %{
              id: "input",
              type: "text_input",
              props: %{a11y: %{labelled_by: "other_section/label"}},
              children: []
            }
          ]
        })

      input = hd(tree.children)
      assert input.props[:a11y][:labelled_by] == "other_section/label"
    end

    test "no scope leaves references unchanged" do
      tree =
        Tree.normalize(%{
          id: "auto:MyApp:1",
          type: "column",
          props: %{},
          children: [
            %{
              id: "input",
              type: "text_input",
              props: %{a11y: %{labelled_by: "label"}},
              children: []
            }
          ]
        })

      input = hd(tree.children)
      assert input.props[:a11y][:labelled_by] == "label"
    end

    test "non-ref a11y props are not modified" do
      tree =
        Tree.normalize(%{
          id: "form",
          type: "container",
          props: %{},
          children: [
            %{
              id: "heading",
              type: "text",
              props: %{a11y: %{role: "heading", level: 1, labelled_by: "title"}},
              children: []
            }
          ]
        })

      heading = hd(tree.children)
      assert heading.props[:a11y][:role] == "heading"
      assert heading.props[:a11y][:level] == 1
      assert heading.props[:a11y][:labelled_by] == "form/title"
    end
  end

  describe "tree diffing with scoped IDs" do
    test "keyed children with same parent are matched correctly" do
      old =
        Tree.normalize(%{
          id: "list",
          type: "keyed_column",
          props: %{},
          children: [
            %{id: "a", type: "text", props: %{content: "A"}, children: []},
            %{id: "b", type: "text", props: %{content: "B"}, children: []}
          ]
        })

      new =
        Tree.normalize(%{
          id: "list",
          type: "keyed_column",
          props: %{},
          children: [
            %{id: "b", type: "text", props: %{content: "B"}, children: []},
            %{id: "a", type: "text", props: %{content: "A"}, children: []}
          ]
        })

      ops = Tree.diff(old, new)
      # Reorders now produce granular move ops (remove + insert) instead of
      # a full replace_node, minimizing re-rendering on the renderer side.
      removes = Enum.filter(ops, &(&1.op == "remove_child"))
      inserts = Enum.filter(ops, &(&1.op == "insert_child"))
      assert length(removes) == 1
      assert length(inserts) == 1
      assert hd(inserts).node.id == "list/b"
    end

    test "scoped IDs do not break incremental diffing" do
      old =
        Tree.normalize(%{
          id: "panel",
          type: "container",
          props: %{},
          children: [
            %{id: "label", type: "text", props: %{content: "Hello"}, children: []}
          ]
        })

      new =
        Tree.normalize(%{
          id: "panel",
          type: "container",
          props: %{},
          children: [
            %{id: "label", type: "text", props: %{content: "World"}, children: []}
          ]
        })

      ops = Tree.diff(old, new)
      assert length(ops) == 1
      assert hd(ops).op == "update_props"
    end
  end

  describe "Tree.find with scoped IDs" do
    test "find by full scoped path" do
      tree =
        Tree.normalize(%{
          id: "panel",
          type: "container",
          props: %{},
          children: [
            %{id: "save", type: "button", props: %{}, children: []}
          ]
        })

      result = Tree.find(tree, "panel/save")
      assert result != nil
      assert result.type == "button"
    end

    test "find by local ID does not guess" do
      tree =
        Tree.normalize(%{
          id: "panel",
          type: "container",
          props: %{},
          children: [
            %{id: "save", type: "button", props: %{}, children: []}
          ]
        })

      assert Tree.find(tree, "save") == nil
    end

    test "exact match takes priority over local ID match" do
      # A node whose full ID is "save" should be found before a node
      # whose local ID segment is "save" but whose full ID is "panel/save"
      tree = %{
        id: "save",
        type: "container",
        props: %{},
        children: [
          %{id: "panel/save", type: "button", props: %{}, children: []}
        ]
      }

      result = Tree.find(tree, "save")
      assert result.type == "container"
    end
  end

  describe "widget ID validation" do
    test "empty ID raises" do
      tree = %{id: "", type: "button", props: %{}, children: []}

      assert_raise ArgumentError, ~r/must not be empty/, fn ->
        Tree.normalize(tree)
      end
    end

    test "non-ASCII characters in ID raise" do
      tree = %{id: "héllo", type: "button", props: %{}, children: []}

      assert_raise ArgumentError, ~r/invalid characters/, fn ->
        Tree.normalize(tree)
      end
    end

    test "control characters in ID raise" do
      tree = %{id: "bad\nid", type: "button", props: %{}, children: []}

      assert_raise ArgumentError, ~r/invalid characters/, fn ->
        Tree.normalize(tree)
      end
    end

    test "space in ID raises" do
      tree = %{id: "bad id", type: "button", props: %{}, children: []}

      assert_raise ArgumentError, ~r/invalid characters/, fn ->
        Tree.normalize(tree)
      end
    end

    test "printable ASCII IDs are accepted" do
      tree = %{id: "my-button_123!@#", type: "button", props: %{}, children: []}
      normalized = Tree.normalize(tree)
      assert normalized.id == "my-button_123!@#"
    end
  end
end
