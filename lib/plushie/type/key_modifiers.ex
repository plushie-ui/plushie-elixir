defmodule Plushie.Type.KeyModifiers do
  @moduledoc """
  Event field type for keyboard modifier state.

  Parses a wire-format modifier map (string keys, boolean values) into
  a `%Plushie.KeyModifiers{}` struct. Missing fields default to `false`.

  ## Examples

      iex> Plushie.Type.KeyModifiers.parse(%{"ctrl" => true, "shift" => false})
      {:ok, %Plushie.KeyModifiers{ctrl: true, shift: false, alt: false, logo: false, command: false}}

      iex> Plushie.Type.KeyModifiers.parse(%{})
      {:ok, %Plushie.KeyModifiers{}}

      iex> Plushie.Type.KeyModifiers.parse(nil)
      {:ok, %Plushie.KeyModifiers{}}
  """

  @behaviour Plushie.Type

  @spec parse(value :: term()) :: {:ok, Plushie.KeyModifiers.t()} | :error
  def parse(mods) when is_map(mods) do
    {:ok,
     %Plushie.KeyModifiers{
       ctrl: Map.get(mods, "ctrl", false),
       shift: Map.get(mods, "shift", false),
       alt: Map.get(mods, "alt", false),
       logo: Map.get(mods, "logo", false),
       command: Map.get(mods, "command", false)
     }}
  end

  def parse(nil), do: {:ok, %Plushie.KeyModifiers{}}
  def parse(_), do: :error

  @impl Plushie.Type
  def cast(value), do: parse(value)

  @impl Plushie.Type
  def typespec do
    quote do: Plushie.KeyModifiers.t()
  end
end
