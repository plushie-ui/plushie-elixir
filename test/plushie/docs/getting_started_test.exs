defmodule Plushie.Docs.GettingStartedTest do
  use ExUnit.Case, async: true

  # -- Types reproduced from the getting-started doc --

  defmodule Counter do
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
        column padding: 16, spacing: 8 do
          text("count", "Count: #{model.count}", size: 20)

          row spacing: 8 do
            button("increment", "+")
            button("decrement", "-")
          end
        end
      end
    end
  end

  # -- Tests --

  test "getting_started_counter_init_test" do
    model = Counter.init([])
    assert model.count == 0
  end

  test "getting_started_counter_increment_test" do
    model = Counter.init([])
    model = Counter.update(model, %Plushie.Event.WidgetEvent{type: :click, id: "increment"})
    assert model.count == 1
  end

  test "getting_started_counter_decrement_test" do
    model = Counter.init([])
    model = Counter.update(model, %Plushie.Event.WidgetEvent{type: :click, id: "decrement"})
    assert model.count == -1
  end

  test "getting_started_counter_unknown_event_test" do
    model = Counter.init([])
    model = Counter.update(model, %Plushie.Event.WidgetEvent{type: :click, id: "unknown"})
    assert model.count == 0
  end

  test "getting_started_counter_view_test" do
    model = Counter.init([])
    tree = Plushie.Tree.normalize(Counter.view(model))

    assert tree.type == "window"
    assert tree.id == "main"
    assert tree.props[:title] == "Counter"

    assert [column] = tree.children
    assert column.type == "column"
    assert column.props[:padding] == 16
    assert column.props[:spacing] == 8

    assert [text_node, row_node] = column.children
    assert text_node.type == "text"
    assert text_node.props[:content] == "Count: 0"
    assert text_node.props[:size] == 20

    assert row_node.type == "row"
    assert [inc, dec] = row_node.children
    assert inc.id == "increment"
    assert inc.props[:label] == "+"
    assert dec.id == "decrement"
    assert dec.props[:label] == "-"
  end

  test "getting_started_counter_view_after_increments_test" do
    model = Counter.init([])
    model = Counter.update(model, %Plushie.Event.WidgetEvent{type: :click, id: "increment"})
    model = Counter.update(model, %Plushie.Event.WidgetEvent{type: :click, id: "increment"})
    tree = Plushie.Tree.normalize(Counter.view(model))

    assert [column] = tree.children
    assert [text_node, _] = column.children
    assert text_node.props[:content] == "Count: 2"
  end
end
