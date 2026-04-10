defmodule Plushie.Type.String do
  @moduledoc """
  String type. Accepts binaries and atoms (atoms are coerced to
  strings via `Atom.to_string/1`).

  Supports `:min_length`, `:max_length`, and `:pattern` field
  constraints. Length constraints use `byte_size/1` guards;
  `:pattern` is validated at runtime only.

      field :name, :string, min_length: 1, max_length: 100
  """

  use Plushie.Type

  @type t :: String.t() | atom()

  @impl Plushie.Type
  def cast(v) when is_binary(v), do: {:ok, v}
  def cast(v) when is_atom(v) and not is_nil(v), do: {:ok, Atom.to_string(v)}
  def cast(_), do: :error

  @impl Plushie.Type
  def typespec, do: quote(do: String.t() | atom())

  @impl Plushie.Type
  def guard(var),
    do: quote(do: is_binary(unquote(var)) or (is_atom(unquote(var)) and not is_nil(unquote(var))))

  @impl Plushie.Type
  def field_options, do: [:min_length, :max_length, :pattern]

  @impl Plushie.Type
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
