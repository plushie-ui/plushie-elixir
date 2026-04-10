defmodule Plushie.Type.Any do
  @moduledoc """
  Accepts any value without validation.
  """

  use Plushie.Type

  @impl true
  def cast(v), do: {:ok, v}

  @impl true
  def typespec, do: quote(do: term())
end
