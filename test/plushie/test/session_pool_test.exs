defmodule Plushie.Test.SessionPoolTest do
  use ExUnit.Case, async: false

  alias Plushie.Test.Backend.Runtime
  alias Plushie.Test.SessionPool

  # These tests verify the multiplexing infrastructure, not rendering.

  describe "SessionPool" do
    setup do
      binary = Application.fetch_env!(:plushie, :test_binary_path)

      {:ok, pool} =
        SessionPool.start_link(
          renderer: binary,
          mode: :mock,
          format: :json,
          max_sessions: 4,
          rust_log: "off"
        )

      %{pool: pool}
    end

    test "register returns unique session IDs", %{pool: pool} do
      s1 = SessionPool.register(pool)
      s2 = SessionPool.register(pool)
      assert s1 != s2
      assert String.starts_with?(s1, "pool_")
      assert String.starts_with?(s2, "pool_")
    end

    test "send_message returns response for request messages", %{pool: pool} do
      session_id = SessionPool.register(pool)

      # Send a tree, then query it.
      SessionPool.send_message(pool, session_id, %{
        type: "snapshot",
        tree: %{id: "root", type: "text", props: %{content: "hello"}, children: []}
      })

      # Small delay for the async snapshot to be processed.
      Process.sleep(50)

      {:ok, resp} =
        SessionPool.send_message(
          pool,
          session_id,
          %{type: "query", target: "tree", selector: %{}},
          "query_response"
        )

      assert resp["type"] == "query_response"
      assert resp["session"] == session_id
      assert resp["data"]["props"]["content"] == "hello"
    end

    test "sessions are isolated", %{pool: pool} do
      s1 = SessionPool.register(pool)
      s2 = SessionPool.register(pool)

      SessionPool.send_message(pool, s1, %{
        type: "snapshot",
        tree: %{id: "root", type: "text", props: %{content: "one"}, children: []}
      })

      SessionPool.send_message(pool, s2, %{
        type: "snapshot",
        tree: %{id: "root", type: "text", props: %{content: "two"}, children: []}
      })

      Process.sleep(50)

      {:ok, r1} =
        SessionPool.send_message(
          pool,
          s1,
          %{type: "query", target: "tree", selector: %{}},
          "query_response"
        )

      {:ok, r2} =
        SessionPool.send_message(
          pool,
          s2,
          %{type: "query", target: "tree", selector: %{}},
          "query_response"
        )

      assert r1["data"]["props"]["content"] == "one"
      assert r2["data"]["props"]["content"] == "two"
    end

    test "unregister sends Reset and cleans up", %{pool: pool} do
      session_id = SessionPool.register(pool)

      SessionPool.send_message(pool, session_id, %{
        type: "snapshot",
        tree: %{id: "root", type: "text", props: %{content: "data"}, children: []}
      })

      assert :ok = SessionPool.unregister(pool, session_id)
    end

    test "theme_changed subscription emits event on theme change" do
      binary = Application.fetch_env!(:plushie, :test_binary_path)

      {:ok, pool} =
        SessionPool.start_link(
          renderer: binary,
          mode: :mock,
          format: :json,
          max_sessions: 4,
          rust_log: "off"
        )

      session_id = SessionPool.register(pool)

      # Send initial snapshot with default (dark) theme
      SessionPool.send_message(pool, session_id, %{
        type: "snapshot",
        tree: %{
          id: "main",
          type: "window",
          props: %{theme: "dark"},
          children: [%{id: "t", type: "text", props: %{content: "x"}, children: []}]
        }
      })

      Process.sleep(50)

      # Subscribe to theme changes
      SessionPool.send_message(pool, session_id, %{
        type: "subscribe",
        kind: "on_theme_change",
        tag: "theme_sub"
      })

      Process.sleep(50)

      # Change the theme via a new snapshot with a different theme
      SessionPool.send_message(pool, session_id, %{
        type: "snapshot",
        tree: %{
          id: "main",
          type: "window",
          props: %{theme: "nord"},
          children: [%{id: "t", type: "text", props: %{content: "x"}, children: []}]
        }
      })

      # The renderer should emit a theme_changed event
      assert_receive {:plushie_pool_event, ^session_id, msg}, 1000
      assert msg["type"] == "event"
      assert msg["family"] == "theme_changed"
    end

    test "register raises when pool is full" do
      binary = Application.fetch_env!(:plushie, :test_binary_path)

      {:ok, pool} =
        SessionPool.start_link(
          renderer: binary,
          mode: :mock,
          format: :json,
          max_sessions: 2,
          rust_log: "off"
        )

      # Fill the pool
      _s1 = SessionPool.register(pool)
      _s2 = SessionPool.register(pool)

      # Third registration should raise
      assert_raise RuntimeError, ~r/Session pool is full \(2 sessions\)/, fn ->
        SessionPool.register(pool)
      end
    end

    test "register succeeds after unregister frees space" do
      binary = Application.fetch_env!(:plushie, :test_binary_path)

      {:ok, pool} =
        SessionPool.start_link(
          renderer: binary,
          mode: :mock,
          format: :json,
          max_sessions: 2,
          rust_log: "off"
        )

      s1 = SessionPool.register(pool)
      _s2 = SessionPool.register(pool)

      # Pool is full, but unregistering frees space
      SessionPool.send_message(pool, s1, %{
        type: "snapshot",
        tree: %{id: "root", type: "text", props: %{content: "x"}, children: []}
      })

      SessionPool.unregister(pool, s1)

      # Should succeed now
      s3 = SessionPool.register(pool)
      assert is_binary(s3)
    end

    test "send_interact raises for an unknown session", %{pool: pool} do
      assert_raise RuntimeError, ~r/failed to send interact/, fn ->
        SessionPool.send_interact(pool, "missing", %{type: "interact", action: "click"})
      end
    end
  end

  describe "owner death cleanup" do
    test "session slot is freed when owner process dies" do
      binary = Application.fetch_env!(:plushie, :test_binary_path)

      {:ok, pool} =
        SessionPool.start_link(
          renderer: binary,
          mode: :mock,
          format: :json,
          max_sessions: 2,
          rust_log: "off"
        )

      # Register both slots from a spawned process, then kill it.
      test_pid = self()

      doomed =
        spawn(fn ->
          s1 = SessionPool.register(pool)
          send(test_pid, {:registered, s1})
          # Block until told to die (or the test kills us).
          receive do
            :halt -> :ok
          end
        end)

      # Wait for registration to complete.
      assert_receive {:registered, _s1}

      # Fill the second slot from the test process.
      _s2 = SessionPool.register(pool)

      # Pool is full; a third register would fail.
      assert_raise RuntimeError, ~r/Session pool is full/, fn ->
        SessionPool.register(pool)
      end

      # Kill the doomed process. The pool should detect the DOWN and
      # release its session slot.
      Process.exit(doomed, :kill)
      ref = Process.monitor(doomed)
      assert_receive {:DOWN, ^ref, :process, ^doomed, _reason}

      # Give the pool time to process the DOWN message and the
      # renderer's reset_response.
      Process.sleep(200)

      # The freed slot should allow a new registration.
      s3 = SessionPool.register(pool)
      assert is_binary(s3)
    end

    test "pool doesn't hang when owner dies before response arrives" do
      binary = Application.fetch_env!(:plushie, :test_binary_path)

      {:ok, pool} =
        SessionPool.start_link(
          renderer: binary,
          mode: :mock,
          format: :json,
          max_sessions: 4,
          rust_log: "off"
        )

      test_pid = self()

      doomed =
        spawn(fn ->
          session_id = SessionPool.register(pool)

          # Send a snapshot so the session has state.
          SessionPool.send_message(pool, session_id, %{
            type: "snapshot",
            tree: %{id: "root", type: "text", props: %{content: "bye"}, children: []}
          })

          Process.sleep(50)
          send(test_pid, {:ready, session_id})

          # Block until killed.
          receive do
            :halt -> :ok
          end
        end)

      assert_receive {:ready, _session_id}

      # Kill the owner mid-session.
      Process.exit(doomed, :kill)
      ref = Process.monitor(doomed)
      assert_receive {:DOWN, ^ref, :process, ^doomed, _reason}

      # Wait for the pool to clean up.
      Process.sleep(200)

      # The pool is still alive and functional; register a new session
      # and do a round trip to prove it isn't stuck.
      new_id = SessionPool.register(pool)

      SessionPool.send_message(pool, new_id, %{
        type: "snapshot",
        tree: %{id: "root", type: "text", props: %{content: "alive"}, children: []}
      })

      Process.sleep(50)

      {:ok, resp} =
        SessionPool.send_message(
          pool,
          new_id,
          %{type: "query", target: "tree", selector: %{}},
          "query_response"
        )

      assert resp["data"]["props"]["content"] == "alive"
    end
  end

  describe "renderer_mode_flag/1" do
    test "maps multiplexed modes to the correct renderer CLI flag" do
      assert SessionPool.renderer_mode_flag(:mock) == "--mock"
      assert SessionPool.renderer_mode_flag(:headless) == "--headless"
    end

    test "windowed is not a multiplexed renderer mode" do
      assert_raise FunctionClauseError, fn ->
        apply(SessionPool, :renderer_mode_flag, [:windowed])
      end
    end
  end

  describe "Runtime backend" do
    setup do
      binary = Application.fetch_env!(:plushie, :test_binary_path)

      {:ok, pool} =
        SessionPool.start_link(
          renderer: binary,
          mode: :mock,
          format: :json,
          max_sessions: 4,
          rust_log: "off"
        )

      %{pool: pool}
    end

    test "start and basic interaction", %{pool: pool} do
      {:ok, pid} = Runtime.start(Counter, pool: pool)
      assert Runtime.model(pid).count == 0

      Runtime.click(pid, "#inc")
      assert Runtime.model(pid).count == 1

      Runtime.click(pid, "#inc")
      assert Runtime.model(pid).count == 2

      Runtime.stop(pid)
    end

    test "concurrent sessions are isolated", %{pool: pool} do
      {:ok, p1} = Runtime.start(Counter, pool: pool)
      {:ok, p2} = Runtime.start(Counter, pool: pool)

      Runtime.click(p1, "#inc")
      Runtime.click(p1, "#inc")
      Runtime.click(p2, "#inc")

      assert Runtime.model(p1).count == 2
      assert Runtime.model(p2).count == 1

      Runtime.stop(p1)
      Runtime.stop(p2)
    end

    test "reset restores initial state", %{pool: pool} do
      {:ok, pid} = Runtime.start(Counter, pool: pool)
      Runtime.click(pid, "#inc")
      assert Runtime.model(pid).count == 1

      Runtime.reset(pid)
      assert Runtime.model(pid).count == 0

      Runtime.stop(pid)
    end
  end
end
