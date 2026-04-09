defmodule Plushie.Automation.Element do
  @moduledoc """
  Represents a widget element found in the UI tree during automation.

  Created by `find/2` and used for scoped assertions, automation flows, and
  runtime inspection. Contains the widget's ID, type, props, and children.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          props: map(),
          children: [t()]
        }

  defstruct [:id, :type, :props, :children]

  @doc "Creates an Element from a ui_node map (%{id, type, props, children})."
  @spec from_node(node :: map()) :: t()
  def from_node(%{} = node) do
    %__MODULE__{
      id: node[:id] || node["id"],
      type: node[:type] || node["type"],
      props: atomize_keys(node[:props] || node["props"] || %{}),
      children: (node[:children] || node["children"] || []) |> Enum.map(&from_node/1)
    }
  end

  # Converts string keys in a props map to atoms. The normalized tree
  # uses atom keys; this handles the rare case where string-keyed data
  # reaches Element construction. Unknown keys that don't have an
  # existing atom are kept as strings (custom widget props).
  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) ->
        case safe_to_atom(k) do
          {:ok, atom} -> {atom, v}
          :error -> {k, v}
        end

      {k, v} ->
        {k, v}
    end)
  end

  defp safe_to_atom(str) do
    {:ok, String.to_existing_atom(str)}
  rescue
    ArgumentError -> :error
  end

  @doc """
  Extracts text content from an element.

  Checks props in order: "content", "label", "value", "placeholder".
  Returns nil if no text prop is found.
  """
  @spec text(element :: t()) :: String.t() | nil
  def text(%__MODULE__{props: props}) do
    props[:content] || props[:label] || props[:value] || props[:placeholder]
  end

  @doc "Returns the a11y props map from the element, or nil if not set."
  @spec a11y(element :: t()) :: map() | nil
  def a11y(%__MODULE__{props: props}) do
    props[:a11y]
  end

  @doc """
  Returns the accessibility role for this element.

  Reads the role from the element's a11y props first. Falls back
  to inferring from the widget type for elements without a11y
  (e.g., manually constructed Elements in tests).
  """
  @spec inferred_role(element :: t()) :: String.t()
  def inferred_role(%__MODULE__{} = element) do
    case get_in(element.props, [:a11y, :role]) do
      role when is_atom(role) and not is_nil(role) -> Atom.to_string(role)
      role when is_binary(role) -> role
      _ -> role_for_type(element.type)
    end
  end

  # Fallback role inference from widget type. Used when the element
  # doesn't have an a11y prop (e.g., raw Element construction in tests).
  # In production, all widgets have a11y defaults with roles.
  @role_map %{
    "button" => "button",
    "text" => "label",
    "rich_text" => "label",
    "text_input" => "text_input",
    "text_editor" => "multiline_text_input",
    "checkbox" => "check_box",
    "toggler" => "switch",
    "radio" => "radio_button",
    "slider" => "slider",
    "vertical_slider" => "slider",
    "pick_list" => "combo_box",
    "combo_box" => "combo_box",
    "progress_bar" => "progress_indicator",
    "scrollable" => "scroll_view",
    "container" => "generic_container",
    "column" => "generic_container",
    "row" => "generic_container",
    "stack" => "generic_container",
    "keyed_column" => "generic_container",
    "grid" => "generic_container",
    "float" => "generic_container",
    "pin" => "generic_container",
    "responsive" => "generic_container",
    "space" => "generic_container",
    "themer" => "generic_container",
    "pointer_area" => "generic_container",
    "sensor" => "generic_container",
    "overlay" => "generic_container",
    "window" => "window",
    "image" => "image",
    "svg" => "image",
    "qr_code" => "image",
    "canvas" => "canvas",
    "table" => "table",
    "tooltip" => "tooltip",
    "markdown" => "document",
    "pane_grid" => "group",
    "rule" => "splitter"
  }

  defp role_for_type(type_name), do: Map.get(@role_map, type_name, "unknown")
end
