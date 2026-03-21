defmodule Plushie.SubscriptionTest do
  use ExUnit.Case, async: true

  alias Plushie.Subscription

  # ---------------------------------------------------------------------------
  # describe "constructors"
  # ---------------------------------------------------------------------------

  describe "every/2" do
    test "returns a map with type, interval, and tag" do
      spec = Subscription.every(1000, :tick)
      assert spec == %Subscription{type: :every, interval: 1000, tag: :tick}
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
      assert spec == %Subscription{type: :on_key_press, tag: :key_down}
    end

    test "rejects non-atom tag" do
      assert_raise FunctionClauseError, fn -> Subscription.on_key_press("nope") end
    end
  end

  describe "on_key_release/1" do
    test "returns a map with type and tag" do
      spec = Subscription.on_key_release(:key_up)
      assert spec == %Subscription{type: :on_key_release, tag: :key_up}
    end

    test "rejects non-atom tag" do
      assert_raise FunctionClauseError, fn -> Subscription.on_key_release(42) end
    end
  end

  describe "on_window_close/1" do
    test "returns a map with type and tag" do
      spec = Subscription.on_window_close(:closing)
      assert spec == %Subscription{type: :on_window_close, tag: :closing}
    end

    test "rejects non-atom tag" do
      assert_raise FunctionClauseError, fn -> Subscription.on_window_close("nope") end
    end
  end

  describe "on_window_event/1" do
    test "returns a map with type and tag" do
      spec = Subscription.on_window_event(:resized)
      assert spec == %Subscription{type: :on_window_event, tag: :resized}
    end

    test "rejects non-atom tag" do
      assert_raise FunctionClauseError, fn -> Subscription.on_window_event({}) end
    end
  end

  describe "on_ime/1" do
    test "returns a map with type and tag" do
      spec = Subscription.on_ime(:ime_input)
      assert spec == %Subscription{type: :on_ime, tag: :ime_input}
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
      key = Subscription.key(%Subscription{type: :every, interval: 1000, tag: :tick})
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

    test "max_rate is NOT part of the subscription key" do
      a = Subscription.on_mouse_move(:mouse, max_rate: 30)
      b = Subscription.on_mouse_move(:mouse, max_rate: 60)
      c = Subscription.on_mouse_move(:mouse)
      assert Subscription.key(a) == Subscription.key(b)
      assert Subscription.key(a) == Subscription.key(c)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "max_rate"
  # ---------------------------------------------------------------------------

  describe "max_rate" do
    test "constructors store max_rate from opts" do
      spec = Subscription.on_mouse_move(:mouse, max_rate: 30)
      assert spec.max_rate == 30
    end

    test "constructors default max_rate to nil when omitted" do
      spec = Subscription.on_mouse_move(:mouse)
      assert spec.max_rate == nil
    end

    test "max_rate/2 setter applies rate to existing subscription" do
      spec =
        Subscription.on_animation_frame(:frame)
        |> Subscription.max_rate(60)

      assert spec.max_rate == 60
      assert spec.type == :on_animation_frame
      assert spec.tag == :frame
    end

    test "max_rate of 0 is accepted (subscribe but never emit)" do
      spec = Subscription.on_mouse_move(:mouse, max_rate: 0)
      assert spec.max_rate == 0
    end

    test "max_rate rejects negative values" do
      assert_raise FunctionClauseError, fn ->
        Subscription.max_rate(Subscription.on_mouse_move(:m), -1)
      end
    end

    test "all renderer constructors accept max_rate" do
      constructors = [
        {:on_key_press, :k},
        {:on_key_release, :k},
        {:on_mouse_move, :m},
        {:on_mouse_button, :m},
        {:on_mouse_scroll, :m},
        {:on_window_event, :w},
        {:on_window_close, :w},
        {:on_window_open, :w},
        {:on_window_resize, :w},
        {:on_window_focus, :w},
        {:on_window_unfocus, :w},
        {:on_window_move, :w},
        {:on_animation_frame, :f},
        {:on_theme_change, :t},
        {:on_ime, :i},
        {:on_touch, :t},
        {:on_file_drop, :f},
        {:on_event, :e},
        {:on_modifiers_changed, :m}
      ]

      for {func, tag} <- constructors do
        spec = apply(Subscription, func, [tag, [max_rate: 42]])
        assert spec.max_rate == 42, "#{func} should store max_rate"
      end
    end
  end
end
