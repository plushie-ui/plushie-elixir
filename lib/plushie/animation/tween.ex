defmodule Plushie.Animation.Tween do
  @moduledoc """
  SDK-side stateful interpolator for model-level animation.

  Pure functions operating on structs -- no processes, no state
  management beyond what lives in your app model. Use this for
  complex animations that need frame-by-frame control: canvas
  animations, physics simulations, custom interpolation logic.

  For simple property animations (fades, slides, scales), prefer
  renderer-side transitions via `Plushie.Animation.Transition`
  which require zero model state and zero wire traffic.

  ## Example

      alias Plushie.Animation.Tween

      def init(_opts) do
        %{anim: Tween.new(from: 0.0, to: 1.0, duration: 300, easing: :ease_out)}
      end

      def subscribe(_model) do
        [Plushie.Subscription.on_animation_frame()]
      end

      def update(model, %SystemEvent{type: :animation_frame, value: ts}) do
        anim = model.anim |> Tween.start_once(ts) |> Tween.advance(ts)
        %{model | anim: anim}
      end

      def view(model) do
        opacity = Tween.value(model.anim)
        # use opacity in widget props
      end

  ## Easing

  Uses `Plushie.Animation.Easing` for the full catalogue of 31
  named curves plus cubic bezier. Pass easing as an atom:

      Tween.new(from: 0.0, to: 1.0, duration: 300, easing: :ease_out_bounce)

  ## Interruption

  Change the target mid-animation with `redirect/2`. The animation
  smoothly continues from its current interpolated value:

      anim = Tween.redirect(model.anim, to: 0.0, at: timestamp)

  ## Spring mode

  For physics-based animation on the SDK side:

      anim = Tween.spring(from: 0.0, to: 1.0, stiffness: 200, damping: 20)
  """

  alias Plushie.Animation.Easing

  defstruct [
    :from,
    :to,
    :duration,
    :started_at,
    :last_timestamp,
    :delay,
    :repeat,
    :auto_reverse,
    :spring_config,
    :easing_fn,
    easing: :ease_in_out,
    value: nil,
    finished: false
  ]

  @type t :: %__MODULE__{
          from: number(),
          to: number(),
          duration: pos_integer() | nil,
          started_at: integer() | nil,
          last_timestamp: integer() | nil,
          easing: Easing.t(),
          easing_fn: (float() -> float()) | nil,
          delay: non_neg_integer() | nil,
          repeat: pos_integer() | :forever | nil,
          auto_reverse: boolean() | nil,
          spring_config: map() | nil,
          value: number() | nil,
          finished: boolean()
        }

  # ---------------------------------------------------------------------------
  # Constructors
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new timed animation.

  ## Required options

  - `from:` -- start value
  - `to:` -- end value
  - `duration:` -- duration in milliseconds

  ## Optional

  - `easing:` -- easing atom or `{:cubic_bezier, ...}`. Default: `:ease_in_out`
  - `delay:` -- delay before start in ms. Default: 0
  - `repeat:` -- repeat count or `:forever`
  - `auto_reverse:` -- reverse on each repeat cycle

  ## Example

      Tween.new(from: 0.0, to: 1.0, duration: 300, easing: :ease_out)
  """
  @spec new(opts :: keyword()) :: t()
  def new(opts) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    duration = Keyword.fetch!(opts, :duration)
    easing = Keyword.get(opts, :easing, :ease_in_out)

    unless Easing.valid?(easing) do
      raise ArgumentError, "invalid easing: #{inspect(easing)}"
    end

    %__MODULE__{
      from: from,
      to: to,
      duration: duration,
      easing: easing,
      easing_fn: Easing.function(easing),
      delay: Keyword.get(opts, :delay, 0),
      repeat: Keyword.get(opts, :repeat),
      auto_reverse: Keyword.get(opts, :auto_reverse, false),
      value: from,
      finished: false
    }
  end

  @doc """
  Creates a spring-mode animation (SDK-side spring solver).

  ## Required options

  - `from:` -- start value
  - `to:` -- end value

  ## Optional

  - `stiffness:` -- spring constant. Default: 100
  - `damping:` -- friction. Default: 10
  - `mass:` -- mass. Default: 1.0
  - `velocity:` -- initial velocity. Default: 0.0

  ## Example

      Tween.spring(from: 0.0, to: 1.0, stiffness: 200, damping: 20)
  """
  @spec spring(opts :: keyword()) :: t()
  def spring(opts) when is_list(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)

    %__MODULE__{
      from: from,
      to: to,
      value: from,
      finished: false,
      spring_config: %{
        stiffness: Keyword.get(opts, :stiffness, 100),
        damping: Keyword.get(opts, :damping, 10),
        mass: Keyword.get(opts, :mass, 1.0),
        velocity: Keyword.get(opts, :velocity, 0.0)
      }
    }
  end

  # ---------------------------------------------------------------------------
  # Lifecycle
  # ---------------------------------------------------------------------------

  @doc """
  Starts the animation at the given timestamp. Resets value to `from`.

  If already started, restarts from the beginning.
  """
  @spec start(animation :: t(), timestamp :: integer()) :: t()
  def start(%__MODULE__{} = anim, timestamp) when is_integer(timestamp) do
    %{anim | started_at: timestamp, last_timestamp: timestamp, value: anim.from, finished: false}
  end

  @doc """
  Starts the animation only if it hasn't been started yet.

  Convenience for the common pattern of starting on the first frame.
  """
  @spec start_once(animation :: t(), timestamp :: integer()) :: t()
  def start_once(%__MODULE__{started_at: nil} = anim, timestamp), do: start(anim, timestamp)
  def start_once(%__MODULE__{} = anim, _timestamp), do: anim

  @doc """
  Advances the animation to the given timestamp.

  Always returns an updated `%Tween{}` struct. Check
  `finished?/1` to detect completion.

  If the animation hasn't been started, returns the struct unchanged.
  """
  @spec advance(animation :: t(), timestamp :: integer()) :: t()
  def advance(%__MODULE__{started_at: nil} = anim, _timestamp), do: anim
  def advance(%__MODULE__{finished: true} = anim, _timestamp), do: anim

  def advance(%__MODULE__{spring_config: %{} = config} = anim, timestamp) do
    advance_spring(anim, config, timestamp)
  end

  def advance(%__MODULE__{} = anim, timestamp) do
    advance_timed(anim, timestamp)
  end

  @doc """
  Redirects the animation to a new target, starting from the
  current interpolated value. Resets the timer.

  Use this for smooth interruption -- the animation continues
  from where it is rather than jumping.

  ## Options

  - `to:` -- new target value (required)
  - `at:` -- current timestamp (required)
  - `easing:` -- optionally change easing
  - `duration:` -- optionally change duration
  """
  @spec redirect(animation :: t(), opts :: keyword()) :: t()
  def redirect(%__MODULE__{} = anim, opts) when is_list(opts) do
    new_to = Keyword.fetch!(opts, :to)
    timestamp = Keyword.fetch!(opts, :at)
    new_easing = Keyword.get(opts, :easing, anim.easing)

    # For spring mode, preserve velocity for natural momentum
    spring_config =
      case anim.spring_config do
        %{} = config -> config
        nil -> nil
      end

    %{
      anim
      | from: if(anim.value != nil, do: anim.value, else: anim.from),
        to: new_to,
        started_at: timestamp,
        last_timestamp: timestamp,
        finished: false,
        easing: new_easing,
        easing_fn:
          if(new_easing != anim.easing, do: Easing.function(new_easing), else: anim.easing_fn),
        duration: Keyword.get(opts, :duration, anim.duration),
        spring_config: spring_config
    }
  end

  # ---------------------------------------------------------------------------
  # Queries
  # ---------------------------------------------------------------------------

  @doc "Returns the current interpolated value."
  @spec value(animation :: t()) :: number() | nil
  def value(%__MODULE__{value: v}), do: v

  @doc "Returns true if the animation has completed."
  @spec finished?(animation :: t()) :: boolean()
  def finished?(%__MODULE__{finished: f}), do: f

  @doc "Returns true if the animation is actively running (started and not finished)."
  @spec running?(animation :: t()) :: boolean()
  def running?(%__MODULE__{started_at: nil}), do: false
  def running?(%__MODULE__{finished: true}), do: false
  def running?(%__MODULE__{}), do: true

  # ---------------------------------------------------------------------------
  # Private: timed advance
  # ---------------------------------------------------------------------------

  defp advance_timed(anim, timestamp) do
    raw_elapsed = timestamp - anim.started_at
    delay = anim.delay || 0
    elapsed = max(0, raw_elapsed - delay)

    if raw_elapsed < delay do
      %{anim | value: anim.from}
    else
      t = clamp(elapsed / anim.duration)
      easing_fn = anim.easing_fn || Easing.function(anim.easing)
      current = anim.from + (anim.to - anim.from) * easing_fn.(t)

      if t >= 1.0 do
        handle_repeat_or_finish(anim, anim.to, timestamp)
      else
        %{anim | value: current}
      end
    end
  end

  defp handle_repeat_or_finish(anim, final_value, _timestamp) do
    case anim.repeat do
      nil ->
        %{anim | value: final_value, finished: true}

      :forever ->
        restart_cycle(anim)

      n when is_integer(n) and n > 1 ->
        %{restart_cycle(anim) | repeat: n - 1}

      _n ->
        %{anim | value: final_value, finished: true}
    end
  end

  defp restart_cycle(anim) do
    if anim.auto_reverse do
      %{anim | from: anim.to, to: anim.from, started_at: anim.started_at + anim.duration}
    else
      %{anim | value: anim.from, started_at: anim.started_at + anim.duration}
    end
  end

  # ---------------------------------------------------------------------------
  # Private: spring advance
  # ---------------------------------------------------------------------------

  defp advance_spring(anim, config, timestamp) do
    # Delta since last advance, not total elapsed (avoids re-simulation)
    delta_ms = timestamp - (anim.last_timestamp || anim.started_at)
    # Fixed 1ms timestep for stability, simulate delta_ms steps
    dt = 0.001
    steps = min(max(delta_ms, 0), 1000)

    {pos, vel} =
      Enum.reduce(
        1..max(1, steps)//1,
        {if(anim.value != nil, do: anim.value, else: anim.from), config.velocity},
        fn _, {pos, vel} ->
          force = -config.stiffness * (pos - anim.to) - config.damping * vel
          acc = force / config.mass
          new_vel = vel + acc * dt
          new_pos = pos + new_vel * dt
          {new_pos, new_vel}
        end
      )

    settled = abs(vel) < 0.01 and abs(pos - anim.to) < 0.001

    if settled do
      %{
        anim
        | value: anim.to,
          finished: true,
          last_timestamp: timestamp,
          spring_config: %{config | velocity: 0.0}
      }
    else
      %{anim | value: pos, last_timestamp: timestamp, spring_config: %{config | velocity: vel}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private: utils
  # ---------------------------------------------------------------------------

  defp clamp(t) when t < 0, do: 0.0
  defp clamp(t) when t > 1.0, do: 1.0
  defp clamp(t), do: t * 1.0
end
