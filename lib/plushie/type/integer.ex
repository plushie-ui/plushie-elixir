defmodule Plushie.Type.Integer do
  @moduledoc """
  Integer type. Accepts Elixir integers only.
  """

  use Plushie.Type

  @impl true
  def cast(v) when is_integer(v), do: {:ok, v}
  def cast(_), do: :error

  @impl true
  def typespec, do: quote(do: integer())

  @impl true
  def guard(var), do: quote(do: is_integer(unquote(var)))

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
