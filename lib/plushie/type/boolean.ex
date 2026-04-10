defmodule Plushie.Type.Boolean do
  @moduledoc """
  Boolean type. Accepts `true` and `false` only.
  """

  use Plushie.Type

  @impl true
  def cast(v) when is_boolean(v), do: {:ok, v}
  def cast(_), do: :error

  @impl true
  def typespec, do: quote(do: boolean())

  @impl true
  def guard(var), do: quote(do: is_boolean(unquote(var)))
end
