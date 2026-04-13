defmodule Plushie.Undo do
  @default_max_size 100

  @moduledoc """
  Undo/redo stack for reversible commands. Pure data structure, no processes.

  Each command provides an `apply` function and an `undo` function. The stack
  tracks entries as `{apply_fn, undo_fn}` pairs so that undo moves an entry
  to the redo stack (calling `undo_fn`) and redo moves it back (calling
  `apply_fn`).

  ## Max size

  The undo stack is bounded by `:max_size` (default #{@default_max_size}).
  When a push exceeds the limit, the oldest entries are dropped. The redo
  stack is unbounded (it can only shrink or be cleared, never grow past
  the undo stack size).

  ## Coalescing

  Commands with the same `:coalesce` key that arrive within
  `:coalesce_window_ms` of each other are merged into a single undo entry.
  The merged entry keeps the *original* undo function (so one undo reverses
  all coalesced changes) and composes the apply functions.

  ## Example

      iex> u = Plushie.Undo.new(0)
      iex> cmd = %{apply: &(&1 + 1), undo: &(&1 - 1)}
      iex> u = Plushie.Undo.push(u, cmd)
      iex> Plushie.Undo.current(u)
      1
      iex> u = Plushie.Undo.undo(u)
      iex> Plushie.Undo.current(u)
      0
  """

  defstruct [:current, :max_size, undo_size: 0, undo_stack: [], redo_stack: []]

  @type command :: %{
          required(:apply) => (term() -> term()),
          required(:undo) => (term() -> term()),
          optional(:label) => String.t(),
          optional(:coalesce) => term(),
          optional(:coalesce_window_ms) => non_neg_integer()
        }

  @type entry :: %{
          apply_fn: (term() -> term()),
          undo_fn: (term() -> term()),
          label: String.t() | nil,
          coalesce: term() | nil,
          timestamp: integer()
        }

  @type t :: %__MODULE__{
          current: term(),
          max_size: pos_integer(),
          undo_size: non_neg_integer(),
          undo_stack: [entry()],
          redo_stack: [entry()]
        }

  @doc """
  Create a new undo stack with `model` as the initial state.

  ## Options

    * `:max_size` - maximum number of undo entries (default #{@default_max_size}).
      When exceeded, the oldest entries are dropped silently.
  """
  @spec new(model :: term(), opts :: keyword()) :: t()
  def new(model, opts \\ []) do
    max_size = Keyword.get(opts, :max_size, @default_max_size)

    unless is_integer(max_size) and max_size > 0 do
      raise ArgumentError,
            "expected :max_size to be a positive integer, got: #{inspect(max_size)}"
    end

    %__MODULE__{current: model, max_size: max_size}
  end

  @doc """
  Push a command onto the undo stack, updating the current model. Clears
  the redo stack.

  The command must be a map with `:apply` and `:undo` keys (both single-arity
  functions). Optional keys: `:label`, `:coalesce`, `:coalesce_window_ms`.

  If the command carries a `:coalesce` key that matches the top of the undo
  stack and the time delta is within `:coalesce_window_ms`, the entry is
  merged rather than pushed.

  When the undo stack exceeds `:max_size`, the oldest entries are dropped.
  """
  @spec push(undo :: t(), command :: command()) :: t()
  def push(%__MODULE__{} = u, %{apply: apply_fn, undo: undo_fn} = command)
      when is_function(apply_fn, 1) and is_function(undo_fn, 1) do
    now = timestamp()
    new_model = apply_fn.(u.current)

    case maybe_coalesce(u, command, now) do
      {:coalesce, merged_entry} ->
        # Coalesced entries replace the top; size unchanged.
        %{u | current: new_model, undo_stack: [merged_entry | tl(u.undo_stack)], redo_stack: []}

      :no_coalesce ->
        entry = %{
          apply_fn: apply_fn,
          undo_fn: undo_fn,
          label: Map.get(command, :label),
          coalesce: Map.get(command, :coalesce),
          timestamp: now
        }

        new_size = u.undo_size + 1
        {undo_stack, final_size} = enforce_max_size([entry | u.undo_stack], new_size, u.max_size)
        %{u | current: new_model, undo_stack: undo_stack, undo_size: final_size, redo_stack: []}
    end
  end

  @doc "Undo the last command. Returns unchanged if the undo stack is empty."
  @spec undo(undo :: t()) :: t()
  def undo(%__MODULE__{undo_stack: []} = u), do: u

  def undo(%__MODULE__{undo_stack: [entry | rest]} = u) do
    old_model = entry.undo_fn.(u.current)

    %{
      u
      | current: old_model,
        undo_stack: rest,
        undo_size: u.undo_size - 1,
        redo_stack: [entry | u.redo_stack]
    }
  end

  @doc "Redo the last undone command. Returns unchanged if the redo stack is empty."
  @spec redo(undo :: t()) :: t()
  def redo(%__MODULE__{redo_stack: []} = u), do: u

  def redo(%__MODULE__{redo_stack: [entry | rest]} = u) do
    new_model = entry.apply_fn.(u.current)

    %{
      u
      | current: new_model,
        redo_stack: rest,
        undo_stack: [entry | u.undo_stack],
        undo_size: u.undo_size + 1
    }
  end

  @doc "Return the current model."
  @spec current(undo :: t()) :: term()
  def current(%__MODULE__{current: c}), do: c

  @doc "Return `true` if there are entries on the undo stack."
  @spec can_undo?(undo :: t()) :: boolean()
  def can_undo?(%__MODULE__{undo_stack: [_ | _]}), do: true
  def can_undo?(%__MODULE__{}), do: false

  @doc "Return `true` if there are entries on the redo stack."
  @spec can_redo?(undo :: t()) :: boolean()
  def can_redo?(%__MODULE__{redo_stack: [_ | _]}), do: true
  def can_redo?(%__MODULE__{}), do: false

  @doc "Return the labels from the undo stack, most recent first."
  @spec history(undo :: t()) :: [String.t() | nil]
  def history(%__MODULE__{undo_stack: s}), do: Enum.map(s, & &1.label)

  # -- Private ---------------------------------------------------------------

  defp enforce_max_size(stack, size, max_size) when size > max_size do
    {Enum.take(stack, max_size), max_size}
  end

  defp enforce_max_size(stack, size, _max_size), do: {stack, size}

  defp maybe_coalesce(%__MODULE__{undo_stack: []}, _command, _now), do: :no_coalesce

  defp maybe_coalesce(%__MODULE__{undo_stack: [top | _]}, command, now) do
    coalesce_key = Map.get(command, :coalesce)
    window = Map.get(command, :coalesce_window_ms, 0)

    if coalesce_key != nil and coalesce_key == top.coalesce and now - top.timestamp <= window do
      # Compose apply: old apply then new apply.
      # Compose undo: new undo then old undo (reverse order).
      merged = %{
        top
        | apply_fn: fn model -> command.apply.(top.apply_fn.(model)) end,
          undo_fn: fn model -> top.undo_fn.(command.undo.(model)) end,
          timestamp: now
      }

      {:coalesce, merged}
    else
      :no_coalesce
    end
  end

  # Seam for testing: allows tests to control time via process dictionary.
  defp timestamp do
    case Process.get(:plushie_undo_timestamp) do
      nil -> System.monotonic_time(:millisecond)
      ts -> ts
    end
  end
end
