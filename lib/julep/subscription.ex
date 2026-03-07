defmodule Julep.Subscription do
  @moduledoc """
  Declarative subscription specifications for Julep apps.

  Subscriptions are ongoing event sources. Return them from `subscribe/1`
  and the runtime manages their lifecycle automatically -- starting new
  subscriptions and stopping removed ones by diffing the list each cycle.

  ## Tag semantics -- two different roles

  The `event_tag` parameter means different things depending on the
  subscription type. Understanding this distinction is essential.

  ### Timer subscriptions (`:every`)

  For `every/2`, the tag **becomes the event wrapper**. Your `update/2`
  receives `{tag, timestamp}`. The tag IS the message identifier.

      Julep.Subscription.every(1000, :tick)
      # update/2 receives: {:tick, 1234567890}

  ### Renderer subscriptions (all others)

  For renderer subscriptions (`on_key_press`, `on_key_release`,
  `on_window_close`, etc.), the tag is **management-only**. It is sent
  to the renderer to register/unregister the listener, and it is used by
  the runtime to diff subscription lists. The tag does **NOT** appear in
  the event tuple delivered to `update/2`. Events arrive as fixed tuples
  documented on each constructor.

      Julep.Subscription.on_key_press(:my_keys)
      # update/2 receives: {:key_press, %Julep.KeyEvent{}} -- NOT {:my_keys, ...}

      Julep.Subscription.on_window_resize(:win_resize)
      # update/2 receives: {:window_resized, window_id, width, height}

  ## Example

      def subscribe(model) do
        subs = []
        if model.timer_running do
          subs = [Julep.Subscription.every(1000, :tick) | subs]
        end
        subs
      end

      def update(model, {:tick, _timestamp}) do
        # Timer tag appears as the first element of the event tuple.
        %{model | ticks: model.ticks + 1}
      end

      def update(model, {:key_press, %Julep.KeyEvent{key: "Escape"}}) do
        # Renderer subscription tag is NOT in the event -- match on :key_press.
        %{model | menu_open: false}
      end
  """

  @typedoc """
  A subscription specification. Every subscription has a `:type` atom
  identifying the kind (`:every`, `:on_key_press`, etc.) and a `:tag`
  atom used for subscription management. For timer subscriptions, the
  tag is also the event prefix in `update/2` (e.g. `{tag, timestamp}`).
  For renderer subscriptions (keyboard, window, mouse, etc.), the tag
  is sent to the renderer to register/unregister the listener but is
  not included in the event tuple -- those use fixed event names like
  `:key_press`, `:key_release`, etc. Additional keys vary by type.
  """
  @type t :: %{optional(atom()) => term(), type: atom(), tag: atom()}

  @doc """
  Timer that fires every `interval_ms` milliseconds.

  The tag becomes the event wrapper -- `update/2` receives
  `{event_tag, timestamp}` where `timestamp` is
  `System.monotonic_time(:millisecond)`.

  ## Example

      Julep.Subscription.every(1000, :tick)

      # In update/2:
      def update(model, {:tick, _timestamp}), do: %{model | count: model.count + 1}
  """
  @spec every(interval_ms :: pos_integer(), event_tag :: atom()) :: t()
  def every(interval_ms, event_tag)
      when is_integer(interval_ms) and interval_ms > 0 and is_atom(event_tag) do
    %{type: :every, interval: interval_ms, tag: event_tag}
  end

  @doc """
  Fires on key press events from the renderer.

  Delivers `{:key_press, %Julep.KeyEvent{}}` to `update/2`. The
  `event_tag` is used **only for subscription management** (registration
  and diffing). It does NOT appear in the event tuple.

  See `Julep.KeyEvent` and `Julep.KeyModifiers` for struct definitions.

  ## Example

      Julep.Subscription.on_key_press(:my_keys)

      # In update/2 -- match on :key_press, NOT the tag:
      def update(model, {:key_press, %Julep.KeyEvent{key: "Enter"}}), do: ...
  """
  @spec on_key_press(event_tag :: atom()) :: t()
  def on_key_press(event_tag) when is_atom(event_tag) do
    %{type: :on_key_press, tag: event_tag}
  end

  @doc """
  Fires on key release events from the renderer.

  Delivers `{:key_release, %Julep.KeyEvent{}}` to `update/2`. Same
  format as `on_key_press/1`. The `event_tag` is used for subscription
  management only -- it does NOT appear in the event tuple.

  ## Example

      Julep.Subscription.on_key_release(:keys)

      # In update/2:
      def update(model, {:key_release, %Julep.KeyEvent{key: key}}), do: ...
  """
  @spec on_key_release(event_tag :: atom()) :: t()
  def on_key_release(event_tag) when is_atom(event_tag) do
    %{type: :on_key_release, tag: event_tag}
  end

  @doc """
  Fires when a window close is requested (e.g. user clicks the close button).

  Delivers `{:window_close_requested, window_id}` to `update/2`.
  The `event_tag` is for subscription management only.

  ## Example

      Julep.Subscription.on_window_close(:win_close)

      # In update/2:
      def update(model, {:window_close_requested, window_id}), do: ...
  """
  @spec on_window_close(event_tag :: atom()) :: t()
  def on_window_close(event_tag) when is_atom(event_tag) do
    %{type: :on_window_close, tag: event_tag}
  end

  @doc """
  Fires on general window events (resize, move, focus, etc.).

  Delivers various `{:window_*, ...}` tuples depending on the event.
  The `event_tag` is for subscription management only.
  """
  @spec on_window_event(event_tag :: atom()) :: t()
  def on_window_event(event_tag) when is_atom(event_tag) do
    %{type: :on_window_event, tag: event_tag}
  end

  @doc """
  Fires when a new window is opened.

  Delivers `{:window_opened, window_id, position, {width, height}}` to
  `update/2`. `position` is `{x, y}` or `nil`. The `event_tag` is for
  subscription management only.
  """
  @spec on_window_open(event_tag :: atom()) :: t()
  def on_window_open(event_tag) when is_atom(event_tag) do
    %{type: :on_window_open, tag: event_tag}
  end

  @doc """
  Fires when a window is resized.

  Delivers `{:window_resized, window_id, width, height}` to `update/2`.
  The `event_tag` is for subscription management only.
  """
  @spec on_window_resize(event_tag :: atom()) :: t()
  def on_window_resize(event_tag) when is_atom(event_tag) do
    %{type: :on_window_resize, tag: event_tag}
  end

  @doc """
  Fires when a window gains focus.

  Delivers `{:window_focused, window_id}` to `update/2`.
  The `event_tag` is for subscription management only.
  """
  @spec on_window_focus(event_tag :: atom()) :: t()
  def on_window_focus(event_tag) when is_atom(event_tag) do
    %{type: :on_window_focus, tag: event_tag}
  end

  @doc """
  Fires when a window loses focus.

  Delivers `{:window_unfocused, window_id}` to `update/2`.
  The `event_tag` is for subscription management only.
  """
  @spec on_window_unfocus(event_tag :: atom()) :: t()
  def on_window_unfocus(event_tag) when is_atom(event_tag) do
    %{type: :on_window_unfocus, tag: event_tag}
  end

  @doc """
  Fires when a window is moved.

  Delivers `{:window_moved, window_id, x, y}` to `update/2`.
  The `event_tag` is for subscription management only.
  """
  @spec on_window_move(event_tag :: atom()) :: t()
  def on_window_move(event_tag) when is_atom(event_tag) do
    %{type: :on_window_move, tag: event_tag}
  end

  @doc """
  Fires on mouse movement.

  Delivers `{:cursor_moved, x, y}` to `update/2`.
  The `event_tag` is for subscription management only.
  """
  @spec on_mouse_move(event_tag :: atom()) :: t()
  def on_mouse_move(event_tag) when is_atom(event_tag) do
    %{type: :on_mouse_move, tag: event_tag}
  end

  @doc """
  Fires on mouse button press/release.

  Delivers `{:button_pressed, button}` or `{:button_released, button}`
  to `update/2`. `button` is a string like `"left"`, `"right"`, `"middle"`.
  The `event_tag` is for subscription management only.
  """
  @spec on_mouse_button(event_tag :: atom()) :: t()
  def on_mouse_button(event_tag) when is_atom(event_tag) do
    %{type: :on_mouse_button, tag: event_tag}
  end

  @doc """
  Fires on mouse scroll events.

  Delivers `{:wheel_scrolled, delta_x, delta_y, unit}` to `update/2`.
  The `event_tag` is for subscription management only.
  """
  @spec on_mouse_scroll(event_tag :: atom()) :: t()
  def on_mouse_scroll(event_tag) when is_atom(event_tag) do
    %{type: :on_mouse_scroll, tag: event_tag}
  end

  @doc """
  Fires on IME (Input Method Editor) events.

  Delivers one of:

  * `{:ime_opened}` -- the IME session started
  * `{:ime_preedit, text, {start, end} | nil}` -- composing text updated
  * `{:ime_commit, text}` -- final text committed
  * `{:ime_closed}` -- the IME session ended

  The `event_tag` is for subscription management only.
  """
  @spec on_ime(event_tag :: atom()) :: t()
  def on_ime(event_tag) when is_atom(event_tag) do
    %{type: :on_ime, tag: event_tag}
  end

  @doc """
  Fires on touch events.

  Delivers `{:finger_pressed, finger_id, x, y}`,
  `{:finger_moved, finger_id, x, y}`,
  `{:finger_lifted, finger_id, x, y}`, or
  `{:finger_lost, finger_id, x, y}` to `update/2`.
  The `event_tag` is for subscription management only.
  """
  @spec on_touch(event_tag :: atom()) :: t()
  def on_touch(event_tag) when is_atom(event_tag) do
    %{type: :on_touch, tag: event_tag}
  end

  @doc """
  Fires when the system theme changes (light/dark mode).

  Delivers `{:theme_changed, mode}` to `update/2` where `mode` is
  a string like `"light"` or `"dark"`. The `event_tag` is for subscription
  management only.
  """
  @spec on_theme_change(event_tag :: atom()) :: t()
  def on_theme_change(event_tag) when is_atom(event_tag) do
    %{type: :on_theme_change, tag: event_tag}
  end

  @doc """
  Fires on each animation frame (vsync tick).

  Delivers `{:animation_frame, timestamp}` to `update/2`.
  The `event_tag` is for subscription management only.
  """
  @spec on_animation_frame(event_tag :: atom()) :: t()
  def on_animation_frame(event_tag) when is_atom(event_tag) do
    %{type: :on_animation_frame, tag: event_tag}
  end

  @doc """
  Fires when a file is dropped on a window.

  Delivers `{:file_dropped, window_id, path}` to `update/2`.
  Also fires `{:file_hovered, window_id, path}` while hovering
  and `{:files_hovered_left, window_id}` when the hover exits.
  The `event_tag` is for subscription management only.
  """
  @spec on_file_drop(event_tag :: atom()) :: t()
  def on_file_drop(event_tag) when is_atom(event_tag) do
    %{type: :on_file_drop, tag: event_tag}
  end

  @doc """
  Fires on any renderer event (catch-all).

  Use this to receive all event types that the renderer emits.
  The event tuple shape varies by event family. The `event_tag` is for
  subscription management only.
  """
  @spec on_event(event_tag :: atom()) :: t()
  def on_event(event_tag) when is_atom(event_tag) do
    %{type: :on_event, tag: event_tag}
  end

  @doc """
  Subscribes to keyboard modifier state changes (shift, ctrl, alt, etc.).
  The `event_tag` is for subscription management only.
  """
  @spec on_modifiers_changed(tag :: atom()) :: t()
  def on_modifiers_changed(tag) when is_atom(tag) do
    %{type: :on_modifiers_changed, tag: tag}
  end

  @doc "Combines a list of subscriptions. Identity function -- returns the list as-is."
  @spec batch(subscriptions :: [t()]) :: [t()]
  def batch(subscriptions) when is_list(subscriptions), do: subscriptions

  @doc """
  Returns a key that uniquely identifies this subscription spec.
  Two specs with the same key are considered the same subscription.
  """
  @spec key(sub :: t()) :: term()
  def key(%{type: type, tag: tag} = sub) do
    case type do
      :every -> {:every, Map.get(sub, :interval), tag}
      other -> {other, tag}
    end
  end
end
