defmodule Plushie.Tree.Search do
  @moduledoc false

  @type tree_node :: Plushie.Tree.tree_node()

  @doc false
  @spec find(tree :: tree_node(), id :: String.t()) :: tree_node() | nil
  def find(tree, target_id) do
    case find_all_exact(tree, target_id, []) do
      [] ->
        nil

      [node] ->
        node

      _ ->
        raise ArgumentError,
              "tree contains multiple nodes with id #{inspect(target_id)}; use find/3 with a window id"
    end
  end

  @doc false
  @spec find(tree :: tree_node(), id :: String.t(), window_id :: String.t()) :: tree_node() | nil
  def find(tree, target_id, window_id) do
    tree
    |> find_window(window_id)
    |> case do
      nil -> nil
      window -> find_exact(window, target_id)
    end
  end

  @doc false
  @spec find_local(tree :: tree_node(), id :: String.t()) :: tree_node() | nil
  def find_local(tree, local_id) do
    case find_all_local(tree, local_id, []) do
      [] ->
        nil

      [node] ->
        node

      _ ->
        raise ArgumentError,
              "tree contains multiple nodes with local id #{inspect(local_id)}; use a scoped id or window-aware lookup"
    end
  end

  @doc false
  @spec find_local(tree :: tree_node(), id :: String.t(), window_id :: String.t()) ::
          tree_node() | nil
  def find_local(tree, local_id, window_id) do
    tree
    |> find_window(window_id)
    |> case do
      nil -> nil
      window -> find_local(window, local_id)
    end
  end

  @doc false
  @spec window_id_for(tree :: tree_node(), id :: String.t()) :: String.t() | nil
  def window_id_for(tree, target_id) do
    case collect_window_ids(tree, target_id, nil, []) |> Enum.uniq() do
      [] ->
        nil

      [window_id] ->
        window_id

      _ ->
        raise ArgumentError,
              "tree contains multiple nodes with id #{inspect(target_id)} in different windows"
    end
  end

  @doc false
  @spec exists?(tree :: map() | nil, id :: String.t()) :: boolean()
  def exists?(nil, _id), do: false

  def exists?(tree, id) do
    find(tree, id) != nil
  end

  @doc false
  @spec ids(tree :: map() | nil) :: [String.t()]
  def ids(nil), do: []

  def ids(%{id: id, children: children}) do
    [id | Enum.flat_map(children, &ids/1)]
  end

  def ids(%{"id" => id, "children" => children}) do
    [id | Enum.flat_map(children, &ids/1)]
  end

  def ids(_), do: []

  @doc false
  @spec text_of(node :: tree_node()) :: String.t() | nil
  def text_of(%{props: %{content: c}}) when is_binary(c), do: c
  def text_of(%{props: %{"content" => c}}) when is_binary(c), do: c
  def text_of(%{"props" => %{"content" => c}}) when is_binary(c), do: c
  def text_of(_), do: nil

  @doc false
  @spec find_all(node :: tree_node() | nil, fun :: (tree_node() -> as_boolean(term()))) ::
          [tree_node()]
  def find_all(nil, _fun), do: []

  def find_all(node, fun) do
    do_find_all(node, fun, [])
    |> Enum.reverse()
  end

  @doc false
  @spec find_first(node :: tree_node() | nil, fun :: (tree_node() -> as_boolean(term()))) ::
          tree_node() | nil
  def find_first(nil, _fun), do: nil

  def find_first(node, fun) do
    do_find_first(node, fun)
  end

  # Private helpers

  defp find_exact(%{id: id} = node, id), do: node

  defp find_exact(%{children: children}, target_id) when is_list(children) do
    Enum.find_value(children, &find_exact(&1, target_id))
  end

  defp find_exact(%{"id" => id} = node, id), do: node

  defp find_exact(%{"children" => children}, target_id) when is_list(children) do
    Enum.find_value(children, &find_exact(&1, target_id))
  end

  defp find_exact(_node, _target_id), do: nil

  defp find_all_exact(%{id: id} = node, target_id, acc) when id == target_id do
    acc =
      case node do
        %{children: children} when is_list(children) ->
          Enum.reduce(children, [node | acc], &find_all_exact(&1, target_id, &2))

        _ ->
          [node | acc]
      end

    acc
  end

  defp find_all_exact(%{children: children}, target_id, acc) when is_list(children) do
    Enum.reduce(children, acc, &find_all_exact(&1, target_id, &2))
  end

  defp find_all_exact(%{"id" => id} = node, target_id, acc) when id == target_id do
    acc =
      case node do
        %{"children" => children} when is_list(children) ->
          Enum.reduce(children, [node | acc], &find_all_exact(&1, target_id, &2))

        _ ->
          [node | acc]
      end

    acc
  end

  defp find_all_exact(%{"children" => children}, target_id, acc) when is_list(children) do
    Enum.reduce(children, acc, &find_all_exact(&1, target_id, &2))
  end

  defp find_all_exact(_node, _target_id, acc), do: acc

  defp find_all_local(%{id: id} = node, local_id, acc) do
    acc = if local_id(id) == local_id, do: [node | acc], else: acc

    case node do
      %{children: children} when is_list(children) ->
        Enum.reduce(children, acc, &find_all_local(&1, local_id, &2))

      _ ->
        acc
    end
  end

  defp find_all_local(%{"id" => id} = node, local_id, acc) do
    acc = if local_id(id) == local_id, do: [node | acc], else: acc

    case node do
      %{"children" => children} when is_list(children) ->
        Enum.reduce(children, acc, &find_all_local(&1, local_id, &2))

      _ ->
        acc
    end
  end

  defp find_all_local(%{children: children}, local_id, acc) when is_list(children) do
    Enum.reduce(children, acc, &find_all_local(&1, local_id, &2))
  end

  defp find_all_local(%{"children" => children}, local_id, acc) when is_list(children) do
    Enum.reduce(children, acc, &find_all_local(&1, local_id, &2))
  end

  defp find_all_local(_node, _local_id, acc), do: acc

  defp local_id(id) when is_binary(id) do
    id |> String.split(["#", "/"]) |> List.last()
  end

  defp find_window(%{type: "window", id: id} = node, id), do: node

  defp find_window(%{children: children}, window_id) when is_list(children) do
    Enum.find_value(children, &find_window(&1, window_id))
  end

  defp find_window(_, _window_id), do: nil

  defp collect_window_ids(%{type: "window", id: id, children: children}, target_id, _current, acc) do
    acc = if id == target_id, do: [id | acc], else: acc
    Enum.reduce(children, acc, &collect_window_ids(&1, target_id, id, &2))
  end

  defp collect_window_ids(%{id: id, children: children}, target_id, current_window, acc) do
    acc = if id == target_id and current_window, do: [current_window | acc], else: acc

    Enum.reduce(children, acc, &collect_window_ids(&1, target_id, current_window, &2))
  end

  defp collect_window_ids(%{children: children}, target_id, current_window, acc)
       when is_list(children) do
    Enum.reduce(children, acc, &collect_window_ids(&1, target_id, current_window, &2))
  end

  defp collect_window_ids(
         %{"type" => "window", "id" => id, "children" => children},
         target_id,
         _current,
         acc
       ) do
    acc = if id == target_id, do: [id | acc], else: acc
    Enum.reduce(children, acc, &collect_window_ids(&1, target_id, id, &2))
  end

  defp collect_window_ids(%{"id" => id, "children" => children}, target_id, current_window, acc) do
    acc = if id == target_id and current_window, do: [current_window | acc], else: acc

    Enum.reduce(children, acc, &collect_window_ids(&1, target_id, current_window, &2))
  end

  defp collect_window_ids(%{"children" => children}, target_id, current_window, acc)
       when is_list(children) do
    Enum.reduce(children, acc, &collect_window_ids(&1, target_id, current_window, &2))
  end

  defp collect_window_ids(_node, _target_id, _current_window, acc), do: acc

  defp do_find_all(%{children: children} = node, fun, acc) do
    acc = if fun.(node), do: [node | acc], else: acc
    Enum.reduce(children, acc, &do_find_all(&1, fun, &2))
  end

  defp do_find_all(node, fun, acc) do
    if fun.(node), do: [node | acc], else: acc
  end

  defp do_find_first(%{children: children} = node, fun) do
    if fun.(node) do
      node
    else
      Enum.find_value(children, &do_find_first(&1, fun))
    end
  end

  defp do_find_first(node, fun) do
    if fun.(node), do: node
  end
end
