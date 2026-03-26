defmodule CounterTest do
  use ExUnit.Case, async: true

  alias Plushie.Event.WidgetEvent

  alias Counter

  # ---------------------------------------------------------------------------
  # init/1
  # ---------------------------------------------------------------------------

  describe "init/1" do
    test "returns initial model with count 0" do
      assert Counter.init([]) == %{count: 0}
    end

    test "returns initial model regardless of opts" do
      assert Counter.init(nil) == %{count: 0}
    end
  end

  # ---------------------------------------------------------------------------
  # update/2
  # ---------------------------------------------------------------------------

  describe "update/2 -- increment" do
    test "increments count by 1" do
      model = %{count: 0}
      result = Counter.update(model, %WidgetEvent{type: :click, id: "increment"})
      assert result.count == 1
    end

    test "increments from a non-zero count" do
      model = %{count: 4}
      result = Counter.update(model, %WidgetEvent{type: :click, id: "increment"})
      assert result.count == 5
    end
  end

  describe "update/2 -- decrement" do
    test "decrements count by 1" do
      model = %{count: 3}
      result = Counter.update(model, %WidgetEvent{type: :click, id: "decrement"})
      assert result.count == 2
    end

    test "decrements below zero" do
      model = %{count: 0}
      result = Counter.update(model, %WidgetEvent{type: :click, id: "decrement"})
      assert result.count == -1
    end
  end

  describe "update/2 -- unknown event" do
    test "returns model unchanged for unknown event tuple" do
      model = %{count: 7}
      result = Counter.update(model, %WidgetEvent{type: :click, id: "something_else"})
      assert result == model
    end

    test "returns model unchanged for unrecognized event type" do
      model = %{count: 2}
      result = Counter.update(model, %WidgetEvent{type: :input, id: "name", value: "Alice"})
      assert result == model
    end

    test "returns model unchanged for bare atom event" do
      model = %{count: 0}
      result = Counter.update(model, :tick)
      assert result == model
    end
  end

  # ---------------------------------------------------------------------------
  # view/1
  # ---------------------------------------------------------------------------

  describe "view/1 -- tree structure" do
    test "returns a window node at the root" do
      tree = Counter.view(%{count: 0})
      assert tree.type == "window"
      assert tree.id == "main"
    end

    test "window has a title prop" do
      tree = Counter.view(%{count: 0})
      assert is_binary(tree.props[:title])
    end

    test "window contains a column as direct child" do
      tree = Counter.view(%{count: 0})
      assert length(tree.children) == 1
      col = hd(tree.children)
      assert col.type == "column"
    end

    test "column has padding and spacing props" do
      tree = Counter.view(%{count: 0})
      col = hd(tree.children)
      assert is_integer(col.props[:padding]) or col.props[:padding] != nil
      assert is_integer(col.props[:spacing]) or col.props[:spacing] != nil
    end

    test "increment button is present in the tree" do
      tree = Counter.view(%{count: 0})
      inc = Plushie.UI.find(tree, "increment")
      assert inc != nil
      assert inc.type == "button"
    end

    test "decrement button is present in the tree" do
      tree = Counter.view(%{count: 0})
      dec = Plushie.UI.find(tree, "decrement")
      assert dec != nil
      assert dec.type == "button"
    end
  end

  describe "view/1 -- count display" do
    test "view with count 0 contains \"Count: 0\" text node" do
      tree = Counter.view(%{count: 0})
      text_nodes = Plushie.Tree.find_all(tree, fn n -> n.type == "text" end)
      match = Enum.find(text_nodes, fn n -> n.props[:content] == "Count: 0" end)
      assert match != nil
    end

    test "view with count 5 contains \"Count: 5\" text node" do
      tree = Counter.view(%{count: 5})
      text_nodes = Plushie.Tree.find_all(tree, fn n -> n.type == "text" end)
      match = Enum.find(text_nodes, fn n -> n.props[:content] == "Count: 5" end)
      assert match != nil
    end

    test "view with negative count displays correctly" do
      tree = Counter.view(%{count: -3})
      text_nodes = Plushie.Tree.find_all(tree, fn n -> n.type == "text" end)
      match = Enum.find(text_nodes, fn n -> n.props[:content] == "Count: -3" end)
      assert match != nil
    end
  end

  # ---------------------------------------------------------------------------
  # Full cycle
  # ---------------------------------------------------------------------------

  describe "full cycle" do
    test "init -> increment 3x -> decrement 1x -> view shows Count: 2" do
      model =
        Counter.init([])
        |> Counter.update(%WidgetEvent{type: :click, id: "increment"})
        |> Counter.update(%WidgetEvent{type: :click, id: "increment"})
        |> Counter.update(%WidgetEvent{type: :click, id: "increment"})
        |> Counter.update(%WidgetEvent{type: :click, id: "decrement"})

      assert model.count == 2

      tree = Counter.view(model)
      text_nodes = Plushie.Tree.find_all(tree, fn n -> n.type == "text" end)
      match = Enum.find(text_nodes, fn n -> n.props[:content] == "Count: 2" end)
      assert match != nil
    end
  end
end
