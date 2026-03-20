defmodule Toddy.SubscriptionParityTest do
  @moduledoc """
  Tests for all new subscriptions added in the iced parity pass.
  Does not duplicate tests from subscription_test.exs.
  """
  use ExUnit.Case, async: true

  alias Toddy.Subscription

  describe "on_window_open/1" do
    test "returns correct subscription spec" do
      sub = Subscription.on_window_open(:win_open)
      assert sub == %Subscription{type: :on_window_open, tag: :win_open}
    end
  end

  describe "on_window_resize/1" do
    test "returns correct subscription spec" do
      sub = Subscription.on_window_resize(:win_resize)
      assert sub == %Subscription{type: :on_window_resize, tag: :win_resize}
    end
  end

  describe "on_window_focus/1" do
    test "returns correct subscription spec" do
      sub = Subscription.on_window_focus(:win_focus)
      assert sub == %Subscription{type: :on_window_focus, tag: :win_focus}
    end
  end

  describe "on_window_unfocus/1" do
    test "returns correct subscription spec" do
      sub = Subscription.on_window_unfocus(:win_unfocus)
      assert sub == %Subscription{type: :on_window_unfocus, tag: :win_unfocus}
    end
  end

  describe "on_window_move/1" do
    test "returns correct subscription spec" do
      sub = Subscription.on_window_move(:win_move)
      assert sub == %Subscription{type: :on_window_move, tag: :win_move}
    end
  end

  describe "on_mouse_move/1" do
    test "returns correct subscription spec" do
      sub = Subscription.on_mouse_move(:mouse)
      assert sub == %Subscription{type: :on_mouse_move, tag: :mouse}
    end
  end

  describe "on_mouse_button/1" do
    test "returns correct subscription spec" do
      sub = Subscription.on_mouse_button(:btn)
      assert sub == %Subscription{type: :on_mouse_button, tag: :btn}
    end
  end

  describe "on_mouse_scroll/1" do
    test "returns correct subscription spec" do
      sub = Subscription.on_mouse_scroll(:scroll)
      assert sub == %Subscription{type: :on_mouse_scroll, tag: :scroll}
    end
  end

  describe "on_touch/1" do
    test "returns correct subscription spec" do
      sub = Subscription.on_touch(:touch)
      assert sub == %Subscription{type: :on_touch, tag: :touch}
    end
  end

  describe "on_theme_change/1" do
    test "returns correct subscription spec" do
      sub = Subscription.on_theme_change(:theme)
      assert sub == %Subscription{type: :on_theme_change, tag: :theme}
    end
  end

  describe "on_animation_frame/1" do
    test "returns correct subscription spec" do
      sub = Subscription.on_animation_frame(:frame)
      assert sub == %Subscription{type: :on_animation_frame, tag: :frame}
    end
  end

  describe "on_file_drop/1" do
    test "returns correct subscription spec" do
      sub = Subscription.on_file_drop(:drop)
      assert sub == %Subscription{type: :on_file_drop, tag: :drop}
    end
  end

  describe "on_event/1" do
    test "returns correct subscription spec" do
      sub = Subscription.on_event(:any)
      assert sub == %Subscription{type: :on_event, tag: :any}
    end
  end

  describe "batch/1" do
    test "returns the list unchanged" do
      subs = [
        Subscription.on_mouse_move(:mouse),
        Subscription.on_touch(:touch)
      ]

      assert Subscription.batch(subs) == subs
    end

    test "handles empty list" do
      assert Subscription.batch([]) == []
    end

    test "handles single subscription" do
      sub = Subscription.on_theme_change(:theme)
      assert Subscription.batch([sub]) == [sub]
    end
  end

  # ---------------------------------------------------------------------------
  # Subscription key uniqueness
  # ---------------------------------------------------------------------------

  describe "key/1 for new subscriptions" do
    test "keys are unique per type+tag" do
      subs = [
        Subscription.on_window_open(:a),
        Subscription.on_window_resize(:a),
        Subscription.on_mouse_move(:a),
        Subscription.on_touch(:a),
        Subscription.on_theme_change(:a),
        Subscription.on_animation_frame(:a),
        Subscription.on_file_drop(:a),
        Subscription.on_event(:a)
      ]

      keys = Enum.map(subs, &Subscription.key/1)
      assert length(Enum.uniq(keys)) == length(keys)
    end

    test "same type different tags produce different keys" do
      k1 = Subscription.key(Subscription.on_mouse_move(:alpha))
      k2 = Subscription.key(Subscription.on_mouse_move(:beta))
      assert k1 != k2
    end

    test "key includes type and tag" do
      key = Subscription.key(Subscription.on_animation_frame(:tick))
      assert key == {:on_animation_frame, :tick}
    end
  end
end
