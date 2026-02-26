defmodule Julep.Iced.Border do
  @moduledoc "Border type for container and widget styling."

  @doc "Creates a new border with default values."
  @spec new() :: map()
  def new, do: %{color: nil, width: 0, radius: 0}

  @doc "Sets the border color."
  @spec color(map(), term()) :: map()
  def color(border, color), do: %{border | color: color}

  @doc "Sets the border width."
  @spec width(map(), number()) :: map()
  def width(border, width), do: %{border | width: width}

  @doc "Sets a uniform corner radius."
  @spec rounded(map(), number()) :: map()
  def rounded(border, radius), do: %{border | radius: radius}

  @doc "Creates a per-corner radius map."
  @spec radius(number(), number(), number(), number()) :: map()
  def radius(top_left, top_right, bottom_right, bottom_left) do
    %{top_left: top_left, top_right: top_right, bottom_right: bottom_right, bottom_left: bottom_left}
  end

  @doc "Encodes a border to the wire format. Per-corner radius maps are converted to string keys."
  @spec encode(map()) :: map()
  def encode(%{} = border) do
    Map.update(border, :radius, border[:radius], &encode_radius/1)
  end

  defp encode_radius(%{top_left: tl, top_right: tr, bottom_right: br, bottom_left: bl}) do
    %{"top_left" => tl, "top_right" => tr, "bottom_right" => br, "bottom_left" => bl}
  end

  defp encode_radius(radius), do: radius
end
