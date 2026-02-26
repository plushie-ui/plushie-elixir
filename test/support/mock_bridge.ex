defmodule Julep.Test.MockBridge do
  @moduledoc """
  A minimal stand-in for Julep.Bridge used in unit tests.

  Records every cast sent by the Runtime so tests can assert on
  the sequence of messages that were sent without touching a real renderer
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

  @doc "Returns all widget ops received so far, in order."
  def get_widget_ops(bridge) do
    GenServer.call(bridge, :get_widget_ops)
  end

  @doc "Returns all subscription register messages received so far, in order."
  def get_subscription_registers(bridge) do
    GenServer.call(bridge, :get_subscription_registers)
  end

  @doc "Returns all subscription unregister messages received so far, in order."
  def get_subscription_unregisters(bridge) do
    GenServer.call(bridge, :get_subscription_unregisters)
  end

  @doc "Returns all window ops received so far, in order."
  def get_window_ops(bridge) do
    GenServer.call(bridge, :get_window_ops)
  end

  @impl true
  def init(_opts) do
    {:ok, %{
      snapshots: [],
      patches: [],
      effect_requests: [],
      widget_ops: [],
      subscription_registers: [],
      subscription_unregisters: [],
      window_ops: []
    }}
  end

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

  def handle_cast({:send_widget_op, op, payload}, state) do
    entry = %{op: op, payload: payload}
    {:noreply, %{state | widget_ops: state.widget_ops ++ [entry]}}
  end

  def handle_cast({:send_subscription_register, kind, tag}, state) do
    entry = %{kind: kind, tag: tag}
    {:noreply, %{state | subscription_registers: state.subscription_registers ++ [entry]}}
  end

  def handle_cast({:send_subscription_unregister, kind}, state) do
    entry = %{kind: kind}
    {:noreply, %{state | subscription_unregisters: state.subscription_unregisters ++ [entry]}}
  end

  def handle_cast({:send_window_op, op, window_id, settings}, state) do
    entry = %{op: op, window_id: window_id, settings: settings}
    {:noreply, %{state | window_ops: state.window_ops ++ [entry]}}
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

  def handle_call(:get_widget_ops, _from, state) do
    {:reply, state.widget_ops, state}
  end

  def handle_call(:get_subscription_registers, _from, state) do
    {:reply, state.subscription_registers, state}
  end

  def handle_call(:get_subscription_unregisters, _from, state) do
    {:reply, state.subscription_unregisters, state}
  end

  def handle_call(:get_window_ops, _from, state) do
    {:reply, state.window_ops, state}
  end
end
