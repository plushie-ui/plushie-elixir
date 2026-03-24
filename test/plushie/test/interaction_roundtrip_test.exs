defmodule Plushie.Test.InteractionRoundtripTest do
  use ExUnit.Case, async: true

  alias Plushie.Event.Widget

  alias Plushie.Test.Backend.Runtime

  # A single app that has one of each interactive widget type and tracks every
  # event it receives in its model. This lets each test assert on what event
  # was dispatched and that the model was updated accordingly.
  defmodule TrackingApp do
    use Plushie.App

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
        id: "auto:TrackingApp:root",
        type: "column",
        props: %{},
        children: [
          %{id: "submit_btn", type: "button", props: %{label: "Submit"}, children: []},
          %{
            id: "name_input",
            type: "text_input",
            props: %{value: model.text_value, on_submit: true},
            children: []
          },
          %{
            id: "agree_check",
            type: "checkbox",
            props: %{label: "Agree", checked: model.checkbox_state},
            children: []
          },
          %{
            id: "dark_mode",
            type: "toggler",
            props: %{label: "Dark mode", is_toggled: model.toggler_state},
            children: []
          },
          %{
            id: "volume",
            type: "slider",
            props: %{value: model.slider_value, range: [0, 100]},
            children: []
          },
          %{
            id: "language",
            type: "pick_list",
            props: %{options: ["Elixir", "Erlang", "Gleam"], selected: model.selected},
            children: []
          }
        ]
      }
    end
  end

  setup do
    {:ok, pid} = Runtime.start(TrackingApp, pool: Plushie.TestPool)

    on_exit(fn ->
      if Process.alive?(pid), do: Runtime.stop(pid)
    end)

    {:ok, pid: pid}
  end

  # -- click -> %Widget{type: :click, id: id} --

  describe "click button" do
    test "dispatches %Widget{type: :click, id: id}", %{pid: pid} do
      Runtime.click(pid, "#submit_btn")
      assert Runtime.model(pid).last_event == %Widget{type: :click, id: "submit_btn"}
    end
  end

  # -- type_text -> {:input, id, text} --

  describe "type_text into text_input" do
    test "dispatches {:input, id, text}", %{pid: pid} do
      Runtime.type_text(pid, "#name_input", "Arthur")

      assert Runtime.model(pid).last_event == %Widget{
               type: :input,
               id: "name_input",
               value: "Arthur"
             }
    end

    test "model field updated with typed text", %{pid: pid} do
      Runtime.type_text(pid, "#name_input", "Zaphod")
      assert Runtime.model(pid).text_value == "Zaphod"
    end

    test "sequential inputs update model each time", %{pid: pid} do
      Runtime.type_text(pid, "#name_input", "first")
      assert Runtime.model(pid).text_value == "first"

      Runtime.type_text(pid, "#name_input", "second")
      assert Runtime.model(pid).text_value == "second"
    end
  end

  # -- toggle checkbox -> {:toggle, id, value} --

  describe "toggle checkbox" do
    test "sets checkbox to checked with explicit true", %{pid: pid} do
      Runtime.toggle(pid, "#agree_check", true)
      assert Runtime.model(pid).checkbox_state == true
    end

    test "sets checkbox to unchecked with explicit false", %{pid: pid} do
      Runtime.toggle(pid, "#agree_check", true)
      Runtime.toggle(pid, "#agree_check", false)
      assert Runtime.model(pid).checkbox_state == false
    end

    test "toggle without value negates current state", %{pid: pid} do
      Runtime.toggle(pid, "#agree_check")
      assert Runtime.model(pid).checkbox_state == true
      Runtime.toggle(pid, "#agree_check")
      assert Runtime.model(pid).checkbox_state == false
    end
  end

  # -- toggle toggler -> {:toggle, id, value} --

  describe "toggle toggler" do
    test "sets toggler on with explicit true", %{pid: pid} do
      Runtime.toggle(pid, "#dark_mode", true)
      assert Runtime.model(pid).toggler_state == true
    end

    test "sets toggler off with explicit false", %{pid: pid} do
      Runtime.toggle(pid, "#dark_mode", true)
      Runtime.toggle(pid, "#dark_mode", false)
      assert Runtime.model(pid).toggler_state == false
    end
  end

  # -- slide -> {:slide, id, value} --

  describe "slide slider" do
    test "dispatches {:slide, id, value}", %{pid: pid} do
      Runtime.slide(pid, "#volume", 80)
      assert Runtime.model(pid).last_event == %Widget{type: :slide, id: "volume", value: 80}
    end

    test "model field updated with slid value", %{pid: pid} do
      Runtime.slide(pid, "#volume", 42)
      assert Runtime.model(pid).slider_value == 42
    end

    test "accepts float values", %{pid: pid} do
      Runtime.slide(pid, "#volume", 66.6)
      assert Runtime.model(pid).slider_value == 66.6
    end
  end

  # -- submit text_input -> {:submit, id, value} --

  describe "submit text_input" do
    test "dispatches {:submit, id, value} with current value", %{pid: pid} do
      Runtime.type_text(pid, "#name_input", "Arthur")
      Runtime.submit(pid, "#name_input")

      assert Runtime.model(pid).last_event == %Widget{
               type: :submit,
               id: "name_input",
               value: "Arthur"
             }
    end

    test "submit with no value dispatches empty string", %{pid: pid} do
      Runtime.submit(pid, "#name_input")

      assert Runtime.model(pid).last_event == %Widget{
               type: :submit,
               id: "name_input",
               value: ""
             }
    end
  end

  # -- select pick_list -> {:select, id, value} --

  describe "select from pick_list" do
    test "dispatches {:select, id, value}", %{pid: pid} do
      Runtime.select(pid, "#language", "Elixir")

      assert Runtime.model(pid).last_event == %Widget{
               type: :select,
               id: "language",
               value: "Elixir"
             }
    end

    test "model field updated with selected value", %{pid: pid} do
      Runtime.select(pid, "#language", "Erlang")
      assert Runtime.model(pid).selected == "Erlang"
    end

    test "selecting a different value replaces the previous", %{pid: pid} do
      Runtime.select(pid, "#language", "Gleam")
      Runtime.select(pid, "#language", "Elixir")
      assert Runtime.model(pid).selected == "Elixir"
    end
  end
end
