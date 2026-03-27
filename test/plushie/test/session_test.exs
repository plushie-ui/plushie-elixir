defmodule Plushie.Automation.SessionTest do
  use Plushie.Test.Case, app: Plushie.Automation.SessionTest.CounterApp

  alias Plushie.Event.WidgetEvent

  defmodule CounterApp do
    use Plushie.App

    def init(_opts), do: %{count: 0}

    def update(model, %WidgetEvent{type: :click, id: "increment"}),
      do: %{model | count: model.count + 1}

    def update(model, %WidgetEvent{type: :click, id: "decrement"}),
      do: %{model | count: model.count - 1}

    def update(model, _event), do: model

    def view(model) do
      %{
        id: "main",
        type: "window",
        props: %{},
        children: [
          %{
            id: "auto:CounterApp:root",
            type: "column",
            props: %{},
            children: [
              %{
                id: "count",
                type: "text",
                props: %{content: "Count: #{model.count}"},
                children: []
              },
              %{id: "increment", type: "button", props: %{label: "+"}, children: []},
              %{id: "decrement", type: "button", props: %{label: "-"}, children: []}
            ]
          }
        ]
      }
    end
  end

  test "click and assert model" do
    click("#increment")
    assert model().count == 1
  end

  test "multiple clicks accumulate" do
    click("#increment")
    click("#increment")
    click("#decrement")
    assert model().count == 1
  end

  test "find returns element" do
    element = find("#count")
    assert element.id == "count"
    assert element.type == "text"
  end

  test "find returns nil for missing element" do
    assert find("#nonexistent") == nil
  end

  test "find! returns element when present" do
    assert find!("#increment").id == "increment"
  end

  test "find! raises for missing element" do
    assert_raise RuntimeError, ~r/not found/, fn ->
      find!("#ghost")
    end
  end

  test "text extracts content" do
    assert find!("#count") |> text() == "Count: 0"
  end

  test "text updates after interaction" do
    click("#increment")
    assert find!("#count") |> text() == "Count: 1"
  end

  test "assert_text passes for correct text" do
    assert_text("#count", "Count: 0")
  end

  test "assert_exists passes for existing element" do
    assert_exists("#increment")
  end

  test "assert_not_exists passes for missing element" do
    assert_not_exists("#phantom")
  end

  test "model returns current state" do
    assert model() == %{count: 0}
    click("#increment")
    assert model() == %{count: 1}
  end

  test "tree returns a map" do
    assert is_map(tree())
  end

  test "reset restores initial state" do
    click("#increment")
    click("#increment")
    assert model().count == 2

    reset()
    assert model().count == 0
  end
end
