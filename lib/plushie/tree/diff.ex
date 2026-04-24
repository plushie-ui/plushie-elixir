defmodule Plushie.Tree.Diff do
  @moduledoc false

  @type tree_node :: Plushie.Tree.tree_node()

  @empty_container %{
    id: "root",
    type: "container",
    props: %{},
    children: []
  }

  @doc false
  @spec diff(old_tree :: map() | nil, new_tree :: map() | nil) :: [map()]
  def diff(nil, nil), do: []
  def diff(nil, new_tree), do: [%{op: "replace_node", path: [], node: new_tree}]
  def diff(_old_tree, nil), do: [%{op: "replace_node", path: [], node: @empty_container}]

  def diff(%{id: old_id} = _old_tree, %{id: new_id} = new_tree) when old_id != new_id do
    [%{op: "replace_node", path: [], node: new_tree}]
  end

  def diff(%{} = old_tree, %{} = new_tree) do
    diff_node(old_tree, new_tree, [])
  end

  # Private helpers

  defp diff_node(old, new, _path) when old === new, do: []

  defp diff_node(old, new, path) do
    if old.type != new.type do
      [%{op: "replace_node", path: path, node: new}]
    else
      child_ops = diff_children(old.children, new.children, path)
      prop_ops = diff_props(old.props, new.props, path)
      prop_ops ++ child_ops
    end
  end

  defp diff_props(old_props, new_props, _path) when old_props == new_props, do: []

  defp diff_props(old_props, new_props, path) do
    changed =
      new_props
      |> Enum.reduce(%{}, fn {k, v}, acc ->
        case Map.fetch(old_props, k) do
          {:ok, ^v} -> acc
          {:ok, old_v} -> if id_keyed_list_equal?(old_v, v), do: acc, else: Map.put(acc, k, v)
          :error -> Map.put(acc, k, v)
        end
      end)

    # Keys removed in new: set to nil so the renderer can clear them
    removed =
      old_props
      |> Enum.reduce(%{}, fn {k, _v}, acc ->
        if Map.has_key?(new_props, k), do: acc, else: Map.put(acc, k, nil)
      end)

    merged = Map.merge(changed, removed)

    if map_size(merged) == 0 do
      []
    else
      [%{op: "update_props", path: path, props: merged}]
    end
  end

  # Compares two list-valued props by element ID when both are lists of
  # ID-bearing maps (e.g. canvas shape lists). This catches the common
  # case where the view function reconstructed the list with identical
  # content but the structural `===` check failed (different map key
  # ordering, float rounding, nested struct re-encoding).
  #
  # Returns true only when both lists have the same length, every element
  # has an :id key, the ID sequences match, and each pair is structurally
  # equal. Falls back to false for non-list or non-ID-bearing values so
  # the caller treats them as changed (existing behavior).
  defp id_keyed_list_equal?(old, new) when is_list(old) and is_list(new) do
    length(old) == length(new) and
      id_keyed_list?(old) and
      id_keyed_list?(new) and
      lists_equal_by_id?(old, new)
  end

  defp id_keyed_list_equal?(_old, _new), do: false

  defp id_keyed_list?(list) do
    list != [] and Enum.all?(list, &match?(%{id: _}, &1))
  end

  defp lists_equal_by_id?(old, new) do
    old_by_id = Map.new(old, fn %{id: id} = el -> {id, el} end)

    Enum.all?(new, fn %{id: id} = el ->
      case Map.fetch(old_by_id, id) do
        {:ok, ^el} -> true
        _ -> false
      end
    end)
  end

  defp diff_children(old_children, new_children, path) do
    old_ids = Enum.map(old_children, & &1.id)
    new_ids = Enum.map(new_children, & &1.id)

    check_duplicate_child_ids!(old_ids)
    check_duplicate_child_ids!(new_ids)

    old_by_id = old_children |> Enum.with_index() |> Map.new(fn {c, i} -> {c.id, {c, i}} end)
    new_by_id = new_children |> Enum.with_index() |> Map.new(fn {c, i} -> {c.id, {c, i}} end)

    # Common IDs in old and new order
    common_old = Enum.filter(old_ids, &Map.has_key?(new_by_id, &1))
    common_new = Enum.filter(new_ids, &Map.has_key?(old_by_id, &1))

    # Fast path: identical ID sequences, just diff props per child
    if old_ids == new_ids do
      diff_children_same_order(old_children, new_children, path)
    else
      # IDs that exist only in old (pure removals)
      old_only = MapSet.new(old_ids) |> MapSet.difference(MapSet.new(new_ids))

      if common_old == common_new do
        # Medium path: no reordering among common IDs. Use simple
        # insert/remove logic (no LIS needed).
        diff_children_no_reorder(
          old_by_id,
          new_children,
          old_only,
          path
        )
      else
        # Slow path: reordering detected. Use LIS to minimize moves.
        diff_children_reorder(
          old_by_id,
          new_by_id,
          new_children,
          common_new,
          old_only,
          path
        )
      end
    end
  end

  defp check_duplicate_child_ids!(ids) do
    case duplicate_ids(ids) do
      [] -> :ok
      dupes -> raise ArgumentError, "duplicate child IDs in diff: #{inspect(dupes)}"
    end
  end

  defp duplicate_ids(ids) do
    {_seen, dupes} =
      Enum.reduce(ids, {MapSet.new(), []}, fn id, {seen, dupes} ->
        cond do
          MapSet.member?(seen, id) and id not in dupes ->
            {seen, [id | dupes]}

          MapSet.member?(seen, id) ->
            {seen, dupes}

          true ->
            {MapSet.put(seen, id), dupes}
        end
      end)

    Enum.reverse(dupes)
  end

  # Fast path: old and new have identical ID lists. Diff props per child.
  defp diff_children_same_order(old_children, new_children, path) do
    old_children
    |> Enum.zip(new_children)
    |> Enum.with_index()
    |> Enum.flat_map(fn {{old_child, new_child}, idx} ->
      diff_node(old_child, new_child, path ++ [idx])
    end)
  end

  # Medium path: common IDs maintain relative order. Pure inserts and
  # removes with no moves needed.
  defp diff_children_no_reorder(old_by_id, new_children, old_only, path) do
    # Collect old indices that will be removed (old-only IDs)
    removed_indices =
      old_only
      |> Enum.map(fn id -> old_by_id |> Map.fetch!(id) |> elem(1) end)
      |> Enum.sort()

    remove_ops =
      removed_indices
      |> Enum.reverse()
      |> Enum.map(fn idx -> %{op: "remove_child", path: path, index: idx} end)

    # Walk new children for updates and inserts
    {update_ops, insert_ops} =
      new_children
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {child, idx}, {updates, inserts} ->
        case Map.fetch(old_by_id, child.id) do
          {:ok, {old_child, old_idx}} ->
            child_path = path ++ [index_after_removals(old_idx, removed_indices)]
            ops = diff_node(old_child, child, child_path)
            {updates ++ ops, inserts}

          :error ->
            insert = %{op: "insert_child", path: path, index: idx, node: child}
            {updates, inserts ++ [insert]}
        end
      end)

    remove_ops ++ update_ops ++ insert_ops
  end

  # Slow path: reordering detected. Use LIS to find the largest subset
  # of common elements that maintain relative order. Elements in the LIS
  # stay in place; elements not in the LIS are removed and re-inserted
  # at their new positions.
  defp diff_children_reorder(
         old_by_id,
         _new_by_id,
         new_children,
         common_new,
         old_only,
         path
       ) do
    # For common IDs in new order, get their old indices
    old_indices_of_common =
      Enum.map(common_new, fn id ->
        old_by_id |> Map.fetch!(id) |> elem(1)
      end)

    # Find LIS positions (indices into common_new that form the LIS)
    lis_positions = longest_increasing_subsequence(old_indices_of_common)
    lis_set = MapSet.new(lis_positions)

    # IDs that stay in place (in the LIS)
    lis_ids =
      common_new
      |> Enum.with_index()
      |> Enum.filter(fn {_id, i} -> MapSet.member?(lis_set, i) end)
      |> Enum.map(fn {id, _i} -> id end)
      |> MapSet.new()

    # IDs that need to move: common but not in LIS
    moved_ids =
      common_new
      |> MapSet.new()
      |> MapSet.difference(lis_ids)

    # All indices to remove: old-only IDs + moved IDs (removed from old position)
    all_remove_ids = MapSet.union(old_only, moved_ids)

    removed_indices =
      all_remove_ids
      |> Enum.map(fn id -> old_by_id |> Map.fetch!(id) |> elem(1) end)
      |> Enum.sort()

    remove_ops =
      removed_indices
      |> Enum.reverse()
      |> Enum.map(fn idx -> %{op: "remove_child", path: path, index: idx} end)

    # Build new child lookup for O(1) access
    new_child_by_id = Map.new(new_children, fn c -> {c.id, c} end)

    # Update ops for LIS elements (they survive removals, need adjusted indices)
    update_ops =
      lis_ids
      |> Enum.flat_map(fn id ->
        {old_child, old_idx} = Map.fetch!(old_by_id, id)
        new_child = Map.fetch!(new_child_by_id, id)
        child_path = path ++ [index_after_removals(old_idx, removed_indices)]
        diff_node(old_child, new_child, child_path)
      end)

    # Insert ops: new-only IDs and moved IDs, at their new positions
    insert_ops =
      new_children
      |> Enum.with_index()
      |> Enum.filter(fn {child, _idx} ->
        not Map.has_key?(old_by_id, child.id) or MapSet.member?(moved_ids, child.id)
      end)
      |> Enum.map(fn {child, idx} ->
        # For moved IDs, use the new version of the node from new_children
        # (which is already `child` here). For props that changed, the
        # insert carries the full new node so no separate update is needed.
        %{op: "insert_child", path: path, index: idx, node: child}
      end)

    remove_ops ++ update_ops ++ insert_ops
  end

  # Returns the adjusted index of an element after removals, using binary
  # search on a sorted tuple of removed indices. O(log r) per call.
  @spec index_after_removals(non_neg_integer(), [non_neg_integer()]) :: non_neg_integer()
  defp index_after_removals(old_idx, sorted_removed) do
    tup = List.to_tuple(sorted_removed)
    old_idx - bsearch_count_lt(tup, old_idx, 0, tuple_size(tup))
  end

  # Binary search: count elements in a sorted tuple that are strictly less
  # than the target value. O(log n) with O(1) random access.
  defp bsearch_count_lt(_tup, _target, lo, hi) when lo >= hi, do: lo

  defp bsearch_count_lt(tup, target, lo, hi) do
    mid = div(lo + hi, 2)

    if elem(tup, mid) < target do
      bsearch_count_lt(tup, target, mid + 1, hi)
    else
      bsearch_count_lt(tup, target, lo, mid)
    end
  end

  # Longest Increasing Subsequence using patience sorting.
  # Returns the indices (positions) in the input list that form the LIS.
  # Uses Erlang :array for O(1) random access in the inner binary search.
  # O(n log n) time, O(n) space.
  @spec longest_increasing_subsequence([integer()]) :: [non_neg_integer()]
  defp longest_increasing_subsequence([]), do: []

  defp longest_increasing_subsequence(values) do
    # tails[i] = smallest tail value for increasing subsequence of length i+1
    # idxs[i] = index in original list for tails[i]
    # preds = %{pos => predecessor_pos} for backtracking
    n = length(values)
    empty_arr = :array.new(n, default: 0)

    {_tails, preds, idxs, len} =
      values
      |> Enum.with_index()
      |> Enum.reduce({empty_arr, %{}, empty_arr, 0}, fn {val, pos}, {tails, preds, idxs, len} ->
        insert_pos = lis_bsearch(tails, val, 0, len)

        preds =
          if insert_pos > 0 do
            Map.put(preds, pos, :array.get(insert_pos - 1, idxs))
          else
            preds
          end

        tails = :array.set(insert_pos, val, tails)
        idxs = :array.set(insert_pos, pos, idxs)
        len = max(len, insert_pos + 1)

        {tails, preds, idxs, len}
      end)

    # Reconstruct the LIS by following predecessors backward
    last_idx = :array.get(len - 1, idxs)
    reconstruct_lis(preds, last_idx, len, [])
  end

  defp lis_bsearch(_tails, _val, lo, hi) when lo >= hi, do: lo

  defp lis_bsearch(tails, val, lo, hi) do
    mid = div(lo + hi, 2)

    if :array.get(mid, tails) < val do
      lis_bsearch(tails, val, mid + 1, hi)
    else
      lis_bsearch(tails, val, lo, mid)
    end
  end

  defp reconstruct_lis(_preds, _idx, 0, acc), do: acc

  defp reconstruct_lis(preds, idx, remaining, acc) do
    case Map.fetch(preds, idx) do
      {:ok, prev_idx} -> reconstruct_lis(preds, prev_idx, remaining - 1, [idx | acc])
      :error -> [idx | acc]
    end
  end
end
