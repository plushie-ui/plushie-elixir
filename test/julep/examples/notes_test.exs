defmodule Julep.Examples.NotesTest do
  use ExUnit.Case, async: true

  alias Julep.Event.Widget

  alias Julep.Examples.Notes

  describe "init/1" do
    test "starts with empty notes and list route" do
      model = Notes.init([])
      assert Julep.State.get(model.state, [:notes]) == []
      assert Julep.Route.current(model.route) == "/list"
    end

    test "starts with multi-select selection" do
      model = Notes.init([])
      assert model.selection.mode == :multi
    end

    test "starts with empty undo state" do
      model = Notes.init([])
      assert Julep.Undo.current(model.undo) == %{text: "", title: ""}
    end
  end

  describe "note management" do
    test "creating a new note" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})

      notes = Julep.State.get(model.state, [:notes])
      assert length(notes) == 1
      assert Julep.Route.current(model.route) == "/edit"
    end

    test "new note gets incrementing id" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      model = Notes.update(model, %Widget{type: :click, id: "back"})
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})

      notes = Julep.State.get(model.state, [:notes])
      assert [%{id: 1}, %{id: 2}] = notes
    end

    test "editing a note title" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      model = Notes.update(model, %Widget{type: :input, id: "title", value: "My Note"})

      assert Julep.Undo.current(model.undo).title == "My Note"
    end

    test "editing a note body" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      model = Notes.update(model, %Widget{type: :input, id: "body", value: "Some content"})

      assert Julep.Undo.current(model.undo).text == "Some content"
    end

    test "edits are saved when navigating back" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      model = Notes.update(model, %Widget{type: :input, id: "title", value: "Saved Title"})
      model = Notes.update(model, %Widget{type: :input, id: "body", value: "Saved Body"})
      model = Notes.update(model, %Widget{type: :click, id: "back"})

      [note] = Julep.State.get(model.state, [:notes])
      assert note.title == "Saved Title"
      assert note.body == "Saved Body"
    end

    test "undo/redo" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      model = Notes.update(model, %Widget{type: :input, id: "title", value: "First"})
      model = Notes.update(model, %Widget{type: :input, id: "title", value: "Second"})

      model = Notes.update(model, %Widget{type: :click, id: "undo"})
      assert Julep.Undo.current(model.undo).title == "First"

      model = Notes.update(model, %Widget{type: :click, id: "redo"})
      assert Julep.Undo.current(model.undo).title == "Second"
    end

    test "undo all the way back to initial state" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      model = Notes.update(model, %Widget{type: :input, id: "title", value: "Only Change"})

      model = Notes.update(model, %Widget{type: :click, id: "undo"})
      assert Julep.Undo.current(model.undo).title == ""
    end

    test "delete selected notes" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      model = Notes.update(model, %Widget{type: :click, id: "back"})
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      model = Notes.update(model, %Widget{type: :click, id: "back"})

      notes = Julep.State.get(model.state, [:notes])
      assert length(notes) == 2

      first_id = hd(notes).id |> to_string()
      model = Notes.update(model, %Widget{type: :toggle, id: "note_select:#{first_id}", value: true})
      model = Notes.update(model, %Widget{type: :click, id: "delete_selected"})

      notes = Julep.State.get(model.state, [:notes])
      assert length(notes) == 1
    end

    test "delete clears selection afterwards" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      model = Notes.update(model, %Widget{type: :click, id: "back"})

      model = Notes.update(model, %Widget{type: :toggle, id: "note_select:1", value: true})
      model = Notes.update(model, %Widget{type: :click, id: "delete_selected"})

      assert Julep.Selection.selected(model.selection) == MapSet.new()
    end

    test "clicking a note loads its content into undo" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      model = Notes.update(model, %Widget{type: :input, id: "title", value: "Hello"})
      model = Notes.update(model, %Widget{type: :input, id: "body", value: "World"})
      model = Notes.update(model, %Widget{type: :click, id: "back"})

      # Now re-open the note
      model = Notes.update(model, %Widget{type: :click, id: "note:1"})
      assert Julep.Undo.current(model.undo).title == "Hello"
      assert Julep.Undo.current(model.undo).text == "World"
      # Fresh undo stack -- no history from previous edit session
      refute Julep.Undo.can_undo?(model.undo)
    end

    test "search filters notes" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      model = Notes.update(model, %Widget{type: :input, id: "title", value: "Shopping List"})
      model = Notes.update(model, %Widget{type: :click, id: "back"})
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      model = Notes.update(model, %Widget{type: :input, id: "title", value: "Meeting Notes"})
      model = Notes.update(model, %Widget{type: :click, id: "back"})

      model = Notes.update(model, %Widget{type: :input, id: "search", value: "shop"})

      assert Julep.State.get(model.state, [:search_query]) == "shop"
    end
  end

  describe "selection" do
    test "toggling note selection on" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      model = Notes.update(model, %Widget{type: :click, id: "back"})

      model = Notes.update(model, %Widget{type: :toggle, id: "note_select:1", value: true})
      assert Julep.Selection.selected?(model.selection, 1)
    end

    test "toggling note selection off" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      model = Notes.update(model, %Widget{type: :click, id: "back"})

      model = Notes.update(model, %Widget{type: :toggle, id: "note_select:1", value: true})
      model = Notes.update(model, %Widget{type: :toggle, id: "note_select:1", value: false})
      refute Julep.Selection.selected?(model.selection, 1)
    end

    test "multi-select allows selecting multiple notes" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      model = Notes.update(model, %Widget{type: :click, id: "back"})
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      model = Notes.update(model, %Widget{type: :click, id: "back"})

      model = Notes.update(model, %Widget{type: :toggle, id: "note_select:1", value: true})
      model = Notes.update(model, %Widget{type: :toggle, id: "note_select:2", value: true})

      assert Julep.Selection.selected?(model.selection, 1)
      assert Julep.Selection.selected?(model.selection, 2)
    end
  end

  describe "view/1" do
    test "list view renders without errors" do
      model = Notes.init([])
      tree = Notes.view(model)
      assert tree.type == "window"
    end

    test "edit view renders without errors" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      tree = Notes.view(model)
      assert tree.type == "window"
    end

    test "list view contains expected widgets" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      model = Notes.update(model, %Widget{type: :input, id: "title", value: "Test Note"})
      model = Notes.update(model, %Widget{type: :click, id: "back"})

      tree = Notes.view(model)
      assert Julep.UI.exists?(tree, "search")
      assert Julep.UI.exists?(tree, "new_note")
      assert Julep.UI.exists?(tree, "delete_selected")
      assert Julep.UI.exists?(tree, "note:1")
    end

    test "edit view contains expected widgets" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})

      tree = Notes.view(model)
      assert Julep.UI.exists?(tree, "back")
      assert Julep.UI.exists?(tree, "undo")
      assert Julep.UI.exists?(tree, "redo")
      assert Julep.UI.exists?(tree, "title")
      assert Julep.UI.exists?(tree, "body")
    end
  end

  describe "routing" do
    test "back returns to list" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      assert Julep.Route.current(model.route) == "/edit"

      model = Notes.update(model, %Widget{type: :click, id: "back"})
      assert Julep.Route.current(model.route) == "/list"
    end

    test "clicking a note navigates to edit" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "new_note"})
      model = Notes.update(model, %Widget{type: :click, id: "back"})

      model = Notes.update(model, %Widget{type: :click, id: "note:1"})
      assert Julep.Route.current(model.route) == "/edit"
    end

    test "clicking nonexistent note does not navigate" do
      model = Notes.init([])
      model = Notes.update(model, %Widget{type: :click, id: "note:999"})
      assert Julep.Route.current(model.route) == "/list"
    end
  end

  describe "data query integration" do
    test "Data.query filters notes by title" do
      notes = [
        %{id: 1, title: "Shopping List", body: "milk, eggs"},
        %{id: 2, title: "Meeting Notes", body: "discuss budget"}
      ]

      result = Julep.Data.query(notes, search: {[:title, :body], "shop"})
      assert length(result.entries) == 1
      assert hd(result.entries).id == 1
    end

    test "Data.query filters notes by body" do
      notes = [
        %{id: 1, title: "Shopping List", body: "milk, eggs"},
        %{id: 2, title: "Meeting Notes", body: "discuss budget"}
      ]

      result = Julep.Data.query(notes, search: {[:title, :body], "budget"})
      assert length(result.entries) == 1
      assert hd(result.entries).id == 2
    end
  end
end
