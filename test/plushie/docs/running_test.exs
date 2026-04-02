defmodule Plushie.Docs.RunningTest do
  use ExUnit.Case, async: true

  # ============================================================================
  # A minimal app for testing start_link option shapes.
  # We don't actually call start_link (it needs a renderer binary), but we
  # verify the option shapes compile and the APIs accept them.
  # ============================================================================

  defmodule DummyApp do
    use Plushie.App

    def init(_opts), do: %{}
    def update(model, _event), do: model

    def view(_model) do
      import Plushie.UI

      window "main" do
        text("hello", "Hello")
      end
    end
  end

  # ============================================================================
  # start_link default (from "Local desktop" section)
  # The doc shows: {:ok, pid} = Plushie.start_link(MyApp)
  # We verify the function exists with correct arity and accepts the module.
  # ============================================================================

  test "running_start_link_default_test" do
    # Verify start_link/2 is exported and accepts an app module with opts.
    # We can't actually start (no binary), but we can verify the child_spec
    # shape which exercises the same option parsing path.
    spec = Plushie.child_spec(app: DummyApp)
    assert spec.id == Plushie
    assert spec.type == :supervisor
    assert {Plushie, :start_link, [DummyApp, _opts]} = spec.start
  end

  # ============================================================================
  # start_link with stdio + daemon (from "Network drops" section)
  # The doc shows: Plushie.start_link(MyApp, transport: :stdio, daemon: true)
  # ============================================================================

  test "running_start_link_stdio_daemon_test" do
    opts = [transport: :stdio, daemon: true]
    spec = Plushie.child_spec([app: DummyApp] ++ opts)

    assert spec.type == :supervisor
    {Plushie, :start_link, [DummyApp, merged_opts]} = spec.start
    assert merged_opts[:transport] == :stdio
    assert merged_opts[:daemon] == true
  end

  # ============================================================================
  # Settings with default_event_rate (from "Global default" section)
  # The doc shows a settings/0 callback returning [default_event_rate: 60].
  # We define a module with this callback and verify the return value.
  # ============================================================================

  defmodule AppWithDefaultRate do
    use Plushie.App

    def init(_opts), do: %{}
    def update(model, _event), do: model

    def view(_model),
      do:
        import(Plushie.UI) &&
          (window("main") do
             text("x", "x")
           end)

    def settings do
      [default_event_rate: 60]
    end
  end

  test "running_settings_default_event_rate_test" do
    settings = AppWithDefaultRate.settings()
    assert settings[:default_event_rate] == 60
  end

  # ============================================================================
  # Settings with low event rate (from "For a monitoring dashboard" section)
  # The doc shows: [default_event_rate: 15]
  # ============================================================================

  defmodule AppWithLowRate do
    use Plushie.App

    def init(_opts), do: %{}
    def update(model, _event), do: model

    def view(_model),
      do:
        import(Plushie.UI) &&
          (window("main") do
             text("x", "x")
           end)

    def settings do
      [default_event_rate: 15]
    end
  end

  test "running_settings_low_event_rate_test" do
    settings = AppWithLowRate.settings()
    assert settings[:default_event_rate] == 15
  end

  # ============================================================================
  # Subscriptions with max_rate (from "Per-subscription" section)
  # The doc shows:
  #   Subscription.on_pointer_move(:mouse, max_rate: 30)
  #   Subscription.on_animation_frame(:frame, max_rate: 60)
  #   Subscription.on_pointer_move(:capture, max_rate: 0)
  # ============================================================================

  test "running_subscription_pointer_move_with_rate_test" do
    alias Plushie.Subscription

    sub_mouse = Subscription.on_pointer_move(:mouse, max_rate: 30)
    assert %Subscription{type: :on_pointer_move, tag: :mouse, max_rate: 30} = sub_mouse

    sub_frame = Subscription.on_animation_frame(:frame, max_rate: 60)
    assert %Subscription{type: :on_animation_frame, tag: :frame, max_rate: 60} = sub_frame

    sub_capture = Subscription.on_pointer_move(:capture, max_rate: 0)
    assert %Subscription{type: :on_pointer_move, tag: :capture, max_rate: 0} = sub_capture
  end

  # ============================================================================
  # TCP adapter (from "Example: TCP adapter" section)
  # The doc shows a GenServer-based adapter. We define it as a test module
  # and verify it compiles and has the expected callbacks.
  # ============================================================================

  defmodule TCPAdapter do
    use GenServer

    def start_link(socket), do: GenServer.start_link(__MODULE__, socket)

    def init(socket) do
      :inet.setopts(socket, active: true)
      {:ok, %{socket: socket, bridge: nil, buffer: <<>>}}
    end

    # Bridge registered itself on init
    def handle_info({:iostream_bridge, bridge_pid}, state) do
      {:noreply, %{state | bridge: bridge_pid}}
    end

    # Bridge wants to send data to the renderer
    def handle_info({:iostream_send, iodata}, state) do
      :gen_tcp.send(state.socket, Plushie.Transport.Framing.encode_packet(iodata))
      {:noreply, state}
    end

    # TCP data arrived -- decode frames and forward complete messages
    def handle_info({:tcp, _socket, data}, state) do
      {messages, buffer} =
        Plushie.Transport.Framing.decode_packets(state.buffer <> data)

      for msg <- messages, do: send(state.bridge, {:iostream_data, msg})
      {:noreply, %{state | buffer: buffer}}
    end

    # TCP closed -- tell the Bridge
    def handle_info({:tcp_closed, _socket}, state) do
      if state.bridge, do: send(state.bridge, {:iostream_closed, :tcp_closed})
      {:stop, :normal, state}
    end
  end

  test "running_tcp_adapter_compiles_test" do
    # The module compiled successfully if we got here. Verify it has
    # the expected GenServer callbacks.
    assert function_exported?(TCPAdapter, :init, 1)
    assert function_exported?(TCPAdapter, :handle_info, 2)
    assert function_exported?(TCPAdapter, :start_link, 1)
  end

  # ============================================================================
  # Transport option shapes -- verify iostream tuple is accepted
  # ============================================================================

  test "running_iostream_transport_option_shape_test" do
    adapter_pid = self()
    opts = [transport: {:iostream, adapter_pid}, format: :msgpack]
    spec = Plushie.child_spec([app: DummyApp] ++ opts)

    {Plushie, :start_link, [DummyApp, merged_opts]} = spec.start
    assert {:iostream, ^adapter_pid} = merged_opts[:transport]
    assert merged_opts[:format] == :msgpack
  end
end
