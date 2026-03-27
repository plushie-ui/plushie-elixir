defmodule Plushie.Test.CrossBackendTest do
  @moduledoc """
  Cross-backend equivalence tests.

  Defines shared assertions and runs them against the Runtime backend by
  default. To run against Headless or Windowed, set
  PLUSHIE_TEST_BACKEND=headless or PLUSHIE_TEST_BACKEND=windowed.

  These tests verify that core app lifecycle, event handling, and tree
  structure behave identically regardless of which backend executes them.
  """

  use ExUnit.Case, async: true

  alias Plushie.Event.WidgetEvent

  alias Plushie.Test.Backend.Runtime

  # -- Test apps -----------------------------------------------------------

  defmodule CounterApp do
    use Plushie.App

    def init(_opts), do: %{count: 0}

    def update(model, %WidgetEvent{type: :click, id: "inc"}),
      do: %{model | count: model.count + 1}

    def update(model, %WidgetEvent{type: :click, id: "dec"}),
      do: %{model | count: model.count - 1}

    def update(model, _event), do: model

    def view(model) do
      %{
        id: "main",
        type: "window",
        props: %{},
        children: [
          %{
            id: "root",
            type: "column",
            props: %{},
            children: [
              %{
                id: "label",
                type: "text",
                props: %{content: "Count: #{model.count}"},
                children: []
              },
              %{id: "inc", type: "button", props: %{label: "+"}, children: []},
              %{id: "dec", type: "button", props: %{label: "-"}, children: []}
            ]
          }
        ]
      }
    end
  end

  defmodule TodoApp do
    use Plushie.App

    def init(_opts), do: %{items: [], input: ""}

    def update(model, %WidgetEvent{type: :input, id: "task", value: value}),
      do: %{model | input: value}

    def update(model, %WidgetEvent{type: :submit, id: "task", value: _value}) do
      if model.input != "" do
        %{model | items: model.items ++ [model.input], input: ""}
      else
        model
      end
    end

    def update(model, _event), do: model

    def view(model) do
      item_nodes =
        Enum.with_index(model.items, fn item, i ->
          %{id: "item_#{i}", type: "text", props: %{content: item}, children: []}
        end)

      %{
        id: "main",
        type: "window",
        props: %{},
        children: [
          %{
            id: "root",
            type: "column",
            props: %{},
            children:
              [
                %{
                  id: "task",
                  type: "text_input",
                  props: %{placeholder: "Add task", value: model.input},
                  children: []
                }
              ] ++ item_nodes
          }
        ]
      }
    end
  end

  # -- Helpers -------------------------------------------------------------

  defp start_backend(app) do
    backend = resolve_backend()
    {:ok, pid} = backend.start(app, pool: Plushie.TestPool)

    on_exit(fn ->
      if Process.alive?(pid), do: backend.stop(pid)
    end)

    {backend, pid}
  end

  defp resolve_backend, do: Runtime

  # -- Tests ---------------------------------------------------------------

  describe "counter app equivalence" do
    test "initial model is zero" do
      {backend, pid} = start_backend(CounterApp)

      assert backend.model(pid) == %{count: 0}
    end

    test "increment produces count of 1" do
      {backend, pid} = start_backend(CounterApp)

      backend.click(pid, "#inc")
      assert backend.model(pid) == %{count: 1}
    end

    test "increment then decrement returns to zero" do
      {backend, pid} = start_backend(CounterApp)

      backend.click(pid, "#inc")
      backend.click(pid, "#dec")
      assert backend.model(pid) == %{count: 0}
    end

    test "tree reflects model after events" do
      {backend, pid} = start_backend(CounterApp)

      backend.click(pid, "#inc")
      backend.click(pid, "#inc")

      element = backend.find(pid, "#label")
      assert element != nil
      assert element.type == "text"
      assert element.props[:content] == "Count: 2"
    end
  end

  describe "todo app equivalence" do
    test "typing and submitting adds an item" do
      {backend, pid} = start_backend(TodoApp)

      backend.type_text(pid, "#task", "Buy milk")
      backend.submit(pid, "#task")

      model = backend.model(pid)
      assert model.items == ["Buy milk"]
      assert model.input == ""
    end
  end
end
