defmodule Plushie.Type.Float do
  @moduledoc """
  Numeric type. Accepts both integers and floats (any `number()`).
  """

  use Plushie.Type

  @impl true
  def cast(v) when is_number(v), do: {:ok, v}
  def cast(_), do: :error

  @impl true
  def typespec, do: quote(do: number())

  @impl true
  def guard(var), do: quote(do: is_number(unquote(var)))

  @impl true
  def field_options, do: [:min, :max]

  @impl true
  def constrain_guard(var, opts) do
    guards = []

    guards =
      if opts[:min], do: [quote(do: unquote(var) >= unquote(opts[:min])) | guards], else: guards

    guards =
      if opts[:max], do: [quote(do: unquote(var) <= unquote(opts[:max])) | guards], else: guards

    guards
  end
end
