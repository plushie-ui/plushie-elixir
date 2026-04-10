defmodule Plushie.Type.Composite.Union do
  @moduledoc """
  Composite type for unions.

  Tries each type in order. The first successful cast wins.

      field :background, {:union, [Plushie.Type.Color, Plushie.Type.Gradient]}
  """

  @behaviour Plushie.Type.Composite

  @impl Plushie.Type.Composite
  def cast(types, value) do
    Enum.find_value(types, :error, fn type ->
      case Plushie.Type.cast_value(type, value) do
        {:ok, v} -> {:ok, v}
        :error -> nil
      end
    end)
  end

  @impl Plushie.Type.Composite
  def decode(types, value) do
    Enum.find_value(types, :error, fn type ->
      case Plushie.Type.decode_value(type, value) do
        {:ok, v} -> {:ok, v}
        :error -> nil
      end
    end)
  end

  @impl Plushie.Type.Composite
  def typespec(types, resolver) do
    type_asts = Enum.map(types, resolver)

    type_asts
    |> Enum.reverse()
    |> Enum.reduce(fn t, acc -> {:|, [], [t, acc]} end)
  end

  @impl Plushie.Type.Composite
  def guard(_types, _var), do: nil

  @impl Plushie.Type.Composite
  def display_string(types, resolver) do
    Enum.map_join(types, " | ", resolver)
  end

  @impl Plushie.Type.Composite
  def valid_spec?(types, checker) when is_list(types), do: Enum.all?(types, checker)
  def valid_spec?(_, _), do: false
end
