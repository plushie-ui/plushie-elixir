defmodule Toddy.Type.Shadow do
  @moduledoc """
  Shadow type for widget styling.

  Used in `container` and other widgets via the `shadow` prop.
  The renderer parses shadow into `iced::Shadow`.

  ## Wire format

      %{color: "#00000080", offset: [4, 4], blur_radius: 8.0}

  The `offset` is an `[x, y]` list. `color` is a hex string (see `Toddy.Type.Color`).

  ## Example

      shadow = Toddy.Type.Shadow.new()
               |> Toddy.Type.Shadow.color("#00000040")
               |> Toddy.Type.Shadow.offset(2, 2)
               |> Toddy.Type.Shadow.blur_radius(6)
  """

  @type t :: %__MODULE__{
          color: Toddy.Type.Color.t(),
          offset_x: number(),
          offset_y: number(),
          blur_radius: number()
        }

  @behaviour Toddy.DSL.Buildable

  @known_keys ~w(color offset offset_x offset_y blur_radius)a

  defstruct color: "#000000", offset_x: 0, offset_y: 0, blur_radius: 0

  @doc "Creates a new shadow with default values."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Sets the shadow color. Accepts a hex string or named color atom."
  @spec color(shadow :: t(), color :: Toddy.Type.Color.input()) :: t()
  def color(%__MODULE__{} = shadow, color) do
    %{shadow | color: Toddy.Type.Color.cast(color)}
  end

  @doc "Sets the shadow offset in pixels."
  @spec offset(shadow :: t(), x :: number(), y :: number()) :: t()
  def offset(%__MODULE__{} = shadow, x, y) when is_number(x) and is_number(y),
    do: %{shadow | offset_x: x, offset_y: y}

  @doc "Sets the shadow blur radius in pixels."
  @spec blur_radius(shadow :: t(), r :: number()) :: t()
  def blur_radius(%__MODULE__{} = shadow, r) when is_number(r),
    do: %{shadow | blur_radius: r}

  @impl Toddy.DSL.Buildable
  def __field_keys__, do: @known_keys

  @impl Toddy.DSL.Buildable
  def __field_types__, do: %{}

  @doc "Constructs a `Shadow` from a keyword list."
  @impl Toddy.DSL.Buildable
  @spec from_opts(opts :: keyword()) :: t()
  def from_opts(opts) when is_list(opts) do
    for {key, _} <- opts, key not in @known_keys do
      raise ArgumentError,
            "unknown shadow field #{inspect(key)}. Valid fields: #{inspect(@known_keys)}"
    end

    Enum.reduce(opts, new(), fn
      {:color, v}, acc -> color(acc, v)
      {:offset, {x, y}}, acc -> offset(acc, x, y)
      {:offset_x, v}, acc -> %{acc | offset_x: v}
      {:offset_y, v}, acc -> %{acc | offset_y: v}
      {:blur_radius, v}, acc -> blur_radius(acc, v)
    end)
  end
end
