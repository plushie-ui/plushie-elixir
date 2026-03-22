defmodule Plushie.Test.SessionPoolTest do
  use ExUnit.Case, async: false

  alias Plushie.Test.Backend.MockRenderer
  alias Plushie.Test.SessionPool

  # Use the mock renderer for speed -- no display server needed.
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

    test "register succeeds after unregister frees a slot" do
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

      # Pool is full, but unregistering frees a slot
      SessionPool.send_message(pool, s1, %{
        type: "snapshot",
        tree: %{id: "root", type: "text", props: %{content: "x"}, children: []}
      })

      SessionPool.unregister(pool, s1)

      # Should succeed now
      s3 = SessionPool.register(pool)
      assert is_binary(s3)
    end
  end

  describe "Mock backend" do
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
      {:ok, pid} = MockRenderer.start(Counter, pool: pool)
      assert MockRenderer.model(pid).count == 0

      MockRenderer.click(pid, "#increment")
      assert MockRenderer.model(pid).count == 1

      MockRenderer.click(pid, "#increment")
      assert MockRenderer.model(pid).count == 2

      MockRenderer.stop(pid)
    end

    test "concurrent sessions are isolated", %{pool: pool} do
      {:ok, p1} = MockRenderer.start(Counter, pool: pool)
      {:ok, p2} = MockRenderer.start(Counter, pool: pool)

      MockRenderer.click(p1, "#increment")
      MockRenderer.click(p1, "#increment")
      MockRenderer.click(p2, "#increment")

      assert MockRenderer.model(p1).count == 2
      assert MockRenderer.model(p2).count == 1

      MockRenderer.stop(p1)
      MockRenderer.stop(p2)
    end

    test "reset restores initial state", %{pool: pool} do
      {:ok, pid} = MockRenderer.start(Counter, pool: pool)
      MockRenderer.click(pid, "#increment")
      assert MockRenderer.model(pid).count == 1

      MockRenderer.reset(pid)
      assert MockRenderer.model(pid).count == 0

      MockRenderer.stop(pid)
    end
  end
end
