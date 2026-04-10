defmodule Plushie.Type.Atom do
  @moduledoc "Atom type. Accepts any atom (including `nil`)."

  use Plushie.Type

  @type t :: atom()

  @impl Plushie.Type
  def cast(v) when is_atom(v), do: {:ok, v}
  def cast(_), do: :error

  @impl Plushie.Type
  def typespec, do: quote(do: atom())

  @impl Plushie.Type
  def guard(var), do: quote(do: is_atom(unquote(var)))
end
