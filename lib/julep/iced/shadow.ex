defmodule Julep.Iced.Shadow do
  @moduledoc """
  Shadow type for widget styling.

  Used in `container` and other widgets via the `shadow` prop.
  The renderer parses shadow maps into `iced::Shadow`.

  ## Wire format

      %{
        color: "#00000080",
        offset: [4, 4],
        blur_radius: 8.0
      }

  The `offset` is an `[x, y]` list. `color` is any color format
  (see `Julep.Iced.Color`).

  ## Example

      shadow = Julep.Iced.Shadow.new()
               |> Julep.Iced.Shadow.color("#00000040")
               |> Julep.Iced.Shadow.offset(2, 2)
               |> Julep.Iced.Shadow.blur_radius(6)
  """

  @typedoc "Shadow specification with color, offset, and blur radius."
  @type t :: %{
          color: String.t(),
          offset_x: number(),
          offset_y: number(),
          blur_radius: number()
        }

  @doc "Creates a new shadow with default values."
  @spec new() :: t()
  def new, do: %{color: "#000000", offset_x: 0, offset_y: 0, blur_radius: 0}

  @doc "Sets the shadow color."
  @spec color(shadow :: t(), color :: String.t()) :: t()
  def color(shadow, color), do: %{shadow | color: color}

  @doc "Sets the shadow offset."
  @spec offset(shadow :: t(), x :: number(), y :: number()) :: t()
  def offset(shadow, x, y), do: %{shadow | offset_x: x, offset_y: y}

  @doc "Sets the shadow blur radius."
  @spec blur_radius(shadow :: t(), r :: number()) :: t()
  def blur_radius(shadow, r), do: %{shadow | blur_radius: r}

  @doc "Encodes a shadow to the wire format."
  @spec encode(shadow :: t()) :: t()
  def encode(%{} = shadow), do: shadow
end
