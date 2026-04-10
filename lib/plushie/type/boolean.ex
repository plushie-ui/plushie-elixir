defmodule Plushie.Type.Boolean do
  @moduledoc "Boolean type. Accepts `true` and `false` only."

  use Plushie.Type

  @type t :: boolean()

  @impl Plushie.Type
  def cast(v) when is_boolean(v), do: {:ok, v}
  def cast(_), do: :error

  @impl Plushie.Type
  def typespec, do: quote(do: boolean())

  @impl Plushie.Type
  def guard(var), do: quote(do: is_boolean(unquote(var)))
end
