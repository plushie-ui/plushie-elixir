defmodule Toddy.SubscriptionTest do
  use ExUnit.Case, async: true

  alias Toddy.Subscription

  # ---------------------------------------------------------------------------
  # describe "constructors"
  # ---------------------------------------------------------------------------

  describe "every/2" do
    test "returns a map with type, interval, and tag" do
      spec = Subscription.every(1000, :tick)
      assert spec == %{type: :every, interval: 1000, tag: :tick}
    end

    test "rejects non-positive interval" do
      assert_raise FunctionClauseError, fn -> Subscription.every(0, :tick) end
      assert_raise FunctionClauseError, fn -> Subscription.every(-1, :tick) end
    end

    test "rejects non-integer interval" do
      assert_raise FunctionClauseError, fn -> Subscription.every(1.5, :tick) end
    end

    test "rejects non-atom tag" do
      assert_raise FunctionClauseError, fn -> Subscription.every(1000, "tick") end
    end
  end

  describe "on_key_press/1" do
    test "returns a map with type and tag" do
      spec = Subscription.on_key_press(:key_down)
      assert spec == %{type: :on_key_press, tag: :key_down}
    end

    test "rejects non-atom tag" do
      assert_raise FunctionClauseError, fn -> Subscription.on_key_press("nope") end
    end
  end

  describe "on_key_release/1" do
    test "returns a map with type and tag" do
      spec = Subscription.on_key_release(:key_up)
      assert spec == %{type: :on_key_release, tag: :key_up}
    end

    test "rejects non-atom tag" do
      assert_raise FunctionClauseError, fn -> Subscription.on_key_release(42) end
    end
  end

  describe "on_window_close/1" do
    test "returns a map with type and tag" do
      spec = Subscription.on_window_close(:closing)
      assert spec == %{type: :on_window_close, tag: :closing}
    end

    test "rejects non-atom tag" do
      assert_raise FunctionClauseError, fn -> Subscription.on_window_close("nope") end
    end
  end

  describe "on_window_event/1" do
    test "returns a map with type and tag" do
      spec = Subscription.on_window_event(:resized)
      assert spec == %{type: :on_window_event, tag: :resized}
    end

    test "rejects non-atom tag" do
      assert_raise FunctionClauseError, fn -> Subscription.on_window_event({}) end
    end
  end

  describe "on_ime/1" do
    test "returns a map with type and tag" do
      spec = Subscription.on_ime(:ime_input)
      assert spec == %{type: :on_ime, tag: :ime_input}
    end

    test "rejects non-atom tag" do
      assert_raise FunctionClauseError, fn -> Subscription.on_ime("nope") end
    end
  end

  # ---------------------------------------------------------------------------
  # describe "key/1"
  # ---------------------------------------------------------------------------

  describe "key/1" do
    test "every specs include interval in key" do
      key = Subscription.key(%{type: :every, interval: 1000, tag: :tick})
      assert key == {:every, 1000, :tick}
    end

    test "every specs with different intervals have different keys" do
      k1 = Subscription.key(Subscription.every(1000, :tick))
      k2 = Subscription.key(Subscription.every(2000, :tick))
      assert k1 != k2
    end

    test "non-every specs use {type, tag} as key" do
      key = Subscription.key(Subscription.on_key_press(:key_down))
      assert key == {:on_key_press, :key_down}
    end

    test "identical specs produce the same key" do
      a = Subscription.every(500, :ping)
      b = Subscription.every(500, :ping)
      assert Subscription.key(a) == Subscription.key(b)
    end

    test "different types with same tag have different keys" do
      k1 = Subscription.key(Subscription.on_key_press(:input))
      k2 = Subscription.key(Subscription.on_key_release(:input))
      assert k1 != k2
    end
  end
end
