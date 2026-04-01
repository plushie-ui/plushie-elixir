defmodule Plushie.Animation.Easing do
  @moduledoc """
  Easing function catalogue for animations and transitions.

  Provides 31 named easing curves (matching the standard set from
  CSS/lilt) plus custom cubic bezier support. Used by both
  `Plushie.Animation.Transition` (as atoms encoded for the wire
  protocol) and `Plushie.Animation` (as functions for SDK-side
  interpolation).

  ## Named curves

  Each curve has a public function that takes a progress value
  `t` in `0.0..1.0` and returns the eased value. Some curves
  (back, elastic, bounce) can overshoot the 0..1 range.

  ### Linear

  Constant velocity. No acceleration or deceleration.

  ### Sine (ease_in, ease_out, ease_in_out)

  Gentle acceleration/deceleration using sine curves. The default
  `ease_in_out` is a good general-purpose choice.

  ### Power curves (quad, cubic, quart, quint)

  Increasingly aggressive acceleration. Higher power = sharper
  start/stop.

  ### Exponential (expo)

  Very sharp acceleration. Starts almost stationary, then
  accelerates rapidly.

  ### Circular (circ)

  Based on circular arc geometry. Moderate sharpness.

  ### Back

  Overshoots the target slightly before settling. Good for
  playful, bouncy interfaces.

  ### Elastic

  Oscillates around the target like a spring on a rubber band.
  Large overshoot.

  ### Bounce

  Simulates a bouncing ball. Multiple diminishing bounces at the
  end.

  ## Cubic bezier

  For custom curves, pass `{:cubic_bezier, x1, y1, x2, y2}`:

      opacity: transition(300, to: 0.0, easing: {:cubic_bezier, 0.25, 0.1, 0.25, 1.0})

  Control points match the CSS `cubic-bezier()` function.
  """

  @pi :math.pi()

  # Back constants (standard CSS values)
  @c1 1.70158
  @c2 @c1 * 1.525
  @c3 @c1 + 1.0

  # Elastic constants
  @c4 2.0 * @pi / 3.0
  @c5 2.0 * @pi / 4.5

  # Bounce constants
  @n1 7.5625
  @d1 2.75

  @named_easings ~w(
    linear
    ease_in ease_out ease_in_out
    ease_in_quad ease_out_quad ease_in_out_quad
    ease_in_cubic ease_out_cubic ease_in_out_cubic
    ease_in_quart ease_out_quart ease_in_out_quart
    ease_in_quint ease_out_quint ease_in_out_quint
    ease_in_expo ease_out_expo ease_in_out_expo
    ease_in_circ ease_out_circ ease_in_out_circ
    ease_in_back ease_out_back ease_in_out_back
    ease_in_elastic ease_out_elastic ease_in_out_elastic
    ease_in_bounce ease_out_bounce ease_in_out_bounce
  )a

  @type named ::
          :linear
          | :ease_in
          | :ease_out
          | :ease_in_out
          | :ease_in_quad
          | :ease_out_quad
          | :ease_in_out_quad
          | :ease_in_cubic
          | :ease_out_cubic
          | :ease_in_out_cubic
          | :ease_in_quart
          | :ease_out_quart
          | :ease_in_out_quart
          | :ease_in_quint
          | :ease_out_quint
          | :ease_in_out_quint
          | :ease_in_expo
          | :ease_out_expo
          | :ease_in_out_expo
          | :ease_in_circ
          | :ease_out_circ
          | :ease_in_out_circ
          | :ease_in_back
          | :ease_out_back
          | :ease_in_out_back
          | :ease_in_elastic
          | :ease_out_elastic
          | :ease_in_out_elastic
          | :ease_in_bounce
          | :ease_out_bounce
          | :ease_in_out_bounce

  @type t :: named() | {:cubic_bezier, float(), float(), float(), float()}

  @doc "Returns the list of all named easing atoms."
  @spec named_easings() :: [named()]
  def named_easings, do: @named_easings

  @doc "Returns true if the value is a valid easing spec."
  @spec valid?(term()) :: boolean()
  def valid?(easing) when easing in @named_easings, do: true

  def valid?({:cubic_bezier, x1, y1, x2, y2})
      when is_number(x1) and is_number(y1) and is_number(x2) and is_number(y2),
      do: true

  def valid?(_), do: false

  @doc "Returns the wire-format string for an easing spec."
  @spec name(t()) :: String.t() | map()
  def name(easing) when easing in @named_easings, do: Atom.to_string(easing)
  def name({:cubic_bezier, x1, y1, x2, y2}), do: %{"cubic_bezier" => [x1, y1, x2, y2]}

  @doc """
  Returns the Elixir easing function for SDK-side interpolation.

  The returned function takes a float `t` in `0.0..1.0` and
  returns the eased progress value.
  """
  @spec function(t()) :: (float() -> float())
  def function(:linear), do: &linear/1
  def function(:ease_in), do: &ease_in/1
  def function(:ease_out), do: &ease_out/1
  def function(:ease_in_out), do: &ease_in_out/1
  def function(:ease_in_quad), do: &ease_in_quad/1
  def function(:ease_out_quad), do: &ease_out_quad/1
  def function(:ease_in_out_quad), do: &ease_in_out_quad/1
  def function(:ease_in_cubic), do: &ease_in_cubic/1
  def function(:ease_out_cubic), do: &ease_out_cubic/1
  def function(:ease_in_out_cubic), do: &ease_in_out_cubic/1
  def function(:ease_in_quart), do: &ease_in_quart/1
  def function(:ease_out_quart), do: &ease_out_quart/1
  def function(:ease_in_out_quart), do: &ease_in_out_quart/1
  def function(:ease_in_quint), do: &ease_in_quint/1
  def function(:ease_out_quint), do: &ease_out_quint/1
  def function(:ease_in_out_quint), do: &ease_in_out_quint/1
  def function(:ease_in_expo), do: &ease_in_expo/1
  def function(:ease_out_expo), do: &ease_out_expo/1
  def function(:ease_in_out_expo), do: &ease_in_out_expo/1
  def function(:ease_in_circ), do: &ease_in_circ/1
  def function(:ease_out_circ), do: &ease_out_circ/1
  def function(:ease_in_out_circ), do: &ease_in_out_circ/1
  def function(:ease_in_back), do: &ease_in_back/1
  def function(:ease_out_back), do: &ease_out_back/1
  def function(:ease_in_out_back), do: &ease_in_out_back/1
  def function(:ease_in_elastic), do: &ease_in_elastic/1
  def function(:ease_out_elastic), do: &ease_out_elastic/1
  def function(:ease_in_out_elastic), do: &ease_in_out_elastic/1
  def function(:ease_in_bounce), do: &ease_in_bounce/1
  def function(:ease_out_bounce), do: &ease_out_bounce/1
  def function(:ease_in_out_bounce), do: &ease_in_out_bounce/1

  def function({:cubic_bezier, x1, y1, x2, y2}) do
    fn t -> cubic_bezier(t, x1, y1, x2, y2) end
  end

  @doc """
  Interpolates a value from `a` to `b` at progress `t` with the
  given easing.

      iex> Easing.interpolate(0.0, 100.0, 0.5, :linear)
      50.0
  """
  @spec interpolate(a :: number(), b :: number(), t :: float(), easing :: t()) :: float()
  def interpolate(a, b, t, easing) do
    clamped = max(0.0, min(1.0, t))
    eased = apply_easing(clamped, easing)
    a + (b - a) * eased
  end

  defp apply_easing(t, easing) when easing in @named_easings do
    apply(__MODULE__, easing, [t])
  end

  defp apply_easing(t, {:cubic_bezier, x1, y1, x2, y2}) do
    cubic_bezier(t, x1, y1, x2, y2)
  end

  # ---------------------------------------------------------------------------
  # Linear
  # ---------------------------------------------------------------------------

  @doc "Linear easing: constant velocity."
  @spec linear(float()) :: float()
  def linear(t), do: t

  # ---------------------------------------------------------------------------
  # Sine
  # ---------------------------------------------------------------------------

  @doc "Sine ease in: gentle acceleration."
  @spec ease_in(float()) :: float()
  def ease_in(t), do: 1.0 - :math.cos(t * @pi / 2.0)

  @doc "Sine ease out: gentle deceleration."
  @spec ease_out(float()) :: float()
  def ease_out(t), do: :math.sin(t * @pi / 2.0)

  @doc "Sine ease in-out: gentle acceleration and deceleration."
  @spec ease_in_out(float()) :: float()
  def ease_in_out(t), do: -(:math.cos(@pi * t) - 1.0) / 2.0

  # ---------------------------------------------------------------------------
  # Quadratic
  # ---------------------------------------------------------------------------

  @doc "Quadratic ease in."
  @spec ease_in_quad(float()) :: float()
  def ease_in_quad(t), do: t * t

  @doc "Quadratic ease out."
  @spec ease_out_quad(float()) :: float()
  def ease_out_quad(t), do: 1.0 - (1.0 - t) * (1.0 - t)

  @doc "Quadratic ease in-out."
  @spec ease_in_out_quad(float()) :: float()
  def ease_in_out_quad(t) when t < 0.5, do: 2.0 * t * t
  def ease_in_out_quad(t), do: 1.0 - :math.pow(-2.0 * t + 2.0, 2) / 2.0

  # ---------------------------------------------------------------------------
  # Cubic
  # ---------------------------------------------------------------------------

  @doc "Cubic ease in."
  @spec ease_in_cubic(float()) :: float()
  def ease_in_cubic(t), do: t * t * t

  @doc "Cubic ease out."
  @spec ease_out_cubic(float()) :: float()
  def ease_out_cubic(t), do: 1.0 - :math.pow(1.0 - t, 3)

  @doc "Cubic ease in-out."
  @spec ease_in_out_cubic(float()) :: float()
  def ease_in_out_cubic(t) when t < 0.5, do: 4.0 * t * t * t
  def ease_in_out_cubic(t), do: 1.0 - :math.pow(-2.0 * t + 2.0, 3) / 2.0

  # ---------------------------------------------------------------------------
  # Quartic
  # ---------------------------------------------------------------------------

  @doc "Quartic ease in."
  @spec ease_in_quart(float()) :: float()
  def ease_in_quart(t), do: t * t * t * t

  @doc "Quartic ease out."
  @spec ease_out_quart(float()) :: float()
  def ease_out_quart(t), do: 1.0 - :math.pow(1.0 - t, 4)

  @doc "Quartic ease in-out."
  @spec ease_in_out_quart(float()) :: float()
  def ease_in_out_quart(t) when t < 0.5, do: 8.0 * t * t * t * t
  def ease_in_out_quart(t), do: 1.0 - :math.pow(-2.0 * t + 2.0, 4) / 2.0

  # ---------------------------------------------------------------------------
  # Quintic
  # ---------------------------------------------------------------------------

  @doc "Quintic ease in."
  @spec ease_in_quint(float()) :: float()
  def ease_in_quint(t), do: t * t * t * t * t

  @doc "Quintic ease out."
  @spec ease_out_quint(float()) :: float()
  def ease_out_quint(t), do: 1.0 - :math.pow(1.0 - t, 5)

  @doc "Quintic ease in-out."
  @spec ease_in_out_quint(float()) :: float()
  def ease_in_out_quint(t) when t < 0.5, do: 16.0 * t * t * t * t * t
  def ease_in_out_quint(t), do: 1.0 - :math.pow(-2.0 * t + 2.0, 5) / 2.0

  # ---------------------------------------------------------------------------
  # Exponential
  # ---------------------------------------------------------------------------

  @doc "Exponential ease in."
  @spec ease_in_expo(float()) :: float()
  def ease_in_expo(t) when t == 0.0, do: 0.0
  def ease_in_expo(t), do: :math.pow(2.0, 10.0 * t - 10.0)

  @doc "Exponential ease out."
  @spec ease_out_expo(float()) :: float()
  def ease_out_expo(t) when t == 1.0, do: 1.0
  def ease_out_expo(t), do: 1.0 - :math.pow(2.0, -10.0 * t)

  @doc "Exponential ease in-out."
  @spec ease_in_out_expo(float()) :: float()
  def ease_in_out_expo(t) when t == 0.0, do: 0.0
  def ease_in_out_expo(t) when t == 1.0, do: 1.0
  def ease_in_out_expo(t) when t < 0.5, do: :math.pow(2.0, 20.0 * t - 10.0) / 2.0
  def ease_in_out_expo(t), do: (2.0 - :math.pow(2.0, -20.0 * t + 10.0)) / 2.0

  # ---------------------------------------------------------------------------
  # Circular
  # ---------------------------------------------------------------------------

  @doc "Circular ease in."
  @spec ease_in_circ(float()) :: float()
  def ease_in_circ(t), do: 1.0 - :math.sqrt(1.0 - t * t)

  @doc "Circular ease out."
  @spec ease_out_circ(float()) :: float()
  def ease_out_circ(t), do: :math.sqrt(1.0 - (t - 1.0) * (t - 1.0))

  @doc "Circular ease in-out."
  @spec ease_in_out_circ(float()) :: float()
  def ease_in_out_circ(t) when t < 0.5 do
    (1.0 - :math.sqrt(1.0 - :math.pow(2.0 * t, 2))) / 2.0
  end

  def ease_in_out_circ(t) do
    (1.0 + :math.sqrt(1.0 - :math.pow(-2.0 * t + 2.0, 2))) / 2.0
  end

  # ---------------------------------------------------------------------------
  # Back (overshoots)
  # ---------------------------------------------------------------------------

  @doc "Back ease in: pulls back before accelerating."
  @spec ease_in_back(float()) :: float()
  def ease_in_back(t), do: @c3 * t * t * t - @c1 * t * t

  @doc "Back ease out: overshoots then settles."
  @spec ease_out_back(float()) :: float()
  def ease_out_back(t) do
    1.0 + @c3 * :math.pow(t - 1.0, 3) + @c1 * :math.pow(t - 1.0, 2)
  end

  @doc "Back ease in-out: pulls back and overshoots."
  @spec ease_in_out_back(float()) :: float()
  def ease_in_out_back(t) when t < 0.5 do
    :math.pow(2.0 * t, 2) * ((@c2 + 1.0) * 2.0 * t - @c2) / 2.0
  end

  def ease_in_out_back(t) do
    (:math.pow(2.0 * t - 2.0, 2) * ((@c2 + 1.0) * (2.0 * t - 2.0) + @c2) + 2.0) / 2.0
  end

  # ---------------------------------------------------------------------------
  # Elastic (oscillating overshoot)
  # ---------------------------------------------------------------------------

  @doc "Elastic ease in: oscillates then accelerates."
  @spec ease_in_elastic(float()) :: float()
  def ease_in_elastic(t) when t == 0.0, do: 0.0
  def ease_in_elastic(t) when t == 1.0, do: 1.0

  def ease_in_elastic(t) do
    -:math.pow(2.0, 10.0 * t - 10.0) * :math.sin((10.0 * t - 10.75) * @c4)
  end

  @doc "Elastic ease out: overshoots with oscillation."
  @spec ease_out_elastic(float()) :: float()
  def ease_out_elastic(t) when t == 0.0, do: 0.0
  def ease_out_elastic(t) when t == 1.0, do: 1.0

  def ease_out_elastic(t) do
    :math.pow(2.0, -10.0 * t) * :math.sin((10.0 * t - 0.75) * @c4) + 1.0
  end

  @doc "Elastic ease in-out."
  @spec ease_in_out_elastic(float()) :: float()
  def ease_in_out_elastic(t) when t == 0.0, do: 0.0
  def ease_in_out_elastic(t) when t == 1.0, do: 1.0

  def ease_in_out_elastic(t) when t < 0.5 do
    -(:math.pow(2.0, 20.0 * t - 10.0) * :math.sin((20.0 * t - 11.125) * @c5)) / 2.0
  end

  def ease_in_out_elastic(t) do
    :math.pow(2.0, -20.0 * t + 10.0) * :math.sin((20.0 * t - 11.125) * @c5) / 2.0 + 1.0
  end

  # ---------------------------------------------------------------------------
  # Bounce
  # ---------------------------------------------------------------------------

  @doc "Bounce ease out: bouncing ball effect."
  @spec ease_out_bounce(float()) :: float()
  def ease_out_bounce(t) when t < 1.0 / @d1, do: @n1 * t * t

  def ease_out_bounce(t) when t < 2.0 / @d1 do
    t2 = t - 1.5 / @d1
    @n1 * t2 * t2 + 0.75
  end

  def ease_out_bounce(t) when t < 2.5 / @d1 do
    t2 = t - 2.25 / @d1
    @n1 * t2 * t2 + 0.9375
  end

  def ease_out_bounce(t) do
    t2 = t - 2.625 / @d1
    @n1 * t2 * t2 + 0.984375
  end

  @doc "Bounce ease in."
  @spec ease_in_bounce(float()) :: float()
  def ease_in_bounce(t), do: 1.0 - ease_out_bounce(1.0 - t)

  @doc "Bounce ease in-out."
  @spec ease_in_out_bounce(float()) :: float()
  def ease_in_out_bounce(t) when t < 0.5 do
    (1.0 - ease_out_bounce(1.0 - 2.0 * t)) / 2.0
  end

  def ease_in_out_bounce(t) do
    (1.0 + ease_out_bounce(2.0 * t - 1.0)) / 2.0
  end

  # ---------------------------------------------------------------------------
  # Cubic bezier
  # ---------------------------------------------------------------------------

  @doc """
  Evaluates a cubic bezier easing curve at progress `t`.

  Control points `(x1, y1)` and `(x2, y2)` match the CSS
  `cubic-bezier()` function. The curve starts at `(0, 0)` and
  ends at `(1, 1)`.

  Uses Newton-Raphson iteration to solve for the parameter given
  the x coordinate, then evaluates y at that parameter.
  """
  @spec cubic_bezier(t :: float(), x1 :: float(), y1 :: float(), x2 :: float(), y2 :: float()) ::
          float()
  def cubic_bezier(t, _x1, _y1, _x2, _y2) when t <= 0.0, do: 0.0
  def cubic_bezier(t, _x1, _y1, _x2, _y2) when t >= 1.0, do: 1.0

  def cubic_bezier(t, x1, y1, x2, y2) do
    # Solve for the bezier parameter `s` where bezier_x(s) == t
    s = newton_raphson_solve(t, x1, x2, t, 8)
    # Evaluate bezier_y at that parameter
    bezier_eval(s, y1, y2)
  end

  # Evaluates the cubic bezier polynomial for one axis.
  # B(s) = 3(1-s)^2*s*p1 + 3(1-s)*s^2*p2 + s^3
  defp bezier_eval(s, p1, p2) do
    s2 = s * s
    s3 = s2 * s
    3.0 * (1.0 - s) * (1.0 - s) * s * p1 + 3.0 * (1.0 - s) * s2 * p2 + s3
  end

  # Derivative of the bezier polynomial for one axis.
  # B'(s) = 3(1-s)^2*p1 + 6(1-s)*s*(p2-p1) + 3*s^2*(1-p2)
  defp bezier_derivative(s, p1, p2) do
    3.0 * (1.0 - s) * (1.0 - s) * p1 +
      6.0 * (1.0 - s) * s * (p2 - p1) +
      3.0 * s * s * (1.0 - p2)
  end

  # Newton-Raphson iteration to find s where bezier_x(s) == target_x.
  defp newton_raphson_solve(_target_x, _x1, _x2, guess, 0), do: guess

  defp newton_raphson_solve(target_x, x1, x2, guess, iterations) do
    x = bezier_eval(guess, x1, x2)
    dx = bezier_derivative(guess, x1, x2)

    if abs(x - target_x) < 1.0e-7 or abs(dx) < 1.0e-7 do
      guess
    else
      next = guess - (x - target_x) / dx
      # Clamp to 0..1 to prevent divergence
      next = max(0.0, min(1.0, next))
      newton_raphson_solve(target_x, x1, x2, next, iterations - 1)
    end
  end
end
