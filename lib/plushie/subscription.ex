defmodule Plushie.Subscription do
  @moduledoc """
  Declarative subscription specifications for Plushie apps.

  Subscriptions are ongoing event sources. Return them from `subscribe/1`
  and the runtime manages their lifecycle automatically, starting new
  subscriptions and stopping removed ones by diffing the list each cycle.

  ## Timer subscriptions

  Timer subscriptions carry a tag that becomes part of the event struct.
  Your `update/2` receives `%Plushie.Event.TimerEvent{tag: tag, timestamp: ts}`.

      Plushie.Subscription.every(1000, :tick)
      # update/2 receives: %Plushie.Event.TimerEvent{tag: :tick, timestamp: 1234567890}

  ## Renderer subscriptions

  Renderer subscriptions (`on_key_press`, `on_pointer_move`, etc.) take
  no tag. Events arrive as typed structs (`%KeyEvent{}`, `%WindowEvent{}`,
  etc.) and are matched by struct type.

      Plushie.Subscription.on_key_press()
      # update/2 receives: %Plushie.Event.KeyEvent{type: :press, ...}

      Plushie.Subscription.on_window_resize()
      # update/2 receives: %Plushie.Event.WindowEvent{type: :resized, ...}

  Renderer subs are keyed by `{kind, window_id}` for lifecycle diffing.
  Only one subscription of each kind per window (or globally when no
  window is specified).

  ## Rate limiting

  Renderer subscriptions accept a `:max_rate` option that tells the
  renderer to coalesce events beyond the given rate (events per second).
  This reduces wire traffic and host CPU usage for high-frequency events.

      # Rate-limit mouse moves to 30 events per second:
      Subscription.on_pointer_move(max_rate: 30)

      # Animation frames at 60fps (matches display refresh):
      Subscription.on_animation_frame(max_rate: 60)

      # Subscribe but never emit (capture tracking only):
      Subscription.on_pointer_move(max_rate: 0)

  The rate can also be set via the `max_rate/2` setter for pipeline style:

      Subscription.on_pointer_move() |> Subscription.max_rate(30)

  Timer subscriptions (`every/2`) do not support max_rate. They are
  host-side timers, not renderer events.

  ## Example

      def subscribe(model) do
        subs = []
        if model.timer_running do
          subs = [Plushie.Subscription.every(1000, :tick) | subs]
        end
        subs
      end

      def update(model, %Plushie.Event.TimerEvent{tag: :tick}) do
        # Timer events are Timer structs with tag and timestamp fields.
        %{model | ticks: model.ticks + 1}
      end

      def update(model, %Plushie.Event.KeyEvent{type: :press, key: :escape}) do
        # Renderer subscriptions deliver typed event structs.
        %{model | menu_open: false}
      end
  """

  @typedoc """
  A subscription specification. Every subscription has a `:type` atom
  identifying the kind (`:every`, `:on_key_press`, etc.) and a `:tag`
  field. For timer subscriptions, the tag is the user-provided atom that
  appears in `%Plushie.Event.TimerEvent{tag: tag}`. For renderer
  subscriptions, the tag is `nil` (management is by `{kind, window_id}`).
  """
  @type t :: %__MODULE__{
          type: atom(),
          tag: atom() | nil,
          interval: pos_integer() | nil,
          max_rate: non_neg_integer() | nil,
          window_id: String.t() | nil
        }

  @enforce_keys [:type]
  defstruct [:type, :tag, :interval, :max_rate, :window_id]

  @doc """
  Timer that fires every `interval_ms` milliseconds.

  The tag becomes part of the Timer event struct. `update/2` receives
  `%Plushie.Event.TimerEvent{tag: event_tag, timestamp: timestamp}` where
  `timestamp` is `System.monotonic_time(:millisecond)`.

  ## Example

      Plushie.Subscription.every(1000, :tick)

      # In update/2:
      def update(model, %Plushie.Event.TimerEvent{tag: :tick}), do: %{model | count: model.count + 1}
  """
  @spec every(interval_ms :: pos_integer(), event_tag :: atom()) :: t()
  def every(interval_ms, event_tag)
      when is_integer(interval_ms) and interval_ms > 0 and is_atom(event_tag) do
    %__MODULE__{type: :every, interval: interval_ms, tag: event_tag}
  end

  @doc """
  Fires on key press events from the renderer.

  Delivers `%Plushie.Event.KeyEvent{type: :press, ...}` to `update/2`.

  See `Plushie.Event.KeyEvent` and `Plushie.KeyModifiers` for struct definitions.

  ## Example

      Plushie.Subscription.on_key_press()

      # In update/2:
      def update(model, %Plushie.Event.KeyEvent{type: :press, key: :enter}), do: ...
  """
  @spec on_key_press(opts :: keyword()) :: t()
  def on_key_press(opts \\ []) do
    {window_id, opts} = Keyword.pop(opts, :window)

    %__MODULE__{
      type: :on_key_press,
      tag: nil,
      max_rate: opts[:max_rate],
      window_id: window_id
    }
  end

  @doc """
  Fires on key release events from the renderer.

  Delivers `%Plushie.Event.KeyEvent{type: :release, ...}` to `update/2`.

  ## Example

      Plushie.Subscription.on_key_release()

      # In update/2:
      def update(model, %Plushie.Event.KeyEvent{type: :release, key: key}), do: ...
  """
  @spec on_key_release(opts :: keyword()) :: t()
  def on_key_release(opts \\ []) do
    {window_id, opts} = Keyword.pop(opts, :window)

    %__MODULE__{
      type: :on_key_release,
      tag: nil,
      max_rate: opts[:max_rate],
      window_id: window_id
    }
  end

  @doc """
  Fires when keyboard modifier state changes (shift, ctrl, alt, etc.).

  Delivers `%Plushie.Event.ModifiersEvent{modifiers: %KeyModifiers{}, captured: bool}`
  to `update/2`.

  ## Example

      Plushie.Subscription.on_modifiers_changed()

      def update(model, %Plushie.Event.ModifiersEvent{modifiers: %{shift: true}}), do: ...
  """
  @spec on_modifiers_changed(opts :: keyword()) :: t()
  def on_modifiers_changed(opts \\ []) do
    {window_id, opts} = Keyword.pop(opts, :window)

    %__MODULE__{
      type: :on_modifiers_changed,
      tag: nil,
      max_rate: opts[:max_rate],
      window_id: window_id
    }
  end

  @doc """
  Fires when a window close is requested (e.g. user clicks the close button).

  Delivers `%Plushie.Event.WindowEvent{type: :close_requested, window_id: id}` to `update/2`.

  ## Example

      Plushie.Subscription.on_window_close()

      # In update/2:
      def update(model, %Plushie.Event.WindowEvent{type: :close_requested, window_id: wid}), do: ...
  """
  @spec on_window_close(opts :: keyword()) :: t()
  def on_window_close(opts \\ []) do
    {window_id, opts} = Keyword.pop(opts, :window)

    %__MODULE__{
      type: :on_window_close,
      tag: nil,
      max_rate: opts[:max_rate],
      window_id: window_id
    }
  end

  @doc """
  Fires on general window events (resize, move, focus, etc.).

  Delivers `%Plushie.Event.WindowEvent{}` structs depending on the event.

  **Note:** If both `on_window_event` and a specific subscription
  (e.g. `on_window_resize`) are registered, matching events will be
  delivered twice, once from each subscription. Use either the
  aggregate or specific subscriptions, not both.
  """
  @spec on_window_event(opts :: keyword()) :: t()
  def on_window_event(opts \\ []) do
    {window_id, opts} = Keyword.pop(opts, :window)

    %__MODULE__{
      type: :on_window_event,
      tag: nil,
      max_rate: opts[:max_rate],
      window_id: window_id
    }
  end

  @doc """
  Fires when a new window is opened.

  Delivers `%Plushie.Event.WindowEvent{type: :opened, window_id: id, ...}` to
  `update/2`.
  """
  @spec on_window_open(opts :: keyword()) :: t()
  def on_window_open(opts \\ []) do
    {window_id, opts} = Keyword.pop(opts, :window)

    %__MODULE__{
      type: :on_window_open,
      tag: nil,
      max_rate: opts[:max_rate],
      window_id: window_id
    }
  end

  @doc """
  Fires when a window is resized.

  Delivers `%Plushie.Event.WindowEvent{type: :resized, window_id: id, width: w, height: h}` to `update/2`.
  """
  @spec on_window_resize(opts :: keyword()) :: t()
  def on_window_resize(opts \\ []) do
    {window_id, opts} = Keyword.pop(opts, :window)

    %__MODULE__{
      type: :on_window_resize,
      tag: nil,
      max_rate: opts[:max_rate],
      window_id: window_id
    }
  end

  @doc """
  Fires when a window gains focus.

  Delivers `%Plushie.Event.WindowEvent{type: :focused, window_id: id}` to `update/2`.
  """
  @spec on_window_focus(opts :: keyword()) :: t()
  def on_window_focus(opts \\ []) do
    {window_id, opts} = Keyword.pop(opts, :window)

    %__MODULE__{
      type: :on_window_focus,
      tag: nil,
      max_rate: opts[:max_rate],
      window_id: window_id
    }
  end

  @doc """
  Fires when a window loses focus.

  Delivers `%Plushie.Event.WindowEvent{type: :unfocused, window_id: id}` to `update/2`.
  """
  @spec on_window_unfocus(opts :: keyword()) :: t()
  def on_window_unfocus(opts \\ []) do
    {window_id, opts} = Keyword.pop(opts, :window)

    %__MODULE__{
      type: :on_window_unfocus,
      tag: nil,
      max_rate: opts[:max_rate],
      window_id: window_id
    }
  end

  @doc """
  Fires when a window is moved.

  Delivers `%Plushie.Event.WindowEvent{type: :moved, window_id: id, x: x, y: y}` to `update/2`.
  """
  @spec on_window_move(opts :: keyword()) :: t()
  def on_window_move(opts \\ []) do
    {window_id, opts} = Keyword.pop(opts, :window)

    %__MODULE__{
      type: :on_window_move,
      tag: nil,
      max_rate: opts[:max_rate],
      window_id: window_id
    }
  end

  @doc """
  Fires on pointer movement (mouse or touch).

  Delivers `%WidgetEvent{type: :move, id: window_id, scope: [], ...}` to `update/2`.
  The `data` map includes `pointer: :mouse`, `x`, `y`, and `modifiers`.
  Also delivers `:enter` and `:exit` events for cursor enter/leave.
  """
  @spec on_pointer_move(opts :: keyword()) :: t()
  def on_pointer_move(opts \\ []) do
    {window_id, opts} = Keyword.pop(opts, :window)

    %__MODULE__{
      type: :on_pointer_move,
      tag: nil,
      max_rate: opts[:max_rate],
      window_id: window_id
    }
  end

  @doc """
  Fires on pointer button press/release (mouse or touch).

  Delivers `%WidgetEvent{type: :press, id: window_id, scope: [], ...}` or
  `%WidgetEvent{type: :release, ...}` to `update/2`. The `value` map includes
  `button` (`:left`, `:right`, `:middle`), `pointer`, and `modifiers`.
  """
  @spec on_pointer_button(opts :: keyword()) :: t()
  def on_pointer_button(opts \\ []) do
    {window_id, opts} = Keyword.pop(opts, :window)

    %__MODULE__{
      type: :on_pointer_button,
      tag: nil,
      max_rate: opts[:max_rate],
      window_id: window_id
    }
  end

  @doc """
  Fires on pointer scroll events.

  Delivers `%WidgetEvent{type: :scroll, id: window_id, scope: [], ...}` to `update/2`.
  The `data` map includes `delta_x`, `delta_y`, `unit` (`:line` or `:pixel`),
  `pointer`, and `modifiers`.
  """
  @spec on_pointer_scroll(opts :: keyword()) :: t()
  def on_pointer_scroll(opts \\ []) do
    {window_id, opts} = Keyword.pop(opts, :window)

    %__MODULE__{
      type: :on_pointer_scroll,
      tag: nil,
      max_rate: opts[:max_rate],
      window_id: window_id
    }
  end

  @doc """
  Fires on IME (Input Method Editor) events.

  Delivers one of:

  * `%ImeEvent{type: :opened, captured: bool}` -- the IME session started
  * `%ImeEvent{type: :preedit, text: str, cursor: {start, end_pos} | nil, captured: bool}`
  * `%ImeEvent{type: :commit, text: str, captured: bool}` -- final text committed
  * `%ImeEvent{type: :closed, captured: bool}` -- the IME session ended
  """
  @spec on_ime(opts :: keyword()) :: t()
  def on_ime(opts \\ []) do
    {window_id, opts} = Keyword.pop(opts, :window)
    %__MODULE__{type: :on_ime, tag: nil, max_rate: opts[:max_rate], window_id: window_id}
  end

  @doc """
  Fires on touch events.

  Delivers `%WidgetEvent{type: :press, id: window_id, scope: [], ...}`,
  `%WidgetEvent{type: :move, ...}`, or `%WidgetEvent{type: :release, ...}`
  to `update/2`. The `data` map includes `pointer: :touch`, `finger`, `x`, `y`.
  Touch `:release` events from a lost finger include `lost: true` in the data.
  """
  @spec on_pointer_touch(opts :: keyword()) :: t()
  def on_pointer_touch(opts \\ []) do
    {window_id, opts} = Keyword.pop(opts, :window)

    %__MODULE__{
      type: :on_pointer_touch,
      tag: nil,
      max_rate: opts[:max_rate],
      window_id: window_id
    }
  end

  @doc """
  Fires when the system theme changes (light/dark mode).

  Delivers `%SystemEvent{type: :theme_changed, data: mode}` to `update/2` where `mode` is
  a string like `"light"` or `"dark"`.
  """
  @spec on_theme_change(opts :: keyword()) :: t()
  def on_theme_change(opts \\ []) do
    {window_id, opts} = Keyword.pop(opts, :window)

    %__MODULE__{
      type: :on_theme_change,
      tag: nil,
      max_rate: opts[:max_rate],
      window_id: window_id
    }
  end

  @doc """
  Fires on each animation frame (vsync tick).

  Delivers `%SystemEvent{type: :animation_frame, data: timestamp}` to `update/2`.
  """
  @spec on_animation_frame(opts :: keyword()) :: t()
  def on_animation_frame(opts \\ []) do
    {window_id, opts} = Keyword.pop(opts, :window)

    %__MODULE__{
      type: :on_animation_frame,
      tag: nil,
      max_rate: opts[:max_rate],
      window_id: window_id
    }
  end

  @doc """
  Fires when a file is dropped on a window.

  Delivers `%WindowEvent{type: :file_dropped, window_id: id, path: path}` to `update/2`.
  Also fires `%WindowEvent{type: :file_hovered, ...}` while hovering
  and `%WindowEvent{type: :files_hovered_left, ...}` when the hover exits.
  """
  @spec on_file_drop(opts :: keyword()) :: t()
  def on_file_drop(opts \\ []) do
    {window_id, opts} = Keyword.pop(opts, :window)

    %__MODULE__{
      type: :on_file_drop,
      tag: nil,
      max_rate: opts[:max_rate],
      window_id: window_id
    }
  end

  @doc """
  Fires on any renderer event (catch-all).

  Use this to receive all event types that the renderer emits.
  The event struct type varies by event family.
  """
  @spec on_event(opts :: keyword()) :: t()
  def on_event(opts \\ []) do
    {window_id, opts} = Keyword.pop(opts, :window)
    %__MODULE__{type: :on_event, tag: nil, max_rate: opts[:max_rate], window_id: window_id}
  end

  @doc """
  Sets the maximum event rate (events per second) for a renderer subscription.

  The renderer coalesces events beyond this rate, delivering at most `rate`
  events per second. A rate of 0 means "subscribe but never emit": the
  subscription is active (affects capture tracking) but no events are sent.

  Timer subscriptions (`:every`) do not support max_rate (they are host-side
  timers, not renderer events).

  ## Examples

      # Rate-limit mouse moves to 30 events per second:
      Subscription.on_pointer_move() |> Subscription.max_rate(30)

      # Animation frames at 60fps:
      Subscription.on_animation_frame(max_rate: 60)
  """
  @spec max_rate(sub :: t(), rate :: non_neg_integer()) :: t()
  def max_rate(%__MODULE__{} = sub, rate) when is_integer(rate) and rate >= 0 do
    %{sub | max_rate: rate}
  end

  @doc """
  Scope a list of subscriptions to a specific window.

  Window-scoped subscriptions tell the renderer to only deliver events
  from the given window. Without a window scope, subscriptions receive
  events from all windows.

      Subscription.for_window("editor", [
        Subscription.on_key_press(),
        Subscription.on_pointer_move(max_rate: 60)
      ])
  """
  @spec for_window(window_id :: String.t(), subscriptions :: [t()]) :: [t()]
  def for_window(window_id, subscriptions) when is_binary(window_id) and is_list(subscriptions) do
    Enum.map(subscriptions, fn sub -> %{sub | window_id: window_id} end)
  end

  @doc """
  Combines a list of subscriptions. Validates that all elements are
  `%Subscription{}` structs and returns the list.
  """
  @spec batch(subscriptions :: [t()]) :: [t()]
  def batch(subscriptions) when is_list(subscriptions) do
    Enum.each(subscriptions, fn
      %__MODULE__{} -> :ok
      other -> raise ArgumentError, "expected %Plushie.Subscription{}, got: #{inspect(other)}"
    end)

    subscriptions
  end

  @doc """
  Returns a key that uniquely identifies this subscription spec.
  Two specs with the same key are considered the same subscription.

  Timer subscriptions are keyed by `{:every, interval, tag}`.
  Renderer subscriptions are keyed by `{type, window_id}`.
  """
  @spec key(sub :: t()) :: {:every, pos_integer(), atom()} | {atom(), String.t() | nil}
  def key(%__MODULE__{type: :every, tag: tag, interval: interval}) do
    {:every, interval, tag}
  end

  def key(%__MODULE__{type: type, tag: tag}) when is_tuple(tag) do
    # Widget-namespaced subscriptions: the tag is already unique
    # (e.g. {:__widget__, window_id, widget_id, inner_tag}).
    {type, tag}
  end

  def key(%__MODULE__{type: type, window_id: window_id}) do
    {type, window_id}
  end

  @doc """
  Transforms the tag of a subscription spec.

  Used by the runtime to namespace stateful widget subscription tags
  so timer events can be routed back to the correct widget.
  """
  @spec map_tag(sub :: t(), mapper :: (term() -> term())) :: t()
  def map_tag(%__MODULE__{} = sub, mapper) when is_function(mapper, 1) do
    %{sub | tag: mapper.(sub.tag)}
  end
end
