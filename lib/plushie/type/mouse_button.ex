defmodule Plushie.Type.MouseButton do
  @moduledoc """
  Event field type for mouse buttons.

  Parses wire-format mouse button strings into atoms.

  ## Examples

      iex> Plushie.Type.MouseButton.parse("left")
      {:ok, :left}

      iex> Plushie.Type.MouseButton.parse("right")
      {:ok, :right}

      iex> Plushie.Type.MouseButton.parse("unknown")
      :error
  """

  @behaviour Plushie.Type

  # nil defaults to :left because canvas press/release events omit
  # the button field when the left button is used (the common case).
  # The renderer only sends the button field for non-left clicks.

  @buttons %{
    "left" => :left,
    "right" => :right,
    "middle" => :middle,
    "back" => :back,
    "forward" => :forward
  }

  @spec parse(value :: term()) :: {:ok, :left | :right | :middle | :back | :forward} | :error
  def parse(value) when is_binary(value) do
    case Map.fetch(@buttons, value) do
      {:ok, button} -> {:ok, button}
      :error -> :error
    end
  end

  def parse(nil), do: {:ok, :left}
  def parse(_), do: :error

  @impl Plushie.Type
  def cast(value), do: parse(value)

  @impl Plushie.Type
  def typespec do
    quote do: :left | :right | :middle | :back | :forward
  end
end
