defmodule Plushie.TreePropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Plushie.Tree

  # -- Generators -------------------------------------------------------------

  # Generates a random widget type string.
  defp type_gen do
    StreamData.member_of(~w(container column row text button checkbox toggler))
  end

  # Generates a random prop value.
  defp prop_value_gen do
    StreamData.one_of([
      StreamData.string(:alphanumeric, min_length: 0, max_length: 10),
      StreamData.integer(-100..100),
      StreamData.boolean(),
      StreamData.float(min: -100.0, max: 100.0)
    ])
  end

  # Generates a random props map with 0-3 entries.
  defp props_gen do
    keys = StreamData.member_of(~w(label content size width height spacing padding)a)

    StreamData.map_of(keys, prop_value_gen(), min_length: 0, max_length: 3)
  end

  # Generates a tree node with unique IDs, bounded depth and width.
  defp tree_node_gen(max_depth) do
    StreamData.bind(type_gen(), fn type ->
      StreamData.bind(props_gen(), fn props ->
        build_node_gen(type, props, max_depth)
      end)
    end)
  end

  defp build_node_gen(type, props, max_depth) when max_depth <= 0 do
    id = make_ref() |> :erlang.ref_to_list() |> List.to_string()
    StreamData.constant(%{id: id, type: type, props: props, children: []})
  end

  defp build_node_gen(type, props, max_depth) do
    children_gen = StreamData.list_of(tree_node_gen(max_depth - 1), min_length: 0, max_length: 4)

    StreamData.bind(children_gen, fn children ->
      id = make_ref() |> :erlang.ref_to_list() |> List.to_string()
      StreamData.constant(%{id: id, type: type, props: props, children: children})
    end)
  end

  # Generates a pair of trees that share some structure (to make diffs
  # interesting). Starts with a random tree and applies random mutations.
  defp tree_pair_gen do
    StreamData.bind(tree_node_gen(2), fn base ->
      StreamData.bind(mutate_tree_gen(base), fn mutated ->
        StreamData.constant({base, mutated})
      end)
    end)
  end

  # Generates a mutated version of a tree by applying random changes.
  defp mutate_tree_gen(tree) do
    StreamData.bind(StreamData.integer(0..3), fn mutation_count ->
      Enum.reduce(1..max(mutation_count, 1), StreamData.constant(tree), fn _, gen ->
        StreamData.bind(gen, fn current ->
          apply_random_mutation_gen(current)
        end)
      end)
    end)
  end

  # Applies a single random mutation to a tree.
  defp apply_random_mutation_gen(tree) do
    StreamData.bind(StreamData.integer(0..4), fn choice ->
      apply_mutation(tree, choice)
    end)
  end

  defp apply_mutation(tree, 0) do
    StreamData.bind(props_gen(), fn new_props ->
      StreamData.constant(%{tree | props: Map.merge(tree.props, new_props)})
    end)
  end

  defp apply_mutation(tree, 1) do
    StreamData.bind(tree_node_gen(0), fn new_child ->
      StreamData.constant(%{tree | children: tree.children ++ [new_child]})
    end)
  end

  defp apply_mutation(%{children: []} = tree, 2), do: StreamData.constant(tree)

  defp apply_mutation(tree, 2) do
    StreamData.bind(StreamData.integer(0..max(length(tree.children) - 1, 0)), fn idx ->
      StreamData.constant(%{tree | children: List.delete_at(tree.children, idx)})
    end)
  end

  defp apply_mutation(tree, 3), do: mutate_random_child_gen(tree)

  defp apply_mutation(tree, 4) when length(tree.children) < 2, do: StreamData.constant(tree)
  defp apply_mutation(tree, 4), do: StreamData.constant(%{tree | children: Enum.shuffle(tree.children)})

  defp mutate_random_child_gen(%{children: []} = tree), do: StreamData.constant(tree)

  defp mutate_random_child_gen(tree) do
    StreamData.bind(StreamData.integer(0..max(length(tree.children) - 1, 0)), fn idx ->
      child = Enum.at(tree.children, idx)

      StreamData.bind(apply_random_mutation_gen(child), fn mutated_child ->
        StreamData.constant(%{tree | children: List.replace_at(tree.children, idx, mutated_child)})
      end)
    end)
  end

  # -- Diff application -------------------------------------------------------

  # Applies a list of diff ops to a tree sequentially.
  # The diff algorithm emits ops in the correct application order:
  # removes (descending index) then updates then inserts (ascending).
  defp apply_ops(tree, ops) do
    Enum.reduce(ops, tree, fn op, acc ->
      apply_single_op(acc, op)
    end)
  end

  defp apply_single_op(_tree, %{op: "replace_node", path: [], node: new_node}), do: new_node

  defp apply_single_op(tree, %{op: "replace_node", path: path, node: new_node}) do
    set_at_path(tree, path, new_node)
  end

  defp apply_single_op(tree, %{op: "update_props", path: path, props: new_props}) do
    update_at_path(tree, path, fn node ->
      merged =
        Enum.reduce(new_props, node.props, fn
          {k, nil}, props -> Map.delete(props, k)
          {k, v}, props -> Map.put(props, k, v)
        end)

      %{node | props: merged}
    end)
  end

  defp apply_single_op(tree, %{op: "remove_child", path: path, index: index}) do
    update_at_path(tree, path, fn node ->
      %{node | children: List.delete_at(node.children, index)}
    end)
  end

  defp apply_single_op(tree, %{op: "insert_child", path: path, index: index, node: new_node}) do
    update_at_path(tree, path, fn node ->
      %{node | children: List.insert_at(node.children, index, new_node)}
    end)
  end

  # Navigate to a node at the given child-index path and apply a function.
  defp update_at_path(tree, [], fun), do: fun.(tree)

  defp update_at_path(tree, [idx | rest], fun) do
    child = Enum.at(tree.children, idx)
    updated_child = update_at_path(child, rest, fun)
    %{tree | children: List.replace_at(tree.children, idx, updated_child)}
  end

  # Set the node at a path to a new value.
  defp set_at_path(_tree, [], new_node), do: new_node

  defp set_at_path(tree, [idx | rest], new_node) do
    child = Enum.at(tree.children, idx)
    updated_child = set_at_path(child, rest, new_node)
    %{tree | children: List.replace_at(tree.children, idx, updated_child)}
  end

  # Strips any fields beyond :id, :type, :props, :children for comparison.
  defp normalize_for_compare(tree) do
    %{
      id: tree.id,
      type: tree.type,
      props: tree.props,
      children: Enum.map(tree.children, &normalize_for_compare/1)
    }
  end

  # -- Properties -------------------------------------------------------------

  describe "diff/2 round-trip" do
    property "applying diff ops to old tree yields new tree" do
      check all({old_tree, new_tree} <- tree_pair_gen(), max_runs: 200) do
        ops = Tree.diff(old_tree, new_tree)
        patched = apply_ops(old_tree, ops)
        assert normalize_for_compare(patched) == normalize_for_compare(new_tree)
      end
    end

    property "identical trees produce no ops" do
      check all(tree <- tree_node_gen(2), max_runs: 100) do
        assert Tree.diff(tree, tree) == []
      end
    end

    property "diff from nil to tree produces a single replace_node" do
      check all(tree <- tree_node_gen(1), max_runs: 50) do
        ops = Tree.diff(nil, tree)
        assert length(ops) == 1
        assert hd(ops).op == "replace_node"
        assert hd(ops).path == []
        assert hd(ops).node == tree
      end
    end

    property "prop-only changes produce update_props ops (no structural changes)" do
      check all(tree <- tree_node_gen(1), new_props <- props_gen(), max_runs: 100) do
        new_tree = %{tree | props: Map.merge(tree.props, new_props)}
        ops = Tree.diff(tree, new_tree)

        # All ops should be update_props (no structural changes)
        Enum.each(ops, fn op ->
          assert op.op == "update_props"
        end)

        patched = apply_ops(tree, ops)
        assert normalize_for_compare(patched) == normalize_for_compare(new_tree)
      end
    end
  end
end
