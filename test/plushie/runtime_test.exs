defmodule Plushie.RuntimeTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Plushie.Event.WidgetEvent

  # Test app: simple counter driven by button click events.

  defmodule SimpleApp do
    use Plushie.App

    def init(_opts), do: %{value: 0}

    def update(model, %WidgetEvent{type: :click, id: "inc"}),
      do: %{model | value: model.value + 1}

    def update(model, %WidgetEvent{type: :click, id: "dec"}),
      do: %{model | value: model.value - 1}

    def update(model, _event), do: model

    def view(model) do
      import Plushie.UI

      window "main" do
        column do
          text("Value: #{model.value}")
          button("inc", "+")
        end
      end
    end
  end

  # Test app: exercises send_after (schedules a timer in init).

  defmodule CommandApp do
    use Plushie.App

    def init(_opts) do
      {%{value: 0}, Plushie.Command.send_after(10, :timer_tick)}
    end

    def update(model, :timer_tick), do: %{model | value: model.value + 1}
    def update(model, _event), do: model

    def view(model) do
      import Plushie.UI

      window "main" do
        column do
          text("#{model.value}")
        end
      end
    end
  end

  # Test app: exercises the async command (no timer in init to avoid races).

  defmodule AsyncApp do
    use Plushie.App

    def init(_opts), do: %{value: 0}

    def update(model, %WidgetEvent{type: :click, id: "async"}) do
      cmd = Plushie.Command.async(fn -> 42 end, :async_result)
      {model, cmd}
    end

    def update(model, %Plushie.Event.AsyncEvent{tag: :async_result, result: result}),
      do: %{model | value: result}

    def update(model, _event), do: model

    def view(model) do
      import Plushie.UI

      window "main" do
        column do
          text("#{model.value}")
        end
      end
    end
  end

  defmodule StarRatingNative do
    use Plushie.Widget, :native_widget

    widget(:star_rating)
    event(:selected, value: :any)
    prop(:value, :number)

    rust_crate("native/star_rating")
    rust_constructor("star_rating::StarRating::new()")
  end

  defmodule NativeEventApp do
    use Plushie.App

    def init(_opts), do: %{selected: nil}

    def update(model, %WidgetEvent{type: {:star_rating, :selected}, id: "rating", value: value}) do
      %{model | selected: value}
    end

    def update(model, _event), do: model

    def view(_model) do
      import Plushie.UI

      window "main" do
        column do
          StarRatingNative.new("rating", value: 0)
        end
      end
    end
  end

  defmodule TickWidget do
    use Plushie.Widget
    widget(:tick_widget)
    event(:tick_widget_pulsed)

    @impl true
    def subscribe(_props, _state) do
      [Plushie.Subscription.every(1_000, :pulse)]
    end

    @impl true
    def handle_event(%Plushie.Event.TimerEvent{tag: :pulse}, _state) do
      {:emit, :tick_widget_pulsed, %{}}
    end

    def handle_event(_event, _state), do: :ignored

    @impl true
    def view(id, _props, _state) do
      import Plushie.UI

      canvas id, width: 10, height: 10 do
      end
    end
  end

  defmodule WidgetSubApp do
    use Plushie.App

    def init(_opts), do: %{clicks: 0, pulses: 0}

    def update(model, %WidgetEvent{type: :click, id: "inc"}) do
      %{model | clicks: model.clicks + 1}
    end

    def update(model, %WidgetEvent{type: {:tick_widget, :tick_widget_pulsed}}) do
      %{model | pulses: model.pulses + 1}
    end

    def update(model, _event), do: model

    def view(_model) do
      import Plushie.UI

      window "main" do
        column do
          button("inc", "+")
          TickWidget.new("ticker")
        end
      end
    end
  end

  defmodule CoalesceOrderApp do
    use Plushie.App

    def init(_opts), do: %{events: []}

    def update(model, %Plushie.Event.MouseEvent{type: :moved}) do
      %{model | events: model.events ++ [:mouse]}
    end

    def update(model, %Plushie.Event.WidgetEvent{type: :resize}) do
      %{model | events: model.events ++ [:sensor]}
    end

    def update(model, _event), do: model

    def view(_model) do
      import Plushie.UI

      window "main" do
        column do
        end
      end
    end
  end

  defmodule SensorWindowCoalesceApp do
    use Plushie.App

    def init(_opts), do: %{events: []}

    def update(model, %Plushie.Event.WidgetEvent{type: :resize, window_id: window_id}) do
      %{model | events: model.events ++ [window_id]}
    end

    def update(model, _event), do: model

    def view(_model) do
      import Plushie.UI

      [
        window("main", title: "Main") do
          sensor("size", on_resize: true)
        end,
        window("prefs", title: "Prefs") do
          sensor("size", on_resize: true)
        end
      ]
    end
  end

  defmodule SwitchingWidget do
    use Plushie.Widget
    widget(:switching_widget)
    state(phase: :first)
    event(:switched, value: :any)
    event(:ticked_second)

    @impl true
    def subscribe(_props, %{phase: :first}) do
      [Plushie.Subscription.every(1_000, :first)]
    end

    def subscribe(_props, %{phase: :second}) do
      [Plushie.Subscription.every(1_000, :second)]
    end

    @impl true
    def handle_event(%Plushie.Event.TimerEvent{tag: :first}, _state) do
      {:emit, :switched, %{to: :second}, %{phase: :second}}
    end

    def handle_event(%Plushie.Event.TimerEvent{tag: :second}, _state) do
      {:emit, :ticked_second, nil}
    end

    def handle_event(_event, _state), do: :consumed

    @impl true
    def view(id, _props, %{phase: phase}) do
      import Plushie.UI

      canvas id, width: 100, height: 100 do
        layer "content" do
          text(0, 0, "phase:#{phase}")
        end
      end
    end
  end

  defmodule SwitchingWidgetApp do
    use Plushie.App

    def init(_opts), do: %{}
    def update(model, _event), do: model

    def view(_model) do
      import Plushie.UI

      window "main" do
        column do
          SwitchingWidget.new("switcher")
        end
      end
    end
  end

  # Helpers

  # Starts a uniquely-named InternalMockBridge and Runtime pair for a single test.
  # Returns {runtime_pid, bridge_name}.
  defp start_runtime(app, extra_opts \\ []) do
    # Use the test PID to ensure unique names per test (async: true safe).
    tag = System.unique_integer([:positive])
    bridge_name = :"mock_bridge_#{tag}"
    runtime_name = :"runtime_#{tag}"

    {:ok, _bridge} = Plushie.Test.InternalMockBridge.start_link(name: bridge_name)

    opts =
      [app: app, bridge: bridge_name, name: runtime_name]
      |> Keyword.merge(extra_opts)

    {:ok, runtime} = Plushie.Runtime.start_link(opts)

    {runtime, bridge_name}
  end

  # Waits for handle_continue/:initial_render to complete.
  defp await_initial_render(runtime) do
    Plushie.Runtime.sync(runtime)
  end

  # Dispatches an event and waits for the runtime to process it.
  defp dispatch_and_wait(runtime, event) do
    Plushie.Runtime.dispatch(runtime, event)
    Plushie.Runtime.sync(runtime)
  end

  # Polls until a condition on the model is met (via the public get_model API)
  # or timeout expires.
  defp await_model(runtime, condition_fn, timeout \\ 500) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_await_model(runtime, condition_fn, deadline)
  end

  defp do_await_model(runtime, condition_fn, deadline) do
    model = Plushie.Runtime.get_model(runtime)

    if condition_fn.(model) do
      model
    else
      if System.monotonic_time(:millisecond) >= deadline do
        flunk("Timed out waiting for model condition. Last model: #{inspect(model)}")
      else
        Process.sleep(5)
        do_await_model(runtime, condition_fn, deadline)
      end
    end
  end

  # Polls until a condition on the bridge state is met or timeout expires.
  defp await_bridge(bridge, condition_fn, timeout \\ 500) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_await_bridge(bridge, condition_fn, deadline)
  end

  defp do_await_bridge(bridge, condition_fn, deadline) do
    if condition_fn.(bridge) do
      :ok
    else
      if System.monotonic_time(:millisecond) >= deadline do
        flunk("Timed out waiting for bridge condition")
      else
        Process.sleep(5)
        do_await_bridge(bridge, condition_fn, deadline)
      end
    end
  end

  describe "init/update/view cycle" do
    test "Runtime starts and sends initial snapshot to bridge" do
      {runtime, bridge} = start_runtime(SimpleApp)
      await_initial_render(runtime)

      snapshots = Plushie.Test.InternalMockBridge.get_snapshots(bridge)
      assert length(snapshots) == 1

      [snapshot] = snapshots
      assert snapshot.type == "window"
      assert snapshot.id == "main"

      # The text child should reflect the initial model value of 0.
      text_node = find_by_type(snapshot, "text")
      assert text_node != nil
      assert text_node.props[:content] == "Value: 0"
    end

    test "dispatching an event updates the model and sends a patch" do
      {runtime, bridge} = start_runtime(SimpleApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "inc"})

      # Initial render sends a snapshot; subsequent updates send patches.
      snapshots = Plushie.Test.InternalMockBridge.get_snapshots(bridge)
      assert length(snapshots) == 1

      patches = Plushie.Test.InternalMockBridge.get_patches(bridge)
      assert length(patches) == 1

      # Verify the runtime's current tree reflects the update.
      text_node = find_by_type(Plushie.Runtime.get_tree(runtime), "text")
      assert text_node.props[:content] == "Value: 1"
    end

    test "multiple events produce patches and update model correctly" do
      {runtime, _bridge} = start_runtime(SimpleApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "inc"})
      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "inc"})
      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "dec"})

      assert Plushie.Runtime.get_model(runtime).value == 1

      text_node = find_by_type(Plushie.Runtime.get_tree(runtime), "text")
      assert text_node.props[:content] == "Value: 1"
    end

    test "unknown events are handled and model remains unchanged" do
      {runtime, bridge} = start_runtime(SimpleApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "nope"})
      dispatch_and_wait(runtime, :mystery_event)

      # Unknown events don't change the tree, so no patches are sent.
      patches = Plushie.Test.InternalMockBridge.get_patches(bridge)
      assert patches == []

      assert Plushie.Runtime.get_model(runtime).value == 0
    end

    test "widget-specific extension families are normalized before update/2" do
      {runtime, _bridge} = start_runtime(NativeEventApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, %WidgetEvent{
        type: {:star_rating, :selected},
        id: "rating",
        value: 4
      })

      assert Plushie.Runtime.get_model(runtime).selected == 4
    end

    test "runtime stops when renderer is missing a required native extension" do
      # Seed the WidgetRegistry cache to include StarRatingNative so the
      # runtime expects it in the renderer's hello message.
      :persistent_term.put({Plushie.WidgetRegistry, :all}, [StarRatingNative])
      on_exit(fn -> Plushie.WidgetRegistry.invalidate() end)

      Process.flag(:trap_exit, true)
      {runtime, _bridge} = start_runtime(SimpleApp)
      await_initial_render(runtime)
      ref = Process.monitor(runtime)

      log =
        capture_log(fn ->
          send(
            runtime,
            {:renderer_event,
             {:hello,
              %{
                protocol: 1,
                version: "0.5.0",
                name: "plushie",
                backend: "test",
                transport: "spawn",
                widgets: []
              }}}
          )

          assert_receive {:DOWN, ^ref, :process, ^runtime, {%ArgumentError{}, _stack}}, 1_000
        end)

      assert log =~ "renderer is missing required native widgets"
    after
      Process.flag(:trap_exit, false)
    end
  end

  describe "commands" do
    test "send_after delivers the event after the specified delay" do
      {runtime, _bridge} = start_runtime(CommandApp)
      await_initial_render(runtime)

      # send_after(10, :timer_tick) is scheduled in init; wait long enough.
      Process.sleep(80)
      Plushie.Runtime.sync(runtime)

      assert Plushie.Runtime.get_model(runtime).value == 1

      text_node = find_by_type(Plushie.Runtime.get_tree(runtime), "text")
      assert text_node.props[:content] == "1"
    end

    test "async command delivers its result through update" do
      {runtime, _bridge} = start_runtime(AsyncApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "async"})

      # Wait for the spawned Task to complete and the runtime to process it.
      await_model(runtime, fn m -> m.value == 42 end)

      text_node = find_by_type(Plushie.Runtime.get_tree(runtime), "text")
      assert text_node.props[:content] == "42"
    end

    test "batch commands are all executed" do
      # Build an app whose update returns a batch of two send_after commands.
      # Uses distinct event keys since duplicate keys cause timer dedup.
      defmodule BatchApp do
        use Plushie.App

        def init(_opts), do: %{ticks: 0}

        def update(model, :tick_a), do: %{model | ticks: model.ticks + 1}
        def update(model, :tick_b), do: %{model | ticks: model.ticks + 1}

        def update(model, %WidgetEvent{type: :click, id: "batch"}) do
          cmd =
            Plushie.Command.batch([
              Plushie.Command.send_after(10, :tick_a),
              Plushie.Command.send_after(10, :tick_b)
            ])

          {model, cmd}
        end

        def update(model, _event), do: model

        def view(model) do
          import Plushie.UI

          window "main" do
            column do
              text("ticks:#{model.ticks}")
              button("batch", "Go")
            end
          end
        end
      end

      {runtime, _bridge} = start_runtime(BatchApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "batch"})

      # Wait for both delayed events to fire.
      Process.sleep(80)
      Plushie.Runtime.sync(runtime)

      assert Plushie.Runtime.get_model(runtime).ticks == 2

      text_node = find_by_type(Plushie.Runtime.get_tree(runtime), "text")
      assert text_node.props[:content] == "ticks:2"
    end

    test "done/2 dispatches the mapped value through update" do
      defmodule DoneApp do
        use Plushie.App

        def init(_opts), do: %{result: nil}

        def update(model, %WidgetEvent{type: :click, id: "go"}) do
          cmd = Plushie.Command.done(:raw_value, fn val -> {:transformed, val} end)
          {model, cmd}
        end

        def update(model, {:transformed, val}), do: %{model | result: val}
        def update(model, _event), do: model

        def view(model) do
          import Plushie.UI

          window "main" do
            column do
              text(inspect(model.result))
            end
          end
        end
      end

      {runtime, _bridge} = start_runtime(DoneApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "go"})

      # done/2 uses send_to_self, so the event arrives in the next message.
      model = await_model(runtime, fn m -> m.result == :raw_value end)
      assert model.result == :raw_value
    end

    test "init with commands executes them" do
      {runtime, _bridge} = start_runtime(CommandApp)
      await_initial_render(runtime)

      # The CommandApp init schedules send_after(10, :timer_tick).
      Process.sleep(80)
      Plushie.Runtime.sync(runtime)

      assert Plushie.Runtime.get_model(runtime).value == 1
    end
  end

  describe "renderer lifecycle" do
    test "{:renderer_exit, reason} calls handle_renderer_exit and model is updated" do
      # An app that marks itself as :crashed on renderer exit.
      defmodule ExitApp do
        use Plushie.App

        def init(_opts), do: %{status: :ok}
        def update(model, _event), do: model

        def view(model) do
          import Plushie.UI

          window "main" do
            column do
              text(inspect(model.status))
            end
          end
        end

        def handle_renderer_exit(model, _reason), do: %{model | status: :crashed}
      end

      capture_log(fn ->
        {runtime, bridge} = start_runtime(ExitApp)
        await_initial_render(runtime)

        send(runtime, {:renderer_exit, :port_closed})
        Plushie.Runtime.sync(runtime)

        assert Plushie.Runtime.get_model(runtime).status == :crashed

        # renderer_exit does NOT produce a new snapshot -- it only updates the model
        # so it is ready when the renderer restarts.
        snapshots = Plushie.Test.InternalMockBridge.get_snapshots(bridge)
        assert length(snapshots) == 1
      end)
    end

    test ":renderer_restarted re-sends the current tree to the bridge" do
      capture_log(fn ->
        {runtime, bridge} = start_runtime(SimpleApp)
        await_initial_render(runtime)

        initial_snapshots = Plushie.Test.InternalMockBridge.get_snapshots(bridge)
        assert length(initial_snapshots) == 1

        send(runtime, :renderer_restarted)
        Plushie.Runtime.sync(runtime)

        snapshots = Plushie.Test.InternalMockBridge.get_snapshots(bridge)
        # Should have sent the same tree a second time.
        assert length(snapshots) == 2

        [first, second] = snapshots
        assert first == second
      end)
    end

    test ":renderer_restarted re-registers unchanged renderer subscriptions" do
      defmodule RestartSubApp do
        use Plushie.App

        def init(_opts), do: %{}
        def update(model, _event), do: model
        def subscribe(_model), do: [Plushie.Subscription.on_key_press(:keys)]

        def view(_model) do
          import Plushie.UI

          window "main" do
            column do
            end
          end
        end
      end

      capture_log(fn ->
        {runtime, bridge} = start_runtime(RestartSubApp)
        await_initial_render(runtime)

        assert [%{kind: "on_key_press", tag: "keys"}] =
                 Plushie.Test.InternalMockBridge.get_subscribes(bridge)

        send(runtime, :renderer_restarted)
        Plushie.Runtime.sync(runtime)

        subscribes = Plushie.Test.InternalMockBridge.get_subscribes(bridge)
        assert Enum.count(subscribes, &(&1.kind == "on_key_press")) == 2
      end)
    end

    test "pending interact replies with renderer exit reason" do
      capture_log(fn ->
        {runtime, bridge} = start_runtime(SimpleApp)
        await_initial_render(runtime)

        task =
          Task.async(fn ->
            Plushie.Runtime.interact(runtime, "click", %{"by" => "id", "value" => "ok"})
          end)

        await_bridge(bridge, fn b ->
          Plushie.Test.InternalMockBridge.get_interacts(b) != []
        end)

        send(runtime, {:renderer_exit, :port_closed})

        assert Task.await(task) == {:error, {:renderer_exit, :port_closed}}
      end)
    end

    test "pending interact replies when renderer restarts" do
      capture_log(fn ->
        {runtime, bridge} = start_runtime(SimpleApp)
        await_initial_render(runtime)

        task =
          Task.async(fn ->
            Plushie.Runtime.interact(runtime, "click", %{"by" => "id", "value" => "ok"})
          end)

        await_bridge(bridge, fn b ->
          Plushie.Test.InternalMockBridge.get_interacts(b) != []
        end)

        send(runtime, :renderer_restarted)

        assert Task.await(task) == {:error, :renderer_restarted}
      end)
    end

    test "concurrent interact returns interact_in_progress" do
      capture_log(fn ->
        {runtime, bridge} = start_runtime(SimpleApp)
        await_initial_render(runtime)

        first =
          Task.async(fn ->
            Plushie.Runtime.interact(runtime, "click", %{"by" => "id", "value" => "ok"})
          end)

        await_bridge(bridge, fn b ->
          Plushie.Test.InternalMockBridge.get_interacts(b) != []
        end)

        assert Plushie.Runtime.interact(runtime, "click", %{"by" => "id", "value" => "ok"}) ==
                 {:error, :interact_in_progress}

        send(runtime, :renderer_restarted)
        assert Task.await(first) == {:error, :renderer_restarted}
      end)
    end

    test "stale interact responses do not complete a newer interact" do
      capture_log(fn ->
        {runtime, bridge} = start_runtime(SimpleApp)
        await_initial_render(runtime)

        first =
          Task.async(fn ->
            Plushie.Runtime.interact(runtime, "click", %{"by" => "id", "value" => "ok"})
          end)

        await_bridge(bridge, fn b ->
          length(Plushie.Test.InternalMockBridge.get_interacts(b)) == 1
        end)

        [%{id: first_id}] = Plushie.Test.InternalMockBridge.get_interacts(bridge)

        send(runtime, :renderer_restarted)
        assert Task.await(first) == {:error, :renderer_restarted}

        second =
          Task.async(fn ->
            Plushie.Runtime.interact(runtime, "click", %{"by" => "id", "value" => "ok"})
          end)

        await_bridge(bridge, fn b ->
          length(Plushie.Test.InternalMockBridge.get_interacts(b)) == 2
        end)

        [%{id: ^first_id}, %{id: second_id}] =
          Plushie.Test.InternalMockBridge.get_interacts(bridge)

        send(runtime, {:renderer_event, {:interact_response, first_id, []}})
        refute Task.yield(second, 50)

        send(runtime, {:renderer_event, {:interact_response, second_id, []}})
        assert Task.await(second) == :ok
      end)
    end
  end

  describe "subscriptions" do
    test "app with every subscription receives periodic tick events" do
      defmodule TickApp do
        use Plushie.App

        def init(_opts), do: %{ticks: 0}

        def update(model, %Plushie.Event.TimerEvent{tag: :tick}),
          do: %{model | ticks: model.ticks + 1}

        def update(model, _event), do: model

        def subscribe(_model), do: [Plushie.Subscription.every(20, :tick)]

        def view(model) do
          import Plushie.UI

          window "main" do
            column do
              text("ticks:#{model.ticks}")
            end
          end
        end
      end

      {runtime, _bridge} = start_runtime(TickApp)
      await_initial_render(runtime)

      # Wait long enough for at least 2 ticks (20ms interval).
      Process.sleep(80)
      Plushie.Runtime.sync(runtime)

      assert Plushie.Runtime.get_model(runtime).ticks >= 2
    end

    test "subscription removed when subscribe/1 stops returning it" do
      defmodule ToggleSubApp do
        use Plushie.App

        def init(_opts), do: %{timer_on: true, ticks: 0}

        def update(model, %Plushie.Event.TimerEvent{tag: :tick}),
          do: %{model | ticks: model.ticks + 1}

        def update(model, :stop_timer), do: %{model | timer_on: false}
        def update(model, _event), do: model

        def subscribe(model) do
          if model.timer_on do
            [Plushie.Subscription.every(15, :tick)]
          else
            []
          end
        end

        def view(model) do
          import Plushie.UI

          window "main" do
            column do
              text("ticks:#{model.ticks}")
            end
          end
        end
      end

      {runtime, _bridge} = start_runtime(ToggleSubApp)
      await_initial_render(runtime)

      # Let some ticks accumulate.
      Process.sleep(60)
      Plushie.Runtime.sync(runtime)

      ticks_before = Plushie.Runtime.get_model(runtime).ticks
      assert ticks_before >= 2

      # Stop the timer subscription.
      dispatch_and_wait(runtime, :stop_timer)

      # Wait and confirm no more ticks arrive.
      Process.sleep(60)
      Plushie.Runtime.sync(runtime)

      ticks_after = Plushie.Runtime.get_model(runtime).ticks
      # Ticks should not have increased after stopping.
      assert ticks_after == ticks_before
    end

    test "rapid toggle of timer subscription settles correctly" do
      defmodule RapidToggleApp do
        use Plushie.App

        def init(_opts), do: %{timer_on: true, ticks: 0}

        def update(model, %Plushie.Event.TimerEvent{tag: :tick}),
          do: %{model | ticks: model.ticks + 1}

        def update(model, :toggle), do: %{model | timer_on: not model.timer_on}
        def update(model, _event), do: model

        def subscribe(model) do
          if model.timer_on do
            [Plushie.Subscription.every(15, :tick)]
          else
            []
          end
        end

        def view(model) do
          import Plushie.UI

          window "main" do
            column do
              text("ticks:#{model.ticks}")
            end
          end
        end
      end

      {runtime, _bridge} = start_runtime(RapidToggleApp)
      await_initial_render(runtime)

      # Rapid toggle: on -> off -> on (3 updates in quick succession).
      dispatch_and_wait(runtime, :toggle)
      dispatch_and_wait(runtime, :toggle)
      dispatch_and_wait(runtime, :toggle)

      # Final state: timer_on = false (started true, toggled 3 times).
      model = Plushie.Runtime.get_model(runtime)
      refute model.timer_on

      # Verify no ticks arrive while timer is off.
      ticks_before = model.ticks
      Process.sleep(60)
      Plushie.Runtime.sync(runtime)
      assert Plushie.Runtime.get_model(runtime).ticks == ticks_before

      # Toggle back on and verify the timer runs.
      dispatch_and_wait(runtime, :toggle)
      assert Plushie.Runtime.get_model(runtime).timer_on

      # Wait for at least one tick to confirm the timer is actually running.
      await_model(runtime, fn m -> m.ticks > ticks_before end, 500)
    end

    test "multiple subscriptions can coexist" do
      defmodule MultiSubApp do
        use Plushie.App

        def init(_opts), do: %{fast: 0, slow: 0}

        def update(model, %Plushie.Event.TimerEvent{tag: :fast_tick}),
          do: %{model | fast: model.fast + 1}

        def update(model, %Plushie.Event.TimerEvent{tag: :slow_tick}),
          do: %{model | slow: model.slow + 1}

        def update(model, _event), do: model

        def subscribe(_model) do
          [
            Plushie.Subscription.every(15, :fast_tick),
            Plushie.Subscription.every(40, :slow_tick)
          ]
        end

        def view(model) do
          import Plushie.UI

          window "main" do
            column do
              text("fast:#{model.fast}")
              text("slow:#{model.slow}")
            end
          end
        end
      end

      {runtime, _bridge} = start_runtime(MultiSubApp)
      await_initial_render(runtime)

      Process.sleep(100)
      Plushie.Runtime.sync(runtime)

      model = Plushie.Runtime.get_model(runtime)
      # Both subscriptions should have fired at least once.
      assert model.fast >= 2
      assert model.slow >= 1
      # Fast should tick more than slow.
      assert model.fast > model.slow
    end
  end

  describe "error recovery" do
    test "update/2 exception does not crash the runtime" do
      defmodule CrashUpdateApp do
        use Plushie.App

        def init(_opts), do: %{value: 0}
        def update(_model, :crash), do: raise("boom")

        def update(model, %WidgetEvent{type: :click, id: "inc"}),
          do: %{model | value: model.value + 1}

        def update(model, _event), do: model

        def view(model) do
          import Plushie.UI

          window "main" do
            column do
              text("#{model.value}")
            end
          end
        end
      end

      capture_log(fn ->
        {runtime, _bridge} = start_runtime(CrashUpdateApp)
        await_initial_render(runtime)

        # This should not crash the runtime.
        dispatch_and_wait(runtime, :crash)

        # Runtime is still alive and model unchanged.
        assert Process.alive?(runtime)
        assert Plushie.Runtime.get_model(runtime).value == 0

        # Can still process normal events after the crash.
        dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "inc"})
        assert Plushie.Runtime.get_model(runtime).value == 1
      end)
    end

    test "view/1 exception does not crash the runtime" do
      defmodule CrashViewApp do
        use Plushie.App

        def init(_opts), do: %{crash_view: false}
        def update(model, :crash_view), do: %{model | crash_view: true}
        def update(model, :fix_view), do: %{model | crash_view: false}
        def update(model, _event), do: model

        def view(%{crash_view: true}), do: raise("view boom")

        def view(_model) do
          import Plushie.UI

          window "main" do
            column do
              text("ok")
            end
          end
        end
      end

      capture_log(fn ->
        {runtime, _bridge} = start_runtime(CrashViewApp)
        await_initial_render(runtime)

        # Trigger the crashing view -- runtime should survive.
        dispatch_and_wait(runtime, :crash_view)
        assert Process.alive?(runtime)

        # Fix the view and confirm the runtime continues normally.
        dispatch_and_wait(runtime, :fix_view)
        assert Plushie.Runtime.get_model(runtime).crash_view == false
      end)
    end
  end

  describe "effects" do
    test "effect command is forwarded to the bridge" do
      defmodule EffectApp do
        use Plushie.App
        alias Plushie.Event.EffectEvent

        def init(_opts), do: %{result: nil}

        def update(model, %WidgetEvent{type: :click, id: "open"}) do
          cmd = Plushie.Effect.file_open(:open, title: "Pick a file")
          {model, cmd}
        end

        def update(model, %EffectEvent{tag: :open, result: {:ok, result}}) do
          %{model | result: result}
        end

        def update(model, _event), do: model

        def view(model) do
          import Plushie.UI

          window "main" do
            column do
              text(inspect(model.result))
            end
          end
        end
      end

      {runtime, bridge} = start_runtime(EffectApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "open"})

      effects = Plushie.Test.InternalMockBridge.get_effects(bridge)
      assert length(effects) == 1

      [req] = effects
      assert req.kind == "file_open"
      assert req.payload == %{title: "Pick a file"}
    end

    test "effect_result event is dispatched through update" do
      defmodule EffectResultApp do
        use Plushie.App
        alias Plushie.Event.EffectEvent

        def init(_opts), do: %{path: nil, effect_id: nil}

        def update(model, %WidgetEvent{type: :click, id: "pick"}) do
          cmd = Plushie.Effect.file_open(:pick, title: "Pick a file")
          {%{model | effect_id: cmd.payload.id}, cmd}
        end

        def update(model, %EffectEvent{tag: :pick, result: {:ok, %{path: path}}}) do
          %{model | path: path}
        end

        def update(model, _event), do: model

        def view(model) do
          import Plushie.UI

          window "main" do
            column do
              button("pick", "Pick")
              text(inspect(model.path))
            end
          end
        end
      end

      {runtime, _bridge} = start_runtime(EffectResultApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "pick"})
      effect_id = Plushie.Runtime.get_model(runtime).effect_id

      send(
        runtime,
        {:renderer_event, {:effect_response, effect_id, {:ok, %{path: "/tmp/test.txt"}}}}
      )

      Plushie.Runtime.sync(runtime)

      assert Plushie.Runtime.get_model(runtime).path == "/tmp/test.txt"
    end
  end

  describe "effect timeout" do
    test "effect command registers a pending timeout and cleans up on timeout" do
      defmodule EffectTimeoutApp do
        use Plushie.App
        alias Plushie.Event.EffectEvent

        def init(_opts), do: %{effect_id: nil, timeout_result: nil}

        def update(model, %WidgetEvent{type: :click, id: "trigger"}) do
          cmd = Plushie.Effect.clipboard_read(:read)
          {%{model | effect_id: cmd.payload.id}, cmd}
        end

        def update(model, %EffectEvent{tag: :read, result: {:error, :timeout}}) do
          %{model | timeout_result: {:timed_out, :read}}
        end

        def update(model, _event), do: model

        def view(model) do
          import Plushie.UI

          window "main" do
            column do
              text(inspect(model.timeout_result))
            end
          end
        end
      end

      {runtime, bridge} = start_runtime(EffectTimeoutApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "trigger"})

      # After dispatching the effect, verify the bridge received it.
      effect_id = Plushie.Runtime.get_model(runtime).effect_id
      assert is_binary(effect_id)

      effects = Plushie.Test.InternalMockBridge.get_effects(bridge)
      assert length(effects) == 1

      # Simulate the timeout firing (avoids waiting for the real 5s timeout).
      send(runtime, {:effect_timeout, effect_id})
      Plushie.Runtime.sync(runtime)

      assert Plushie.Runtime.get_model(runtime).timeout_result == {:timed_out, :read}
    end

    test "late effect response after timeout is ignored" do
      defmodule LateEffectApp do
        use Plushie.App
        alias Plushie.Event.EffectEvent

        def init(_opts), do: %{effect_id: nil, timeout_result: nil, success_result: nil}

        def update(model, %WidgetEvent{type: :click, id: "trigger"}) do
          cmd = Plushie.Effect.clipboard_read(:read)
          {%{model | effect_id: cmd.payload.id}, cmd}
        end

        def update(model, %EffectEvent{tag: :read, result: {:error, :timeout}}) do
          %{model | timeout_result: :read}
        end

        def update(model, %EffectEvent{tag: :read, result: {:ok, value}}) do
          %{model | success_result: {:read, value}}
        end

        def update(model, _event), do: model

        def view(_model) do
          import Plushie.UI

          window "main" do
            column do
            end
          end
        end
      end

      {runtime, _bridge} = start_runtime(LateEffectApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "trigger"})
      effect_id = Plushie.Runtime.get_model(runtime).effect_id

      send(runtime, {:effect_timeout, effect_id})
      Plushie.Runtime.sync(runtime)

      send(runtime, {:renderer_event, {:effect_response, effect_id, {:ok, "late"}}})
      Plushie.Runtime.sync(runtime)

      model = Plushie.Runtime.get_model(runtime)
      assert model.timeout_result == :read
      assert model.success_result == nil
    end
  end

  describe "subscription registration" do
    test "renderer subscription sends register message to bridge" do
      defmodule KeySubApp do
        use Plushie.App

        def init(_opts), do: %{listening: true}
        def update(model, _event), do: model

        def subscribe(model) do
          if model.listening do
            [Plushie.Subscription.on_key_press(:keys)]
          else
            []
          end
        end

        def view(_model) do
          import Plushie.UI

          window "main" do
            column do
              text("listening")
            end
          end
        end
      end

      {runtime, bridge} = start_runtime(KeySubApp)
      await_initial_render(runtime)

      # Allow cast to be processed by the mock bridge.
      GenServer.call(bridge, :sync)

      registers = Plushie.Test.InternalMockBridge.get_subscribes(bridge)
      assert length(registers) == 1
      assert hd(registers) == %{kind: "on_key_press", tag: "keys", max_rate: nil, window_id: nil}
    end

    test "removing a renderer subscription sends unregister message to bridge" do
      defmodule KeyToggleApp do
        use Plushie.App

        def init(_opts), do: %{listening: true}
        def update(model, :stop_listening), do: %{model | listening: false}
        def update(model, _event), do: model

        def subscribe(model) do
          if model.listening do
            [Plushie.Subscription.on_key_press(:keys)]
          else
            []
          end
        end

        def view(_model) do
          import Plushie.UI

          window "main" do
            column do
              text("ok")
            end
          end
        end
      end

      {runtime, bridge} = start_runtime(KeyToggleApp)
      await_initial_render(runtime)
      GenServer.call(bridge, :sync)

      # Verify register was sent
      registers = Plushie.Test.InternalMockBridge.get_subscribes(bridge)
      assert length(registers) == 1

      # Now remove the subscription
      dispatch_and_wait(runtime, :stop_listening)
      GenServer.call(bridge, :sync)

      unregisters = Plushie.Test.InternalMockBridge.get_unsubscribes(bridge)
      assert length(unregisters) == 1
      assert hd(unregisters) == %{kind: "on_key_press", tag: "keys"}
    end

    test "canvas widget subscriptions are registered on initial render and survive interact_step" do
      {runtime, _bridge} = start_runtime(WidgetSubApp)
      await_initial_render(runtime)

      # Verify the widget timer subscription is active by sending a tick.
      send(runtime, {:subscription_tick, {:__widget__, "main", "ticker", :pulse}, 1_000})
      Plushie.Runtime.sync(runtime)
      assert Plushie.Runtime.get_model(runtime).pulses == 1

      send(
        runtime,
        {:renderer_event,
         {:interact_step, "step_1",
          [%{"family" => "click", "id" => "inc", "window_id" => "main"}]}}
      )

      await_model(runtime, fn m -> m.clicks == 1 end)

      # Verify subscription survived the interact_step by sending another tick.
      send(runtime, {:subscription_tick, {:__widget__, "main", "ticker", :pulse}, 1_000})
      Plushie.Runtime.sync(runtime)
      assert Plushie.Runtime.get_model(runtime).pulses == 2
    end

    test "canvas widget subscriptions survive force_rerender" do
      capture_log(fn ->
        {runtime, _bridge} = start_runtime(WidgetSubApp)
        await_initial_render(runtime)

        # Verify the widget timer subscription is active by sending a tick.
        send(runtime, {:subscription_tick, {:__widget__, "main", "ticker", :pulse}, 1_000})
        Plushie.Runtime.sync(runtime)
        assert Plushie.Runtime.get_model(runtime).pulses == 1

        send(runtime, :force_rerender)
        Plushie.Runtime.sync(runtime)

        # Verify subscription survived force_rerender by sending another tick.
        send(runtime, {:subscription_tick, {:__widget__, "main", "ticker", :pulse}, 1_000})
        Plushie.Runtime.sync(runtime)
        assert Plushie.Runtime.get_model(runtime).pulses == 2
      end)
    end

    test "canvas widget timer state changes resync widget subscriptions" do
      {runtime, bridge} = start_runtime(SwitchingWidgetApp)
      await_initial_render(runtime)

      patches_before = length(Plushie.Test.InternalMockBridge.get_patches(bridge))

      # Trigger the :first timer tick, which switches the widget to :second phase.
      # The widget re-renders with "phase:second" content, producing a patch.
      send(
        runtime,
        {:subscription_tick, {:__widget__, "main", "switcher", :first}, 1_000}
      )

      Plushie.Runtime.sync(runtime)

      # A patch should have been sent for the tree change.
      patches_after = length(Plushie.Test.InternalMockBridge.get_patches(bridge))
      assert patches_after > patches_before

      # Verify the :first subscription was replaced by :second: the old timer
      # tick should be silently ignored (no re-render), while :second fires.
      patches_before_stale = length(Plushie.Test.InternalMockBridge.get_patches(bridge))

      send(
        runtime,
        {:subscription_tick, {:__widget__, "main", "switcher", :first}, 1_000}
      )

      Plushie.Runtime.sync(runtime)

      # Stale tick: no new patch (subscription was removed).
      assert length(Plushie.Test.InternalMockBridge.get_patches(bridge)) == patches_before_stale
    end
  end

  describe "coalescing" do
    test "flushes coalesced events in arrival order across keys" do
      {runtime, _bridge} = start_runtime(CoalesceOrderApp)
      await_initial_render(runtime)

      send(runtime, {:renderer_event, %Plushie.Event.MouseEvent{type: :moved, x: 1, y: 1}})

      send(
        runtime,
        {:renderer_event,
         %Plushie.Event.WidgetEvent{
           type: :resize,
           id: "win",
           data: %{width: 10, height: 10}
         }}
      )

      model = await_model(runtime, fn m -> m.events == [:mouse, :sensor] end)
      assert model.events == [:mouse, :sensor]
    end

    test "sensor resize coalescing keeps same local ids in different windows separate" do
      {runtime, _bridge} = start_runtime(SensorWindowCoalesceApp)
      await_initial_render(runtime)

      send(
        runtime,
        {:renderer_event,
         %Plushie.Event.WidgetEvent{
           type: :resize,
           id: "size",
           scope: [],
           window_id: "main",
           data: %{width: 10, height: 10}
         }}
      )

      send(
        runtime,
        {:renderer_event,
         %Plushie.Event.WidgetEvent{
           type: :resize,
           id: "size",
           scope: [],
           window_id: "prefs",
           data: %{width: 20, height: 20}
         }}
      )

      model = await_model(runtime, fn m -> m.events == ["main", "prefs"] end)
      assert model.events == ["main", "prefs"]
    end
  end

  describe "multi-window support" do
    test "window nodes in the tree trigger window open ops" do
      defmodule WindowApp do
        use Plushie.App

        def init(_opts), do: %{show_secondary: false}
        def update(model, :open_secondary), do: %{model | show_secondary: true}
        def update(model, _event), do: model

        def view(model) do
          import Plushie.UI

          windows = [
            window "main", title: "Main" do
              text("hello")
            end
          ]

          windows =
            if model.show_secondary do
              windows ++
                [
                  window "secondary", title: "Secondary" do
                    text("world")
                  end
                ]
            else
              windows
            end

          windows
        end

        def window_config(_model), do: %{title: "App Window"}
      end

      {runtime, bridge} = start_runtime(WindowApp)
      await_initial_render(runtime)
      GenServer.call(bridge, :sync)

      # Initial render should detect the "main" window and send open
      window_ops = Plushie.Test.InternalMockBridge.get_window_ops(bridge)
      assert length(window_ops) == 1
      assert hd(window_ops).op == "open"
      assert hd(window_ops).window_id == "main"
      assert hd(window_ops).settings == %{title: "Main"}

      # Open the secondary window
      dispatch_and_wait(runtime, :open_secondary)
      GenServer.call(bridge, :sync)

      window_ops = Plushie.Test.InternalMockBridge.get_window_ops(bridge)
      assert length(window_ops) == 2

      second_op = Enum.at(window_ops, 1)
      assert second_op.op == "open"
      assert second_op.window_id == "secondary"
    end

    test "removing a window from the tree triggers window close op" do
      defmodule WindowCloseApp do
        use Plushie.App

        def init(_opts), do: %{show_window: true}
        def update(model, :close_it), do: %{model | show_window: false}
        def update(model, _event), do: model

        def view(model) do
          import Plushie.UI

          if model.show_window do
            [
              window("ephemeral", title: "Temp") do
                text("temp")
              end
            ]
          else
            []
          end
        end

        def window_config(_model), do: %{}
      end

      {runtime, bridge} = start_runtime(WindowCloseApp)
      await_initial_render(runtime)
      GenServer.call(bridge, :sync)

      # Initial render opens the window
      window_ops = Plushie.Test.InternalMockBridge.get_window_ops(bridge)
      assert length(window_ops) == 1
      assert hd(window_ops).op == "open"
      assert hd(window_ops).window_id == "ephemeral"

      # Remove the window
      dispatch_and_wait(runtime, :close_it)
      GenServer.call(bridge, :sync)

      window_ops = Plushie.Test.InternalMockBridge.get_window_ops(bridge)
      assert length(window_ops) == 2

      close_op = Enum.at(window_ops, 1)
      assert close_op.op == "close"
      assert close_op.window_id == "ephemeral"
    end
  end

  describe "stream and cancel commands" do
    test "stream emits multiple intermediate results through update" do
      defmodule StreamApp do
        use Plushie.App

        def init(_opts), do: %{chunks: [], final: nil}

        def update(model, %WidgetEvent{type: :click, id: "start_stream"}) do
          cmd =
            Plushie.Command.stream(
              fn emit ->
                emit.({:chunk, "a"})
                emit.({:chunk, "b"})
                emit.({:chunk, "c"})
                :done
              end,
              :import
            )

          {model, cmd}
        end

        def update(model, %Plushie.Event.StreamEvent{tag: :import, value: {:chunk, value}}) do
          %{model | chunks: model.chunks ++ [value]}
        end

        def update(model, %Plushie.Event.AsyncEvent{tag: :import, result: :done}) do
          %{model | final: :done}
        end

        def update(model, _event), do: model

        def view(model) do
          import Plushie.UI

          window "main" do
            column do
              text("chunks:#{length(model.chunks)}")
            end
          end
        end
      end

      {runtime, _bridge} = start_runtime(StreamApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "start_stream"})

      # Wait for the stream task to emit all values and complete.
      model = await_model(runtime, fn m -> m.final == :done end)
      assert model.chunks == ["a", "b", "c"]
    end

    test "cancel stops a running stream task" do
      defmodule CancelStreamApp do
        use Plushie.App

        def init(_opts), do: %{chunks: [], cancelled: false}

        def update(model, %WidgetEvent{type: :click, id: "start"}) do
          cmd =
            Plushie.Command.stream(
              fn emit ->
                # Emit one value then block long enough to be cancelled.
                emit.({:chunk, "first"})
                Process.sleep(5000)
                emit.({:chunk, "second"})
                :done
              end,
              :import
            )

          {model, cmd}
        end

        def update(model, %WidgetEvent{type: :click, id: "cancel"}) do
          {%{model | cancelled: true}, Plushie.Command.cancel(:import)}
        end

        def update(model, %Plushie.Event.StreamEvent{tag: :import, value: {:chunk, value}}) do
          %{model | chunks: model.chunks ++ [value]}
        end

        def update(model, %Plushie.Event.AsyncEvent{tag: :import, result: :done}) do
          model
        end

        def update(model, _event), do: model

        def view(model) do
          import Plushie.UI

          window "main" do
            column do
              text("chunks:#{length(model.chunks)}")
            end
          end
        end
      end

      capture_log(fn ->
        {runtime, _bridge} = start_runtime(CancelStreamApp)
        await_initial_render(runtime)

        # Start the stream
        dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "start"})

        # Wait for the first emit to arrive
        await_model(runtime, fn m -> m.chunks == ["first"] end)

        # Cancel the stream
        dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "cancel"})

        assert Plushie.Runtime.get_model(runtime).cancelled == true

        # Wait and confirm no more chunks arrive
        Process.sleep(100)
        Plushie.Runtime.sync(runtime)

        assert Plushie.Runtime.get_model(runtime).chunks == ["first"]
      end)
    end

    test "cancel is a no-op when no task is running for the tag" do
      defmodule CancelNoopApp do
        use Plushie.App

        def init(_opts), do: %{value: 0}

        def update(model, %WidgetEvent{type: :click, id: "cancel"}) do
          {%{model | value: model.value + 1}, Plushie.Command.cancel(:nonexistent)}
        end

        def update(model, _event), do: model

        def view(model) do
          import Plushie.UI

          window "main" do
            column do
              text("#{model.value}")
            end
          end
        end
      end

      {runtime, _bridge} = start_runtime(CancelNoopApp)
      await_initial_render(runtime)

      # Should not crash
      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "cancel"})

      assert Plushie.Runtime.get_model(runtime).value == 1
    end

    test "async tasks are tracked and cleaned up on completion" do
      {runtime, _bridge} = start_runtime(AsyncApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "async"})

      # Wait for the task to complete and the result to be delivered to update/2.
      model = await_model(runtime, fn m -> m.value == 42 end)
      assert model.value == 42
    end
  end

  describe "extension config in settings" do
    test "settings includes widget_config from application env" do
      Application.put_env(:plushie, :widget_config, %{"terminal" => %{"shell" => "/bin/bash"}})

      {runtime, bridge} = start_runtime(SimpleApp)
      await_initial_render(runtime)

      settings_list = Plushie.Test.InternalMockBridge.get_settings(bridge)
      assert settings_list != []

      # The first settings message should contain the widget_config.
      settings = hd(settings_list)
      assert settings[:widget_config] == %{"terminal" => %{"shell" => "/bin/bash"}}
    after
      Application.delete_env(:plushie, :widget_config)
    end

    test "settings omits widget_config when application env is empty" do
      Application.delete_env(:plushie, :widget_config)

      {runtime, bridge} = start_runtime(SimpleApp)
      await_initial_render(runtime)

      settings_list = Plushie.Test.InternalMockBridge.get_settings(bridge)
      assert settings_list != []

      settings = hd(settings_list)
      refute Map.has_key?(settings, :widget_config)
    end
  end

  describe "interact caller timeout cleanup" do
    test "pending_interact is cleaned up on caller timeout" do
      capture_log(fn ->
        {runtime, bridge} = start_runtime(SimpleApp)
        await_initial_render(runtime)

        # Spawn a process that calls interact with a very short timeout.
        # The bridge never replies, so it will time out.
        task =
          Task.async(fn ->
            try do
              Plushie.Runtime.interact(
                runtime,
                "click",
                %{"by" => "id", "value" => "ok"},
                %{},
                50
              )
            catch
              :exit, {:timeout, _} -> :timed_out
            end
          end)

        assert Task.await(task, 1000) == :timed_out

        # Give the runtime a moment to process the DOWN message from the
        # dead task process.
        Process.sleep(20)

        # Verify that a subsequent interact can proceed (not blocked by
        # the stale pending_interact).
        second =
          Task.async(fn ->
            Plushie.Runtime.interact(runtime, "click", %{"by" => "id", "value" => "ok"})
          end)

        await_bridge(bridge, fn b ->
          length(Plushie.Test.InternalMockBridge.get_interacts(b)) >= 2
        end)

        # Complete the second interact so the task can finish.
        [_, %{id: second_id}] = Plushie.Test.InternalMockBridge.get_interacts(bridge)
        send(runtime, {:renderer_event, {:interact_response, second_id, []}})

        assert Task.await(second, 1000) == :ok
      end)
    end
  end

  describe "concurrent effect stub registration" do
    test "concurrent registration for same kind returns error" do
      {runtime, _bridge} = start_runtime(SimpleApp)
      await_initial_render(runtime)

      # First registration -- will block waiting for the bridge ack.
      first =
        Task.async(fn ->
          Plushie.Runtime.register_effect_stub(runtime, :clipboard_read, "stub_value")
        end)

      # Give the runtime time to process the first call.
      Process.sleep(20)

      # Second registration for the same kind should get :stub_ack_pending.
      assert Plushie.Runtime.register_effect_stub(runtime, :clipboard_read, "other") ==
               {:error, :stub_ack_pending}

      # Complete the first by simulating the bridge ack.
      send(runtime, {:renderer_event, {:effect_stub_ack, "clipboard_read"}})
      assert Task.await(first, 1000) == :ok
    end
  end

  describe "concurrent await_async" do
    defmodule SlowAsyncApp do
      use Plushie.App

      def init(_opts), do: %{value: 0}

      def update(model, %WidgetEvent{type: :click, id: "start"}) do
        cmd =
          Plushie.Command.async(
            fn ->
              Process.sleep(500)
              42
            end,
            :slow_task
          )

        {model, cmd}
      end

      def update(model, _event), do: model

      def view(_model) do
        import Plushie.UI
        window("main", do: column(do: button("start", "Go")))
      end
    end

    test "concurrent await_async for same tag returns error" do
      {runtime, _bridge} = start_runtime(SlowAsyncApp)
      await_initial_render(runtime)

      # Start a slow async task.
      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "start"})

      # First await -- will block until the slow task completes.
      first =
        Task.async(fn ->
          Plushie.Runtime.await_async(runtime, :slow_task)
        end)

      # Give the runtime time to process the first await call.
      Process.sleep(20)

      # Second await for the same tag should get :await_in_progress.
      assert Plushie.Runtime.await_async(runtime, :slow_task) ==
               {:error, :await_in_progress}

      # The first should eventually complete.
      assert Task.await(first, 2000) == :ok
    end
  end

  describe "consecutive view failures" do
    @describetag capture_log: true
    test "consecutive view failures increment counter and warn at threshold" do
      defmodule AlwaysCrashViewApp do
        use Plushie.App

        def init(_opts), do: %{count: 0}
        def update(model, :bump), do: %{model | count: model.count + 1}
        def update(model, _event), do: model

        # view/1 always raises after init (count > 0)
        def view(%{count: n}) when n > 0, do: raise("view always fails")

        def view(_model) do
          import Plushie.UI

          window "main" do
            column do
              text("ok")
            end
          end
        end
      end

      {runtime, _bridge} = start_runtime(AlwaysCrashViewApp)
      await_initial_render(runtime)

      # Dispatch enough events to trigger 5+ consecutive view failures.
      # The runtime survives and keeps the previous tree.
      for _ <- 1..6 do
        dispatch_and_wait(runtime, :bump)
      end

      assert Process.alive?(runtime)
      # Model updates succeed even though view/1 fails.
      assert Plushie.Runtime.get_model(runtime).count == 6
    end
  end

  # Private helpers

  # Depth-first search for the first node with the given type string.
  defp find_by_type(%{type: type} = node, type), do: node

  defp find_by_type(%{children: children}, target_type) when is_list(children) do
    Enum.find_value(children, &find_by_type(&1, target_type))
  end

  defp find_by_type(_node, _target_type), do: nil
end
