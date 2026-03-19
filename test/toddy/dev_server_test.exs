defmodule Toddy.DevServerTest do
  use ExUnit.Case, async: true

  # ---------------------------------------------------------------------------
  # Unit tests for DevServer internals: filtering, debouncing.
  #
  # These tests exercise the logic WITHOUT a real FileSystem watcher.
  # We simulate file events by sending the same messages FileSystem would.
  # ---------------------------------------------------------------------------

  describe "watchable? filtering" do
    # We test the filtering logic by sending fake file events to a DevServer
    # and checking whether :force_rerender arrives at the runtime.

    setup do
      runtime = spawn_sink()
      {:ok, dev} = start_dev_server(runtime, debounce_ms: 1)
      %{dev: dev, runtime: runtime}
    end

    test "accepts .ex files", %{dev: dev, runtime: runtime} do
      send(dev, {:file_event, self(), {"/project/lib/app.ex", [:modified]}})
      assert_receive_rerender(runtime)
    end

    test "accepts .exs files", %{dev: dev, runtime: runtime} do
      send(dev, {:file_event, self(), {"/project/test/app_test.exs", [:modified]}})
      assert_receive_rerender(runtime)
    end

    test "ignores non-elixir files", %{dev: dev, runtime: runtime} do
      send(dev, {:file_event, self(), {"/project/lib/style.css", [:modified]}})
      refute_receive_rerender(runtime)
    end

    test "ignores _build/ paths", %{dev: dev, runtime: runtime} do
      send(dev, {:file_event, self(), {"/project/_build/dev/lib/app.ex", [:modified]}})
      refute_receive_rerender(runtime)
    end

    test "ignores files with no extension", %{dev: dev, runtime: runtime} do
      send(dev, {:file_event, self(), {"/project/lib/Makefile", [:modified]}})
      refute_receive_rerender(runtime)
    end
  end

  describe "debouncing" do
    test "rapid file events produce a single recompile" do
      runtime = spawn_sink()
      {:ok, dev} = start_dev_server(runtime, debounce_ms: 50)

      # Fire several events in rapid succession.
      for i <- 1..5 do
        send(dev, {:file_event, self(), {"/project/lib/mod#{i}.ex", [:modified]}})
      end

      # Wait for debounce + recompile.
      Process.sleep(100)

      # Should have received exactly one :force_rerender.
      rerender_count = count_rerenders(runtime)
      assert rerender_count == 1
    end

    test "events after debounce window trigger another recompile" do
      runtime = spawn_sink()
      {:ok, dev} = start_dev_server(runtime, debounce_ms: 20)

      # First batch.
      send(dev, {:file_event, self(), {"/project/lib/a.ex", [:modified]}})
      Process.sleep(60)

      # Second batch (after debounce window).
      send(dev, {:file_event, self(), {"/project/lib/b.ex", [:modified]}})
      Process.sleep(60)

      rerender_count = count_rerenders(runtime)
      assert rerender_count == 2
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Starts a DevServer that won't actually use FileSystem (we inject events
  # manually). We bypass ensure_file_system! by mocking the init.
  defp start_dev_server(runtime, opts) do
    # We can't use the real DevServer.start_link because it calls
    # FileSystem.start_link. Instead we start a bare GenServer with
    # the same state shape and message handling.
    tag = System.unique_integer([:positive])
    name = :"dev_server_test_#{tag}"
    debounce_ms = Keyword.get(opts, :debounce_ms, 100)

    {:ok, pid} =
      GenServer.start_link(
        Toddy.DevServer.TestHarness,
        %{
          runtime: runtime,
          watcher: nil,
          debounce_ms: debounce_ms,
          debounce_ref: nil,
          recompiling: false
        },
        name: name
      )

    {:ok, pid}
  end

  # A simple process that collects messages.
  defp spawn_sink do
    spawn(fn -> sink_loop([]) end)
  end

  defp sink_loop(msgs) do
    receive do
      {:get_messages, from} ->
        send(from, {:messages, Enum.reverse(msgs)})
        sink_loop(msgs)

      msg ->
        sink_loop([msg | msgs])
    end
  end

  defp get_messages(sink) do
    send(sink, {:get_messages, self()})

    receive do
      {:messages, msgs} -> msgs
    after
      500 -> []
    end
  end

  defp count_rerenders(sink) do
    get_messages(sink)
    |> Enum.count(&(&1 == :force_rerender))
  end

  defp assert_receive_rerender(runtime) do
    # Wait for debounce + processing.
    Process.sleep(50)

    msgs = get_messages(runtime)
    assert :force_rerender in msgs, "expected :force_rerender, got: #{inspect(msgs)}"
  end

  defp refute_receive_rerender(runtime) do
    Process.sleep(50)

    msgs = get_messages(runtime)
    refute :force_rerender in msgs, "did not expect :force_rerender, but got it"
  end
end
