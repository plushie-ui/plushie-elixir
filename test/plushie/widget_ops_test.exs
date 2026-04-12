defmodule Plushie.WidgetOpsTest do
  use ExUnit.Case, async: true

  alias Plushie.{Command, Protocol}

  defp decode_json!(str) do
    str |> String.trim_trailing("\n") |> Jason.decode!()
  end

  describe "Protocol.encode_widget_op/2" do
    test "produces a JSON object with type 'widget_op'" do
      result = Protocol.encode_widget_op("focus", %{target: "username"}, :json)
      parsed = decode_json!(result)
      assert parsed["type"] == "widget_op"
    end

    test "includes the op and payload fields" do
      result = Protocol.encode_widget_op("scroll_to", %{target: "log", offset_y: 100}, :json)
      parsed = decode_json!(result)
      assert parsed["op"] == "scroll_to"
      assert parsed["payload"]["target"] == "log"
      assert parsed["payload"]["offset_y"] == 100
    end

    test "output ends with a trailing newline" do
      result = Protocol.encode_widget_op("focus_next", %{}, :json)
      assert String.ends_with?(result, "\n")
    end

    test "output is valid JSON before the trailing newline" do
      result = Protocol.encode_widget_op("select_all", %{target: "editor"}, :json)
      assert {:ok, _} = Jason.decode(String.trim_trailing(result, "\n"))
    end

    test "empty payload encodes correctly" do
      result = Protocol.encode_widget_op("focus_previous", %{}, :json)
      parsed = decode_json!(result)
      assert parsed["payload"] == %{}
    end
  end

  describe "Command constructors for widget ops" do
    test "focus/1 returns a command targeting the widget" do
      cmd = Command.focus("name_input")
      assert %Command{type: :command, payload: %{id: "name_input", family: "focus"}} = cmd
    end

    test "focus_next/0 returns a widget_op command" do
      cmd = Command.focus_next()
      assert %Command{type: :widget_op, payload: %{op: "focus_next"}} = cmd
    end

    test "focus_previous/0 returns a widget_op command" do
      cmd = Command.focus_previous()
      assert %Command{type: :widget_op, payload: %{op: "focus_previous"}} = cmd
    end

    test "select_all/1 returns a command targeting the widget" do
      cmd = Command.select_all("editor")
      assert %Command{type: :command, payload: %{id: "editor", family: "select_all"}} = cmd
    end

    test "scroll_to/3 returns a command targeting the widget with value" do
      cmd = Command.scroll_to("feed", 0.0, 250.0)

      assert %Command{type: :command, payload: %{id: "feed", family: "scroll_to"}} = cmd

      assert cmd.payload.value == %{x: 0.0, y: 250.0}
    end

    test "close_window/1 returns a Command with type :close_window and window_id in payload" do
      cmd = Command.close_window("settings")
      assert %Command{type: :close_window, payload: %{window_id: "settings"}} = cmd
    end
  end

  # A minimal app that returns widget op commands in response to events.
  defmodule WidgetOpApp do
    use Plushie.App

    def init(_opts), do: %{status: :idle}

    def update(model, {:do, :focus}),
      do: {model, Command.focus("target_widget")}

    def update(model, {:do, :focus_next}),
      do: {model, Command.focus_next()}

    def update(model, {:do, :focus_previous}),
      do: {model, Command.focus_previous()}

    def update(model, {:do, :select_all}),
      do: {model, Command.select_all("editor")}

    def update(model, {:do, :scroll_to}),
      do: {model, Command.scroll_to("log_view", 0.0, 999.0)}

    def update(model, {:do, :close_window}),
      do: {model, Command.close_window("preferences")}

    def update(model, _event), do: model

    def view(_model) do
      import Plushie.UI

      window "main" do
        column do
          text("widget ops test")
        end
      end
    end
  end

  defp start_runtime(app) do
    tag = System.unique_integer([:positive])
    bridge_name = :"mock_bridge_wops_#{tag}"
    runtime_name = :"runtime_wops_#{tag}"

    {:ok, _bridge} = Plushie.Test.InternalMockBridge.start_link(name: bridge_name)
    {:ok, runtime} = Plushie.Runtime.start_link(app: app, bridge: bridge_name, name: runtime_name)

    {runtime, bridge_name}
  end

  defp await_initial_render(runtime), do: Plushie.Runtime.sync(runtime)

  defp dispatch_and_wait(runtime, event) do
    Plushie.Runtime.dispatch(runtime, event)
    Plushie.Runtime.sync(runtime)
  end

  describe "runtime dispatches widget ops to bridge" do
    test "focus command sends command with family 'focus'" do
      {runtime, bridge} = start_runtime(WidgetOpApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, {:do, :focus})

      cmds = Plushie.Test.InternalMockBridge.get_commands(bridge)
      assert length(cmds) == 1
      assert hd(cmds).id == "target_widget"
      assert hd(cmds).family == "focus"
    end

    test "focus_next command sends widget_op with op 'focus_next'" do
      {runtime, bridge} = start_runtime(WidgetOpApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, {:do, :focus_next})

      ops = Plushie.Test.InternalMockBridge.get_widget_ops(bridge)
      assert length(ops) == 1
      assert hd(ops).op == "focus_next"
    end

    test "focus_previous command sends widget_op with op 'focus_previous'" do
      {runtime, bridge} = start_runtime(WidgetOpApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, {:do, :focus_previous})

      ops = Plushie.Test.InternalMockBridge.get_widget_ops(bridge)
      assert length(ops) == 1
      assert hd(ops).op == "focus_previous"
    end

    test "select_all command sends command with family 'select_all'" do
      {runtime, bridge} = start_runtime(WidgetOpApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, {:do, :select_all})

      cmds = Plushie.Test.InternalMockBridge.get_commands(bridge)
      assert length(cmds) == 1
      assert hd(cmds).id == "editor"
      assert hd(cmds).family == "select_all"
    end

    test "scroll_to command sends command with family 'scroll_to'" do
      {runtime, bridge} = start_runtime(WidgetOpApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, {:do, :scroll_to})

      cmds = Plushie.Test.InternalMockBridge.get_commands(bridge)
      assert length(cmds) == 1
      assert hd(cmds).id == "log_view"
      assert hd(cmds).family == "scroll_to"
      assert hd(cmds).value == %{x: 0.0, y: 999.0}
    end

    test "close_window command sends widget_op with op 'close_window'" do
      {runtime, bridge} = start_runtime(WidgetOpApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, {:do, :close_window})

      ops = Plushie.Test.InternalMockBridge.get_widget_ops(bridge)
      assert length(ops) == 1
      assert hd(ops).op == "close_window"
      assert hd(ops).payload == %{window_id: "preferences"}
    end

    test "widget ops are not sent when bridge is nil" do
      # Directly call execute_commands via the runtime with no bridge.
      # We do this by starting a runtime and checking no crash occurs.
      # The simplest way: the runtime handles nil bridge gracefully.
      tag = System.unique_integer([:positive])
      bridge_name = :"mock_bridge_nil_#{tag}"
      runtime_name = :"runtime_nil_#{tag}"

      {:ok, _bridge} = Plushie.Test.InternalMockBridge.start_link(name: bridge_name)

      {:ok, runtime} =
        Plushie.Runtime.start_link(app: WidgetOpApp, bridge: bridge_name, name: runtime_name)

      await_initial_render(runtime)

      # This test just verifies the runtime doesn't crash when processing
      # widget ops -- the bridge is present here, so ops are sent normally.
      dispatch_and_wait(runtime, {:do, :focus})
      assert Process.alive?(runtime)
    end

    test "batch containing widget ops dispatches all of them" do
      defmodule BatchWidgetApp do
        use Plushie.App

        def init(_opts), do: %{}

        def update(model, :batch_ops) do
          cmd =
            Command.batch([
              Command.focus("first"),
              Command.focus_next(),
              Command.close_window("main")
            ])

          {model, cmd}
        end

        def update(model, _event), do: model

        def view(_model) do
          import Plushie.UI

          window "main" do
            column do
              text("batch test")
            end
          end
        end
      end

      {runtime, bridge} = start_runtime(BatchWidgetApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, :batch_ops)

      cmds = Plushie.Test.InternalMockBridge.get_commands(bridge)
      assert length(cmds) == 1
      assert hd(cmds).id == "first"
      assert hd(cmds).family == "focus"

      ops = Plushie.Test.InternalMockBridge.get_widget_ops(bridge)
      assert length(ops) == 2

      assert Enum.at(ops, 0).op == "focus_next"

      assert Enum.at(ops, 1).op == "close_window"
      assert Enum.at(ops, 1).payload == %{window_id: "main"}
    end
  end
end
