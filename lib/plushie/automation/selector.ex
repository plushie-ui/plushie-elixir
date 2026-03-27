defmodule Plushie.Automation.Selector do
  @moduledoc """
  Selector helpers for automation against a normalized Plushie tree.

  This module resolves the selector forms accepted by `Plushie.Automation.Session`
  into either tree nodes or renderer interact selectors.
  """

  alias Plushie.Automation.Element
  alias Plushie.Automation.Session

  @doc """
  Finds the first element matching an automation selector.
  """
  @spec find(map() | nil, Session.selector()) :: Element.t() | nil
  def find(nil, _selector), do: nil

  def find(tree, "#" <> id) do
    case find_selector_node(tree, id) do
      nil -> nil
      node -> Element.from_node(node)
    end
  end

  def find(tree, {:role, role}) do
    tree
    |> Plushie.Tree.find_all(fn node -> a11y_field(node, :role) == role end)
    |> List.first()
    |> maybe_wrap()
  end

  def find(tree, {:label, label}) do
    tree
    |> Plushie.Tree.find_all(fn node -> a11y_field(node, :label) == label end)
    |> List.first()
    |> maybe_wrap()
  end

  def find(tree, text) when is_binary(text) do
    tree
    |> Plushie.Tree.find_all(fn node ->
      type = node[:type] || node["type"]
      content = prop(node, :content)
      type == "text" and content == text
    end)
    |> List.first()
    |> maybe_wrap()
  end

  def find(_tree, :focused), do: nil

  @doc """
  Finds the raw tree node for selectors that resolve directly to a widget.
  """
  @spec find_node(map() | nil, Session.selector()) :: map() | nil
  def find_node(nil, _selector), do: nil
  def find_node(tree, "#" <> id), do: find_selector_node(tree, id)
  def find_node(_tree, _selector), do: nil

  @doc """
  Encodes an automation selector into the interact selector map expected
  by the renderer. An optional `window_id` scopes the selector to a
  specific window for multi-window apps.
  """
  @spec encode(
          selector :: Session.selector() | nil,
          tree :: map() | nil,
          window_id :: String.t() | nil
        ) ::
          map()
  def encode(selector, tree, window_id \\ nil)

  def encode(nil, _tree, _window_id), do: %{}

  def encode("#" <> id, tree, window_id) do
    resolved =
      if String.contains?(id, "/") do
        id
      else
        case tree && Plushie.Tree.find_local(tree, id) do
          %{id: scoped_id} -> scoped_id
          _ -> id
        end
      end

    # When no window is specified, check for ambiguity across windows.
    if is_nil(window_id) and tree != nil do
      check_ambiguity!("#" <> id, tree)
    end

    sel = %{"by" => "id", "value" => resolved}
    if window_id, do: Map.put(sel, "window_id", window_id), else: sel
  end

  def encode({:role, role}, _tree, window_id) when is_binary(role) do
    sel = %{"by" => "role", "value" => role}
    if window_id, do: Map.put(sel, "window_id", window_id), else: sel
  end

  def encode({:label, label}, _tree, window_id) when is_binary(label) do
    sel = %{"by" => "label", "value" => label}
    if window_id, do: Map.put(sel, "window_id", window_id), else: sel
  end

  def encode(:focused, _tree, _window_id), do: %{"by" => "focused"}

  def encode(text, _tree, window_id) when is_binary(text) do
    sel = %{"by" => "text", "value" => text}
    if window_id, do: Map.put(sel, "window_id", window_id), else: sel
  end

  @doc """
  Finds all elements matching a selector, returning each with the window
  ID it belongs to. Used for ambiguity detection in multi-window apps.
  """
  @spec find_all_with_windows(tree :: map() | nil, selector :: Session.selector()) ::
          [{Element.t(), String.t() | nil}]
  def find_all_with_windows(nil, _selector), do: []

  def find_all_with_windows(tree, "#" <> id) do
    tree
    |> collect_windows()
    |> Enum.flat_map(fn {window_id, window_node} ->
      matches =
        Plushie.Tree.find_all(window_node, fn node ->
          node_id = node[:id]
          node_id == id or (is_binary(node_id) and String.ends_with?(node_id, "/" <> id))
        end)

      Enum.map(matches, fn node -> {Element.from_node(node), window_id} end)
    end)
  end

  def find_all_with_windows(_tree, _selector), do: []

  defp collect_windows(%{type: "window", id: id} = node), do: [{id, node}]

  defp collect_windows(%{children: children}) do
    Enum.flat_map(children, &collect_windows/1)
  end

  defp collect_windows(_), do: []

  defp check_ambiguity!(selector, tree) do
    matches = find_all_with_windows(tree, selector)

    if length(matches) > 1 do
      windows =
        matches
        |> Enum.map(fn {_elem, wid} -> wid end)
        |> Enum.uniq()

      if length(windows) > 1 do
        raise ArgumentError,
              "ambiguous selector #{inspect(selector)}: found in windows #{inspect(windows)}. " <>
                "Use the window: option to disambiguate."
      end
    end
  end

  defp maybe_wrap(nil), do: nil
  defp maybe_wrap(node), do: Element.from_node(node)

  defp find_selector_node(tree, id) do
    if String.contains?(id, "/") do
      Plushie.Tree.find(tree, id)
    else
      Plushie.Tree.find_local(tree, id)
    end
  end

  defp a11y_field(node, field) do
    a11y = prop(node, :a11y) || %{}
    a11y[field] || a11y[to_string(field)]
  end

  defp prop(node, key) do
    props = node[:props] || node["props"] || %{}
    props[key] || props[to_string(key)]
  end
end
