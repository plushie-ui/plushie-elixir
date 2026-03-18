defmodule Julep.Test.SessionPoolTest do
  use ExUnit.Case, async: false

  alias Julep.Test.Backend.Pooled
  alias Julep.Test.SessionPool

  # Use the mock renderer for speed -- no display server needed.
  # These tests verify the multiplexing infrastructure, not rendering.

  describe "SessionPool" do
    setup do
      {:ok, pool} = SessionPool.start_link(mode: :mock, format: :json, max_sessions: 4)
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
  end

  describe "Pooled backend" do
    setup do
      {:ok, pool} = SessionPool.start_link(mode: :mock, format: :json, max_sessions: 4)
      %{pool: pool}
    end

    test "start and basic interaction", %{pool: pool} do
      {:ok, pid} = Pooled.start(Julep.Examples.Counter, pool: pool)
      assert Pooled.model(pid).count == 0

      Pooled.click(pid, "#increment")
      assert Pooled.model(pid).count == 1

      Pooled.click(pid, "#increment")
      assert Pooled.model(pid).count == 2

      Pooled.stop(pid)
    end

    test "concurrent sessions are isolated", %{pool: pool} do
      {:ok, p1} = Pooled.start(Julep.Examples.Counter, pool: pool)
      {:ok, p2} = Pooled.start(Julep.Examples.Counter, pool: pool)

      Pooled.click(p1, "#increment")
      Pooled.click(p1, "#increment")
      Pooled.click(p2, "#increment")

      assert Pooled.model(p1).count == 2
      assert Pooled.model(p2).count == 1

      Pooled.stop(p1)
      Pooled.stop(p2)
    end

    test "reset restores initial state", %{pool: pool} do
      {:ok, pid} = Pooled.start(Julep.Examples.Counter, pool: pool)
      Pooled.click(pid, "#increment")
      assert Pooled.model(pid).count == 1

      Pooled.reset(pid)
      assert Pooled.model(pid).count == 0

      Pooled.stop(pid)
    end
  end
end
