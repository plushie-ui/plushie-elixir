defmodule Plushie.Widget.Node do
  @moduledoc false

  @doc false
  @spec build(id :: String.t(), type :: String.t(), props :: map(), children :: [map()]) :: map()
  def build(id, type, props, children \\ []) do
    %{id: id, type: type, props: atomize_keys(props), children: children}
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) ->
        try do
          {String.to_existing_atom(k), v}
        rescue
          ArgumentError -> {k, v}
        end

      {k, v} ->
        {k, v}
    end)
  end
end
