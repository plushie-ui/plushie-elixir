defmodule Toddy.CommandTest do
  use ExUnit.Case, async: true

  alias Toddy.Command

  # ---------------------------------------------------------------------------
  # Struct shape
  # ---------------------------------------------------------------------------

  describe "Command struct" do
    test "has :type and :payload fields" do
      cmd = %Command{type: :none, payload: %{}}
      assert cmd.type == :none
      assert cmd.payload == %{}
    end

    test "enforces :type and :payload keys -- missing either raises" do
      assert_raise ArgumentError, fn ->
        struct!(Command, type: :none)
      end

      assert_raise ArgumentError, fn ->
        struct!(Command, payload: %{})
      end
    end

    test "is inspectable as a plain struct" do
      cmd = Command.none()
      inspected = inspect(cmd)
      assert inspected =~ "Command"
      assert inspected =~ "type: :none"
    end
  end

  # ---------------------------------------------------------------------------
  # none/0
  # ---------------------------------------------------------------------------

  describe "none/0" do
    test "returns a Command with type :none" do
      assert %Command{type: :none} = Command.none()
    end

    test "payload is an empty map" do
      assert Command.none().payload == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # done/2
  # ---------------------------------------------------------------------------

  describe "done/2" do
    test "returns a Command with type :done" do
      cmd = Command.done(:hello, fn val -> {:got, val} end)
      assert cmd.type == :done
    end

    test "stores the value and mapper in the payload" do
      mapper = fn val -> {:wrapped, val} end
      cmd = Command.done(42, mapper)
      assert cmd.payload.value == 42
      assert cmd.payload.mapper == mapper
    end

    test "mapper is called with the provided value" do
      cmd = Command.done(:input, fn val -> {:mapped, val} end)
      assert cmd.payload.mapper.(cmd.payload.value) == {:mapped, :input}
    end

    test "raises when mapper is not a 1-arity function" do
      assert_raise FunctionClauseError, fn ->
        Command.done(:val, fn _a, _b -> :nope end)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # async/2
  # ---------------------------------------------------------------------------

  describe "async/2" do
    test "returns a Command with type :async" do
      cmd = Command.async(fn -> :ok end, :my_result)
      assert cmd.type == :async
    end

    test "stores the function under :fun in the payload" do
      fun = fn -> 42 end
      cmd = Command.async(fun, :answer)
      assert cmd.payload.fun == fun
    end

    test "stores the event tag under :tag in the payload" do
      cmd = Command.async(fn -> :ok end, :save_done)
      assert cmd.payload.tag == :save_done
    end

    test "raises when the first argument is not a function" do
      assert_raise FunctionClauseError, fn ->
        Command.async(:not_a_fun, :tag)
      end
    end

    test "raises when the event tag is not an atom" do
      assert_raise FunctionClauseError, fn ->
        Command.async(fn -> :ok end, "string_tag")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # focus/1
  # ---------------------------------------------------------------------------

  describe "focus/1" do
    test "returns a Command with type :focus" do
      assert %Command{type: :focus} = Command.focus("username")
    end

    test "stores the widget id under :target in the payload" do
      cmd = Command.focus("username")
      assert cmd.payload.target == "username"
    end

    test "accepts non-string widget ids" do
      cmd = Command.focus(:my_widget)
      assert cmd.payload.target == :my_widget
    end
  end

  # ---------------------------------------------------------------------------
  # focus_next/0 and focus_previous/0
  # ---------------------------------------------------------------------------

  describe "focus_next/0" do
    test "returns a Command with type :focus_next" do
      assert %Command{type: :focus_next} = Command.focus_next()
    end

    test "payload is an empty map" do
      assert Command.focus_next().payload == %{}
    end
  end

  describe "focus_previous/0" do
    test "returns a Command with type :focus_previous" do
      assert %Command{type: :focus_previous} = Command.focus_previous()
    end

    test "payload is an empty map" do
      assert Command.focus_previous().payload == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # select_all/1
  # ---------------------------------------------------------------------------

  describe "select_all/1" do
    test "returns a Command with type :select_all" do
      assert %Command{type: :select_all} = Command.select_all("body_input")
    end

    test "stores the widget id under :target in the payload" do
      cmd = Command.select_all("body_input")
      assert cmd.payload.target == "body_input"
    end
  end

  # ---------------------------------------------------------------------------
  # scroll_to/2
  # ---------------------------------------------------------------------------

  describe "scroll_to/2" do
    test "returns a Command with type :scroll_to" do
      assert %Command{type: :scroll_to} = Command.scroll_to("log_view", 0)
    end

    test "stores the widget id under :target and the offset under :offset_y" do
      cmd = Command.scroll_to("log_view", 500)
      assert cmd.payload.target == "log_view"
      assert cmd.payload.offset_y == 500
    end

    test "offset can be any term" do
      cmd = Command.scroll_to("feed", :bottom)
      assert cmd.payload.offset_y == :bottom
    end
  end

  # ---------------------------------------------------------------------------
  # send_after/2
  # ---------------------------------------------------------------------------

  describe "send_after/2" do
    test "returns a Command with type :send_after" do
      assert %Command{type: :send_after} = Command.send_after(1000, :auto_save)
    end

    test "stores delay under :delay and event under :event in the payload" do
      cmd = Command.send_after(250, :tick)
      assert cmd.payload.delay == 250
      assert cmd.payload.event == :tick
    end

    test "accepts zero delay" do
      cmd = Command.send_after(0, :immediate)
      assert cmd.payload.delay == 0
    end

    test "raises when delay is negative" do
      assert_raise FunctionClauseError, fn ->
        Command.send_after(-1, :oops)
      end
    end

    test "raises when delay is not an integer" do
      assert_raise FunctionClauseError, fn ->
        Command.send_after(1.5, :oops)
      end
    end

    test "event can be any term, including a tagged tuple" do
      cmd = Command.send_after(100, {:refresh, :all})
      assert cmd.payload.event == {:refresh, :all}
    end
  end

  # ---------------------------------------------------------------------------
  # close_window/1
  # ---------------------------------------------------------------------------

  describe "close_window/1" do
    test "returns a Command with type :close_window" do
      assert %Command{type: :close_window} = Command.close_window("settings")
    end

    test "stores the window id under :window_id in the payload" do
      cmd = Command.close_window("preferences")
      assert cmd.payload.window_id == "preferences"
    end
  end

  # ---------------------------------------------------------------------------
  # batch/1
  # ---------------------------------------------------------------------------

  describe "batch/1" do
    test "wraps a list of commands under type :batch" do
      cmds = [Command.focus("a"), Command.focus("b")]
      batch = Command.batch(cmds)
      assert batch.type == :batch
      assert batch.payload.commands == cmds
    end

    test "wraps a single command in a list" do
      single = Command.focus("solo")
      batch = Command.batch(single)
      assert batch.type == :batch
      assert batch.payload.commands == [single]
    end

    test "wraps an empty list" do
      batch = Command.batch([])
      assert batch.type == :batch
      assert batch.payload.commands == []
    end

    test "normalises a nested list via List.wrap semantics" do
      inner = Command.none()
      # List.wrap on a list passes it through; a single item becomes [item]
      batch = Command.batch([inner])
      assert length(batch.payload.commands) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # allow_automatic_tabbing/1
  # ---------------------------------------------------------------------------

  describe "allow_automatic_tabbing/1" do
    test "returns a window_op command with op allow_automatic_tabbing" do
      cmd = Command.allow_automatic_tabbing(true)
      assert cmd.type == :window_op
      assert cmd.payload.op == "allow_automatic_tabbing"
    end

    test "stores enabled flag in payload" do
      cmd = Command.allow_automatic_tabbing(false)
      assert cmd.payload.enabled == false
    end

    test "uses _global as window_id" do
      cmd = Command.allow_automatic_tabbing(true)
      assert cmd.payload.window_id == "_global"
    end

    test "raises when enabled is not a boolean" do
      assert_raise FunctionClauseError, fn ->
        Command.allow_automatic_tabbing("yes")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # stream/2
  # ---------------------------------------------------------------------------

  describe "stream/2" do
    test "returns a Command with type :stream" do
      cmd = Command.stream(fn _emit -> :ok end, :my_stream)
      assert cmd.type == :stream
    end

    test "stores the function under :fun in the payload" do
      fun = fn _emit -> :done end
      cmd = Command.stream(fun, :import)
      assert cmd.payload.fun == fun
    end

    test "stores the event tag under :tag in the payload" do
      cmd = Command.stream(fn _emit -> :ok end, :file_import)
      assert cmd.payload.tag == :file_import
    end

    test "raises when the function does not accept exactly one argument" do
      assert_raise FunctionClauseError, fn ->
        Command.stream(fn -> :ok end, :tag)
      end
    end

    test "raises when the event tag is not an atom" do
      assert_raise FunctionClauseError, fn ->
        Command.stream(fn _emit -> :ok end, "string_tag")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # cancel/1
  # ---------------------------------------------------------------------------

  describe "cancel/1" do
    test "returns a Command with type :cancel" do
      cmd = Command.cancel(:my_stream)
      assert cmd.type == :cancel
    end

    test "stores the event tag under :tag in the payload" do
      cmd = Command.cancel(:file_import)
      assert cmd.payload.tag == :file_import
    end

    test "raises when the event tag is not an atom" do
      assert_raise FunctionClauseError, fn ->
        Command.cancel("string_tag")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # extension_command/3
  # ---------------------------------------------------------------------------

  describe "extension_command/3" do
    test "returns a Command with type :extension_command" do
      cmd = Command.extension_command("node-1", "write", %{data: "hi"})
      assert cmd.type == :extension_command
      assert cmd.payload.node_id == "node-1"
      assert cmd.payload.op == "write"
      assert cmd.payload.payload == %{data: "hi"}
    end

    test "defaults payload to empty map" do
      cmd = Command.extension_command("node-1", "reset")
      assert cmd.payload.payload == %{}
    end

    test "raises when node_id is not a binary" do
      assert_raise FunctionClauseError, fn ->
        Command.extension_command(:not_a_string, "op")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # announce/1
  # ---------------------------------------------------------------------------

  describe "announce/1" do
    test "returns a widget_op Command with op announce" do
      cmd = Command.announce("File saved")
      assert cmd.type == :widget_op
      assert cmd.payload == %{op: "announce", text: "File saved"}
    end

    test "raises when text is not a binary" do
      assert_raise FunctionClauseError, fn ->
        Command.announce(:not_a_string)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # extension_commands/1
  # ---------------------------------------------------------------------------

  describe "extension_commands/1" do
    test "returns a Command with type :extension_commands" do
      cmds = [{"n1", "op1", %{a: 1}}, {"n2", "op2", %{b: 2}}]
      cmd = Command.extension_commands(cmds)
      assert cmd.type == :extension_commands
      assert cmd.payload.commands == cmds
    end

    test "raises when given a non-list" do
      assert_raise FunctionClauseError, fn ->
        Command.extension_commands("not a list")
      end
    end
  end
end
