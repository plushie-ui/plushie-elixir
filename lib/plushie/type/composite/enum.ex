defmodule Plushie.Type.Composite.Enum do
  @moduledoc """
  Composite type for a fixed set of values.

  Accepts exact matches and coerces strings to matching atoms (for
  wire data compatibility).

      field :mode, {:enum, [:read, :write]}
  """

  @behaviour Plushie.Type.Composite

  @impl Plushie.Type.Composite
  def cast(values, value) do
    if value in values do
      {:ok, value}
    else
      cast_from_string(values, value)
    end
  end

  # Wire data arrives as strings. Coerce to matching atom if possible.
  defp cast_from_string(values, value) when is_binary(value) do
    Enum.find_value(values, :error, fn
      atom when is_atom(atom) ->
        if Atom.to_string(atom) == value, do: {:ok, atom}

      _ ->
        nil
    end)
  end

  defp cast_from_string(_, _), do: :error

  @impl Plushie.Type.Composite
  def typespec(values, _resolver) do
    values
    |> Enum.reverse()
    |> Enum.reduce(fn val, acc -> {:|, [], [val, acc]} end)
  end

  @impl Plushie.Type.Composite
  def guard(values, var) do
    quote(do: unquote(var) in unquote(Macro.escape(values)))
  end

  @impl Plushie.Type.Composite
  def display_string(values, _resolver) do
    Enum.map_join(values, " | ", &inspect/1)
  end

  @impl Plushie.Type.Composite
  def valid_spec?(values, _checker) when is_list(values), do: true
  def valid_spec?(_, _), do: false
end
