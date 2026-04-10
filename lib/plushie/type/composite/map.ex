defmodule Plushie.Type.Composite.Map do
  @moduledoc """
  Composite type for typed maps.

  Two forms are supported:

  Dictionary form with uniform key/value types:

      field :scores, {:map, {:string, :integer}}

  Record form with specific named fields:

      field :dimensions, {:map, [width: :float, height: :float]}

  The record form accepts both maps and keyword lists as input.
  Field lookup uses `Map.fetch/2` to correctly preserve false and
  nil values.
  """

  @behaviour Plushie.Type.Composite

  # Dictionary form: {:map, {key_type, val_type}}
  @impl Plushie.Type.Composite
  def cast({key_type, val_type}, value) when is_map(value) do
    Enum.reduce_while(value, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      with {:ok, ck} <- Plushie.Type.cast_value(key_type, k),
           {:ok, cv} <- Plushie.Type.cast_value(val_type, v) do
        {:cont, {:ok, Map.put(acc, ck, cv)}}
      else
        _ -> {:halt, :error}
      end
    end)
  end

  # Record form: {:map, [name: type, ...]}
  def cast(fields, value) when is_list(fields) and (is_map(value) or is_list(value)) do
    Plushie.Type.cast_named_fields(fields, value)
  end

  def cast(_, _), do: :error

  # Decode uses decode_value for inner types (wire data path).
  @impl Plushie.Type.Composite
  def decode({key_type, val_type}, value) when is_map(value) do
    Enum.reduce_while(value, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      with {:ok, ck} <- Plushie.Type.decode_value(key_type, k),
           {:ok, cv} <- Plushie.Type.decode_value(val_type, v) do
        {:cont, {:ok, Map.put(acc, ck, cv)}}
      else
        _ -> {:halt, :error}
      end
    end)
  end

  def decode(fields, value) when is_list(fields) and is_map(value) do
    Plushie.Type.decode_named_fields(fields, value)
  end

  def decode(_, _), do: :error

  @impl Plushie.Type.Composite
  def typespec({key_type, val_type}, resolver) do
    kt = resolver.(key_type)
    vt = resolver.(val_type)
    quote(do: %{optional(unquote(kt)) => unquote(vt)})
  end

  def typespec(fields, resolver) when is_list(fields) do
    field_types = Enum.map(fields, fn {name, t} -> {name, resolver.(t)} end)
    {:%{}, [], field_types}
  end

  @impl Plushie.Type.Composite
  def guard(_spec, var) do
    quote(do: is_map(unquote(var)) or is_list(unquote(var)))
  end

  @impl Plushie.Type.Composite
  def display_string({key_type, val_type}, resolver) do
    "%{#{resolver.(key_type)} => #{resolver.(val_type)}}"
  end

  def display_string(fields, resolver) when is_list(fields) do
    inner =
      Enum.map_join(fields, ", ", fn {name, t} -> "#{name}: #{resolver.(t)}" end)

    "%{#{inner}}"
  end

  @impl Plushie.Type.Composite
  def valid_spec?({k, v}, checker), do: checker.(k) and checker.(v)

  def valid_spec?(fields, checker) when is_list(fields),
    do: Enum.all?(fields, fn {_, t} -> checker.(t) end)

  def valid_spec?(_, _), do: false
end
