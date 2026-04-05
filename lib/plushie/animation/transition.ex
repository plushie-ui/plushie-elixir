defmodule Plushie.Animation.Transition do
  @moduledoc """
  Renderer-side timed transition descriptor.

  Declares animation intent in the view -- the renderer handles
  interpolation locally with zero wire traffic during animation.

  ## Three forms

      # 1. Keyword (duration positional shorthand)
      opacity: transition(300, to: 0.0)
      opacity: transition(300, to: 0.0, easing: :ease_out, delay: 100)

      # 2. Keyword (all keyword)
      opacity: transition(to: 0.0, duration: 300)

      # 3. Pipeline
      alias Plushie.Animation.Transition
      opacity: Transition.new(300, to: 0.0) |> Transition.easing(:ease_out)

      # 4. Do-block
      opacity: transition 300 do
        to 0.0
        easing :ease_out
        delay 100
      end

  ## Enter animations

  Use `from:` to set the starting value on mount:

      container "item",
        opacity: transition(200, to: 1.0, from: 0.0),
        translate_y: transition(200, to: 0, from: 20, delay: 50) do
        ...
      end

  On mount, the renderer uses `from:` as the starting value and
  animates to `to:`. Without `from:`, the target value is used
  immediately (no enter animation). On subsequent renders, `from:`
  is ignored and animation starts from the current interpolated
  value.

  ## Looping

  `loop/1` and `loop/2` are convenience constructors for repeating
  transitions:

      # Pulse forever
      opacity: loop(800, to: 0.4, from: 1.0)

      # Spin forever (no reverse)
      rotation: loop(1000, to: 360, from: 0, auto_reverse: false)

      # Finite: 3 cycles
      opacity: loop(800, to: 0.4, from: 1.0, cycles: 3)

  ## Completion events

  Use `on_complete:` to receive a `%WidgetEvent{type: :transition_complete}`
  when the animation finishes:

      opacity: transition(300, to: 0.0, on_complete: :faded_out)
  """

  alias Plushie.Animation.Easing

  @known_keys ~w(to duration easing delay from repeat auto_reverse on_complete cycles)a

  @type t :: %__MODULE__{
          to: term(),
          duration: pos_integer() | nil,
          easing: Easing.t(),
          delay: non_neg_integer(),
          from: term() | nil,
          repeat: pos_integer() | :forever | nil,
          auto_reverse: boolean(),
          on_complete: atom() | nil
        }

  defstruct [
    :to,
    :duration,
    :from,
    :repeat,
    :on_complete,
    easing: :ease_in_out,
    delay: 0,
    auto_reverse: false
  ]

  # ---------------------------------------------------------------------------
  # Buildable
  # ---------------------------------------------------------------------------

  def __field_keys__, do: @known_keys

  def __field_types__, do: %{}

  def from_opts(opts) when is_list(opts) do
    validate_required!(opts)
    %__MODULE__{} |> with_options(opts)
  end

  # ---------------------------------------------------------------------------
  # Constructors
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new transition with all keyword arguments.

  `to:` and `duration:` are required.

      Transition.new(to: 0.0, duration: 300)
      Transition.new(to: 0.0, duration: 300, easing: :ease_out)
  """
  @spec new(opts :: keyword()) :: t()
  def new(opts) when is_list(opts) do
    validate_required!(opts)
    %__MODULE__{} |> with_options(opts)
  end

  @doc """
  Creates a new transition with duration as a positional argument.

  `to:` is required in the keyword opts.

      Transition.new(300, to: 0.0)
      Transition.new(300, to: 0.0, easing: :ease_out, delay: 100)
  """
  @spec new(duration :: pos_integer(), opts :: keyword()) :: t()
  def new(duration, opts) when is_integer(duration) and duration > 0 and is_list(opts) do
    new([{:duration, duration} | opts])
  end

  @doc """
  Creates a looping transition with all keyword arguments.

  Sets `repeat: :forever` and `auto_reverse: true` by default.
  `to:`, `from:`, and `duration:` are required.

      Transition.loop(to: 0.4, from: 1.0, duration: 800)
      Transition.loop(to: 0.4, from: 1.0, duration: 800, easing: :ease_in_out)
  """
  @spec loop(opts :: keyword()) :: t()
  def loop(opts) when is_list(opts) do
    defaults = [repeat: :forever, auto_reverse: true]
    merged = Keyword.merge(defaults, opts)

    unless Keyword.has_key?(merged, :from) do
      raise ArgumentError, "loop requires from: (the cycle start value)"
    end

    new(merged)
  end

  @doc """
  Creates a looping transition with duration as a positional argument.

      Transition.loop(800, to: 0.4, from: 1.0)
      Transition.loop(800, to: 0.4, from: 1.0, cycles: 3)
  """
  @spec loop(duration :: pos_integer(), opts :: keyword()) :: t()
  def loop(duration, opts) when is_integer(duration) and duration > 0 and is_list(opts) do
    loop([{:duration, duration} | opts])
  end

  # ---------------------------------------------------------------------------
  # Pipeline setters
  # ---------------------------------------------------------------------------

  @doc "Sets the target value."
  @spec to(transition :: t(), to :: term()) :: t()
  def to(%__MODULE__{} = t, to), do: %{t | to: to}

  @doc "Sets the duration in milliseconds."
  @spec duration(transition :: t(), duration :: pos_integer()) :: t()
  def duration(%__MODULE__{} = t, d) when is_integer(d) and d > 0, do: %{t | duration: d}

  @doc "Sets the easing function."
  @spec easing(transition :: t(), easing :: Easing.t()) :: t()
  def easing(%__MODULE__{} = t, easing) do
    unless Easing.valid?(easing) do
      raise ArgumentError,
            "invalid easing: #{inspect(easing)}. Use a named atom or {:cubic_bezier, x1, y1, x2, y2}"
    end

    %{t | easing: easing}
  end

  @doc "Sets the delay before the transition starts (milliseconds)."
  @spec delay(transition :: t(), delay :: non_neg_integer()) :: t()
  def delay(%__MODULE__{} = t, d) when is_integer(d) and d >= 0, do: %{t | delay: d}

  @doc "Sets the explicit start value (for enter animations and loop reset)."
  @spec from(transition :: t(), from :: term()) :: t()
  def from(%__MODULE__{} = t, from), do: %{t | from: from}

  @doc "Sets the repeat count (positive integer or `:forever`)."
  @spec repeat(transition :: t(), repeat :: pos_integer() | :forever) :: t()
  def repeat(%__MODULE__{} = t, :forever), do: %{t | repeat: :forever}

  def repeat(%__MODULE__{} = t, n) when is_integer(n) and n > 0,
    do: %{t | repeat: n}

  @doc "Sets whether the animation reverses on each repeat cycle."
  @spec auto_reverse(transition :: t(), auto_reverse :: boolean()) :: t()
  def auto_reverse(%__MODULE__{} = t, v) when is_boolean(v), do: %{t | auto_reverse: v}

  @doc "Sets the completion event tag."
  @spec on_complete(transition :: t(), tag :: atom()) :: t()
  def on_complete(%__MODULE__{} = t, tag) when is_atom(tag), do: %{t | on_complete: tag}

  # ---------------------------------------------------------------------------
  # with_options
  # ---------------------------------------------------------------------------

  @doc "Applies keyword options to an existing transition."
  @spec with_options(transition :: t(), opts :: keyword()) :: t()
  def with_options(%__MODULE__{} = t, []), do: t

  def with_options(%__MODULE__{} = t, opts) do
    Enum.reduce(opts, t, fn
      {:to, v}, acc -> to(acc, v)
      {:duration, v}, acc -> duration(acc, v)
      {:easing, v}, acc -> easing(acc, v)
      {:delay, v}, acc -> delay(acc, v)
      {:from, v}, acc -> from(acc, v)
      {:repeat, v}, acc -> repeat(acc, v)
      {:auto_reverse, v}, acc -> auto_reverse(acc, v)
      {:on_complete, v}, acc -> on_complete(acc, v)
      {:cycles, v}, acc -> repeat(acc, v)
      {key, _v}, _acc -> raise ArgumentError, "unknown transition option #{inspect(key)}"
    end)
  end

  # ---------------------------------------------------------------------------
  # Validation
  # ---------------------------------------------------------------------------

  defp validate_required!(opts) do
    unless Keyword.has_key?(opts, :to) do
      raise ArgumentError, "transition requires to: (the target value)"
    end

    unless Keyword.has_key?(opts, :duration) do
      raise ArgumentError, "transition requires duration: (milliseconds)"
    end

    duration = Keyword.get(opts, :duration)

    unless is_integer(duration) and duration > 0 do
      raise ArgumentError,
            "transition duration: must be a positive integer (milliseconds), got #{inspect(duration)}"
    end
  end

  # ---------------------------------------------------------------------------
  # Encode
  # ---------------------------------------------------------------------------

  defimpl Plushie.Encode, for: Plushie.Animation.Transition do
    def encode(%Plushie.Animation.Transition{} = t) do
      Plushie.Animation.Transition.encode(t)
    end
  end

  @doc false
  @spec encode(t()) :: map()
  def encode(%__MODULE__{} = t) do
    map = %{"type" => "transition", "to" => t.to, "duration" => t.duration}

    map
    |> maybe_put("easing", t.easing, :ease_in_out, &Easing.name/1)
    |> maybe_put_raw("delay", t.delay, 0)
    |> maybe_put_raw("from", t.from, nil)
    |> maybe_put_raw("repeat", encode_repeat(t.repeat), nil)
    |> maybe_put_raw("auto_reverse", t.auto_reverse, false)
    |> maybe_put_raw("on_complete", encode_atom(t.on_complete), nil)
  end

  defp maybe_put(map, _key, default, default, _transform), do: map
  defp maybe_put(map, key, value, _default, transform), do: Map.put(map, key, transform.(value))

  defp maybe_put_raw(map, _key, default, default), do: map
  defp maybe_put_raw(map, _key, nil, nil), do: map
  defp maybe_put_raw(map, key, value, _default), do: Map.put(map, key, value)

  defp encode_repeat(nil), do: nil
  defp encode_repeat(:forever), do: -1
  defp encode_repeat(n) when is_integer(n), do: n

  defp encode_atom(nil), do: nil
  defp encode_atom(atom) when is_atom(atom), do: Atom.to_string(atom)
end
