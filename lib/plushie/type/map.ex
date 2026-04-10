defmodule Plushie.Type.Map do
  @moduledoc """
  Untyped map. Accepts any map without validating keys or values.

  For maps with typed keys or named fields, use the `{:map, ...}`
  composite forms instead (see `Plushie.Type`).
  """

  use Plushie.Type

  @type t :: map()

  @impl Plushie.Type
  def cast(v) when is_map(v), do: {:ok, v}
  def cast(_), do: :error

  @impl Plushie.Type
  def typespec, do: quote(do: map())

  @impl Plushie.Type
  def guard(var), do: quote(do: is_map(unquote(var)))
end
