defmodule Toddy.Widget.Node do
  @moduledoc false

  @doc false
  @spec build(id :: String.t(), type :: String.t(), props :: map(), children :: [map()]) :: map()
  def build(id, type, props, children \\ []) do
    %{id: id, type: type, props: stringify_keys(props), children: children}
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end
end
