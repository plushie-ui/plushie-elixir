# App modules shared across both test modules below.

defmodule Plushie.Docs.TestingDocTest.Todo do
  defstruct [:text, done: false]
end

defmodule Plushie.Docs.TestingDocTest.TodoApp do
  use Plushie.App

  alias Plushie.Docs.TestingDocTest.Todo
  alias Plushie.Event.WidgetEvent

  def init(_opts), do: %{todos: [], input: ""}

  def update(model, %WidgetEvent{type: :input, id: "todo_input", value: val}),
    do: %{model | input: val}

  def update(model, %WidgetEvent{type: :submit, id: "todo_input", value: val}) do
    {
      %{model | todos: model.todos ++ [%Todo{text: val}], input: ""},
      Plushie.Command.focus("todo_input")
    }
  end

  def update(model, %WidgetEvent{type: :click, id: "add_todo"}) do
    %{model | todos: model.todos ++ [%Todo{text: model.input}], input: ""}
  end

  def update(model, _event), do: model

  def view(model) do
    import Plushie.UI

    window "main" do
      column spacing: 8 do
        text_input("todo_input", model.input)
        button("add_todo", "Add")
        text("todo_count", "#{length(model.todos)}")
      end
    end
  end
end

defmodule Plushie.Docs.TestingDocTest.CounterApp do
  use Plushie.App

  alias Plushie.Event.WidgetEvent

  def init(_opts), do: %{count: 0}

  def update(model, %WidgetEvent{type: :click, id: "increment"}),
    do: %{model | count: model.count + 1}

  def update(model, %WidgetEvent{type: :click, id: "decrement"}),
    do: %{model | count: model.count - 1}

  def update(model, _event), do: model

  def view(model) do
    import Plushie.UI

    window "main", title: "Counter" do
      column spacing: 8 do
        text("count", "#{model.count}")
        button("increment", "+")
        button("decrement", "-")
      end
    end
  end
end

defmodule Plushie.Docs.TestingDocTest.SaveApp do
  use Plushie.App

  alias Plushie.Event.WidgetEvent

  def init(_opts), do: %{data: "unsaved"}

  def update(model, %WidgetEvent{type: :click, id: "save"}) do
    {model, Plushie.Command.async(fn -> :ok end, :save_result)}
  end

  def update(model, _event), do: model

  def view(_model) do
    import Plushie.UI

    window "main" do
      button("save", "Save")
    end
  end
end

# ============================================================================
# Pure unit tests (no backend required)
# ============================================================================

defmodule Plushie.Docs.TestingDocTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Plushie.Docs.TestingDocTest.CounterApp
  alias Plushie.Docs.TestingDocTest.SaveApp
  alias Plushie.Docs.TestingDocTest.Todo
  alias Plushie.Docs.TestingDocTest.TodoApp

  # -- Testing update/2 -------------------------------------------------------

  test "testing_doc_adding_a_todo_appends_and_clears_input_test" do
    model = %{todos: [], input: "Buy milk"}
    model = TodoApp.update(model, %Plushie.Event.WidgetEvent{type: :click, id: "add_todo"})

    assert [%Todo{text: "Buy milk", done: false}] = model.todos
    assert model.input == ""
  end

  # -- Testing commands --------------------------------------------------------

  test "testing_doc_submitting_todo_returns_focus_command_test" do
    model = %{todos: [], input: "Buy milk"}

    {model, cmd} =
      TodoApp.update(model, %Plushie.Event.WidgetEvent{
        type: :submit,
        id: "todo_input",
        value: "Buy milk"
      })

    assert [%Todo{text: "Buy milk"}] = model.todos
    assert %Plushie.Command{type: :focus, payload: %{target: "todo_input"}} = cmd
  end

  test "testing_doc_save_triggers_async_task_test" do
    model = %{data: "unsaved"}
    {_model, cmd} = SaveApp.update(model, %Plushie.Event.WidgetEvent{type: :click, id: "save"})

    assert %Plushie.Command{type: :async, payload: %{tag: :save_result}} = cmd
  end

  # -- Testing view/1 ---------------------------------------------------------

  test "testing_doc_view_shows_todo_count_test" do
    model = %{todos: [%Todo{text: "Buy milk", done: false}], input: ""}
    tree = Plushie.Tree.normalize(TodoApp.view(model))

    counter = Plushie.Tree.find(tree, "todo_count")
    assert counter != nil
    assert counter.props[:content] =~ "1"
  end

  # -- Testing init/1 ---------------------------------------------------------

  test "testing_doc_init_returns_valid_initial_state_test" do
    model = TodoApp.init([])

    assert is_list(model.todos)
    assert model.input == ""
  end

  # -- Tree query helpers ------------------------------------------------------

  test "testing_doc_tree_find_test" do
    tree = Plushie.Tree.normalize(CounterApp.view(%{count: 0}))

    assert Plushie.Tree.find(tree, "count") != nil
    assert Plushie.Tree.exists?(tree, "increment")
    assert Plushie.Tree.exists?(tree, "count")
  end

  test "testing_doc_tree_ids_test" do
    tree = Plushie.Tree.normalize(CounterApp.view(%{count: 0}))
    all_ids = Plushie.Tree.ids(tree)

    assert "increment" in all_ids
    assert "decrement" in all_ids
    assert "count" in all_ids
  end

  test "testing_doc_tree_find_all_test" do
    tree = Plushie.Tree.normalize(CounterApp.view(%{count: 0}))
    buttons = Plushie.Tree.find_all(tree, fn node -> node.type == "button" end)

    assert length(buttons) == 2
  end
end

# ============================================================================
# Framework tests (uses real backend via Plushie.Test.Case)
# ============================================================================

defmodule Plushie.Docs.TestingDocFrameworkTest do
  @moduledoc false

  use Plushie.Test.Case, app: Plushie.Docs.TestingDocTest.CounterApp

  # -- Test framework: clicking increment --------------------------------------

  test "testing_doc_clicking_increment_updates_counter_test" do
    click("#increment")
    assert_text("#count", "1")
  end

  # -- Element handles ---------------------------------------------------------

  test "testing_doc_element_handle_test" do
    element = find!("#increment")
    assert element.id == "increment"
    assert element.type == "button"
    assert is_map(element.props)
    assert is_list(element.children)
  end

  # -- Assertions --------------------------------------------------------------

  test "testing_doc_text_content_assertion_test" do
    click("#increment")
    click("#increment")
    assert_text("#count", "2")
  end

  test "testing_doc_existence_assertion_test" do
    assert_exists("#increment")
    assert_not_exists("#admin-panel")
  end

  test "testing_doc_model_assertion_test" do
    click("#increment")
    assert model().count == 1
  end

  # -- Element not found -------------------------------------------------------

  test "testing_doc_find_nonexistent_returns_none_test" do
    assert find("#nonexistent") == nil
  end
end
