defmodule Plushie.Animation.Spring do
  @moduledoc """
  Renderer-side physics-based spring descriptor.

  Springs animate using a damped harmonic oscillator simulation.
  Unlike timed transitions, springs have no fixed duration -- they
  settle naturally based on stiffness, damping, and mass. This
  makes them ideal for interactive animations where the target
  changes frequently (drag, scroll, hover) because interruption
  preserves velocity for smooth redirection.

  ## Usage

      # Custom parameters
      scale: spring(to: 1.05, stiffness: 200, damping: 20)

      # Named presets
      scale: spring(to: 1.05, preset: :bouncy)

      # Pipeline
      alias Plushie.Animation.Spring
      scale: Spring.new(to: 1.05) |> Spring.stiffness(200) |> Spring.damping(20)

      # Do-block
      scale: spring do
        to 1.05
        stiffness 200
        damping 20
      end

  ## Presets

  - `:gentle` -- slow, smooth, no overshoot
  - `:snappy` -- quick, minimal overshoot
  - `:bouncy` -- quick with visible overshoot
  - `:stiff` -- very quick, crisp stop
  - `:molasses` -- slow, heavy, deliberate

  ## When to use springs vs transitions

  Use **springs** when:
  - The target changes frequently (interactive elements)
  - You want natural-feeling motion with momentum
  - Overshoot/bounce is desirable

  Use **transitions** when:
  - You need precise timing (fade exactly 300ms)
  - You need specific easing curves
  - The animation is fire-and-forget (not interactive)
  """

  @presets %{
    gentle: [stiffness: 120, damping: 14],
    bouncy: [stiffness: 300, damping: 10],
    stiff: [stiffness: 400, damping: 30],
    snappy: [stiffness: 200, damping: 20],
    molasses: [stiffness: 60, damping: 12]
  }

  @known_keys ~w(to from stiffness damping mass velocity preset on_complete)a

  @type preset :: :gentle | :bouncy | :stiff | :snappy | :molasses

  @type t :: %__MODULE__{
          to: term(),
          from: term() | nil,
          stiffness: number(),
          damping: number(),
          mass: number(),
          velocity: number(),
          on_complete: atom() | nil
        }

  defstruct [
    :to,
    :from,
    :on_complete,
    stiffness: 100,
    damping: 10,
    mass: 1.0,
    velocity: 0.0
  ]

  # ---------------------------------------------------------------------------
  # Buildable
  # ---------------------------------------------------------------------------

  def __field_keys__, do: @known_keys

  def __field_types__, do: %{}

  def from_opts(opts) when is_list(opts) do
    validate_required!(opts)

    opts =
      case Keyword.pop(opts, :preset) do
        {nil, opts} -> opts
        {preset, opts} -> apply_preset(preset, opts)
      end

    %__MODULE__{} |> with_options(opts)
  end

  # ---------------------------------------------------------------------------
  # Constructors
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new spring descriptor.

  `to:` is required. Use `preset:` for named configurations or
  set `stiffness:` and `damping:` directly.

      Spring.new(to: 1.05, preset: :bouncy)
      Spring.new(to: 1.05, stiffness: 200, damping: 20)
  """
  @spec new(opts :: keyword()) :: t()
  def new(opts) when is_list(opts) do
    validate_required!(opts)

    opts =
      case Keyword.pop(opts, :preset) do
        {nil, opts} -> opts
        {preset, opts} -> apply_preset(preset, opts)
      end

    %__MODULE__{} |> with_options(opts)
  end

  @doc "Returns the map of available spring presets."
  @spec presets() :: %{preset() => keyword()}
  def presets, do: @presets

  # ---------------------------------------------------------------------------
  # Pipeline setters
  # ---------------------------------------------------------------------------

  @doc "Sets the target value."
  @spec to(spring :: t(), to :: term()) :: t()
  def to(%__MODULE__{} = s, to), do: %{s | to: to}

  @doc "Sets the explicit start value."
  @spec from(spring :: t(), from :: term()) :: t()
  def from(%__MODULE__{} = s, from), do: %{s | from: from}

  @doc "Sets the spring stiffness (higher = faster, snappier)."
  @spec stiffness(spring :: t(), stiffness :: number()) :: t()
  def stiffness(%__MODULE__{} = s, v) when is_number(v) and v > 0, do: %{s | stiffness: v}

  @doc "Sets the spring damping (higher = less oscillation)."
  @spec damping(spring :: t(), damping :: number()) :: t()
  def damping(%__MODULE__{} = s, v) when is_number(v) and v >= 0, do: %{s | damping: v}

  @doc "Sets the spring mass (higher = slower, heavier)."
  @spec mass(spring :: t(), mass :: number()) :: t()
  def mass(%__MODULE__{} = s, v) when is_number(v) and v > 0, do: %{s | mass: v}

  @doc "Sets the initial velocity."
  @spec velocity(spring :: t(), velocity :: number()) :: t()
  def velocity(%__MODULE__{} = s, v) when is_number(v), do: %{s | velocity: v}

  @doc "Sets the completion event tag."
  @spec on_complete(spring :: t(), tag :: atom()) :: t()
  def on_complete(%__MODULE__{} = s, tag) when is_atom(tag), do: %{s | on_complete: tag}

  # ---------------------------------------------------------------------------
  # with_options
  # ---------------------------------------------------------------------------

  @doc "Applies keyword options to an existing spring."
  @spec with_options(spring :: t(), opts :: keyword()) :: t()
  def with_options(%__MODULE__{} = s, []), do: s

  def with_options(%__MODULE__{} = s, opts) do
    Enum.reduce(opts, s, fn
      {:to, v}, acc -> to(acc, v)
      {:from, v}, acc -> from(acc, v)
      {:stiffness, v}, acc -> stiffness(acc, v)
      {:damping, v}, acc -> damping(acc, v)
      {:mass, v}, acc -> mass(acc, v)
      {:velocity, v}, acc -> velocity(acc, v)
      {:on_complete, v}, acc -> on_complete(acc, v)
      {:preset, _v}, acc -> acc
      {key, _v}, _acc -> raise ArgumentError, "unknown spring option #{inspect(key)}"
    end)
  end

  # ---------------------------------------------------------------------------
  # Validation
  # ---------------------------------------------------------------------------

  defp validate_required!(opts) do
    unless Keyword.has_key?(opts, :to) do
      raise ArgumentError, "spring requires to: (the target value)"
    end
  end

  defp apply_preset(preset, opts) do
    case Map.fetch(@presets, preset) do
      {:ok, defaults} ->
        Keyword.merge(defaults, opts)

      :error ->
        valid = Map.keys(@presets) |> Enum.map_join(", ", &inspect/1)
        raise ArgumentError, "unknown spring preset #{inspect(preset)}. Valid presets: #{valid}"
    end
  end

  # ---------------------------------------------------------------------------
  # Encode
  # ---------------------------------------------------------------------------

  defimpl Plushie.Encode, for: Plushie.Animation.Spring do
    def encode(%Plushie.Animation.Spring{} = s) do
      Plushie.Animation.Spring.encode(s)
    end
  end

  @doc false
  @spec encode(t()) :: map()
  def encode(%__MODULE__{} = s) do
    map = %{
      "type" => "spring",
      "to" => s.to,
      "stiffness" => s.stiffness,
      "damping" => s.damping
    }

    map
    |> maybe_put("mass", s.mass, 1.0)
    |> maybe_put("velocity", s.velocity, 0.0)
    |> maybe_put("from", s.from, nil)
    |> maybe_put("on_complete", encode_atom(s.on_complete), nil)
  end

  defp maybe_put(map, _key, default, default), do: map
  defp maybe_put(map, _key, nil, nil), do: map
  defp maybe_put(map, key, value, _default), do: Map.put(map, key, value)

  defp encode_atom(nil), do: nil
  defp encode_atom(atom) when is_atom(atom), do: Atom.to_string(atom)
end
