defmodule Toddy.Iced.Shadow do
  @moduledoc """
  Shadow type for widget styling.

  Used in `container` and other widgets via the `shadow` prop.
  The renderer parses shadow into `iced::Shadow`.

  ## Wire format

      %{"color" => "#00000080", "offset" => [4, 4], "blur_radius" => 8.0}

  The `offset` is an `[x, y]` list. `color` is a hex string (see `Toddy.Iced.Color`).

  ## Example

      shadow = Toddy.Iced.Shadow.new()
               |> Toddy.Iced.Shadow.color("#00000040")
               |> Toddy.Iced.Shadow.offset(2, 2)
               |> Toddy.Iced.Shadow.blur_radius(6)
  """

  @type t :: %__MODULE__{
          color: Toddy.Iced.Color.t(),
          offset_x: number(),
          offset_y: number(),
          blur_radius: number()
        }

  defstruct color: "#000000", offset_x: 0, offset_y: 0, blur_radius: 0

  @doc "Creates a new shadow with default values."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Sets the shadow color. Accepts a hex string or named color atom."
  @spec color(shadow :: t(), color :: Toddy.Iced.Color.input()) :: t()
  def color(%__MODULE__{} = shadow, color) do
    %{shadow | color: Toddy.Iced.Color.cast(color)}
  end

  @doc "Sets the shadow offset in pixels."
  @spec offset(shadow :: t(), x :: number(), y :: number()) :: t()
  def offset(%__MODULE__{} = shadow, x, y) when is_number(x) and is_number(y),
    do: %{shadow | offset_x: x, offset_y: y}

  @doc "Sets the shadow blur radius in pixels."
  @spec blur_radius(shadow :: t(), r :: number()) :: t()
  def blur_radius(%__MODULE__{} = shadow, r) when is_number(r),
    do: %{shadow | blur_radius: r}
end
