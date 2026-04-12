defmodule Examples.TodoTest do
  @moduledoc "Integration tests for the Todo example using the test DSL."

  use Plushie.Test.Case, app: Todo

  test "starts with empty todo list" do
    assert model().todos == []
    assert model().input == ""
    assert model().filter == :all
  end

  test "input field and filter buttons exist" do
    assert_exists("#new_todo")
    assert_exists("#filter_all")
    assert_exists("#filter_active")
    assert_exists("#filter_done")
  end

  test "typing updates the input model" do
    type_text("#new_todo", "Buy milk")
    assert model().input == "Buy milk"
  end

  test "submitting adds a todo and clears input" do
    type_text("#new_todo", "Buy milk")
    submit("#new_todo")

    assert model().input == ""
    assert [%{text: "Buy milk", done: false}] = model().todos
  end

  test "toggling a todo marks it complete" do
    type_text("#new_todo", "Test task")
    submit("#new_todo")

    [todo] = model().todos
    toggle("#main#app/list/#{todo.id}/toggle")

    assert hd(model().todos).done == true
  end

  test "deleting a todo removes it from the list" do
    type_text("#new_todo", "Ephemeral")
    submit("#new_todo")
    assert length(model().todos) == 1

    [todo] = model().todos
    click("#main#app/list/#{todo.id}/delete")

    assert model().todos == []
  end

  test "filter buttons change the active filter" do
    click("#filter_active")
    assert model().filter == :active

    click("#filter_done")
    assert model().filter == :done

    click("#filter_all")
    assert model().filter == :all
  end
end
