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
  Encodes an automation selector into the interact selector map expected by the renderer.
  """
  @spec encode(Session.selector() | nil, map() | nil) :: map()
  def encode(nil, _tree), do: %{}

  def encode("#" <> id, tree) do
    resolved =
      if String.contains?(id, "/") do
        id
      else
        case tree && Plushie.Tree.find_local(tree, id) do
          %{id: scoped_id} -> scoped_id
          _ -> id
        end
      end

    %{"by" => "id", "value" => resolved}
  end

  def encode({:role, role}, _tree) when is_binary(role), do: %{"by" => "role", "value" => role}

  def encode({:label, label}, _tree) when is_binary(label),
    do: %{"by" => "label", "value" => label}

  def encode(:focused, _tree), do: %{"by" => "focused"}
  def encode(text, _tree) when is_binary(text), do: %{"by" => "text", "value" => text}

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
