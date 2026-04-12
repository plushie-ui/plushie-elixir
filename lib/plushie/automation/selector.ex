defmodule Plushie.Automation.Selector do
  @moduledoc """
  Selector helpers for automation against a normalized Plushie tree.

  This module resolves the selector forms accepted by `Plushie.Automation.Session`
  into either tree nodes or renderer interact selectors.
  """

  alias Plushie.Automation.Element
  alias Plushie.Automation.Session

  @doc """
  Parses a window-qualified selector string into its components.

  Returns `{window_id, selector}` where `window_id` is `nil` when no
  window qualifier is present.

  ## Examples

      iex> parse("main#save")
      {"main", "#save"}

      iex> parse("main#form/save")
      {"main", "#form/save"}

      iex> parse("#save")
      {nil, "#save"}

      iex> parse({:text, "Save"})
      {nil, {:text, "Save"}}
  """
  @spec parse(Session.selector()) :: {String.t() | nil, Session.selector()}
  def parse(selector) when is_binary(selector) do
    case String.split(selector, "#", parts: 2) do
      [window_id, widget_path] when window_id != "" ->
        {window_id, "#" <> widget_path}

      _ ->
        {nil, selector}
    end
  end

  def parse(selector), do: {nil, selector}

  @doc """
  Parse a unified selector string into its typed form.

  Supports all selector types in a single string syntax:

  - `"form/email"` or `"#form/email"` - ID path selector
  - `"main#form/email"` - window-qualified ID selector
  - `":focused"` - state pseudo-selector
  - `"main#:focused"` - window-qualified state selector
  - `"[text=Save]"` - attribute selector
  - `"[role=button]"` - attribute selector
  - `"main#[text=Save]"` - window-qualified attribute selector

  Returns `{window_id, resolved_selector}` where resolved_selector
  is one of: `"#id"` (string), `:focused` (atom), `{:text, "Save"}`
  (tuple), etc.
  """
  @spec parse_selector(String.t()) :: {String.t() | nil, Session.selector()}
  def parse_selector(selector) when is_binary(selector) do
    # Split window qualifier on #
    {window_id, target} =
      case String.split(selector, "#", parts: 2) do
        [window_id, rest] when window_id != "" -> {window_id, rest}
        _ -> {nil, selector}
      end

    # Strip leading # from ID selectors (both "#save" and "save" are IDs)
    target =
      if String.starts_with?(target, "#"), do: String.trim_leading(target, "#"), else: target

    # Determine selector type from target's first character
    resolved =
      cond do
        String.starts_with?(target, ":") ->
          target |> String.trim_leading(":") |> String.to_existing_atom()

        String.starts_with?(target, "[") and String.ends_with?(target, "]") ->
          inner = target |> String.trim_leading("[") |> String.trim_trailing("]")

          case String.split(inner, "=", parts: 2) do
            [attr, value] -> {String.to_existing_atom(attr), value}
            _ -> "#" <> target
          end

        true ->
          "#" <> target
      end

    {window_id, resolved}
  end

  @doc """
  Finds the first element matching an automation selector.
  """
  @spec find(map() | nil, Session.selector()) :: Element.t() | nil
  def find(nil, _selector), do: nil

  def find(tree, selector) when is_binary(selector) do
    {window_id, resolved} = parse_selector(selector)

    case resolved do
      "#" <> id ->
        search_tree = if window_id, do: find_window_subtree(tree, window_id), else: tree

        case find_selector_node(search_tree, id) do
          nil -> nil
          node -> Element.from_node(node)
        end

      other ->
        # Delegate state/attribute selectors to the tuple/atom handlers
        search_tree = if window_id, do: find_window_subtree(tree, window_id), else: tree
        find(search_tree, other)
    end
  end

  def find(tree, {:role, role}) when is_binary(role) do
    role_atom = String.to_existing_atom(role)

    tree
    |> Plushie.Tree.find_all(fn node ->
      node_role = a11y_field(node, :role)
      node_role == role or node_role == role_atom
    end)
    |> List.first()
    |> maybe_wrap()
  rescue
    ArgumentError -> nil
  end

  def find(tree, {:role, role}) when is_atom(role) do
    find(tree, {:role, Atom.to_string(role)})
  end

  def find(tree, {:label, label}) do
    tree
    |> Plushie.Tree.find_all(fn node -> a11y_field(node, :label) == label end)
    |> List.first()
    |> maybe_wrap()
  end

  def find(tree, {:text, text}) when is_binary(text) do
    tree
    |> Plushie.Tree.find_all(fn node ->
      Enum.any?([:content, :label, :value, :placeholder], fn key ->
        prop(node, key) == text
      end)
    end)
    |> List.first()
    |> maybe_wrap()
  end

  def find(_tree, :focused) do
    raise ArgumentError,
          ":focused selector requires runtime context. " <>
            "Use Session.find(session, :focused) instead of Selector.find(tree, :focused)"
  end

  @doc """
  Finds the raw tree node for selectors that resolve directly to a widget.
  """
  @spec find_node(map() | nil, Session.selector()) :: map() | nil
  def find_node(nil, _selector), do: nil

  def find_node(tree, selector) when is_binary(selector) do
    case parse(selector) do
      {window_id, "#" <> id} ->
        search_tree = if window_id, do: find_window_subtree(tree, window_id), else: tree
        find_selector_node(search_tree, id)

      _ ->
        nil
    end
  end

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

  def encode(selector, tree, window_id) when is_binary(selector) do
    {parsed_window, resolved_selector} = parse_selector(selector)
    effective_window = window_id || parsed_window

    case resolved_selector do
      "#" <> id ->
        encode_id(id, tree, effective_window)

      atom when is_atom(atom) ->
        encode(atom, tree, effective_window)

      {attr, value} when is_atom(attr) and is_binary(value) ->
        encode({attr, value}, tree, effective_window)
    end
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

  def encode({:text, text}, _tree, window_id) when is_binary(text) do
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

          node_id == id or
            (is_binary(node_id) and
               (String.ends_with?(node_id, "/" <> id) or
                  String.ends_with?(node_id, "#" <> id)))
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

  defp encode_id(id, tree, window_id) do
    resolved =
      if String.contains?(id, "/") or String.contains?(id, "#") do
        id
      else
        search_tree = if window_id, do: find_window_subtree(tree, window_id), else: tree

        case search_tree && Plushie.Tree.find_local(search_tree, id) do
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

  @doc "Finds the window subtree with the given window ID."
  @spec find_window_subtree(map() | nil, String.t()) :: map() | nil
  def find_window_subtree(nil, _window_id), do: nil

  def find_window_subtree(%{type: "window", id: id} = node, window_id) do
    if id == window_id, do: node, else: nil
  end

  def find_window_subtree(%{children: children}, window_id) do
    Enum.find_value(children, fn child -> find_window_subtree(child, window_id) end)
  end

  def find_window_subtree(_, _window_id), do: nil

  defp maybe_wrap(nil), do: nil
  defp maybe_wrap(node), do: Element.from_node(node)

  defp find_selector_node(nil, _id), do: nil

  defp find_selector_node(tree, id) do
    if String.contains?(id, "/") or String.contains?(id, "#") do
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
