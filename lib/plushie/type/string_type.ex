defmodule Plushie.Type.String do
  @moduledoc """
  String (binary) type.
  """

  @behaviour Plushie.Type

  @impl true
  def cast(v) when is_binary(v), do: {:ok, v}
  def cast(_), do: :error

  @impl true
  def typespec, do: quote(do: String.t())

  @impl true
  def guard(var), do: quote(do: is_binary(unquote(var)))

  @impl true
  def field_options, do: [:min_length, :max_length, :pattern]

  @impl true
  def constrain_guard(var, opts) do
    guards = []

    guards =
      if opts[:min_length],
        do: [quote(do: byte_size(unquote(var)) >= unquote(opts[:min_length])) | guards],
        else: guards

    guards =
      if opts[:max_length],
        do: [quote(do: byte_size(unquote(var)) <= unquote(opts[:max_length])) | guards],
        else: guards

    # :pattern is runtime-only, not expressible as a guard
    guards
  end
end
