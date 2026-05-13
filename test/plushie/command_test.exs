defmodule Plushie.CommandTest do
  use ExUnit.Case, async: true

  alias Plushie.Command

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

  describe "none/0" do
    test "returns a Command with type :none" do
      assert %Command{type: :none} = Command.none()
    end

    test "payload is an empty map" do
      assert Command.none().payload == %{}
    end
  end

  describe "dispatch/2" do
    test "returns a Command with type :dispatch" do
      cmd = Command.dispatch(:hello, fn val -> {:got, val} end)
      assert cmd.type == :dispatch
    end

    test "stores the value and mapper in the payload" do
      mapper = fn val -> {:wrapped, val} end
      cmd = Command.dispatch(42, mapper)
      assert cmd.payload.value == 42
      assert cmd.payload.mapper == mapper
    end

    test "mapper is called with the provided value" do
      cmd = Command.dispatch(:input, fn val -> {:mapped, val} end)
      assert cmd.payload.mapper.(cmd.payload.value) == {:mapped, :input}
    end

    test "raises when mapper is not a 1-arity function" do
      assert_raise FunctionClauseError, fn ->
        Command.dispatch(:val, fn _a, _b -> :nope end)
      end
    end
  end

  describe "task/2" do
    test "returns a Command with type :task" do
      cmd = Command.task(fn -> :ok end, :my_result)
      assert cmd.type == :task
    end

    test "stores the function under :fun in the payload" do
      fun = fn -> 42 end
      cmd = Command.task(fun, :answer)
      assert cmd.payload.fun == fun
    end

    test "stores the event tag under :tag in the payload" do
      cmd = Command.task(fn -> :ok end, :save_done)
      assert cmd.payload.tag == :save_done
    end

    test "raises when the first argument is not a function" do
      assert_raise FunctionClauseError, fn ->
        Command.task(:not_a_fun, :tag)
      end
    end

    test "raises when the event tag is not an atom" do
      assert_raise FunctionClauseError, fn ->
        Command.task(fn -> :ok end, "string_tag")
      end
    end
  end

  describe "focus/1" do
    test "returns a command targeting the widget" do
      assert %Command{type: :command, payload: %{id: "username", family: "focus"}} =
               Command.focus("username")
    end

    test "stores the full widget id in the payload" do
      cmd = Command.focus("main#username")
      assert cmd.payload.id == "main#username"
    end
  end

  describe "focus_next/0" do
    test "returns a widget_op command" do
      assert %Command{type: :widget_op, payload: %{op: "focus_next"}} = Command.focus_next()
    end
  end

  describe "focus_previous/0" do
    test "returns a widget_op command" do
      assert %Command{type: :widget_op, payload: %{op: "focus_previous"}} =
               Command.focus_previous()
    end
  end

  describe "focus_next_within/1" do
    test "returns a widget_op command with the scope payload" do
      assert %Command{
               type: :widget_op,
               payload: %{op: "focus_next_within", scope: "main#menu"}
             } = Command.focus_next_within("main#menu")
    end
  end

  describe "focus_previous_within/1" do
    test "returns a widget_op command with the scope payload" do
      assert %Command{
               type: :widget_op,
               payload: %{op: "focus_previous_within", scope: "main#menu"}
             } = Command.focus_previous_within("main#menu")
    end
  end

  describe "select_all/1" do
    test "returns a command targeting the widget" do
      assert %Command{type: :command, payload: %{id: "body_input", family: "select_all"}} =
               Command.select_all("body_input")
    end
  end

  describe "scroll_to/3" do
    test "returns a command targeting the widget" do
      assert %Command{type: :command, payload: %{id: "log_view", family: "scroll_to"}} =
               Command.scroll_to("log_view", 0.0, 0.0)
    end

    test "stores x and y in value" do
      cmd = Command.scroll_to("log_view", 0.0, 500.0)
      assert cmd.payload.id == "log_view"
      assert cmd.payload.value == %{x: 0.0, y: 500.0}
    end
  end

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

  describe "close_window/1" do
    test "returns a Command with type :window_op and op close" do
      assert %Command{type: :window_op, payload: %{op: "close"}} =
               Command.close_window("settings")
    end

    test "stores the window id under :window_id in the payload" do
      cmd = Command.close_window("preferences")
      assert cmd.payload.window_id == "preferences"
    end
  end

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

    test "rejects nested lists" do
      inner = Command.none()

      assert_raise ArgumentError, ~r/expected %Plushie.Command{}/, fn ->
        Command.batch([[inner]])
      end
    end

    test "rejects non-command input" do
      assert_raise FunctionClauseError, fn ->
        Command.batch(nil)
      end

      assert_raise ArgumentError, ~r/expected %Plushie.Command{}/, fn ->
        Command.batch([Command.none(), :not_a_command])
      end
    end
  end

  describe "allow_automatic_tabbing/1" do
    test "returns a system_op command with op allow_automatic_tabbing" do
      cmd = Command.allow_automatic_tabbing(true)
      assert cmd.type == :system_op
      assert cmd.payload.op == "allow_automatic_tabbing"
    end

    test "stores enabled flag in payload" do
      cmd = Command.allow_automatic_tabbing(false)
      assert cmd.payload.enabled == false
    end

    test "raises when enabled is not a boolean" do
      assert_raise FunctionClauseError, fn ->
        Command.allow_automatic_tabbing("yes")
      end
    end
  end

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

  describe "widget_command/3" do
    test "returns a Command with type :command" do
      cmd = Command.widget_command("node-1", "write", %{data: "hi"})
      assert cmd.type == :command
      assert cmd.payload.id == "node-1"
      assert cmd.payload.family == "write"
      assert cmd.payload.value == %{data: "hi"}
    end

    test "defaults value to nil" do
      cmd = Command.widget_command("node-1", "reset")
      assert cmd.payload.value == nil
    end

    test "raises when id is not a binary" do
      assert_raise FunctionClauseError, fn ->
        Command.widget_command(:not_a_string, "op")
      end
    end
  end

  describe "announce/1" do
    test "returns a widget_op Command with op announce" do
      cmd = Command.announce("File saved")
      assert cmd.type == :widget_op

      assert cmd.payload == %{
               op: "announce",
               text: "File saved",
               politeness: "polite"
             }
    end

    test "raises when text is not a binary" do
      assert_raise FunctionClauseError, fn ->
        Command.announce(:not_a_string)
      end
    end
  end

  describe "announce/2" do
    test "carries the politeness through the payload" do
      cmd = Command.announce("Done", :polite)

      assert cmd.payload == %{
               op: "announce",
               text: "Done",
               politeness: "polite"
             }
    end

    test "assertive variant serializes to the wire string" do
      cmd = Command.announce("Connection lost", :assertive)

      assert cmd.payload == %{
               op: "announce",
               text: "Connection lost",
               politeness: "assertive"
             }
    end

    test "rejects unknown politeness values" do
      assert_raise FunctionClauseError, fn ->
        Command.announce("hi", :whenever)
      end
    end
  end

  describe "widget_batch/1" do
    test "returns a Command with type :commands" do
      cmds = [{"n1", "op1", %{a: 1}}, {"n2", "op2", %{b: 2}}]
      cmd = Command.widget_batch(cmds)
      assert cmd.type == :commands
      assert cmd.payload.commands == cmds
    end

    test "raises when given a non-list" do
      assert_raise FunctionClauseError, fn ->
        Command.widget_batch("not a list")
      end
    end

    test "raises when list elements are not widget command tuples" do
      assert_raise ArgumentError, ~r/expected widget command tuple/, fn ->
        Command.widget_batch([{"n1", "op1", nil}, :not_a_tuple])
      end
    end
  end

  describe "image RGBA commands" do
    test "create_image_rgba/4 stores dimensions and pixels" do
      pixels = <<255, 0, 0, 255>>

      assert %Command{
               type: :image_op,
               payload: %{
                 op: "create_image",
                 handle: "pixel",
                 width: 1,
                 height: 1,
                 pixels: ^pixels
               }
             } = Command.create_image_rgba("pixel", 1, 1, pixels)
    end

    test "update_image_rgba/4 stores dimensions and pixels" do
      pixels = <<0, 0, 0, 0>>

      assert %Command{
               type: :image_op,
               payload: %{
                 op: "update_image",
                 handle: "pixel",
                 width: 1,
                 height: 1,
                 pixels: ^pixels
               }
             } = Command.update_image_rgba("pixel", 1, 1, pixels)
    end

    test "RGBA commands reject non-positive dimensions" do
      assert_raise FunctionClauseError, fn ->
        Command.create_image_rgba("pixel", 0, 1, <<>>)
      end

      assert_raise FunctionClauseError, fn ->
        Command.update_image_rgba("pixel", 1, -1, <<>>)
      end
    end
  end

  describe "query and utility constructors" do
    test "tree_hash/1 creates a widget op query" do
      assert %Command{type: :widget_op, payload: %{op: "tree_hash", tag: "hash"}} =
               Command.tree_hash(:hash)
    end

    test "find_focused/1 creates a widget op query" do
      assert %Command{type: :widget_op, payload: %{op: "find_focused", tag: "focus"}} =
               Command.find_focused(:focus)
    end

    test "load_font/2 stores family and font data" do
      data = <<0, 1, 2>>

      assert %Command{type: :load_font, payload: %{family: "Custom", data: ^data}} =
               Command.load_font("Custom", data)
    end

    test "advance_frame/1 stores the timestamp" do
      assert %Command{type: :advance_frame, payload: %{timestamp: 16}} =
               Command.advance_frame(16)
    end
  end

  describe "window visual constructors" do
    test "set_icon/4 stores icon data and dimensions" do
      pixels = <<0, 0, 0, 0>>

      assert %Command{
               type: :window_op,
               payload: %{
                 op: "set_icon",
                 window_id: "main",
                 icon_data: ^pixels,
                 width: 1,
                 height: 1
               }
             } = Command.set_icon("main", pixels, 1, 1)
    end

    test "set_resize_increments/3 stores numeric increments" do
      assert %Command{
               type: :window_op,
               payload: %{op: "set_resize_increments", window_id: "main", width: 8, height: 16}
             } = Command.set_resize_increments("main", 8, 16)
    end

    test "set_resize_increments/3 allows clearing with nil values" do
      assert %Command{
               type: :window_op,
               payload: %{op: "set_resize_increments", window_id: "main", width: nil, height: nil}
             } = Command.set_resize_increments("main", nil, nil)
    end

    test "set_resize_increments/3 rejects mixed or non-numeric dimensions" do
      assert_raise FunctionClauseError, fn ->
        Command.set_resize_increments("main", nil, 10)
      end

      assert_raise FunctionClauseError, fn ->
        Command.set_resize_increments("main", "8", 10)
      end
    end
  end

  describe "window-qualified widget IDs" do
    test "focus/1 preserves full qualified path" do
      cmd = Command.focus("main#email")
      assert cmd.payload.id == "main#email"
    end

    test "focus/1 plain path" do
      cmd = Command.focus("form/email")
      assert cmd.payload.id == "form/email"
    end

    test "scroll_to/3 preserves full qualified path" do
      cmd = Command.scroll_to("settings#list", 0.0, 100.0)
      assert cmd.payload.id == "settings#list"
      assert cmd.payload.value == %{x: 0.0, y: 100.0}
    end

    test "snap_to/3 preserves full qualified path" do
      cmd = Command.snap_to("main#scroll", 10.0, 20.0)
      assert cmd.payload.id == "main#scroll"
    end

    test "select_all/1 preserves full qualified path" do
      cmd = Command.select_all("main#editor")
      assert cmd.payload.id == "main#editor"
    end

    test "move_cursor_to/2 preserves full qualified path" do
      cmd = Command.move_cursor_to("main#input", 5)
      assert cmd.payload.id == "main#input"
      assert cmd.payload.value == 5
    end

    test "select_range/3 preserves full qualified path" do
      cmd = Command.select_range("main#editor", 0, 10)
      assert cmd.payload.id == "main#editor"
    end

    test "focus/1 with scoped canvas element path" do
      cmd = Command.focus("main#drawing/handle")
      assert cmd.payload.id == "main#drawing/handle"
    end
  end
end
