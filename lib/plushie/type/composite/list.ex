defmodule Plushie.Type.Composite.List do
  @moduledoc """
  Composite type for typed lists.

  Every element is cast through the inner type. All must succeed.

      field :tags, {:list, :string}
  """

  @behaviour Plushie.Type.Composite

  @impl Plushie.Type.Composite
  def cast(inner_type, value) when is_list(value) do
    results = Enum.map(value, fn el -> Plushie.Type.cast_value(inner_type, el) end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, Enum.map(results, fn {:ok, v} -> v end)}
    else
      :error
    end
  end

  def cast(_, _), do: :error

  @impl Plushie.Type.Composite
  def decode(inner_type, value) when is_list(value) do
    results = Enum.map(value, fn el -> Plushie.Type.decode_value(inner_type, el) end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, Enum.map(results, fn {:ok, v} -> v end)}
    else
      :error
    end
  end

  def decode(_, _), do: :error

  @impl Plushie.Type.Composite
  def typespec(inner_type, resolver) do
    inner = resolver.(inner_type)
    quote(do: [unquote(inner)])
  end

  @impl Plushie.Type.Composite
  def guard(_inner_type, var) do
    quote(do: is_list(unquote(var)))
  end

  @impl Plushie.Type.Composite
  def display_string(inner_type, resolver) do
    "[#{resolver.(inner_type)}]"
  end

  @impl Plushie.Type.Composite
  def valid_spec?(inner_type, checker), do: checker.(inner_type)
end
