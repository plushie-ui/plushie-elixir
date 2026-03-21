defmodule Plushie.Undo do
  @moduledoc """
  Undo/redo stack for reversible commands. Pure data structure, no processes.

  Each command provides an `apply` function and an `undo` function. The stack
  tracks entries as `{apply_fn, undo_fn}` pairs so that undo moves an entry
  to the redo stack (calling `undo_fn`) and redo moves it back (calling
  `apply_fn`).

  ## Coalescing

  Commands with the same `:coalesce` key that arrive within
  `:coalesce_window_ms` of each other are merged into a single undo entry.
  The merged entry keeps the *original* undo function (so one undo reverses
  all coalesced changes) and composes the apply functions.

  ## Example

      iex> u = Plushie.Undo.new(0)
      iex> cmd = %{apply: &(&1 + 1), undo: &(&1 - 1)}
      iex> u = Plushie.Undo.apply(u, cmd)
      iex> Plushie.Undo.current(u)
      1
      iex> u = Plushie.Undo.undo(u)
      iex> Plushie.Undo.current(u)
      0
  """

  defstruct [:current, undo_stack: [], redo_stack: []]

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
          undo_stack: [entry()],
          redo_stack: [entry()]
        }

  @doc "Create a new undo stack with `model` as the initial state."
  @spec new(model :: term()) :: t()
  def new(model), do: %__MODULE__{current: model}

  @doc """
  Apply a command, updating the current model and pushing an entry onto
  the undo stack. Clears the redo stack.

  If the command carries a `:coalesce` key that matches the top of the undo
  stack and the time delta is within `:coalesce_window_ms`, the entry is
  merged rather than pushed.
  """
  @spec apply(undo :: t(), command :: command()) :: t()
  def apply(%__MODULE__{} = u, command) do
    now = timestamp()
    new_model = command.apply.(u.current)

    case maybe_coalesce(u, command, now) do
      {:coalesce, merged_entry} ->
        %{u | current: new_model, undo_stack: [merged_entry | tl(u.undo_stack)], redo_stack: []}

      :no_coalesce ->
        entry = %{
          apply_fn: command.apply,
          undo_fn: command.undo,
          label: Map.get(command, :label),
          coalesce: Map.get(command, :coalesce),
          timestamp: now
        }

        %{u | current: new_model, undo_stack: [entry | u.undo_stack], redo_stack: []}
    end
  end

  @doc "Undo the last command. Returns unchanged if the undo stack is empty."
  @spec undo(undo :: t()) :: t()
  def undo(%__MODULE__{undo_stack: []} = u), do: u

  def undo(%__MODULE__{undo_stack: [entry | rest]} = u) do
    old_model = entry.undo_fn.(u.current)

    %{u | current: old_model, undo_stack: rest, redo_stack: [entry | u.redo_stack]}
  end

  @doc "Redo the last undone command. Returns unchanged if the redo stack is empty."
  @spec redo(undo :: t()) :: t()
  def redo(%__MODULE__{redo_stack: []} = u), do: u

  def redo(%__MODULE__{redo_stack: [entry | rest]} = u) do
    new_model = entry.apply_fn.(u.current)

    %{u | current: new_model, redo_stack: rest, undo_stack: [entry | u.undo_stack]}
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

  # Seam for testing -- allows tests to control time via process dictionary.
  defp timestamp do
    case Process.get(:plushie_undo_timestamp) do
      nil -> System.monotonic_time(:millisecond)
      ts -> ts
    end
  end
end
