defmodule Plushie.Canvas.Angle do
  @moduledoc """
  Angle type for canvas rotation and arc parameters.

  Accepts degrees by default. Use `{value, :rad}` for explicit radians
  or `{value, :deg}` for explicit degrees.

      rotate(45)              # 45 degrees
      rotate({45, :deg})      # same
      rotate({0.785, :rad})   # explicit radians

  The renderer receives radians on the wire. Conversion happens
  automatically during encoding.

  When used as a field type, values are normalized to radians at cast
  time (like `Plushie.Type.Color` normalizes to hex strings). The
  `to_radians/1` function is also available for direct use in builder
  functions.
  """

  use Plushie.Type

  @type t :: number() | {number(), :deg} | {number(), :rad}

  @impl Plushie.Type
  def cast(v) when is_number(v), do: {:ok, to_radians(v)}
  def cast({v, :deg}) when is_number(v), do: {:ok, to_radians({v, :deg})}
  def cast({v, :rad}) when is_number(v), do: {:ok, to_radians({v, :rad})}
  def cast(_), do: :error

  @impl Plushie.Type
  def castable do
    quote(do: number() | {number(), :deg} | {number(), :rad})
  end

  @impl Plushie.Type
  def typespec, do: quote(do: float())

  @impl Plushie.Type
  def guard(var), do: quote(do: is_number(unquote(var)))

  @doc """
  Converts an angle value to radians.

  Accepts bare numbers (degrees), `{value, :deg}`, or `{value, :rad}`.
  """
  @spec to_radians(t()) :: float()
  def to_radians(v) when is_number(v), do: v * :math.pi() / 180.0
  def to_radians({v, :deg}) when is_number(v), do: v * :math.pi() / 180.0
  def to_radians({v, :rad}) when is_number(v), do: v * 1.0
end
