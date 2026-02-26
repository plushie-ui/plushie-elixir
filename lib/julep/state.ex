defmodule Julep.State do
  @moduledoc "Path-based state management with revision tracking and transactions."

  defstruct [:data, revision: 0, transaction: nil]

  @type t :: %__MODULE__{data: map(), revision: non_neg_integer(), transaction: map() | nil}

  def new(data) when is_map(data) do
    %__MODULE__{data: data, revision: 0, transaction: nil}
  end

  def get(%__MODULE__{data: data}, []), do: data

  def get(%__MODULE__{data: data}, path) when is_list(path) do
    get_in(data, path)
  end

  def put(%__MODULE__{} = state, path, value) when is_list(path) do
    new_data = put_in(state.data, path, value)
    %{state | data: new_data, revision: state.revision + 1}
  end

  def update(%__MODULE__{} = state, path, fun) when is_list(path) and is_function(fun, 1) do
    new_data = update_in(state.data, path, fun)
    %{state | data: new_data, revision: state.revision + 1}
  end

  def revision(%__MODULE__{revision: rev}), do: rev

  def begin_transaction(%__MODULE__{transaction: nil} = state) do
    %{state | transaction: %{data: state.data, revision: state.revision}}
  end

  def begin_transaction(%__MODULE__{transaction: %{}}),
    do: {:error, :transaction_already_active}

  def commit_transaction(%__MODULE__{transaction: %{revision: old_rev}} = state) do
    %{state | transaction: nil, revision: old_rev + 1}
  end

  def rollback_transaction(%__MODULE__{transaction: %{} = snapshot} = state) do
    %{state | data: snapshot.data, revision: snapshot.revision, transaction: nil}
  end
end
