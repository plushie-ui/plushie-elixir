defmodule Plushie.Transport.IOStreamTest do
  use ExUnit.Case, async: true

  alias Plushie.Transport.IOStream

  describe "init/1" do
    test "registers the bridge with the adapter process" do
      adapter = self()

      assert {:ok, %IOStream{io_pid: ^adapter, alive: true}} = IOStream.init(io_pid: adapter)

      assert_receive {:iostream_bridge, pid}
      assert is_pid(pid)
    end
  end

  describe "send_data/2" do
    test "sends iodata to the adapter process" do
      state = %IOStream{io_pid: self(), monitor_ref: make_ref(), alive: true}

      assert {:ok, ^state} = IOStream.send_data(state, ["hello"])
      assert_receive {:iostream_send, ["hello"]}
    end

    test "does not report invalid iodata as an unreachable process" do
      state = %IOStream{io_pid: self(), monitor_ref: make_ref(), alive: true}

      assert_raise ArgumentError, fn ->
        IOStream.send_data(state, [%{}])
      end

      refute_receive {:iostream_send, _}
    end
  end

  describe "handle_info/2" do
    test "returns iostream data" do
      state = %IOStream{io_pid: self(), monitor_ref: make_ref(), alive: true}

      assert {:data, "payload", ^state} = IOStream.handle_info({:iostream_data, "payload"}, state)
    end

    test "marks the stream closed when the adapter closes" do
      state = %IOStream{io_pid: self(), monitor_ref: make_ref(), alive: true}

      assert {:closed, :done, %IOStream{alive: false}} =
               IOStream.handle_info({:iostream_closed, :done}, state)
    end

    test "marks the stream closed when the adapter exits" do
      ref = make_ref()
      state = %IOStream{io_pid: self(), monitor_ref: ref, alive: true}

      assert {:closed, :normal, %IOStream{alive: false}} =
               IOStream.handle_info({:DOWN, ref, :process, self(), :normal}, state)
    end

    test "ignores unrelated messages" do
      assert :ignore = IOStream.handle_info(:unexpected, %IOStream{})
    end
  end
end
