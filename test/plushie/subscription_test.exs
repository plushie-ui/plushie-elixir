defmodule Plushie.SubscriptionTest do
  use ExUnit.Case, async: true

  alias Plushie.Subscription

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

  describe "on_key_press/0" do
    test "returns a map with type and nil tag" do
      spec = Subscription.on_key_press()
      assert spec == %Subscription{type: :on_key_press, tag: nil}
    end
  end

  describe "on_key_release/0" do
    test "returns a map with type and nil tag" do
      spec = Subscription.on_key_release()
      assert spec == %Subscription{type: :on_key_release, tag: nil}
    end
  end

  describe "on_window_close/0" do
    test "returns a map with type and nil tag" do
      spec = Subscription.on_window_close()
      assert spec == %Subscription{type: :on_window_close, tag: nil}
    end
  end

  describe "on_window_event/0" do
    test "returns a map with type and nil tag" do
      spec = Subscription.on_window_event()
      assert spec == %Subscription{type: :on_window_event, tag: nil}
    end
  end

  describe "on_ime/0" do
    test "returns a map with type and nil tag" do
      spec = Subscription.on_ime()
      assert spec == %Subscription{type: :on_ime, tag: nil}
    end
  end

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

    test "renderer specs use {type, window_id} as key" do
      key = Subscription.key(Subscription.on_key_press())
      assert key == {:on_key_press, nil}
    end

    test "renderer specs with window scope use window_id in key" do
      key = Subscription.key(Subscription.on_key_press(window: "main"))
      assert key == {:on_key_press, "main"}
    end

    test "identical specs produce the same key" do
      a = Subscription.every(500, :ping)
      b = Subscription.every(500, :ping)
      assert Subscription.key(a) == Subscription.key(b)
    end

    test "different types have different keys" do
      k1 = Subscription.key(Subscription.on_key_press())
      k2 = Subscription.key(Subscription.on_key_release())
      assert k1 != k2
    end

    test "max_rate is NOT part of the subscription key" do
      a = Subscription.on_pointer_move(max_rate: 30)
      b = Subscription.on_pointer_move(max_rate: 60)
      c = Subscription.on_pointer_move()
      assert Subscription.key(a) == Subscription.key(b)
      assert Subscription.key(a) == Subscription.key(c)
    end
  end

  describe "max_rate" do
    test "constructors store max_rate from opts" do
      spec = Subscription.on_pointer_move(max_rate: 30)
      assert spec.max_rate == 30
    end

    test "constructors default max_rate to nil when omitted" do
      spec = Subscription.on_pointer_move()
      assert spec.max_rate == nil
    end

    test "max_rate/2 setter applies rate to existing subscription" do
      spec =
        Subscription.on_animation_frame()
        |> Subscription.max_rate(60)

      assert spec.max_rate == 60
      assert spec.type == :on_animation_frame
      assert spec.tag == nil
    end

    test "max_rate of 0 is accepted (subscribe but never emit)" do
      spec = Subscription.on_pointer_move(max_rate: 0)
      assert spec.max_rate == 0
    end

    test "max_rate rejects negative values" do
      assert_raise FunctionClauseError, fn ->
        Subscription.max_rate(Subscription.on_pointer_move(), -1)
      end
    end

    test "all renderer constructors accept max_rate" do
      constructors = [
        :on_key_press,
        :on_key_release,
        :on_pointer_move,
        :on_pointer_button,
        :on_pointer_scroll,
        :on_window_event,
        :on_window_close,
        :on_window_open,
        :on_window_resize,
        :on_window_focus,
        :on_window_unfocus,
        :on_window_move,
        :on_animation_frame,
        :on_theme_change,
        :on_ime,
        :on_pointer_touch,
        :on_file_drop,
        :on_event,
        :on_modifiers_changed
      ]

      for func <- constructors do
        spec = apply(Subscription, func, [[max_rate: 42]])
        assert spec.max_rate == 42, "#{func} should store max_rate"
      end
    end

    test "all renderer constructors accept window scope" do
      constructors = [
        :on_key_press,
        :on_key_release,
        :on_pointer_move,
        :on_pointer_button,
        :on_pointer_scroll,
        :on_window_event,
        :on_window_close,
        :on_window_open,
        :on_window_resize,
        :on_window_focus,
        :on_window_unfocus,
        :on_window_move,
        :on_animation_frame,
        :on_theme_change,
        :on_ime,
        :on_pointer_touch,
        :on_file_drop,
        :on_event,
        :on_modifiers_changed
      ]

      for func <- constructors do
        spec = apply(Subscription, func, [[window: "editor"]])
        assert spec.window_id == "editor", "#{func} should store window scope"
      end
    end
  end

  describe "for_window/2" do
    test "sets the window on each subscription" do
      subscriptions = [
        Subscription.on_key_press(),
        Subscription.on_pointer_move(max_rate: 60)
      ]

      assert [
               %Subscription{type: :on_key_press, window_id: "main"},
               %Subscription{type: :on_pointer_move, max_rate: 60, window_id: "main"}
             ] = Subscription.for_window("main", subscriptions)
    end
  end

  describe "map_tag/2" do
    test "transforms the subscription tag" do
      subscription = Subscription.every(100, :tick)

      assert %Subscription{tag: {:widget, :tick}} =
               Subscription.map_tag(subscription, fn tag -> {:widget, tag} end)
    end

    test "supports tuple tags" do
      subscription = %Subscription{type: :every, interval: 100, tag: {:widget, "main", "timer"}}

      assert Subscription.key(subscription) == {:every, 100, {:widget, "main", "timer"}}
    end
  end
end
