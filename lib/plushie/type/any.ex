defmodule Plushie.Type.Any do
  @moduledoc "Accepts any value without validation. No guard is generated."

  use Plushie.Type

  @type t :: term()

  @impl Plushie.Type
  def cast(v), do: {:ok, v}

  @impl Plushie.Type
  def typespec, do: quote(do: term())
end
