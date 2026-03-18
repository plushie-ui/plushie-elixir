defmodule Julep.Test.InteractionRoundtripTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Julep.Event.Widget

  alias Julep.Test.Backend.Mock

  # A single app that has one of each interactive widget type and tracks every
  # event it receives in its model. This lets each test assert on what event
  # was dispatched and that the model was updated accordingly.
  defmodule TrackingApp do
    use Julep.App

    def init(_opts) do
      %{
        last_event: nil,
        text_value: "",
        checkbox_state: false,
        toggler_state: false,
        slider_value: 0,
        selected: nil
      }
    end

    def update(model, %Widget{type: :click, id: "submit_btn"} = event) do
      %{model | last_event: event}
    end

    def update(model, %Widget{type: :input, id: "name_input", value: text} = event) do
      %{model | last_event: event, text_value: text}
    end

    def update(model, %Widget{type: :toggle, id: "agree_check", value: value} = event) do
      %{model | last_event: event, checkbox_state: value}
    end

    def update(model, %Widget{type: :toggle, id: "dark_mode", value: value} = event) do
      %{model | last_event: event, toggler_state: value}
    end

    def update(model, %Widget{type: :slide, id: "volume", value: value} = event) do
      %{model | last_event: event, slider_value: value}
    end

    def update(model, %Widget{type: :select, id: "language", value: value} = event) do
      %{model | last_event: event, selected: value}
    end

    def update(model, %Widget{type: :submit, id: "name_input", value: value} = event) do
      %{model | last_event: event, text_value: value}
    end

    def update(model, _event), do: model

    def view(model) do
      %{
        id: "root",
        type: "column",
        props: %{},
        children: [
          %{id: "submit_btn", type: "button", props: %{"label" => "Submit"}, children: []},
          %{
            id: "name_input",
            type: "text_input",
            props: %{"value" => model.text_value, "on_submit" => true},
            children: []
          },
          %{
            id: "agree_check",
            type: "checkbox",
            props: %{"label" => "Agree", "is_checked" => model.checkbox_state},
            children: []
          },
          %{
            id: "dark_mode",
            type: "toggler",
            props: %{"label" => "Dark mode", "is_toggled" => model.toggler_state},
            children: []
          },
          %{
            id: "volume",
            type: "slider",
            props: %{"value" => model.slider_value, "range" => [0, 100]},
            children: []
          },
          %{
            id: "language",
            type: "pick_list",
            props: %{"options" => ["Elixir", "Erlang", "Gleam"], "selected" => model.selected},
            children: []
          }
        ]
      }
    end
  end

  setup do
    {:ok, pid} = Mock.start(TrackingApp)

    on_exit(fn ->
      if Process.alive?(pid), do: Mock.stop(pid)
    end)

    {:ok, pid: pid}
  end

  # -- click -> %Widget{type: :click, id: id} --

  describe "click button" do
    test "dispatches %Widget{type: :click, id: id}", %{pid: pid} do
      Mock.click(pid, "#submit_btn")
      assert Mock.model(pid).last_event == %Widget{type: :click, id: "submit_btn"}
    end
  end

  # -- type_text -> {:input, id, text} --

  describe "type_text into text_input" do
    test "dispatches {:input, id, text}", %{pid: pid} do
      Mock.type_text(pid, "#name_input", "Arthur")

      assert Mock.model(pid).last_event == %Widget{
               type: :input,
               id: "name_input",
               value: "Arthur"
             }
    end

    test "model field updated with typed text", %{pid: pid} do
      Mock.type_text(pid, "#name_input", "Zaphod")
      assert Mock.model(pid).text_value == "Zaphod"
    end

    test "sequential inputs update model each time", %{pid: pid} do
      Mock.type_text(pid, "#name_input", "first")
      assert Mock.model(pid).text_value == "first"

      Mock.type_text(pid, "#name_input", "second")
      assert Mock.model(pid).text_value == "second"
    end
  end

  # -- toggle checkbox -> {:toggle, id, value} --

  describe "toggle checkbox" do
    test "dispatches {:toggle, id, value} from unchecked state", %{pid: pid} do
      # Initial state: checkbox_state = false, prop is_checked = false
      Mock.toggle(pid, "#agree_check")
      assert Mock.model(pid).last_event == %Widget{type: :toggle, id: "agree_check", value: true}
    end

    test "model field flips to true on first toggle", %{pid: pid} do
      Mock.toggle(pid, "#agree_check")
      assert Mock.model(pid).checkbox_state == true
    end

    test "model field flips back to false on second toggle", %{pid: pid} do
      Mock.toggle(pid, "#agree_check")
      Mock.toggle(pid, "#agree_check")
      assert Mock.model(pid).checkbox_state == false
    end
  end

  # -- toggle toggler -> {:toggle, id, value} --

  describe "toggle toggler" do
    test "dispatches {:toggle, id, value} from off state", %{pid: pid} do
      Mock.toggle(pid, "#dark_mode")
      assert Mock.model(pid).last_event == %Widget{type: :toggle, id: "dark_mode", value: true}
    end

    test "model field reflects new toggler state", %{pid: pid} do
      Mock.toggle(pid, "#dark_mode")
      assert Mock.model(pid).toggler_state == true
    end
  end

  # -- slide -> {:slide, id, value} --

  describe "slide slider" do
    test "dispatches {:slide, id, value}", %{pid: pid} do
      Mock.slide(pid, "#volume", 80)
      assert Mock.model(pid).last_event == %Widget{type: :slide, id: "volume", value: 80}
    end

    test "model field updated with slid value", %{pid: pid} do
      Mock.slide(pid, "#volume", 42)
      assert Mock.model(pid).slider_value == 42
    end

    test "accepts float values", %{pid: pid} do
      Mock.slide(pid, "#volume", 66.6)
      assert Mock.model(pid).slider_value == 66.6
    end
  end

  # -- select pick_list -> {:select, id, value} --

  describe "select from pick_list" do
    test "dispatches {:select, id, value}", %{pid: pid} do
      Mock.select(pid, "#language", "Elixir")
      assert Mock.model(pid).last_event == %Widget{type: :select, id: "language", value: "Elixir"}
    end

    test "model field updated with selected value", %{pid: pid} do
      Mock.select(pid, "#language", "Erlang")
      assert Mock.model(pid).selected == "Erlang"
    end

    test "selecting a different value replaces the previous", %{pid: pid} do
      Mock.select(pid, "#language", "Gleam")
      Mock.select(pid, "#language", "Elixir")
      assert Mock.model(pid).selected == "Elixir"
    end
  end

  # -- submit text_input -> {:submit, id, value} --

  describe "submit text_input" do
    test "dispatches {:submit, id, value} with current value", %{pid: pid} do
      # First type something so there's a value in the model and view prop.
      Mock.type_text(pid, "#name_input", "Marvin")
      Mock.submit(pid, "#name_input")

      assert Mock.model(pid).last_event == %Widget{
               type: :submit,
               id: "name_input",
               value: "Marvin"
             }
    end

    test "submit with no value dispatches empty string", %{pid: pid} do
      Mock.submit(pid, "#name_input")
      assert Mock.model(pid).last_event == %Widget{type: :submit, id: "name_input", value: ""}
    end
  end

  # -- error cases --
  #
  # When an interaction fails, the Mock GenServer raises and the GenServer.call
  # exits the calling process. catch_exit/1 captures it. The exit reason is
  # a 2-tuple of `{exception_and_stacktrace, call_info}` where the first
  # element is itself `{RuntimeError, stacktrace}`.

  defp exit_message(exit_reason) do
    case exit_reason do
      {{%RuntimeError{message: msg}, _stacktrace}, _call} -> msg
      {%RuntimeError{message: msg}, _stacktrace} -> msg
      _ -> inspect(exit_reason)
    end
  end

  describe "interaction errors" do
    test "click on non-button exits with cannot-click error" do
      capture_log(fn ->
        {:ok, pid} = Mock.start(TrackingApp)
        result = catch_exit(Mock.click(pid, "#name_input"))
        assert exit_message(result) =~ "cannot click"
      end)
    end

    test "type_text on non-input exits with cannot-type error" do
      capture_log(fn ->
        {:ok, pid} = Mock.start(TrackingApp)
        result = catch_exit(Mock.type_text(pid, "#submit_btn", "text"))
        assert exit_message(result) =~ "cannot type"
      end)
    end

    test "toggle on non-toggleable exits with cannot-toggle error" do
      capture_log(fn ->
        {:ok, pid} = Mock.start(TrackingApp)
        result = catch_exit(Mock.toggle(pid, "#volume"))
        assert exit_message(result) =~ "cannot toggle"
      end)
    end

    test "slide on non-slider exits with cannot-slide error" do
      capture_log(fn ->
        {:ok, pid} = Mock.start(TrackingApp)
        result = catch_exit(Mock.slide(pid, "#submit_btn", 50))
        assert exit_message(result) =~ "cannot slide"
      end)
    end

    test "interacting with missing element exits with not-found error" do
      capture_log(fn ->
        {:ok, pid} = Mock.start(TrackingApp)
        result = catch_exit(Mock.click(pid, "#ghost"))
        assert exit_message(result) =~ "not found"
      end)
    end
  end
end
