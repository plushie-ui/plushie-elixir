defmodule Plushie.Test.SessionPool.MultiplexedTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Plushie.Test.SessionPool.Multiplexed

  describe "handle_port_data/3" do
    test "buffers incomplete JSON chunks" do
      state = Multiplexed.handle_port_data("{", %Multiplexed{buffer: ""}, :json)

      assert state.buffer == "{"
    end

    test "drops malformed complete JSON lines" do
      log =
        capture_log(fn ->
          state = Multiplexed.handle_port_data({:eol, "{"}, %Multiplexed{buffer: ""}, :json)

          assert state.buffer == ""
        end)

      assert log =~ "dropping malformed JSON line"
    end

    test "caps incomplete JSON buffers" do
      oversized = String.duplicate("x", 1_048_577)

      log =
        capture_log(fn ->
          state =
            Multiplexed.handle_port_data(oversized, %Multiplexed{buffer: ""}, :json)

          assert state.buffer == ""
        end)

      assert log =~ "dropping oversized JSON buffer"
    end

    test "reports malformed MessagePack frames" do
      log =
        capture_log(fn ->
          state = Multiplexed.handle_port_data(<<0xC1>>, %Multiplexed{buffer: ""}, :msgpack)

          assert state.buffer == ""
        end)

      assert log =~ "dropping malformed MessagePack frame"
    end

    test "reports unknown renderer messages" do
      msg = Jason.encode!(%{"type" => "mystery"})

      log =
        capture_log(fn ->
          Multiplexed.handle_port_data(msg, %Multiplexed{buffer: ""}, :json)
        end)

      assert log =~ "dropping unknown multiplexed renderer message"
    end
  end

  describe "send_async/4" do
    test "rejects unknown sessions before writing to the port" do
      assert :error =
               Multiplexed.send_async(
                 %Multiplexed{sessions: %{}, port: nil},
                 "missing",
                 %{type: "snapshot"},
                 :json
               )
    end
  end

  describe "handle_renderer_exit/2" do
    test "notifies session owners" do
      state = %Multiplexed{sessions: %{"pool_1" => {self(), make_ref()}}}

      Multiplexed.handle_renderer_exit(state, 42)

      assert_receive {:plushie_pool_renderer_exited, "pool_1", 42}
    end
  end
end
