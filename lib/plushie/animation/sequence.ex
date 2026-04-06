defmodule Plushie.Animation.Sequence do
  @moduledoc """
  Renderer-side sequential animation chain.

  Chains multiple transitions and springs that execute one after
  another on the same prop. Each step's `from:` defaults to the
  previous step's final value if not specified.

  ## Usage

      # List form
      opacity: sequence([
        transition(200, to: 1.0, from: 0.0),
        loop(800, to: 0.7, from: 1.0, cycles: 3),
        transition(300, to: 0.0)
      ])

      # Do-block form
      opacity: sequence do
        transition(200, to: 1.0, from: 0.0)
        loop(800, to: 0.7, from: 1.0, cycles: 3)
        transition(300, to: 0.0)
      end

  ## Completion

  Only the sequence-level `on_complete:` fires. Individual step
  completion tags are ignored.

      opacity: sequence([
        transition(200, to: 1.0, from: 0.0),
        transition(300, to: 0.0)
      ], on_complete: :fade_cycle_done)
  """

  alias Plushie.Animation.{Spring, Transition}

  @type step :: Transition.t() | Spring.t()

  @type t :: %__MODULE__{
          steps: [step()],
          on_complete: atom() | nil
        }

  defstruct steps: [], on_complete: nil

  # ---------------------------------------------------------------------------
  # Constructors
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new sequence from a list of transition/spring steps.

      Sequence.new([
        Transition.new(200, to: 1.0, from: 0.0),
        Transition.new(300, to: 0.0)
      ])

      Sequence.new([...], on_complete: :done)
  """
  @spec new(steps :: [step()], opts :: keyword()) :: t()
  def new(steps, opts \\ []) when is_list(steps) do
    validate_steps!(steps)

    %__MODULE__{
      steps: steps,
      on_complete: Keyword.get(opts, :on_complete)
    }
  end

  @doc "Sets the completion event tag."
  @spec on_complete(sequence :: t(), tag :: atom()) :: t()
  def on_complete(%__MODULE__{} = s, tag) when is_atom(tag), do: %{s | on_complete: tag}

  # ---------------------------------------------------------------------------
  # Validation
  # ---------------------------------------------------------------------------

  defp validate_steps!([]) do
    raise ArgumentError, "sequence requires at least one step"
  end

  defp validate_steps!(steps) do
    Enum.each(steps, fn
      %Transition{} ->
        :ok

      %Spring{} ->
        :ok

      other ->
        raise ArgumentError, "sequence steps must be Transition or Spring, got #{inspect(other)}"
    end)
  end

  # ---------------------------------------------------------------------------
  # Encode
  # ---------------------------------------------------------------------------

  @doc false
  @spec encode(t()) :: map()
  def encode(%__MODULE__{} = s) do
    encoded_steps =
      Enum.map(s.steps, fn
        %Transition{} = t -> Transition.encode(t)
        %Spring{} = sp -> Spring.encode(sp)
      end)

    map = %{"type" => "sequence", "steps" => encoded_steps}

    if s.on_complete do
      Map.put(map, "on_complete", Atom.to_string(s.on_complete))
    else
      map
    end
  end
end
