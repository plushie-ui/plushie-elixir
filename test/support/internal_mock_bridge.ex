# Internal test stub for framework plumbing tests. For testing Plushie
# apps, use Plushie.Test.Case which runs against the real renderer binary.
defmodule Plushie.Test.InternalMockBridge do
  @moduledoc false
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

  @doc "Returns all effects received so far, in order."
  def get_effects(bridge) do
    GenServer.call(bridge, :get_effects)
  end

  @doc "Returns all widget ops received so far, in order."
  def get_widget_ops(bridge) do
    GenServer.call(bridge, :get_widget_ops)
  end

  @doc "Returns all subscribe messages received so far, in order."
  def get_subscribes(bridge) do
    GenServer.call(bridge, :get_subscribes)
  end

  @doc "Returns all unsubscribe messages received so far, in order."
  def get_unsubscribes(bridge) do
    GenServer.call(bridge, :get_unsubscribes)
  end

  @doc "Returns all window ops received so far, in order."
  def get_window_ops(bridge) do
    GenServer.call(bridge, :get_window_ops)
  end

  @doc "Returns all settings messages received so far, in order."
  def get_settings(bridge) do
    GenServer.call(bridge, :get_settings)
  end

  @impl true
  def init(_opts) do
    {:ok,
     %{
       snapshots: [],
       patches: [],
       effects: [],
       widget_ops: [],
       subscribes: [],
       unsubscribes: [],
       window_ops: [],
       settings: []
     }}
  end

  @impl true
  def handle_cast({:send_snapshot, tree}, state) do
    {:noreply, %{state | snapshots: state.snapshots ++ [tree]}}
  end

  def handle_cast({:send_patch, ops}, state) do
    {:noreply, %{state | patches: state.patches ++ [ops]}}
  end

  def handle_cast({:send_effect, id, kind, payload}, state) do
    entry = %{id: id, kind: kind, payload: payload}
    {:noreply, %{state | effects: state.effects ++ [entry]}}
  end

  def handle_cast({:send_widget_op, op, payload}, state) do
    entry = %{op: op, payload: payload}
    {:noreply, %{state | widget_ops: state.widget_ops ++ [entry]}}
  end

  def handle_cast({:send_subscribe, kind, tag, max_rate}, state) do
    entry = %{kind: kind, tag: tag, max_rate: max_rate}
    {:noreply, %{state | subscribes: state.subscribes ++ [entry]}}
  end

  def handle_cast({:send_unsubscribe, kind}, state) do
    entry = %{kind: kind}
    {:noreply, %{state | unsubscribes: state.unsubscribes ++ [entry]}}
  end

  def handle_cast({:send_settings, settings}, state) do
    {:noreply, %{state | settings: state.settings ++ [settings]}}
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

  def handle_call(:get_effects, _from, state) do
    {:reply, state.effects, state}
  end

  def handle_call(:get_widget_ops, _from, state) do
    {:reply, state.widget_ops, state}
  end

  def handle_call(:get_subscribes, _from, state) do
    {:reply, state.subscribes, state}
  end

  def handle_call(:get_unsubscribes, _from, state) do
    {:reply, state.unsubscribes, state}
  end

  def handle_call(:get_window_ops, _from, state) do
    {:reply, state.window_ops, state}
  end

  def handle_call(:get_settings, _from, state) do
    {:reply, state.settings, state}
  end
end
