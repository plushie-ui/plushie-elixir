defmodule Plushie.Type.Composite.Tuple do
  @moduledoc """
  Composite type for fixed-size typed tuples.

  Each position is cast through its declared type. The tuple size
  must match the type list length.

      field :range, {:tuple, [:float, :float]}
  """

  @behaviour Plushie.Type.Composite

  @impl Plushie.Type.Composite
  def cast(types, value) when is_tuple(value) and tuple_size(value) == length(types) do
    pairs = Enum.zip(types, Tuple.to_list(value))
    results = Enum.map(pairs, fn {type, val} -> Plushie.Type.cast_value(type, val) end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, List.to_tuple(Enum.map(results, fn {:ok, v} -> v end))}
    else
      :error
    end
  end

  def cast(_, _), do: :error

  @impl Plushie.Type.Composite
  def decode(types, value) when is_list(value) and length(value) == length(types) do
    pairs = Enum.zip(types, value)
    results = Enum.map(pairs, fn {type, val} -> Plushie.Type.decode_value(type, val) end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, List.to_tuple(Enum.map(results, fn {:ok, v} -> v end))}
    else
      :error
    end
  end

  def decode(types, value) when is_tuple(value) and tuple_size(value) == length(types) do
    pairs = Enum.zip(types, Tuple.to_list(value))
    results = Enum.map(pairs, fn {type, val} -> Plushie.Type.decode_value(type, val) end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, List.to_tuple(Enum.map(results, fn {:ok, v} -> v end))}
    else
      :error
    end
  end

  def decode(_, _), do: :error

  @impl Plushie.Type.Composite
  def typespec(types, resolver) do
    type_asts = Enum.map(types, resolver)
    {:{}, [], type_asts}
  end

  @impl Plushie.Type.Composite
  def guard(types, var) do
    len = length(types)
    quote(do: is_tuple(unquote(var)) and tuple_size(unquote(var)) == unquote(len))
  end

  @impl Plushie.Type.Composite
  def display_string(types, resolver) do
    inner = Enum.map_join(types, ", ", resolver)
    "{#{inner}}"
  end

  @impl Plushie.Type.Composite
  def valid_spec?(types, checker) when is_list(types), do: Enum.all?(types, checker)
  def valid_spec?(_, _), do: false
end
