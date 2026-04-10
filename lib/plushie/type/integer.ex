defmodule Plushie.Type.Integer do
  @moduledoc """
  Integer type. Accepts Elixir integers only.

  Supports `:min` and `:max` field constraints:

      field :count, :integer, min: 0, max: 999
  """

  use Plushie.Type

  @type t :: integer()

  @impl Plushie.Type
  def cast(v) when is_integer(v), do: {:ok, v}
  def cast(_), do: :error

  @impl Plushie.Type
  def typespec, do: quote(do: integer())

  @impl Plushie.Type
  def guard(var), do: quote(do: is_integer(unquote(var)))

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
