defmodule Julep.Iced.Padding do
  @moduledoc """
  Padding values matching iced's `Padding` struct.

  Accepted input forms:

  - integer -- uniform padding on all sides
  - `{vertical, horizontal}` -- symmetric padding
  - `%{top: t, right: r, bottom: b, left: l}` -- explicit per-side

  `encode/1` always normalises to the full four-side map.
  """

  @type t ::
          number()
          | {number(), number()}
          | %{top: number(), right: number(), bottom: number(), left: number()}

  @doc """
  Normalises a padding value to the canonical four-side map with string keys.

  ## Examples

      iex> Julep.Iced.Padding.encode(8)
      %{"top" => 8, "right" => 8, "bottom" => 8, "left" => 8}

      iex> Julep.Iced.Padding.encode({4, 12})
      %{"top" => 4, "right" => 12, "bottom" => 4, "left" => 12}

      iex> Julep.Iced.Padding.encode(%{top: 1, right: 2, bottom: 3, left: 4})
      %{"top" => 1, "right" => 2, "bottom" => 3, "left" => 4}
  """
  @spec encode(t()) :: map()
  def encode(n) when is_number(n) do
    %{"top" => n, "right" => n, "bottom" => n, "left" => n}
  end

  def encode({vertical, horizontal}) when is_number(vertical) and is_number(horizontal) do
    %{"top" => vertical, "right" => horizontal, "bottom" => vertical, "left" => horizontal}
  end

  def encode(%{top: t, right: r, bottom: b, left: l}) do
    %{"top" => t, "right" => r, "bottom" => b, "left" => l}
  end
end
