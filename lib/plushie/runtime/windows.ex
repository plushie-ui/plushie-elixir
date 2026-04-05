defmodule Plushie.Runtime.Windows do
  @moduledoc """
  Window lifecycle management for the Plushie runtime.

  Detects window nodes in the UI tree, opens/closes/updates windows
  via the bridge, and tracks the set of active window IDs on the
  runtime state.
  """

  require Logger

  # Window setting keys that can be specified as node props on window elements.
  @window_prop_keys ~w(
    title size width height position min_size max_size maximized fullscreen
    visible resizable closeable minimizable decorations transparent blur level
    exit_on_close_request scale_factor
  )a

  @doc """
  Synchronizes the runtime's tracked windows with the current tree.

  Opens windows that appeared in the new tree, closes windows that
  were removed, and sends update ops for windows whose props changed.
  Returns the updated state with the new window set.
  """
  @spec sync_windows(map(), map() | nil) :: map()
  def sync_windows(state, tree) do
    new_windows = detect_windows(tree)
    current_windows = state.windows

    # Open new windows
    opened = MapSet.difference(new_windows, current_windows)

    Enum.each(opened, fn window_id ->
      base_settings =
        try do
          state.app.window_config(state.model)
        catch
          kind, reason ->
            Logger.warning(
              "plushie runtime: window_config/1 #{kind}: " <>
                Exception.format(kind, reason, __STACKTRACE__)
            )

            %{}
        end

      per_window_props = extract_window_props(tree, window_id)
      settings = Map.merge(base_settings, per_window_props)

      if state.bridge do
        Plushie.Bridge.send_window_op(state.bridge, "open", window_id, settings)
      end
    end)

    # Close removed windows
    closed = MapSet.difference(current_windows, new_windows)

    Enum.each(closed, fn window_id ->
      if state.bridge do
        Plushie.Bridge.send_window_op(state.bridge, "close", window_id)
      end
    end)

    # Diff window props for windows that are still open -- send update ops
    # for any changed props (title, size, position, etc.).
    surviving = MapSet.intersection(current_windows, new_windows)

    Enum.each(surviving, fn window_id ->
      old_props = extract_window_props(state.tree, window_id)
      new_props = extract_window_props(tree, window_id)

      if old_props != new_props and state.bridge do
        Plushie.Bridge.send_window_op(state.bridge, "update", window_id, new_props)
      end
    end)

    %{state | windows: new_windows}
  end

  @doc """
  Detects window node IDs from the tree. Searches the entire tree
  recursively, matching the Rust renderer's behavior.
  """
  @spec detect_windows(map() | nil) :: MapSet.t()
  def detect_windows(nil), do: MapSet.new()

  def detect_windows(tree) do
    tree
    |> collect_window_ids([])
    |> MapSet.new()
  end

  defp collect_window_ids(%{type: "window", id: id} = node, acc) do
    acc = [id | acc]
    collect_children_window_ids(node, acc)
  end

  defp collect_window_ids(%{children: _} = node, acc) do
    collect_children_window_ids(node, acc)
  end

  defp collect_window_ids(_, acc), do: acc

  defp collect_children_window_ids(%{children: children}, acc) when is_list(children) do
    Enum.reduce(children, acc, &collect_window_ids/2)
  end

  defp collect_children_window_ids(_, acc), do: acc

  # -- Private helpers --------------------------------------------------------

  @spec extract_window_props(tree :: map() | nil, window_id :: String.t()) :: map()
  defp extract_window_props(nil, _window_id), do: %{}

  defp extract_window_props(tree, window_id) do
    props =
      case find_window_node(tree, window_id) do
        %{props: props} when is_map(props) ->
          Map.take(props, @window_prop_keys)

        _ ->
          %{}
      end

    decompose_size_tuples(props)
  end

  # Recursively search the tree for a window node with the given ID.
  defp find_window_node(%{type: "window", id: id} = node, id), do: node

  defp find_window_node(%{children: children}, window_id) when is_list(children) do
    Enum.find_value(children, fn child -> find_window_node(child, window_id) end)
  end

  defp find_window_node(_, _), do: nil

  # Decompose size tuples into separate width/height keys that Rust expects.
  # size: {w, h}     -> width: w, height: h  (and remove size key)
  # min_size: {w, h} -> min_size: %{width: w, height: h}
  # max_size: {w, h} -> max_size: %{width: w, height: h}
  # Also handles lists (which is what the Encode protocol produces from tuples).
  @spec decompose_size_tuples(map()) :: map()
  defp decompose_size_tuples(props) do
    props
    |> decompose_size()
    |> decompose_nested_size(:min_size)
    |> decompose_nested_size(:max_size)
  end

  defp decompose_size(props) do
    case Map.get(props, :size) do
      {w, h} ->
        props
        |> Map.delete(:size)
        |> Map.put_new(:width, w)
        |> Map.put_new(:height, h)

      [w, h] ->
        props
        |> Map.delete(:size)
        |> Map.put_new(:width, w)
        |> Map.put_new(:height, h)

      _ ->
        props
    end
  end

  defp decompose_nested_size(props, key) do
    case Map.get(props, key) do
      {w, h} -> Map.put(props, key, %{width: w, height: h})
      [w, h] -> Map.put(props, key, %{width: w, height: h})
      _ -> props
    end
  end
end
