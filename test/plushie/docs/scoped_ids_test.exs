defmodule Plushie.Docs.ScopedIdsTest do
  use ExUnit.Case, async: true

  alias Plushie.Event.Widget

  # -- Match on local ID only ------------------------------------------------

  test "scoped_ids_match_local_id_test" do
    event = %Widget{type: :click, id: "save", scope: ["form", "sidebar"]}

    assert match?(%Widget{type: :click, id: "save"}, event)
  end

  # -- Match on ID + immediate parent ----------------------------------------

  test "scoped_ids_match_immediate_parent_test" do
    event = %Widget{type: :click, id: "save", scope: ["form", "sidebar"]}

    assert match?(%Widget{type: :click, id: "save", scope: ["form" | _]}, event)
  end

  # -- Bind parent for dynamic lists -----------------------------------------

  test "scoped_ids_dynamic_list_bind_parent_test" do
    event = %Widget{type: :toggle, id: "done", value: true, scope: ["item_42", "todo_list"]}

    assert %Widget{type: :toggle, id: "done", scope: [item_id | _]} = event
    assert item_id == "item_42"
  end

  # -- Dynamic list delete ---------------------------------------------------

  test "scoped_ids_dynamic_list_delete_test" do
    event = %Widget{type: :click, id: "delete", scope: ["item_7", "todo_list"]}

    assert %Widget{type: :click, id: "delete", scope: [item_id | _]} = event
    assert item_id == "item_7"
  end

  # -- Depth-agnostic matching -----------------------------------------------

  test "scoped_ids_depth_agnostic_test" do
    event = %Widget{type: :input, id: "query", value: "hi", scope: ["search", "sidebar", "root"]}

    assert match?(%Widget{type: :input, id: "query", scope: ["search" | _]}, event)
  end

  # -- Exact depth matching --------------------------------------------------

  test "scoped_ids_exact_depth_test" do
    event = %Widget{type: :input, id: "query", value: "hi", scope: ["search"]}

    assert match?(%Widget{type: :input, id: "query", scope: ["search"]}, event)
  end

  test "scoped_ids_exact_depth_mismatch_test" do
    # Two scope levels should NOT match the exact single-scope pattern
    event = %Widget{type: :input, id: "query", value: "hi", scope: ["search", "panel"]}

    refute match?(%Widget{type: :input, id: "query", scope: ["search"]}, event)
  end

  # -- No scope matching -----------------------------------------------------

  test "scoped_ids_no_scope_test" do
    event = %Widget{type: :click, id: "save", scope: []}

    assert match?(%Widget{type: :click, id: "save", scope: []}, event)
  end

  test "scoped_ids_no_scope_mismatch_test" do
    # Scoped event should NOT match the empty-scope pattern.
    # A click on "save" inside "form" has scope ["form"], so a
    # handler that only matches scope: [] would miss it.
    event = %Widget{type: :click, id: "save", scope: ["form"]}

    assert [_ | _] = event.scope
  end
end
