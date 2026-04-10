defmodule Plushie.Type.Map do
  @moduledoc """
  Map type. Accepts any map.
  """

  @behaviour Plushie.Type

  @impl true
  def cast(v) when is_map(v), do: {:ok, v}
  def cast(_), do: :error

  @impl true
  def typespec, do: quote(do: map())

  @impl true
  def guard(var), do: quote(do: is_map(unquote(var)))
end
