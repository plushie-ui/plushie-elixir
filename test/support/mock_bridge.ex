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

  @doc "Returns all patches received so far, in order."
  def get_patches(bridge) do
    GenServer.call(bridge, :get_patches)
  end

  @doc "Returns all effect requests received so far, in order."
  def get_effect_requests(bridge) do
    GenServer.call(bridge, :get_effect_requests)
  end

  @impl true
  def init(_opts), do: {:ok, %{snapshots: [], patches: [], effect_requests: []}}

  @impl true
  def handle_cast({:send_snapshot, tree}, state) do
    {:noreply, %{state | snapshots: state.snapshots ++ [tree]}}
  end

  def handle_cast({:send_patch, ops}, state) do
    {:noreply, %{state | patches: state.patches ++ [ops]}}
  end

  def handle_cast({:send_effect_request, id, kind, payload}, state) do
    entry = %{id: id, kind: kind, payload: payload}
    {:noreply, %{state | effect_requests: state.effect_requests ++ [entry]}}
  end

  @impl true
  def handle_call(:get_snapshots, _from, state) do
    {:reply, state.snapshots, state}
  end

  def handle_call(:get_patches, _from, state) do
    {:reply, state.patches, state}
  end

  def handle_call(:get_effect_requests, _from, state) do
    {:reply, state.effect_requests, state}
  end
end
