defmodule Toddy.ScopedIdTest do
  use ExUnit.Case, async: true

  alias Toddy.Event.Widget
  alias Toddy.Tree

  # ---------------------------------------------------------------------------
  # Tree.normalize scoping
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # Protocol.Decode scoped ID splitting
  # ---------------------------------------------------------------------------

  describe "Protocol.Decode scoped ID splitting" do
    test "simple ID has empty scope" do
      json = Jason.encode!(%{type: "event", family: "click", id: "save"})
      event = Toddy.Protocol.Decode.decode_message(json, :json)
      assert event.id == "save"
      assert event.scope == []
    end

    test "scoped ID is split into local id and reversed scope" do
      json = Jason.encode!(%{type: "event", family: "click", id: "sidebar/form/save"})
      event = Toddy.Protocol.Decode.decode_message(json, :json)
      assert event.id == "save"
      assert event.scope == ["form", "sidebar"]
    end

    test "single scope level" do
      json = Jason.encode!(%{type: "event", family: "click", id: "panel/save"})
      event = Toddy.Protocol.Decode.decode_message(json, :json)
      assert event.id == "save"
      assert event.scope == ["panel"]
    end
  end

  # ---------------------------------------------------------------------------
  # Toddy.Event.target/1
  # ---------------------------------------------------------------------------

  describe "Toddy.Event.target/1" do
    test "no scope returns bare id" do
      event = %Widget{type: :click, id: "save", scope: []}
      assert Toddy.Event.target(event) == "save"
    end

    test "with scope returns forward-order path" do
      event = %Widget{type: :click, id: "save", scope: ["form", "sidebar"]}
      assert Toddy.Event.target(event) == "sidebar/form/save"
    end

    test "single scope level" do
      event = %Widget{type: :click, id: "save", scope: ["panel"]}
      assert Toddy.Event.target(event) == "panel/save"
    end
  end

  # ---------------------------------------------------------------------------
  # Pattern matching
  # ---------------------------------------------------------------------------

  describe "pattern matching" do
    test "match on local id only (any scope)" do
      event = %Widget{type: :click, id: "save", scope: ["form", "sidebar"]}
      assert match?(%Widget{id: "save"}, event)
    end

    test "match on id + immediate parent" do
      event = %Widget{type: :click, id: "save", scope: ["form", "sidebar"]}
      assert match?(%Widget{id: "save", scope: ["form" | _]}, event)
    end

    test "match on id + deep scope" do
      event = %Widget{type: :click, id: "save", scope: ["form", "settings", "app"]}
      assert match?(%Widget{id: "save", scope: ["form", "settings" | _]}, event)
    end

    test "bind parent scope for dynamic lists" do
      event = %Widget{type: :toggle, id: "done", scope: ["item_3", "todo_list"]}
      %Widget{id: "done", scope: [item_id | _]} = event
      assert item_id == "item_3"
    end

    test "depth-agnostic matching for reusable components" do
      shallow = %Widget{type: :input, id: "query", scope: ["search"]}
      deep = %Widget{type: :input, id: "query", scope: ["search", "sidebar", "app"]}

      assert match?(%Widget{id: "query", scope: ["search" | _]}, shallow)
      assert match?(%Widget{id: "query", scope: ["search" | _]}, deep)
    end
  end

  # ---------------------------------------------------------------------------
  # Dynamic list scoping
  # ---------------------------------------------------------------------------

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
      event = %Widget{type: :toggle, id: "done", scope: ["item_3", "todo_list"]}
      %Widget{id: "done", scope: [item_id | _]} = event
      assert item_id == "item_3"
    end
  end

  # ---------------------------------------------------------------------------
  # A11y ID reference resolution
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # Tree diffing with scoped IDs
  # ---------------------------------------------------------------------------

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
      assert Enum.any?(ops, &(&1.op == "replace_node"))
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

  # ---------------------------------------------------------------------------
  # Tree.find with scoped IDs
  # ---------------------------------------------------------------------------

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

    test "find by local ID falls back when no exact match" do
      tree =
        Tree.normalize(%{
          id: "panel",
          type: "container",
          props: %{},
          children: [
            %{id: "save", type: "button", props: %{}, children: []}
          ]
        })

      result = Tree.find(tree, "save")
      assert result != nil
      assert result.id == "panel/save"
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
end
