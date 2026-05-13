defmodule Plushie.Test.SessionPool.WindowedTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Plushie.Test.SessionPool.Windowed

  describe "handle_port_data/4" do
    test "buffers incomplete JSON chunks" do
      session = Windowed.handle_port_data("{", "pool_1", session(), :json)

      assert session.buffer == "{"
    end

    test "drops malformed complete JSON lines" do
      log =
        capture_log(fn ->
          session = Windowed.handle_port_data({:eol, "{"}, "pool_1", session(), :json)

          assert session.buffer == ""
        end)

      assert log =~ "dropping malformed windowed JSON line"
    end

    test "caps incomplete JSON buffers" do
      oversized = String.duplicate("x", 1_048_577)

      log =
        capture_log(fn ->
          session = Windowed.handle_port_data(oversized, "pool_1", session(), :json)

          assert session.buffer == ""
        end)

      assert log =~ "dropping oversized windowed JSON buffer"
    end

    test "reports malformed MessagePack frames" do
      log =
        capture_log(fn ->
          session = Windowed.handle_port_data(<<0xC1>>, "pool_1", session(), :msgpack)

          assert session.buffer == ""
        end)

      assert log =~ "dropping malformed windowed MessagePack frame"
    end

    test "reports unknown renderer messages" do
      msg = Jason.encode!(%{"type" => "mystery"})

      log =
        capture_log(fn ->
          Windowed.handle_port_data(msg, "pool_1", session(), :json)
        end)

      assert log =~ "dropping unknown windowed renderer message"
    end

    test "reports responses for unknown request ids" do
      msg = Jason.encode!(%{"type" => "query_response", "id" => "missing"})

      log =
        capture_log(fn ->
          Windowed.handle_port_data(msg, "pool_1", session(), :json)
        end)

      assert log =~ "dropping windowed renderer response with unknown request id"
    end
  end

  defp session do
    %Windowed{owner_pid: self(), owner_ref: make_ref(), port: nil, buffer: ""}
  end
end
