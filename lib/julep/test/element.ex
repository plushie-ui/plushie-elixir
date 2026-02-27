defmodule Julep.Test.Element do
  @moduledoc """
  Represents a widget element found in the UI tree during testing.

  Created by `find/2` and used for scoped assertions. Contains the widget's
  ID, type, props, and children.
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
      props: node[:props] || node["props"] || %{},
      children: (node[:children] || node["children"] || []) |> Enum.map(&from_node/1)
    }
  end

  @doc """
  Extracts text content from an element.

  Checks props in order: "content", "label", "value", "placeholder".
  Returns nil if no text prop is found.
  """
  @spec text(element :: t()) :: String.t() | nil
  def text(%__MODULE__{props: props}) do
    props["content"] || props["label"] || props["value"] || props["placeholder"]
  end
end
