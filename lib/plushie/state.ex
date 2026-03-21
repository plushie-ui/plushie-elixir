defmodule Plushie.State do
  @moduledoc """
  Path-based state management with revision tracking and transactions.

  A lightweight wrapper around a plain map that tracks a monotonically
  increasing revision number on every mutation. Useful for detecting
  changes and implementing optimistic concurrency.

  ## Transactions

  `begin_transaction/1` captures a snapshot of the current data and revision.
  Subsequent mutations increment the revision as usual. `commit_transaction/1`
  finalises the transaction (bumping the revision once from the pre-transaction
  value). `rollback_transaction/1` restores the snapshot exactly.

  ## Example

      state = Plushie.State.new(%{count: 0})
      state = Plushie.State.put(state, [:count], 5)
      Plushie.State.get(state, [:count])
      #=> 5
      Plushie.State.revision(state)
      #=> 1
  """

  defstruct [:data, revision: 0, transaction: nil]

  @type t :: %__MODULE__{data: map(), revision: non_neg_integer(), transaction: map() | nil}

  @doc """
  Creates a new state container wrapping `data`.

  The initial revision is 0.
  """
  @spec new(data :: map()) :: t()
  def new(data) when is_map(data) do
    %__MODULE__{data: data, revision: 0, transaction: nil}
  end

  @doc """
  Reads the value at `path` in the state data.

  An empty path returns the entire data map. Path elements are keys
  passed to `Kernel.get_in/2`.
  """
  @spec get(state :: t(), path :: list()) :: term()
  def get(%__MODULE__{data: data}, []), do: data

  def get(%__MODULE__{data: data}, path) when is_list(path) do
    get_in(data, path)
  end

  @doc "Sets the value at `path` to `value`, incrementing the revision."
  @spec put(state :: t(), path :: list(), value :: term()) :: t()
  def put(%__MODULE__{} = state, path, value) when is_list(path) do
    new_data = put_in(state.data, path, value)
    %{state | data: new_data, revision: state.revision + 1}
  end

  @doc """
  Applies `fun` to the value at `path`, incrementing the revision.

  `fun` receives the current value and must return the new value.
  """
  @spec update(state :: t(), path :: list(), fun :: (term() -> term())) :: t()
  def update(%__MODULE__{} = state, path, fun) when is_list(path) and is_function(fun, 1) do
    new_data = update_in(state.data, path, fun)
    %{state | data: new_data, revision: state.revision + 1}
  end

  @doc "Returns the current revision number."
  @spec revision(state :: t()) :: non_neg_integer()
  def revision(%__MODULE__{revision: rev}), do: rev

  @doc """
  Begins a transaction by capturing the current data and revision.

  Returns `{:error, :transaction_already_active}` if a transaction is
  already in progress.
  """
  @spec begin_transaction(state :: t()) :: t() | {:error, :transaction_already_active}
  def begin_transaction(%__MODULE__{transaction: nil} = state) do
    %{state | transaction: %{data: state.data, revision: state.revision}}
  end

  def begin_transaction(%__MODULE__{transaction: %{}}),
    do: {:error, :transaction_already_active}

  @doc """
  Commits the active transaction, setting the revision to one past the
  pre-transaction value.
  """
  @spec commit_transaction(state :: t()) :: t()
  def commit_transaction(%__MODULE__{transaction: %{revision: old_rev}} = state) do
    %{state | transaction: nil, revision: old_rev + 1}
  end

  @doc """
  Rolls back the active transaction, restoring the data and revision
  to their pre-transaction values.
  """
  @spec rollback_transaction(state :: t()) :: t()
  def rollback_transaction(%__MODULE__{transaction: %{} = snapshot} = state) do
    %{state | data: snapshot.data, revision: snapshot.revision, transaction: nil}
  end
end
