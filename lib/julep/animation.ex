defmodule Julep.Animation do
  @moduledoc """
  Server-side animation interpolation and easing functions.

  Pure functions operating on structs -- no processes, no state management
  beyond what lives in your app model. The host computes interpolated
  values on each animation frame tick.

  ## Easing functions

  All easing functions take a `t` value in `0.0..1.0` and return a
  curved `t` value. Available easings:

    * `linear/1` -- identity
    * `ease_in/1` -- cubic ease in
    * `ease_out/1` -- cubic ease out
    * `ease_in_out/1` -- cubic ease in-out
    * `ease_in_quad/1` -- quadratic ease in
    * `ease_out_quad/1` -- quadratic ease out
    * `ease_in_out_quad/1` -- quadratic ease in-out
    * `spring/1` -- spring with overshoot

  ## Interpolation

  `interpolate/4` lerps between two numbers with an optional easing
  function applied to `t`.

  ## Animation struct

  The `%Animation{}` struct tracks a single animated value over time.
  Create one with `new/4`, start it with `start/2`, and advance it on
  each frame with `advance/2`.

  ## Example

      alias Julep.Animation

      def init(_opts) do
        model = %{
          opacity: Animation.new(0.0, 1.0, 300, easing: &Animation.ease_out/1),
          started: false
        }
        {model, []}
      end

      def subscribe(_model) do
        [Julep.Subscription.on_animation_frame(:frame)]
      end

      def update(model, %System{type: :animation_frame, data: ts}) do
        if not model.started do
          %{model | opacity: Animation.start(model.opacity, ts), started: true}
        else
          {_value, opacity} = Animation.advance(model.opacity, ts)
          %{model | opacity: opacity}
        end
      end

      def view(model) do
        opacity = Animation.value(model.opacity)
        # use opacity in your widget props
      end
  """

  defstruct [:from, :to, :duration, :started_at, :easing, :value]

  @type easing :: (float() -> float())

  @type t :: %__MODULE__{
          from: number(),
          to: number(),
          duration: pos_integer(),
          started_at: integer() | nil,
          easing: easing(),
          value: number()
        }

  # -- Easing functions -------------------------------------------------------

  @doc "Linear easing (identity). Returns `t` unchanged."
  @spec linear(t :: float()) :: float()
  def linear(t), do: t

  @doc "Cubic ease in. Starts slow, accelerates."
  @spec ease_in(t :: float()) :: float()
  def ease_in(t), do: t * t * t

  @doc "Cubic ease out. Starts fast, decelerates."
  @spec ease_out(t :: float()) :: float()
  def ease_out(t) do
    inv = 1.0 - t
    1.0 - inv * inv * inv
  end

  @doc "Cubic ease in-out. Slow start, fast middle, slow end."
  @spec ease_in_out(t :: float()) :: float()
  def ease_in_out(t) when t < 0.5, do: 4.0 * t * t * t

  def ease_in_out(t) do
    inv = -2.0 * t + 2.0
    1.0 - inv * inv * inv / 2.0
  end

  @doc "Quadratic ease in. Starts slow, accelerates."
  @spec ease_in_quad(t :: float()) :: float()
  def ease_in_quad(t), do: t * t

  @doc "Quadratic ease out. Starts fast, decelerates."
  @spec ease_out_quad(t :: float()) :: float()
  def ease_out_quad(t), do: 1.0 - (1.0 - t) * (1.0 - t)

  @doc "Quadratic ease in-out. Slow start and end, fast middle."
  @spec ease_in_out_quad(t :: float()) :: float()
  def ease_in_out_quad(t) when t < 0.5, do: 2.0 * t * t
  def ease_in_out_quad(t), do: 1.0 - (-2.0 * t + 2.0) ** 2 / 2.0

  @doc """
  Spring easing with overshoot. Overshoots the target slightly
  before settling. Uses a single-period damped sine approximation.
  """
  @spec spring(t :: float()) :: float()
  def spring(t) when t == +0.0, do: +0.0
  def spring(t) when t == 1.0, do: 1.0

  def spring(t) do
    c4 = 2.0 * :math.pi() / 3.0
    :math.pow(2.0, -10.0 * t) * :math.sin((t * 10.0 - 0.75) * c4) + 1.0
  end

  # -- Interpolation ----------------------------------------------------------

  @doc """
  Linearly interpolate between `from` and `to` at progress `t`,
  with an optional easing function applied to `t` first.

  `t` is clamped to `0.0..1.0` before easing is applied.
  """
  @spec interpolate(from :: number(), to :: number(), t :: float(), easing :: easing()) :: float()
  def interpolate(from, to, t, easing \\ &linear/1)
      when is_number(from) and is_number(to) and is_number(t) and is_function(easing, 1) do
    clamped = clamp(t)
    eased = easing.(clamped)
    from + (to - from) * eased
  end

  # -- Animation lifecycle ----------------------------------------------------

  @doc """
  Create a new animation.

  ## Options

    * `:easing` -- easing function, defaults to `&linear/1`
  """
  @spec new(from :: number(), to :: number(), duration_ms :: pos_integer(), opts :: keyword()) ::
          t()
  def new(from, to, duration_ms, opts \\ [])
      when is_number(from) and is_number(to) and is_integer(duration_ms) and duration_ms > 0 do
    easing = Keyword.get(opts, :easing, &linear/1)

    %__MODULE__{
      from: from,
      to: to,
      duration: duration_ms,
      started_at: nil,
      easing: easing,
      value: from
    }
  end

  @doc """
  Start (or restart) the animation at the given frame timestamp.
  Resets the current value to `from`.
  """
  @spec start(animation :: t(), timestamp :: integer()) :: t()
  def start(%__MODULE__{} = anim, timestamp) when is_integer(timestamp) do
    %{anim | started_at: timestamp, value: anim.from}
  end

  @doc """
  Advance the animation to the given frame timestamp.

  Returns `{current_value, updated_animation}` while the animation is
  in progress, or `{final_value, :finished}` when it completes.

  If the animation has not been started yet, returns `{from, animation}`
  unchanged.
  """
  @spec advance(animation :: t(), timestamp :: integer()) ::
          {float(), t()} | {float(), :finished}
  def advance(%__MODULE__{started_at: nil} = anim, _timestamp) do
    {anim.value, anim}
  end

  def advance(%__MODULE__{} = anim, timestamp) do
    elapsed = timestamp - anim.started_at
    t = clamp(elapsed / anim.duration)
    current = interpolate(anim.from, anim.to, t, anim.easing)

    if t >= 1.0 do
      {anim.to, :finished}
    else
      updated = %{anim | value: current}
      {current, updated}
    end
  end

  @doc """
  Returns `true` if the animation has run to completion.

  Note: once `advance/2` returns `{value, :finished}`, the animation
  struct is no longer updated. Use the `:finished` return value from
  `advance/2` as the primary completion signal.
  """
  @spec finished?(animation :: t()) :: boolean()
  def finished?(%__MODULE__{started_at: nil}), do: false

  def finished?(%__MODULE__{} = anim) do
    anim.value == anim.to
  end

  @doc "Return the current interpolated value."
  @spec value(animation :: t()) :: number()
  def value(%__MODULE__{value: v}), do: v

  # -- Private ----------------------------------------------------------------

  defp clamp(t) when t < 0, do: 0.0
  defp clamp(t) when t > 1.0, do: 1.0
  defp clamp(t), do: t
end
