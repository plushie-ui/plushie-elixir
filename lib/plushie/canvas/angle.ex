defmodule Plushie.Canvas.Angle do
  @moduledoc """
  Angle type for canvas rotation and arc parameters.

  Accepts degrees by default. Use `{value, :rad}` for explicit radians
  or `{value, :deg}` for explicit degrees.

      rotate(45)              # 45 degrees
      rotate({45, :deg})      # same
      rotate({0.785, :rad})   # explicit radians

  The renderer receives degrees on the wire. Bare numbers are treated
  as degrees (matching the Rust SDK convention). Values are normalized
  to degrees at cast time.

  When used as a field type, values are normalized to degrees at cast
  time. The `to_radians/1` function is available for contexts that
  need radian values.
  """

  use Plushie.Type

  @type t :: number() | {number(), :deg} | {number(), :rad}

  @impl Plushie.Type
  def cast(v) when is_number(v), do: {:ok, to_degrees(v)}
  def cast({v, :deg}) when is_number(v), do: {:ok, to_degrees({v, :deg})}
  def cast({v, :rad}) when is_number(v), do: {:ok, to_degrees({v, :rad})}
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
  Converts an angle value to degrees.

  Accepts bare numbers (already degrees), `{value, :deg}`, or `{value, :rad}`.
  """
  @spec to_degrees(t()) :: float()
  def to_degrees(v) when is_number(v), do: v * 1.0
  def to_degrees({v, :deg}) when is_number(v), do: v * 1.0
  def to_degrees({v, :rad}) when is_number(v), do: v * 180.0 / :math.pi()

  @doc """
  Converts an angle value to radians.

  Accepts bare numbers (degrees), `{value, :deg}`, or `{value, :rad}`.
  """
  @spec to_radians(t()) :: float()
  def to_radians(v) when is_number(v), do: v * :math.pi() / 180.0
  def to_radians({v, :deg}) when is_number(v), do: v * :math.pi() / 180.0
  def to_radians({v, :rad}) when is_number(v), do: v * 1.0
end
