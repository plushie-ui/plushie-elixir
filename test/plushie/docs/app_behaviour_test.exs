defmodule Plushie.Docs.AppBehaviourTest do
  use ExUnit.Case, async: true

  import Plushie.UI

  alias Plushie.Command
  alias Plushie.Event.WidgetEvent
  alias Plushie.Event.WindowEvent
  alias Plushie.Subscription

  # -- Types (shared across update/view/subscribe examples) --------------------

  defp new_model(overrides \\ %{}) do
    Map.merge(
      %{todos: [], input: "", filter: :all, auto_refresh: false, next_id: 1},
      overrides
    )
  end

  defp next_id(model), do: model.next_id

  # -- init examples -----------------------------------------------------------

  defp init(_opts) do
    %{todos: [], input: "", filter: :all}
  end

  defp init_with_command(_opts) do
    model = %{todos: [], loading: true}
    {model, Command.task(fn -> :loaded end, :todos_loaded)}
  end

  # -- update example ----------------------------------------------------------

  defp update(model, %WidgetEvent{type: :click, id: "add_todo"}) do
    new_todo = %{id: next_id(model), text: model.input, done: false}

    %{
      model
      | todos: [new_todo | model.todos],
        input: "",
        next_id: model.next_id + 1
    }
  end

  defp update(model, %WidgetEvent{type: :input, id: "todo_field", value: value}) do
    %{model | input: value}
  end

  defp update(model, %WidgetEvent{type: :submit, id: "todo_field"}) do
    new_todo = %{id: next_id(model), text: model.input, done: false}

    model = %{
      model
      | todos: [new_todo | model.todos],
        input: "",
        next_id: model.next_id + 1
    }

    {model, Command.focus("todo_field")}
  end

  defp update(model, _event), do: model

  # -- subscribe example -------------------------------------------------------

  defp subscribe(model) do
    subs = [Subscription.on_key_press()]

    if model.auto_refresh do
      [Subscription.every(5000, :refresh) | subs]
    else
      subs
    end
  end

  # -- settings example --------------------------------------------------------

  defp settings do
    [
      default_font: %{family: "monospace"},
      default_text_size: 16,
      antialiasing: true,
      fonts: ["priv/fonts/Inter.ttf"]
    ]
  end

  # -- window_config example ---------------------------------------------------

  defp window_config(_model) do
    %{
      title: "My App",
      width: 800,
      height: 600,
      min_size: %{width: 400, height: 300},
      resizable: true,
      theme: :dark
    }
  end

  # -- Tests -------------------------------------------------------------------

  test "app_behaviour_init_bare_model_test" do
    model = init([])
    assert model.todos == []
    assert model.input == ""
    assert model.filter == :all
  end

  test "app_behaviour_init_with_command_test" do
    {model, cmd} = init_with_command([])
    assert model.loading == true
    assert model.todos == []
    assert %Command{type: :task} = cmd
  end

  test "app_behaviour_update_add_todo_test" do
    model = new_model()
    model = update(model, %WidgetEvent{type: :input, id: "todo_field", value: "Buy milk"})
    assert model.input == "Buy milk"

    model = update(model, %WidgetEvent{type: :click, id: "add_todo"})
    assert model.input == ""
    assert [item] = model.todos
    assert item.text == "Buy milk"
    assert item.done == false
  end

  test "app_behaviour_update_submit_returns_focus_test" do
    model = new_model()
    model = update(model, %WidgetEvent{type: :input, id: "todo_field", value: "Walk dog"})

    {model, cmd} =
      update(model, %WidgetEvent{type: :submit, id: "todo_field", value: "Walk dog"})

    assert model.input == ""
    assert [item] = model.todos
    assert item.text == "Walk dog"
    assert cmd == Command.focus("todo_field")
  end

  test "app_behaviour_update_unknown_event_test" do
    model = new_model()
    model = update(model, %WidgetEvent{type: :click, id: "unknown"})
    assert model.todos == []
  end

  test "app_behaviour_view_basic_structure_test" do
    # Reproduces the view/1 example from the doc.
    # Uses a fixed model rather than calling model functions.
    model = %{input: "Buy milk", todos: [%{id: "todo_1", text: "Walk dog", done: false}]}

    tree =
      window "main", title: "Todos" do
        column padding: 16, spacing: 8 do
          row spacing: 8 do
            text_input("todo_field", model.input, placeholder: "What needs doing?")
            button("add_todo", "Add")
          end

          for todo <- model.todos do
            row id: todo.id, spacing: 8 do
              checkbox("toggle", todo.done)
              text(todo.text)
            end
          end
        end
      end

    normalized = Plushie.Tree.normalize(tree)
    assert normalized.type == "window"
    assert normalized.id == "main"
    assert normalized.props[:title] == "Todos"

    [col] = normalized.children
    assert col.type == "column"

    [input_row, todo_row] = col.children
    assert input_row.type == "row"

    [input, btn] = input_row.children
    assert input.type == "text_input"
    assert input.props[:value] == "Buy milk"
    assert btn.type == "button"
    assert btn.props[:label] == "Add"

    assert todo_row.type == "row"
    assert todo_row.id == "main#todo_1"
  end

  test "app_behaviour_subscribe_without_auto_refresh_test" do
    model = new_model(%{auto_refresh: false})
    subs = subscribe(model)
    assert [sub] = subs
    assert sub == Subscription.on_key_press()
  end

  test "app_behaviour_subscribe_with_auto_refresh_test" do
    model = new_model(%{auto_refresh: true})
    subs = subscribe(model)
    assert [timer, key_sub] = subs
    assert timer == Subscription.every(5000, :refresh)
    assert key_sub == Subscription.on_key_press()
  end

  test "app_behaviour_settings_test" do
    s = settings()
    assert s[:default_text_size] == 16
    assert s[:antialiasing] == true
    assert s[:fonts] == ["priv/fonts/Inter.ttf"]
    assert s[:default_font] == %{family: "monospace"}
  end

  test "app_behaviour_default_settings_test" do
    # Default settings is an empty keyword list
    assert settings() |> Keyword.keyword?()
  end

  test "app_behaviour_window_config_returns_map_test" do
    model = new_model()
    config = window_config(model)
    assert config.title == "My App"
    assert config.width == 800
    assert config.height == 600
    assert config.resizable == true
    assert config.theme == :dark
  end

  test "app_behaviour_window_command_set_window_mode_test" do
    cmd = Command.set_window_mode("main", :fullscreen)
    assert %Command{type: :window_op} = cmd
    assert cmd.payload.window_id == "main"
    assert cmd.payload.mode == "fullscreen"
  end

  test "app_behaviour_window_close_command_test" do
    cmd = Command.close_window("main")
    assert %Command{type: :window_op, payload: %{op: "close"}} = cmd
    assert cmd.payload.window_id == "main"
  end

  test "app_behaviour_window_events_close_requested_test" do
    model = %{inspector_open: true}

    model =
      case %WindowEvent{type: :close_requested, window_id: "inspector"} do
        %WindowEvent{type: :close_requested, window_id: "inspector"} ->
          %{model | inspector_open: false}
      end

    assert model.inspector_open == false
  end

  test "app_behaviour_window_events_resized_test" do
    model = %{window_size: {0, 0}}

    model =
      case %WindowEvent{type: :resized, window_id: "main", width: 1024, height: 768} do
        %WindowEvent{type: :resized, window_id: "main", width: width, height: height} ->
          %{model | window_size: {width, height}}
      end

    assert model.window_size == {1024, 768}
  end

  test "app_behaviour_window_events_focused_test" do
    model = %{active_window: nil}

    model =
      case %WindowEvent{type: :focused, window_id: "editor"} do
        %WindowEvent{type: :focused, window_id: window_id} ->
          %{model | active_window: window_id}
      end

    assert model.active_window == "editor"
  end

  test "app_behaviour_dialog_window_test" do
    dialog =
      window "confirm",
        title: "Confirm",
        size: {300, 150},
        resizable: false,
        level: :always_on_top do
        column padding: 16, spacing: 12 do
          text("prompt", "Are you sure?")

          row spacing: 8 do
            button("confirm_yes", "Yes")
            button("confirm_no", "No")
          end
        end
      end

    normalized = Plushie.Tree.normalize(dialog)
    assert normalized.type == "window"
    assert normalized.id == "confirm"

    [col] = normalized.children
    [prompt, btns] = col.children
    assert prompt.props[:content] == "Are you sure?"

    [yes, no] = btns.children
    assert yes.props[:label] == "Yes"
    assert no.props[:label] == "No"
  end
end
