defmodule Plushie.SubscriptionParityTest do
  @moduledoc """
  Tests for all new subscriptions added in the iced parity pass.
  Does not duplicate tests from subscription_test.exs.
  """
  use ExUnit.Case, async: true

  alias Plushie.Subscription

  describe "on_window_open/0" do
    test "returns correct subscription spec" do
      sub = Subscription.on_window_open()
      assert sub == %Subscription{type: :on_window_open, tag: nil}
    end
  end

  describe "on_window_resize/0" do
    test "returns correct subscription spec" do
      sub = Subscription.on_window_resize()
      assert sub == %Subscription{type: :on_window_resize, tag: nil}
    end
  end

  describe "on_window_focus/0" do
    test "returns correct subscription spec" do
      sub = Subscription.on_window_focus()
      assert sub == %Subscription{type: :on_window_focus, tag: nil}
    end
  end

  describe "on_window_unfocus/0" do
    test "returns correct subscription spec" do
      sub = Subscription.on_window_unfocus()
      assert sub == %Subscription{type: :on_window_unfocus, tag: nil}
    end
  end

  describe "on_window_move/0" do
    test "returns correct subscription spec" do
      sub = Subscription.on_window_move()
      assert sub == %Subscription{type: :on_window_move, tag: nil}
    end
  end

  describe "on_pointer_move/0" do
    test "returns correct subscription spec" do
      sub = Subscription.on_pointer_move()
      assert sub == %Subscription{type: :on_pointer_move, tag: nil}
    end
  end

  describe "on_pointer_button/0" do
    test "returns correct subscription spec" do
      sub = Subscription.on_pointer_button()
      assert sub == %Subscription{type: :on_pointer_button, tag: nil}
    end
  end

  describe "on_pointer_scroll/0" do
    test "returns correct subscription spec" do
      sub = Subscription.on_pointer_scroll()
      assert sub == %Subscription{type: :on_pointer_scroll, tag: nil}
    end
  end

  describe "on_pointer_touch/0" do
    test "returns correct subscription spec" do
      sub = Subscription.on_pointer_touch()
      assert sub == %Subscription{type: :on_pointer_touch, tag: nil}
    end
  end

  describe "on_theme_change/0" do
    test "returns correct subscription spec" do
      sub = Subscription.on_theme_change()
      assert sub == %Subscription{type: :on_theme_change, tag: nil}
    end
  end

  describe "on_animation_frame/0" do
    test "returns correct subscription spec" do
      sub = Subscription.on_animation_frame()
      assert sub == %Subscription{type: :on_animation_frame, tag: nil}
    end
  end

  describe "on_file_drop/0" do
    test "returns correct subscription spec" do
      sub = Subscription.on_file_drop()
      assert sub == %Subscription{type: :on_file_drop, tag: nil}
    end
  end

  describe "on_event/0" do
    test "returns correct subscription spec" do
      sub = Subscription.on_event()
      assert sub == %Subscription{type: :on_event, tag: nil}
    end
  end

  describe "batch/1" do
    test "returns the list unchanged" do
      subs = [
        Subscription.on_pointer_move(),
        Subscription.on_pointer_touch()
      ]

      assert Subscription.batch(subs) == subs
    end

    test "handles empty list" do
      assert Subscription.batch([]) == []
    end

    test "handles single subscription" do
      sub = Subscription.on_theme_change()
      assert Subscription.batch([sub]) == [sub]
    end

    test "rejects non-subscription elements" do
      assert_raise ArgumentError, ~r/expected %Plushie.Subscription{}/, fn ->
        Subscription.batch([Subscription.on_theme_change(), :not_a_subscription])
      end
    end
  end

  describe "key/1 for new subscriptions" do
    test "keys are unique per type" do
      subs = [
        Subscription.on_window_open(),
        Subscription.on_window_resize(),
        Subscription.on_pointer_move(),
        Subscription.on_pointer_touch(),
        Subscription.on_theme_change(),
        Subscription.on_animation_frame(),
        Subscription.on_file_drop(),
        Subscription.on_event()
      ]

      keys = Enum.map(subs, &Subscription.key/1)
      assert length(Enum.uniq(keys)) == length(keys)
    end

    test "same type with different window scopes produce different keys" do
      k1 = Subscription.key(Subscription.on_pointer_move(window: "a"))
      k2 = Subscription.key(Subscription.on_pointer_move(window: "b"))
      assert k1 != k2
    end

    test "key includes type and window_id" do
      key = Subscription.key(Subscription.on_animation_frame())
      assert key == {:on_animation_frame, nil}
    end
  end
end
