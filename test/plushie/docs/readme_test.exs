defmodule Plushie.Docs.ReadmeTest do
  use ExUnit.Case, async: true

  # -- Types matching the README counter example --

  defmodule Counter do
    use Plushie.App

    alias Plushie.Event.WidgetEvent
    import Plushie.UI

    def init(_opts), do: %{count: 0}

    def update(model, %WidgetEvent{type: :click, id: "inc"}),
      do: %{model | count: model.count + 1}

    def update(model, %WidgetEvent{type: :click, id: "dec"}),
      do: %{model | count: model.count - 1}

    def update(model, _event), do: model

    def view(model) do
      window "main", title: "Counter" do
        column padding: 16, spacing: 8 do
          text("count", "Count: #{model.count}")

          row spacing: 8 do
            button("inc", "+")
            button("dec", "-")
          end
        end
      end
    end
  end

  # -- Tests --

  test "readme_counter_init_test" do
    model = Counter.init([])
    assert model.count == 0
  end

  test "readme_counter_increment_test" do
    model = Counter.init([])
    model = Counter.update(model, %Plushie.Event.WidgetEvent{type: :click, id: "inc"})
    assert model.count == 1
  end

  test "readme_counter_decrement_test" do
    model = Counter.init([])
    model = Counter.update(model, %Plushie.Event.WidgetEvent{type: :click, id: "dec"})
    assert model.count == -1
  end

  test "readme_counter_unknown_event_test" do
    model = Counter.init([])
    model = Counter.update(model, %Plushie.Event.WidgetEvent{type: :click, id: "nope"})
    assert model.count == 0
  end

  test "readme_counter_view_structure_test" do
    tree = Plushie.Tree.normalize(Counter.view(%{count: 0}))

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

    assert row_node.type == "row"
    assert [inc_btn, dec_btn] = row_node.children
    assert inc_btn.id == "inc"
    assert inc_btn.props[:label] == "+"
    assert dec_btn.id == "dec"
    assert dec_btn.props[:label] == "-"
  end

  test "readme_counter_view_after_increment_test" do
    tree = Plushie.Tree.normalize(Counter.view(%{count: 3}))
    assert [column] = tree.children
    assert [text_node, _] = column.children
    assert text_node.props[:content] == "Count: 3"
  end
end
