defmodule Julep.Test.MockBridge do
  @moduledoc """
  A minimal stand-in for Julep.Bridge used in unit tests.

  Records every snapshot cast sent by the Runtime so tests can assert on
  the sequence of trees that were sent without touching a real renderer
  or port.
  """
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @doc "Returns all snapshots received so far, in order."
  def get_snapshots(bridge) do
    GenServer.call(bridge, :get_snapshots)
  end

  @impl true
  def init(_opts), do: {:ok, %{snapshots: []}}

  @impl true
  def handle_cast({:send_snapshot, tree}, state) do
    {:noreply, %{state | snapshots: state.snapshots ++ [tree]}}
  end

  @impl true
  def handle_call(:get_snapshots, _from, state) do
    {:reply, state.snapshots, state}
  end
end
