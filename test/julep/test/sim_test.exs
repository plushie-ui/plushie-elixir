defmodule Julep.Test.SimTest do
  use ExUnit.Case, async: true

  alias Julep.Test.Backend.Sim
  alias Julep.Test.Element

  defmodule CounterApp do
    use Julep.App

    def init(_opts), do: %{count: 0}

    def update(model, {:click, "increment"}), do: %{model | count: model.count + 1}
    def update(model, {:click, "decrement"}), do: %{model | count: model.count - 1}
    def update(model, _event), do: model

    def view(model) do
      %{
        id: "root",
        type: "column",
        props: %{},
        children: [
          %{
            id: "count",
            type: "text",
            props: %{"content" => "Count: #{model.count}"},
            children: []
          },
          %{id: "increment", type: "button", props: %{"label" => "+"}, children: []},
          %{id: "decrement", type: "button", props: %{"label" => "-"}, children: []}
        ]
      }
    end
  end

  setup do
    {:ok, pid} = Sim.start(CounterApp)

    on_exit(fn ->
      if Process.alive?(pid), do: Sim.stop(pid)
    end)

    {:ok, pid: pid}
  end

  describe "find/2" do
    test "finds element by ID selector", %{pid: pid} do
      element = Sim.find(pid, "#count")
      assert %Element{} = element
      assert element.id == "count"
      assert element.type == "text"
    end

    test "returns nil for missing element", %{pid: pid} do
      assert Sim.find(pid, "#nonexistent") == nil
    end

    test "finds element by text content", %{pid: pid} do
      element = Sim.find(pid, "Count: 0")
      assert %Element{} = element
      assert element.id == "count"
    end
  end

  describe "find!/2" do
    test "returns element when found", %{pid: pid} do
      assert %Element{id: "increment"} = Sim.find!(pid, "#increment")
    end

    test "raises for missing element", %{pid: pid} do
      assert_raise RuntimeError, ~r/not found/, fn ->
        Sim.find!(pid, "#ghost")
      end
    end
  end

  describe "click/2" do
    test "clicking increment updates model", %{pid: pid} do
      Sim.click(pid, "#increment")
      assert Sim.model(pid).count == 1
    end

    test "clicking decrement updates model", %{pid: pid} do
      Sim.click(pid, "#decrement")
      assert Sim.model(pid).count == -1
    end

    test "multiple clicks accumulate", %{pid: pid} do
      Sim.click(pid, "#increment")
      Sim.click(pid, "#increment")
      Sim.click(pid, "#increment")
      assert Sim.model(pid).count == 3
    end

    test "mixed clicks accumulate correctly", %{pid: pid} do
      Sim.click(pid, "#increment")
      Sim.click(pid, "#increment")
      Sim.click(pid, "#decrement")
      assert Sim.model(pid).count == 1
    end
  end

  describe "model/1" do
    test "returns initial model", %{pid: pid} do
      assert Sim.model(pid) == %{count: 0}
    end

    test "returns updated model after interaction", %{pid: pid} do
      Sim.click(pid, "#increment")
      assert Sim.model(pid) == %{count: 1}
    end
  end

  describe "tree/1" do
    test "returns normalized tree with string keys", %{pid: pid} do
      tree = Sim.tree(pid)
      assert is_map(tree)
      assert tree["id"] || tree[:id]
    end

    test "tree reflects current model state", %{pid: pid} do
      Sim.click(pid, "#increment")
      tree = Sim.tree(pid)

      # Find the count text node in the tree
      count_node = find_node(tree, "count")
      assert count_node
      props = count_node[:props] || count_node["props"]
      assert props["content"] == "Count: 1"
    end
  end

  describe "reset/1" do
    test "restores initial state", %{pid: pid} do
      Sim.click(pid, "#increment")
      Sim.click(pid, "#increment")
      assert Sim.model(pid).count == 2

      Sim.reset(pid)
      assert Sim.model(pid).count == 0
    end

    test "tree reflects reset state", %{pid: pid} do
      Sim.click(pid, "#increment")
      Sim.reset(pid)

      element = Sim.find(pid, "#count")
      assert Element.text(element) == "Count: 0"
    end
  end

  describe "snapshot/2" do
    test "raises with clear message about backend requirement", %{pid: pid} do
      assert_raise RuntimeError, ~r/headless.*full/i, fn ->
        Sim.snapshot(pid, "my-snapshot")
      end
    end
  end

  # -- Helpers --

  defp find_node(nil, _id), do: nil

  defp find_node(%{} = node, id) do
    node_id = node[:id] || node["id"]

    if node_id == id do
      node
    else
      children = node[:children] || node["children"] || []
      Enum.find_value(children, &find_node(&1, id))
    end
  end
end
