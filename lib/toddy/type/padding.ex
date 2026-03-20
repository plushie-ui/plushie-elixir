defmodule Toddy.Type.Padding do
  @moduledoc """
  Spacing value for the `padding` prop on containers, buttons, and text inputs.

  Maps to iced's `Padding` struct. Accepts a uniform number,
  a `{vertical, horizontal}` tuple, or an explicit four-side map.
  `encode/1` always normalises to the full four-side map.
  """

  @type t ::
          number()
          | {number(), number()}
          | %{top: number(), right: number(), bottom: number(), left: number()}

  @doc """
  Normalises a padding value to the canonical four-side map with atom keys.

  ## Examples

      iex> Toddy.Type.Padding.encode(8)
      %{top: 8, right: 8, bottom: 8, left: 8}

      iex> Toddy.Type.Padding.encode({4, 12})
      %{top: 4, right: 12, bottom: 4, left: 12}

      iex> Toddy.Type.Padding.encode(%{top: 1, right: 2, bottom: 3, left: 4})
      %{top: 1, right: 2, bottom: 3, left: 4}
  """
  @spec encode(padding :: t()) :: map()
  def encode(n) when is_number(n) do
    %{top: n, right: n, bottom: n, left: n}
  end

  def encode({vertical, horizontal}) when is_number(vertical) and is_number(horizontal) do
    %{top: vertical, right: horizontal, bottom: vertical, left: horizontal}
  end

  def encode(%{top: t, right: r, bottom: b, left: l})
      when is_number(t) and is_number(r) and is_number(b) and is_number(l) do
    %{top: t, right: r, bottom: b, left: l}
  end
end
