defmodule Plushie.Type.Float do
  @moduledoc """
  Numeric type. Accepts both integers and floats (any `number()`).

  Integers are accepted without coercion so that `size: 14` works
  without requiring `14.0`. Supports `:min` and `:max` field
  constraints:

      field :opacity, :float, min: 0.0, max: 1.0
  """

  use Plushie.Type

  @type t :: number()

  @impl Plushie.Type
  def cast(v) when is_number(v), do: {:ok, v}
  def cast(_), do: :error

  @impl Plushie.Type
  def typespec, do: quote(do: number())

  @impl Plushie.Type
  def guard(var), do: quote(do: is_number(unquote(var)))

  @impl Plushie.Type
  def field_options, do: [:min, :max]

  @impl Plushie.Type
  def constrain_guard(var, opts) do
    guards = []

    guards =
      if opts[:min], do: [quote(do: unquote(var) >= unquote(opts[:min])) | guards], else: guards

    guards =
      if opts[:max], do: [quote(do: unquote(var) <= unquote(opts[:max])) | guards], else: guards

    guards
  end
end
