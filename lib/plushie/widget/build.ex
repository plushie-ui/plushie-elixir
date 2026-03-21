defmodule Plushie.Widget.Build do
  @moduledoc "Internal helpers for widget `to_node/1` implementations."

  @doc "Adds `key => value` to props if value is not nil."
  @spec put_if(props :: map(), value :: term(), key :: atom()) :: map()
  def put_if(props, nil, _key), do: props
  def put_if(props, value, key), do: Map.put(props, key, value)

  @doc "Adds `key => transform.(value)` to props if value is not nil."
  @spec put_if(
          props :: map(),
          value :: term(),
          key :: atom(),
          transform :: (term() -> term())
        ) ::
          map()
  def put_if(props, nil, _key, _transform), do: props
  def put_if(props, value, key, transform), do: Map.put(props, key, transform.(value))

  @doc "Converts a child element to a ui_node() map if it's a widget struct."
  @spec to_node(child :: map() | struct()) :: Plushie.Widget.ui_node()
  def to_node(%{id: _, type: _, props: _, children: _} = node), do: node
  def to_node(%_module{} = widget), do: Plushie.Widget.to_node(widget)

  @doc "Converts a list of children (maps or structs) to ui_node() maps."
  @spec children_to_nodes(children :: [map() | struct()]) :: [Plushie.Widget.ui_node()]
  def children_to_nodes(children), do: Enum.map(children, &to_node/1)

  @doc "Raises ArgumentError for an unknown option key passed to a widget constructor."
  @spec unknown_option!(module :: module(), key :: term()) :: no_return()
  def unknown_option!(module, key) do
    name = module |> Module.split() |> List.last()
    raise ArgumentError, "unknown option #{inspect(key)} for #{name}.new"
  end
end
