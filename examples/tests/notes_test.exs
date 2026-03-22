defmodule Examples.NotesTest do
  @moduledoc "Integration tests for the Notes example using the test DSL."

  use Plushie.Test.Case, app: Notes

  test "starts with empty notes and list route" do
    m = model()
    assert Plushie.State.get(m.state, [:notes]) == []
    assert Plushie.Route.current(m.route) == "/list"
  end

  test "heading renders" do
    assert_text("#heading", "Notes")
  end

  test "new note button exists" do
    assert_exists("#new_note")
  end

  test "delete selected button exists" do
    assert_exists("#delete_selected")
  end

  test "search input exists" do
    assert_exists("#search")
  end

  test "creating a new note navigates to edit view" do
    click("#new_note")
    m = model()
    notes = Plushie.State.get(m.state, [:notes])
    assert length(notes) == 1
    assert Plushie.Route.current(m.route) == "/edit"
  end

  test "edit view has back, undo, redo buttons" do
    click("#new_note")
    assert_exists("#back")
    assert_exists("#undo")
    assert_exists("#redo")
  end

  test "edit view has title and body inputs" do
    click("#new_note")
    assert_exists("#title")
    assert_exists("#body")
  end

  test "navigating back returns to list" do
    click("#new_note")
    click("#back")
    m = model()
    assert Plushie.Route.current(m.route) == "/list"
  end

  test "editing title updates undo state" do
    click("#new_note")
    type_text("#title", "My Note")
    m = model()
    assert Plushie.Undo.current(m.undo).title == "My Note"
  end

  test "editing body updates undo state" do
    click("#new_note")
    type_text("#body", "Some content")
    m = model()
    assert Plushie.Undo.current(m.undo).text == "Some content"
  end

  test "edits are saved when navigating back" do
    click("#new_note")
    type_text("#title", "Saved Title")
    type_text("#body", "Saved Body")
    click("#back")

    m = model()
    [note] = Plushie.State.get(m.state, [:notes])
    assert note.title == "Saved Title"
    assert note.body == "Saved Body"
  end

  test "created note appears in list view" do
    click("#new_note")
    type_text("#title", "Test Note")
    click("#back")

    assert_exists("#note:1")
  end

  test "selecting and deleting a note" do
    click("#new_note")
    click("#back")
    click("#new_note")
    click("#back")

    m = model()
    assert length(Plushie.State.get(m.state, [:notes])) == 2

    toggle("#note_select:1")
    click("#delete_selected")

    m = model()
    assert length(Plushie.State.get(m.state, [:notes])) == 1
  end

  test "search input updates query in state" do
    type_text("#search", "hello")
    m = model()
    assert Plushie.State.get(m.state, [:search_query]) == "hello"
  end
end
