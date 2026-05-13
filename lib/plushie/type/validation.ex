defmodule Plushie.Type.Validation do
  @moduledoc """
  Renderer-facing form validation state.

  Accepted values are `:valid`, `:pending`, and `{:invalid, message}`.
  Invalid states encode to the map shape expected by the renderer.
  """

  use Plushie.Type

  @type t :: :valid | :pending | %{state: :invalid, message: String.t()}
  @type input :: :valid | :pending | {:invalid, String.t()} | t()

  @impl Plushie.Type
  @spec cast(term()) :: {:ok, t()} | :error
  def cast(state) when state in [:valid, :pending], do: {:ok, state}
  def cast({:invalid, message}) when is_binary(message), do: {:ok, invalid(message)}

  def cast(%{state: state} = value) when state in [:invalid, "invalid"] do
    case Map.get(value, :message) || Map.get(value, "message") do
      message when is_binary(message) -> {:ok, invalid(message)}
      _ -> :error
    end
  end

  def cast(%{"state" => state} = value) when state in [:invalid, "invalid"] do
    case Map.get(value, :message) || Map.get(value, "message") do
      message when is_binary(message) -> {:ok, invalid(message)}
      _ -> :error
    end
  end

  def cast(_), do: :error

  @impl Plushie.Type
  def typespec do
    quote do
      :valid | :pending | {:invalid, String.t()} | %{state: :invalid, message: String.t()}
    end
  end

  @impl Plushie.Type
  def guard(_var), do: nil

  @impl Plushie.Type
  def encode(state) when state in [:valid, :pending], do: Atom.to_string(state)

  def encode(%{state: :invalid, message: message}) do
    %{state: "invalid", message: message}
  end

  defp invalid(message), do: %{state: :invalid, message: message}
end
