defmodule Julep.Iced.Border do
  @moduledoc """
  Border type for container and widget styling.

  Used in `container` and other widgets via the `border` prop.
  The renderer parses border maps with `color`, `width`, and `radius` fields.

  ## Wire format

  The encoded border is a map:

      %{color: "#ff0000", width: 2, radius: 8}

  Radius can be a uniform number or a per-corner map:

      %{top_left: 8, top_right: 8, bottom_right: 0, bottom_left: 0}

  ## Example

      border = Julep.Iced.Border.new()
               |> Julep.Iced.Border.color("#3366ff")
               |> Julep.Iced.Border.width(2)
               |> Julep.Iced.Border.rounded(8)
      # => %{color: "#3366ff", width: 2, radius: 8}
  """

  @typedoc "Per-corner radius map."
  @type radius_map :: %{
          top_left: number(),
          top_right: number(),
          bottom_right: number(),
          bottom_left: number()
        }

  @typedoc "Border specification with color, width, and radius."
  @type t :: %{
          color: Julep.Iced.Color.t() | nil,
          width: number(),
          radius: number() | radius_map()
        }

  @doc "Creates a new border with default values."
  @spec new() :: t()
  def new, do: %{color: nil, width: 0, radius: 0}

  @doc "Sets the border color."
  @spec color(border :: t(), color :: Julep.Iced.Color.t()) :: t()
  def color(border, color), do: %{border | color: color}

  @doc "Sets the border width."
  @spec width(border :: t(), width :: number()) :: t()
  def width(border, width), do: %{border | width: width}

  @doc "Sets a uniform corner radius."
  @spec rounded(border :: t(), radius :: number()) :: t()
  def rounded(border, radius), do: %{border | radius: radius}

  @doc "Creates a per-corner radius map."
  @spec radius(
          top_left :: number(),
          top_right :: number(),
          bottom_right :: number(),
          bottom_left :: number()
        ) :: radius_map()
  def radius(top_left, top_right, bottom_right, bottom_left) do
    %{
      top_left: top_left,
      top_right: top_right,
      bottom_right: bottom_right,
      bottom_left: bottom_left
    }
  end

  @doc "Encodes a border to the wire format. Per-corner radius maps are converted to string keys."
  @spec encode(border :: t()) :: map()
  def encode(%{} = border) do
    Map.update(border, :radius, border[:radius], &encode_radius/1)
  end

  defp encode_radius(%{top_left: tl, top_right: tr, bottom_right: br, bottom_left: bl}) do
    %{"top_left" => tl, "top_right" => tr, "bottom_right" => br, "bottom_left" => bl}
  end

  defp encode_radius(radius), do: radius
end
