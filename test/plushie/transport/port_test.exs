defmodule Plushie.Transport.PortTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Plushie.Transport.Port, as: PortTransport

  describe "init/1" do
    test "returns an error when the renderer path is missing" do
      assert {:error, {:renderer_not_found, "/tmp/plushie-missing-renderer"}} =
               PortTransport.init(
                 mode: :spawn,
                 format: :msgpack,
                 renderer_path: "/tmp/plushie-missing-renderer"
               )
    end
  end

  describe "send_data/2" do
    test "sends iodata to an open port" do
      port = open_port()

      try do
        assert {:ok, %PortTransport{}} =
                 PortTransport.send_data(%PortTransport{port: port}, ["hello"])
      after
        close_port(port)
      end
    end

    test "does not report invalid iodata as a closed port" do
      port = open_port()

      try do
        assert_raise ArgumentError, fn ->
          PortTransport.send_data(%PortTransport{port: port}, [%{}])
        end
      after
        close_port(port)
      end
    end

    test "reports a closed port" do
      port = open_port()
      close_port(port)

      capture_log(fn ->
        assert {:error, :port_closed} =
                 PortTransport.send_data(%PortTransport{port: port}, ["hello"])
      end)
    end
  end

  describe "handle_info/2" do
    test "returns msgpack data from the owned port" do
      port = open_port()

      try do
        state = %PortTransport{port: port, format: :msgpack}

        assert {:data, "payload", ^state} =
                 PortTransport.handle_info({port, {:data, "payload"}}, state)
      after
        close_port(port)
      end
    end

    test "clears the port on exit status" do
      port = open_port()
      state = %PortTransport{port: port, format: :msgpack}

      assert {:closed, {:exit_status, 1}, new_state} =
               PortTransport.handle_info({port, {:exit_status, 1}}, state)

      assert new_state.port == nil

      close_port(port)
    end

    test "ignores unrelated messages" do
      assert :ignore = PortTransport.handle_info(:unexpected, %PortTransport{})
    end
  end

  defp open_port do
    shell = System.find_executable("sh") || "/bin/sh"
    Port.open({:spawn_executable, shell}, [:binary, args: ["-c", "cat >/dev/null"]])
  end

  defp close_port(port) do
    Port.close(port)
  catch
    _, _ -> :ok
  end
end
