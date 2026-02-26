defmodule Julep.Iced.Shadow do
  @moduledoc "Shadow type for widget styling."

  @doc "Creates a new shadow with default values."
  @spec new() :: map()
  def new, do: %{color: "#000000", offset_x: 0, offset_y: 0, blur_radius: 0}

  @doc "Sets the shadow color."
  @spec color(map(), term()) :: map()
  def color(shadow, color), do: %{shadow | color: color}

  @doc "Sets the shadow offset."
  @spec offset(map(), number(), number()) :: map()
  def offset(shadow, x, y), do: %{shadow | offset_x: x, offset_y: y}

  @doc "Sets the shadow blur radius."
  @spec blur_radius(map(), number()) :: map()
  def blur_radius(shadow, r), do: %{shadow | blur_radius: r}

  @doc "Encodes a shadow to the wire format."
  @spec encode(map()) :: map()
  def encode(%{} = shadow), do: shadow
end
