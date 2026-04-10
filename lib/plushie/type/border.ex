defmodule Plushie.Type.Border do
  @moduledoc """
  Border specification for container and widget styling.

  A border has three properties:

    * `color` - hex color string (e.g. `"#ff0000"`). `nil` means no color override.
    * `width` - border width in pixels. Default: `0`.
    * `radius` - corner radius. Either a uniform number or a per-corner
      `radius_map()` from `radius/4`. Default: `0`.

  ## Wire format

  The encoded border is a map:

      %{color: "#ff0000", width: 2, radius: 8}

  Radius can be a uniform number or a per-corner map:

      %{top_left: 8, top_right: 8, bottom_right: 0, bottom_left: 0}

  ## Example

      border = Plushie.Type.Border.new()
               |> Plushie.Type.Border.color("#3366ff")
               |> Plushie.Type.Border.width(2)
               |> Plushie.Type.Border.rounded(8)
  """

  @typedoc "Per-corner radius map."
  @type radius_map :: %{
          top_left: number(),
          top_right: number(),
          bottom_right: number(),
          bottom_left: number()
        }

  @typedoc "Border specification with color, width, and radius."
  @type t :: %__MODULE__{
          color: Plushie.Type.Color.t() | nil,
          width: number(),
          radius: number() | radius_map()
        }

  use Plushie.Type

  @known_keys ~w(color width rounded radius)a

  defstruct color: nil, width: 0, radius: 0

  @doc "Creates a new border with default values (no color, zero width, zero radius)."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Sets the border color. Accepts a hex string or named color atom."
  @spec color(border :: t(), color :: Plushie.Type.Color.input()) :: t()
  def color(%__MODULE__{} = border, color),
    do: %{border | color: elem(Plushie.Type.Color.cast(color), 1)}

  @doc "Sets the border width in pixels."
  @spec width(border :: t(), width :: number()) :: t()
  def width(%__MODULE__{} = border, width) when is_number(width), do: %{border | width: width}

  @doc "Sets a uniform corner radius in pixels."
  @spec rounded(border :: t(), radius :: number()) :: t()
  def rounded(%__MODULE__{} = border, radius) when is_number(radius),
    do: %{border | radius: radius}

  @doc "Creates a per-corner radius map."
  @spec radius(
          top_left :: number(),
          top_right :: number(),
          bottom_right :: number(),
          bottom_left :: number()
        ) :: radius_map()
  def radius(top_left, top_right, bottom_right, bottom_left)
      when is_number(top_left) and is_number(top_right) and
             is_number(bottom_right) and is_number(bottom_left) do
    %{
      top_left: top_left,
      top_right: top_right,
      bottom_right: bottom_right,
      bottom_left: bottom_left
    }
  end

  def __field_keys__, do: @known_keys

  def __field_types__, do: %{}

  @doc "Constructs a `Border` from a keyword list."
  @spec from_opts(opts :: keyword()) :: t()
  def from_opts(opts) when is_list(opts) do
    for {key, _} <- opts, key not in @known_keys do
      raise ArgumentError,
            "unknown border field #{inspect(key)}. Valid fields: #{inspect(@known_keys)}"
    end

    Enum.reduce(opts, new(), fn
      {:color, v}, acc -> color(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:rounded, v}, acc -> rounded(acc, v)
      {:radius, v}, acc -> %{acc | radius: v}
    end)
  end

  # -- Plushie.Type callbacks --------------------------------------------------

  @doc """
  Validates a border value.

  Accepts a `%Border{}` struct or a map with border fields.

  ## Examples

      iex> Plushie.Type.Border.cast(%Plushie.Type.Border{width: 2})
      {:ok, %Plushie.Type.Border{width: 2}}
  """
  @impl Plushie.Type
  @spec cast(term()) :: {:ok, t()} | :error
  def cast(%__MODULE__{} = border), do: {:ok, border}

  def cast(map) when is_map(map) do
    {:ok, from_opts(Enum.to_list(map))}
  rescue
    ArgumentError -> :error
  end

  def cast(_), do: :error

  @impl Plushie.Type
  def typespec do
    quote do: %Plushie.Type.Border{}
  end

  @impl Plushie.Type
  def guard(var) do
    quote do: is_struct(unquote(var), Plushie.Type.Border)
  end

  @doc "Encodes a border to the wire format."
  @impl Plushie.Type
  @spec encode(border :: t()) :: map()
  def encode(%__MODULE__{} = border) do
    %{color: border.color, width: border.width, radius: encode_radius(border.radius)}
  end

  defp encode_radius(%{top_left: tl, top_right: tr, bottom_right: br, bottom_left: bl}) do
    %{top_left: tl, top_right: tr, bottom_right: br, bottom_left: bl}
  end

  defp encode_radius(radius), do: radius
end
