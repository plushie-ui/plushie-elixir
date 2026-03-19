defmodule Toddy.Subscription do
  @moduledoc """
  Declarative subscription specifications for Toddy apps.

  Subscriptions are ongoing event sources. Return them from `subscribe/1`
  and the runtime manages their lifecycle automatically -- starting new
  subscriptions and stopping removed ones by diffing the list each cycle.

  ## Tag semantics -- two different roles

  The `event_tag` parameter means different things depending on the
  subscription type. Understanding this distinction is essential.

  ### Timer subscriptions (`:every`)

  For `every/2`, the tag **becomes part of the Timer struct**. Your `update/2`
  receives `%Toddy.Event.Timer{tag: tag, timestamp: timestamp}`.

      Toddy.Subscription.every(1000, :tick)
      # update/2 receives: %Toddy.Event.Timer{tag: :tick, timestamp: 1234567890}

  ### Renderer subscriptions (all others)

  For renderer subscriptions (`on_key_press`, `on_key_release`,
  `on_window_close`, etc.), the tag is **management-only**. It is sent
  to the renderer to register/unregister the listener, and it is used by
  the runtime to diff subscription lists. The tag does **NOT** appear in
  the event tuple delivered to `update/2`. Events arrive as fixed tuples
  documented on each constructor.

      Toddy.Subscription.on_key_press(:my_keys)
      # update/2 receives: %Toddy.Event.Key{type: :press, ...} -- NOT {:my_keys, ...}

      Toddy.Subscription.on_window_resize(:win_resize)
      # update/2 receives: %Toddy.Event.Window{type: :resized, ...}

  ## Example

      def subscribe(model) do
        subs = []
        if model.timer_running do
          subs = [Toddy.Subscription.every(1000, :tick) | subs]
        end
        subs
      end

      def update(model, %Toddy.Event.Timer{tag: :tick}) do
        # Timer events are Timer structs with tag and timestamp fields.
        %{model | ticks: model.ticks + 1}
      end

      def update(model, %Toddy.Event.Key{type: :press, key: :escape}) do
        # Renderer subscription tag is NOT in the event -- match on struct type.
        %{model | menu_open: false}
      end
  """

  @typedoc """
  A subscription specification. Every subscription has a `:type` atom
  identifying the kind (`:every`, `:on_key_press`, etc.) and a `:tag`
  atom used for subscription management. For timer subscriptions, the
  tag is also part of the Timer event struct in `update/2`
  (e.g. `%Toddy.Event.Timer{tag: tag, timestamp: timestamp}`).
  For renderer subscriptions (keyboard, window, mouse, etc.), the tag
  is sent to the renderer to register/unregister the listener but is
  not included in the event struct -- those use typed event structs like
  `%Toddy.Event.Key{}`, `%Toddy.Event.Window{}`, etc.
  """
  @type t :: %{optional(atom()) => term(), type: atom(), tag: atom()}

  @doc """
  Timer that fires every `interval_ms` milliseconds.

  The tag becomes part of the Timer event struct -- `update/2` receives
  `%Toddy.Event.Timer{tag: event_tag, timestamp: timestamp}` where
  `timestamp` is `System.monotonic_time(:millisecond)`.

  ## Example

      Toddy.Subscription.every(1000, :tick)

      # In update/2:
      def update(model, %Toddy.Event.Timer{tag: :tick}), do: %{model | count: model.count + 1}
  """
  @spec every(interval_ms :: pos_integer(), event_tag :: atom()) :: t()
  def every(interval_ms, event_tag)
      when is_integer(interval_ms) and interval_ms > 0 and is_atom(event_tag) do
    %{type: :every, interval: interval_ms, tag: event_tag}
  end

  @doc """
  Fires on key press events from the renderer.

  Delivers `%Toddy.Event.Key{type: :press, ...}` to `update/2`. The
  `event_tag` is used **only for subscription management** (registration
  and diffing). It does NOT appear in the event struct.

  See `Toddy.Event.Key` and `Toddy.KeyModifiers` for struct definitions.

  ## Example

      Toddy.Subscription.on_key_press(:my_keys)

      # In update/2 -- match on the struct, NOT the tag:
      def update(model, %Toddy.Event.Key{type: :press, key: :enter}), do: ...
  """
  @spec on_key_press(event_tag :: atom()) :: t()
  def on_key_press(event_tag) when is_atom(event_tag) do
    %{type: :on_key_press, tag: event_tag}
  end

  @doc """
  Fires on key release events from the renderer.

  Delivers `%Toddy.Event.Key{type: :release, ...}` to `update/2`. Same
  format as `on_key_press/1`. The `event_tag` is used for subscription
  management only -- it does NOT appear in the event struct.

  ## Example

      Toddy.Subscription.on_key_release(:keys)

      # In update/2:
      def update(model, %Toddy.Event.Key{type: :release, key: key}), do: ...
  """
  @spec on_key_release(event_tag :: atom()) :: t()
  def on_key_release(event_tag) when is_atom(event_tag) do
    %{type: :on_key_release, tag: event_tag}
  end

  @doc """
  Fires when keyboard modifier state changes (shift, ctrl, alt, etc.).

  Delivers `%Toddy.Event.Modifiers{modifiers: %KeyModifiers{}, captured: bool}`
  to `update/2`. The `event_tag` is for subscription management only.

  ## Example

      Toddy.Subscription.on_modifiers_changed(:mods)

      def update(model, %Toddy.Event.Modifiers{modifiers: %{shift: true}}), do: ...
  """
  @spec on_modifiers_changed(event_tag :: atom()) :: t()
  def on_modifiers_changed(event_tag) when is_atom(event_tag) do
    %{type: :on_modifiers_changed, tag: event_tag}
  end

  @doc """
  Fires when a window close is requested (e.g. user clicks the close button).

  Delivers `%Toddy.Event.Window{type: :close_requested, window_id: id}` to `update/2`.
  The `event_tag` is for subscription management only.

  ## Example

      Toddy.Subscription.on_window_close(:win_close)

      # In update/2:
      def update(model, %Toddy.Event.Window{type: :close_requested, window_id: wid}), do: ...
  """
  @spec on_window_close(event_tag :: atom()) :: t()
  def on_window_close(event_tag) when is_atom(event_tag) do
    %{type: :on_window_close, tag: event_tag}
  end

  @doc """
  Fires on general window events (resize, move, focus, etc.).

  Delivers `%Toddy.Event.Window{}` structs depending on the event.
  The `event_tag` is for subscription management only.

  **Note:** If both `on_window_event` and a specific subscription
  (e.g. `on_window_resize`) are registered, matching events will be
  delivered twice -- once from each subscription. Use either the
  aggregate or specific subscriptions, not both.
  """
  @spec on_window_event(event_tag :: atom()) :: t()
  def on_window_event(event_tag) when is_atom(event_tag) do
    %{type: :on_window_event, tag: event_tag}
  end

  @doc """
  Fires when a new window is opened.

  Delivers `%Toddy.Event.Window{type: :opened, window_id: id, ...}` to
  `update/2`. The `event_tag` is for subscription management only.
  """
  @spec on_window_open(event_tag :: atom()) :: t()
  def on_window_open(event_tag) when is_atom(event_tag) do
    %{type: :on_window_open, tag: event_tag}
  end

  @doc """
  Fires when a window is resized.

  Delivers `%Toddy.Event.Window{type: :resized, window_id: id, width: w, height: h}` to `update/2`.
  The `event_tag` is for subscription management only.
  """
  @spec on_window_resize(event_tag :: atom()) :: t()
  def on_window_resize(event_tag) when is_atom(event_tag) do
    %{type: :on_window_resize, tag: event_tag}
  end

  @doc """
  Fires when a window gains focus.

  Delivers `%Toddy.Event.Window{type: :focused, window_id: id}` to `update/2`.
  The `event_tag` is for subscription management only.
  """
  @spec on_window_focus(event_tag :: atom()) :: t()
  def on_window_focus(event_tag) when is_atom(event_tag) do
    %{type: :on_window_focus, tag: event_tag}
  end

  @doc """
  Fires when a window loses focus.

  Delivers `%Toddy.Event.Window{type: :unfocused, window_id: id}` to `update/2`.
  The `event_tag` is for subscription management only.
  """
  @spec on_window_unfocus(event_tag :: atom()) :: t()
  def on_window_unfocus(event_tag) when is_atom(event_tag) do
    %{type: :on_window_unfocus, tag: event_tag}
  end

  @doc """
  Fires when a window is moved.

  Delivers `%Toddy.Event.Window{type: :moved, window_id: id, x: x, y: y}` to `update/2`.
  The `event_tag` is for subscription management only.
  """
  @spec on_window_move(event_tag :: atom()) :: t()
  def on_window_move(event_tag) when is_atom(event_tag) do
    %{type: :on_window_move, tag: event_tag}
  end

  @doc """
  Fires on mouse movement.

  Delivers `%Mouse{type: :moved, x: x, y: y, captured: bool}` to `update/2`.
  Also delivers `%Mouse{type: :entered, ...}` and `%Mouse{type: :left, ...}`.
  The `event_tag` is for subscription management only.
  """
  @spec on_mouse_move(event_tag :: atom()) :: t()
  def on_mouse_move(event_tag) when is_atom(event_tag) do
    %{type: :on_mouse_move, tag: event_tag}
  end

  @doc """
  Fires on mouse button press/release.

  Delivers `%Mouse{type: :button_pressed, button: atom, captured: bool}` or
  `%Mouse{type: :button_released, button: atom, captured: bool}` to `update/2`.
  `button` is `:left`, `:right`, or `:middle`.
  The `event_tag` is for subscription management only.
  """
  @spec on_mouse_button(event_tag :: atom()) :: t()
  def on_mouse_button(event_tag) when is_atom(event_tag) do
    %{type: :on_mouse_button, tag: event_tag}
  end

  @doc """
  Fires on mouse scroll events.

  Delivers `%Mouse{type: :wheel_scrolled, delta_x: num, delta_y: num, unit: atom, captured: bool}`
  to `update/2`. The `unit` field is `:line` or `:pixel`.
  The `event_tag` is for subscription management only.
  """
  @spec on_mouse_scroll(event_tag :: atom()) :: t()
  def on_mouse_scroll(event_tag) when is_atom(event_tag) do
    %{type: :on_mouse_scroll, tag: event_tag}
  end

  @doc """
  Fires on IME (Input Method Editor) events.

  Delivers one of:

  * `%Ime{type: :opened, captured: bool}` -- the IME session started
  * `%Ime{type: :preedit, text: str, cursor: {start, end_pos} | nil, captured: bool}`
  * `%Ime{type: :commit, text: str, captured: bool}` -- final text committed
  * `%Ime{type: :closed, captured: bool}` -- the IME session ended

  The `event_tag` is for subscription management only.
  """
  @spec on_ime(event_tag :: atom()) :: t()
  def on_ime(event_tag) when is_atom(event_tag) do
    %{type: :on_ime, tag: event_tag}
  end

  @doc """
  Fires on touch events.

  Delivers `%Touch{type: :pressed, finger_id: id, x: num, y: num, captured: bool}`,
  `%Touch{type: :moved, ...}`, `%Touch{type: :lifted, ...}`, or `%Touch{type: :lost, ...}`
  to `update/2`.
  The `event_tag` is for subscription management only.
  """
  @spec on_touch(event_tag :: atom()) :: t()
  def on_touch(event_tag) when is_atom(event_tag) do
    %{type: :on_touch, tag: event_tag}
  end

  @doc """
  Fires when the system theme changes (light/dark mode).

  Delivers `%System{type: :theme_changed, data: mode}` to `update/2` where `mode` is
  a string like `"light"` or `"dark"`. The `event_tag` is for subscription
  management only.
  """
  @spec on_theme_change(event_tag :: atom()) :: t()
  def on_theme_change(event_tag) when is_atom(event_tag) do
    %{type: :on_theme_change, tag: event_tag}
  end

  @doc """
  Fires on each animation frame (vsync tick).

  Delivers `%System{type: :animation_frame, data: timestamp}` to `update/2`.
  The `event_tag` is for subscription management only.
  """
  @spec on_animation_frame(event_tag :: atom()) :: t()
  def on_animation_frame(event_tag) when is_atom(event_tag) do
    %{type: :on_animation_frame, tag: event_tag}
  end

  @doc """
  Fires when a file is dropped on a window.

  Delivers `%Window{type: :file_dropped, window_id: id, path: path}` to `update/2`.
  Also fires `%Window{type: :file_hovered, ...}` while hovering
  and `%Window{type: :files_hovered_left, ...}` when the hover exits.
  The `event_tag` is for subscription management only.
  """
  @spec on_file_drop(event_tag :: atom()) :: t()
  def on_file_drop(event_tag) when is_atom(event_tag) do
    %{type: :on_file_drop, tag: event_tag}
  end

  @doc """
  Fires on any renderer event (catch-all).

  Use this to receive all event types that the renderer emits.
  The event struct type varies by event family. The `event_tag` is for
  subscription management only.
  """
  @spec on_event(event_tag :: atom()) :: t()
  def on_event(event_tag) when is_atom(event_tag) do
    %{type: :on_event, tag: event_tag}
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
