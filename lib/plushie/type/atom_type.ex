defmodule Plushie.Type.Atom do
  @moduledoc """
  Atom type. Accepts any atom.
  """

  @behaviour Plushie.Type

  @impl true
  def cast(v) when is_atom(v), do: {:ok, v}
  def cast(_), do: :error

  @impl true
  def typespec, do: quote(do: atom())

  @impl true
  def guard(var), do: quote(do: is_atom(unquote(var)))
end
