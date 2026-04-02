defmodule Plushie.Protocol.Decode do
  @moduledoc false

  # Protocol decoding: deserialize wire bytes, then dispatch into event structs.

  alias Plushie.Protocol.{Error, Keys, Parsers}

  alias Plushie.Event.{
    ImeEvent,
    KeyEvent,
    ModifiersEvent,
    MouseEvent,
    SystemEvent,
    TouchEvent,
    WidgetCommandError,
    WidgetEvent,
    WindowEvent
  }

  @doc """
  Decodes a wire-format binary into a string-keyed map without dispatch.

  Unlike `decode_message/2` which dispatches into Elixir event structs, this
  returns the raw deserialized map. Used by script and test helpers that
  handle renderer responses (query_response, interact_response, etc.) directly.
  """
  @spec decode(data :: binary(), format :: Plushie.Protocol.format()) ::
          {:ok, map()} | {:error, term()}
  def decode(data, format \\ :msgpack), do: deserialize(data, format)

  @doc """
  Decodes a renderer event map into a typed Plushie event struct.

  Accepts either a raw event payload from `interact_step` / `interact_response`
  or a full protocol event message with `"type" => "event"`.

  Raises on unknown or malformed events. The renderer and SDK are lock-step;
  an unrecognised event is a protocol bug, not a forward-compatibility concern.
  Every event from the renderer must include `window_id`.
  """
  @spec decode_event(event :: map()) :: Plushie.Event.delivered_t()
  def decode_event(%{} = event) do
    event
    |> Map.put_new("type", "event")
    |> safe_dispatch()
    |> case do
      {:error, reason} -> raise Error, reason: reason, format: :msgpack, data: <<>>
      decoded -> decoded
    end
  end

  @doc """
  Decodes a protocol message into an event struct or tuple.

  Returns `{:error, reason}` on parse failure or an unrecognised message shape.

  ## Examples

      iex> Plushie.Protocol.Decode.decode_message(~s({"type":"event","family":"click","id":"btn_save","window_id":"main"}), :json)
      %Plushie.Event.WidgetEvent{type: :click, id: "btn_save", window_id: "main", value: nil, data: nil}

      iex> match?({:error, {:decode_failed, _}}, Plushie.Protocol.Decode.decode_message("not json"))
      true
  """
  @spec decode_message(data :: binary(), format :: Plushie.Protocol.format()) ::
          Plushie.Protocol.decode_result()
  def decode_message(data, format \\ :msgpack) do
    case deserialize(data, format) do
      {:ok, msg} -> safe_dispatch(msg)
      {:error, reason} -> {:error, {:decode_failed, reason}}
    end
  end

  @doc """
  Strict variant of `decode_message/2`.

  Raises `Plushie.Protocol.Error` when the payload cannot be decoded into a
  valid protocol message.
  """
  @spec decode_message!(data :: binary(), format :: Plushie.Protocol.format()) ::
          Plushie.Protocol.decoded_message()
  def decode_message!(data, format \\ :msgpack) do
    case decode_message(data, format) do
      {:error, reason} -> raise Error, reason: reason, format: format, data: data
      message -> message
    end
  end

  # ---------------------------------------------------------------------------
  # Deserialization
  # ---------------------------------------------------------------------------

  defp deserialize(data, :json), do: Jason.decode(data)
  defp deserialize(data, :msgpack), do: Msgpax.unpack(data)

  # ---------------------------------------------------------------------------
  # Scoped ID splitting
  # ---------------------------------------------------------------------------

  defp split_scoped_id(id) when is_binary(id) do
    case String.split(id, "/") do
      [local] ->
        {local, []}

      parts ->
        {scope_fwd, [local]} = Enum.split(parts, -1)
        {local, Enum.reverse(scope_fwd)}
    end
  end

  defp event_identity!(%{"family" => family, "id" => id} = msg) when is_binary(id) do
    {local, scope} = split_scoped_id(id)
    {local, scope, event_window_id!(msg, family), family}
  end

  defp event_identity!(%{"family" => family, "id" => id} = msg) do
    raise Plushie.Protocol.Error,
      reason: {:invalid_event_field, family, "id", id, :expected_binary, msg},
      format: :msgpack,
      data: <<>>
  end

  defp event_window_id!(%{"window_id" => window_id}, _family) when is_binary(window_id),
    do: window_id

  defp event_window_id!(%{"window_id" => window_id} = msg, family) do
    raise Plushie.Protocol.Error,
      reason: {:invalid_event_field, family, "window_id", window_id, :expected_binary, msg},
      format: :msgpack,
      data: <<>>
  end

  defp event_window_id!(msg, family) do
    raise Plushie.Protocol.Error,
      reason: {:invalid_event_field, family, "window_id", nil, :required, msg},
      format: :msgpack,
      data: <<>>
  end

  # ---------------------------------------------------------------------------
  # Modifier parsing helper
  # ---------------------------------------------------------------------------

  defp parse_modifiers(mods) when is_map(mods) do
    %Plushie.KeyModifiers{
      ctrl: Map.get(mods, "ctrl", false),
      shift: Map.get(mods, "shift", false),
      alt: Map.get(mods, "alt", false),
      logo: Map.get(mods, "logo", false),
      command: Map.get(mods, "command", false)
    }
  end

  defp parse_modifiers(_), do: %Plushie.KeyModifiers{}

  # IME cursor: {start, end} tuple from map, or nil when absent/null.
  defp parse_ime_cursor(%{"start" => s, "end" => e}), do: {s, e}
  defp parse_ime_cursor(_), do: nil

  # ---------------------------------------------------------------------------
  # Dispatch
  # ---------------------------------------------------------------------------

  # -- Outgoing message types (for roundtrip testing and diagnostics) --

  defp dispatch(%{"type" => "settings", "settings" => settings}) do
    {:settings, settings}
  end

  defp dispatch(%{"type" => "snapshot", "tree" => tree}) do
    {:snapshot, tree}
  end

  defp dispatch(%{"type" => "patch", "ops" => ops}) do
    {:patch, ops}
  end

  defp dispatch(%{
         "type" => "effect",
         "id" => id,
         "kind" => kind,
         "payload" => payload
       }) do
    {:effect, id, kind, payload}
  end

  defp dispatch(%{"type" => "widget_op", "op" => op, "payload" => payload}) do
    {:widget_op, op, payload}
  end

  defp dispatch(%{"type" => "subscribe", "kind" => kind, "tag" => tag}) do
    {:subscribe, kind, tag}
  end

  defp dispatch(%{"type" => "unsubscribe", "kind" => kind}) do
    {:unsubscribe, kind}
  end

  defp dispatch(%{
         "type" => "window_op",
         "op" => op,
         "window_id" => window_id,
         "settings" => settings
       }) do
    {:window_op, op, window_id, settings}
  end

  defp dispatch(%{"type" => "system_op", "op" => op, "settings" => settings}) do
    {:system_op, op, settings}
  end

  defp dispatch(%{"type" => "system_query", "op" => op, "settings" => settings}) do
    {:system_query, op, settings}
  end

  # -- Widget events --

  defp dispatch(%{"type" => "event", "family" => "click", "id" => _id} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    # data is nil for standard widget clicks, populated for canvas
    # element clicks (which carry button, x, y coordinates).
    %WidgetEvent{type: :click, id: local, scope: scope, window_id: window_id, data: msg["data"]}
  end

  defp dispatch(%{"type" => "event", "family" => "input", "id" => _id, "value" => value} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :input, id: local, scope: scope, window_id: window_id, value: value}
  end

  defp dispatch(%{"type" => "event", "family" => "submit", "id" => _id, "value" => value} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :submit, id: local, scope: scope, window_id: window_id, value: value}
  end

  defp dispatch(%{"type" => "event", "family" => "toggle", "id" => _id, "value" => value} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :toggle, id: local, scope: scope, window_id: window_id, value: value}
  end

  defp dispatch(%{"type" => "event", "family" => "select", "id" => _id, "value" => value} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :select, id: local, scope: scope, window_id: window_id, value: value}
  end

  defp dispatch(%{"type" => "event", "family" => "slide", "id" => _id, "value" => value} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :slide, id: local, scope: scope, window_id: window_id, value: value}
  end

  defp dispatch(
         %{"type" => "event", "family" => "slide_release", "id" => _id, "value" => value} = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :slide_release,
      id: local,
      scope: scope,
      window_id: window_id,
      value: value
    }
  end

  defp dispatch(%{"type" => "event", "family" => "paste", "id" => _id, "value" => text} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :paste, id: local, scope: scope, window_id: window_id, value: text}
  end

  defp dispatch(
         %{
           "type" => "event",
           "family" => "option_hovered",
           "id" => _id,
           "value" => value
         } = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :option_hovered,
      id: local,
      scope: scope,
      window_id: window_id,
      value: value
    }
  end

  defp dispatch(%{"type" => "event", "family" => "open", "id" => _id} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :open, id: local, scope: scope, window_id: window_id}
  end

  defp dispatch(%{"type" => "event", "family" => "close", "id" => _id} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :close, id: local, scope: scope, window_id: window_id}
  end

  defp dispatch(
         %{"type" => "event", "family" => "key_binding", "id" => _id, "data" => data} = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :key_binding, id: local, scope: scope, window_id: window_id, data: data}
  end

  # -- Keyboard events --
  # Global key events have no "id" field (or an empty "id"). Widget-scoped
  # key events include a non-empty "id" and are handled as WidgetEvent structs.

  defp dispatch(%{"type" => "event", "family" => "key_press"} = msg)
       when not is_map_key(msg, "id") or :erlang.map_get("id", msg) == "",
       do: decode_key_event(msg, :press)

  defp dispatch(%{"type" => "event", "family" => "key_release"} = msg)
       when not is_map_key(msg, "id") or :erlang.map_get("id", msg) == "",
       do: decode_key_event(msg, :release)

  defp dispatch(
         %{
           "type" => "event",
           "family" => "modifiers_changed",
           "modifiers" => mods
         } = msg
       ) do
    %ModifiersEvent{
      modifiers: parse_modifiers(mods),
      captured: msg["captured"] || false,
      window_id: msg["window_id"]
    }
  end

  # -- Mouse events --

  defp dispatch(
         %{"type" => "event", "family" => "cursor_moved", "data" => %{"x" => x, "y" => y}} = msg
       ) do
    %MouseEvent{
      type: :moved,
      x: x,
      y: y,
      captured: msg["captured"] || false,
      window_id: msg["window_id"]
    }
  end

  defp dispatch(%{"type" => "event", "family" => "cursor_entered"} = msg) do
    %MouseEvent{type: :entered, captured: msg["captured"] || false, window_id: msg["window_id"]}
  end

  defp dispatch(%{"type" => "event", "family" => "cursor_left"} = msg) do
    %MouseEvent{type: :left, captured: msg["captured"] || false, window_id: msg["window_id"]}
  end

  defp dispatch(%{"type" => "event", "family" => "button_pressed", "value" => button} = msg) do
    case Parsers.parse_mouse_button(button) do
      {:ok, parsed_button} ->
        %MouseEvent{
          type: :button_pressed,
          button: parsed_button,
          captured: msg["captured"] || false,
          window_id: msg["window_id"]
        }

      {:error, reason} ->
        invalid_event_field("button_pressed", :button, button, reason, msg)
    end
  end

  defp dispatch(%{"type" => "event", "family" => "button_released", "value" => button} = msg) do
    case Parsers.parse_mouse_button(button) do
      {:ok, parsed_button} ->
        %MouseEvent{
          type: :button_released,
          button: parsed_button,
          captured: msg["captured"] || false,
          window_id: msg["window_id"]
        }

      {:error, reason} ->
        invalid_event_field("button_released", :button, button, reason, msg)
    end
  end

  defp dispatch(
         %{
           "type" => "event",
           "family" => "wheel_scrolled",
           "data" => %{"delta_x" => dx, "delta_y" => dy, "unit" => unit}
         } = msg
       ) do
    case Parsers.parse_scroll_unit(unit) do
      {:ok, parsed_unit} ->
        %MouseEvent{
          type: :wheel_scrolled,
          delta_x: dx,
          delta_y: dy,
          unit: parsed_unit,
          captured: msg["captured"] || false,
          window_id: msg["window_id"]
        }

      {:error, reason} ->
        invalid_event_field("wheel_scrolled", :unit, unit, reason, msg)
    end
  end

  # -- IME events --
  # Each IME lifecycle step is now its own family (no more kind discriminator in data).

  defp dispatch(%{"type" => "event", "family" => "ime_opened", "id" => id} = msg) do
    {local_id, scope} = split_scoped_id(id)

    %ImeEvent{
      type: :opened,
      id: local_id,
      scope: scope,
      captured: msg["captured"] || false,
      window_id: msg["window_id"]
    }
  end

  defp dispatch(%{"type" => "event", "family" => "ime_preedit", "id" => id, "data" => data} = msg) do
    {local_id, scope} = split_scoped_id(id)
    cursor = parse_ime_cursor(data["cursor"])

    %ImeEvent{
      type: :preedit,
      id: local_id,
      scope: scope,
      text: data["text"],
      cursor: cursor,
      captured: msg["captured"] || false,
      window_id: msg["window_id"]
    }
  end

  defp dispatch(%{"type" => "event", "family" => "ime_commit", "id" => id, "data" => data} = msg) do
    {local_id, scope} = split_scoped_id(id)

    %ImeEvent{
      type: :commit,
      id: local_id,
      scope: scope,
      text: data["text"],
      captured: msg["captured"] || false,
      window_id: msg["window_id"]
    }
  end

  defp dispatch(%{"type" => "event", "family" => "ime_closed", "id" => id} = msg) do
    {local_id, scope} = split_scoped_id(id)

    %ImeEvent{
      type: :closed,
      id: local_id,
      scope: scope,
      captured: msg["captured"] || false,
      window_id: msg["window_id"]
    }
  end

  # -- Touch events --

  defp dispatch(
         %{
           "type" => "event",
           "family" => "finger_pressed",
           "data" => %{"id" => finger_id, "x" => x, "y" => y}
         } = msg
       ) do
    %TouchEvent{
      type: :pressed,
      finger_id: finger_id,
      x: x,
      y: y,
      captured: msg["captured"] || false,
      window_id: msg["window_id"]
    }
  end

  defp dispatch(
         %{
           "type" => "event",
           "family" => "finger_moved",
           "data" => %{"id" => finger_id, "x" => x, "y" => y}
         } = msg
       ) do
    %TouchEvent{
      type: :moved,
      finger_id: finger_id,
      x: x,
      y: y,
      captured: msg["captured"] || false,
      window_id: msg["window_id"]
    }
  end

  defp dispatch(
         %{
           "type" => "event",
           "family" => "finger_lifted",
           "data" => %{"id" => finger_id, "x" => x, "y" => y}
         } = msg
       ) do
    %TouchEvent{
      type: :lifted,
      finger_id: finger_id,
      x: x,
      y: y,
      captured: msg["captured"] || false,
      window_id: msg["window_id"]
    }
  end

  defp dispatch(
         %{
           "type" => "event",
           "family" => "finger_lost",
           "data" => %{"id" => finger_id, "x" => x, "y" => y}
         } = msg
       ) do
    %TouchEvent{
      type: :lost,
      finger_id: finger_id,
      x: x,
      y: y,
      captured: msg["captured"] || false,
      window_id: msg["window_id"]
    }
  end

  # -- Window lifecycle events --

  defp dispatch(%{
         "type" => "event",
         "family" => "window_opened",
         "data" => %{"window_id" => window_id, "width" => width, "height" => height} = data
       }) do
    pos =
      case data do
        %{"position" => %{"x" => x, "y" => y}} -> {x, y}
        _ -> nil
      end

    %WindowEvent{
      type: :opened,
      window_id: window_id,
      position: pos,
      width: width,
      height: height,
      scale_factor: data["scale_factor"]
    }
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_closed",
         "data" => %{"window_id" => window_id}
       }) do
    %WindowEvent{type: :closed, window_id: window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_close_requested",
         "data" => %{"window_id" => window_id}
       }) do
    %WindowEvent{type: :close_requested, window_id: window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_moved",
         "data" => %{"window_id" => window_id, "x" => x, "y" => y}
       }) do
    %WindowEvent{type: :moved, window_id: window_id, x: x, y: y}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_resized",
         "data" => %{"window_id" => window_id, "width" => width, "height" => height}
       }) do
    %WindowEvent{type: :resized, window_id: window_id, width: width, height: height}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_focused",
         "data" => %{"window_id" => window_id}
       }) do
    %WindowEvent{type: :focused, window_id: window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_unfocused",
         "data" => %{"window_id" => window_id}
       }) do
    %WindowEvent{type: :unfocused, window_id: window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_rescaled",
         "data" => %{"window_id" => window_id, "scale_factor" => scale_factor}
       }) do
    %WindowEvent{type: :rescaled, window_id: window_id, scale_factor: scale_factor}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "file_hovered",
         "data" => %{"window_id" => window_id, "path" => path}
       }) do
    %WindowEvent{type: :file_hovered, window_id: window_id, path: path}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "file_dropped",
         "data" => %{"window_id" => window_id, "path" => path}
       }) do
    %WindowEvent{type: :file_dropped, window_id: window_id, path: path}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "files_hovered_left",
         "data" => %{"window_id" => window_id}
       }) do
    %WindowEvent{type: :files_hovered_left, window_id: window_id}
  end

  # -- Animation / theme / system events --

  defp dispatch(%{
         "type" => "event",
         "family" => "animation_frame",
         "data" => %{"timestamp" => timestamp}
       }) do
    %SystemEvent{type: :animation_frame, data: timestamp}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "transition_complete",
         "id" => id,
         "data" => data
       }) do
    tag = if data["tag"], do: String.to_atom(data["tag"])

    %WidgetEvent{
      type: :transition_complete,
      id: id,
      data: %{tag: tag, prop: data["prop"]}
    }
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "theme_changed",
         "value" => mode
       }) do
    %SystemEvent{type: :theme_changed, data: mode}
  end

  # -- MouseArea events --

  defp dispatch(%{"type" => "event", "family" => "mouse_right_press", "id" => _id} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :mouse_right_press, id: local, scope: scope, window_id: window_id}
  end

  defp dispatch(%{"type" => "event", "family" => "mouse_right_release", "id" => _id} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :mouse_right_release, id: local, scope: scope, window_id: window_id}
  end

  defp dispatch(%{"type" => "event", "family" => "mouse_middle_press", "id" => _id} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :mouse_middle_press, id: local, scope: scope, window_id: window_id}
  end

  defp dispatch(%{"type" => "event", "family" => "mouse_middle_release", "id" => _id} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :mouse_middle_release, id: local, scope: scope, window_id: window_id}
  end

  defp dispatch(%{"type" => "event", "family" => "mouse_double_click", "id" => _id} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :mouse_double_click, id: local, scope: scope, window_id: window_id}
  end

  defp dispatch(%{"type" => "event", "family" => "mouse_enter", "id" => _id} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :mouse_enter, id: local, scope: scope, window_id: window_id}
  end

  defp dispatch(%{"type" => "event", "family" => "mouse_exit", "id" => _id} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :mouse_exit, id: local, scope: scope, window_id: window_id}
  end

  defp dispatch(
         %{
           "type" => "event",
           "family" => "mouse_move",
           "id" => _id,
           "data" => %{"x" => x, "y" => y}
         } = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :mouse_move,
      id: local,
      scope: scope,
      window_id: window_id,
      data: %{x: x, y: y}
    }
  end

  defp dispatch(
         %{
           "type" => "event",
           "family" => "mouse_scroll",
           "id" => _id,
           "data" => %{"delta_x" => dx, "delta_y" => dy}
         } = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :mouse_scroll,
      id: local,
      scope: scope,
      window_id: window_id,
      data: %{delta_x: dx, delta_y: dy}
    }
  end

  # -- Canvas events --

  defp dispatch(
         %{"type" => "event", "family" => "canvas_press", "id" => _id, "data" => data} = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :canvas_press,
      id: local,
      scope: scope,
      window_id: window_id,
      data: %{x: data["x"], y: data["y"], button: parse_canvas_button(data["button"])}
    }
  end

  defp dispatch(
         %{"type" => "event", "family" => "canvas_release", "id" => _id, "data" => data} = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :canvas_release,
      id: local,
      scope: scope,
      window_id: window_id,
      data: %{x: data["x"], y: data["y"], button: parse_canvas_button(data["button"])}
    }
  end

  defp dispatch(
         %{"type" => "event", "family" => "canvas_move", "id" => _id, "data" => data} = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :canvas_move,
      id: local,
      scope: scope,
      window_id: window_id,
      data: %{x: data["x"], y: data["y"]}
    }
  end

  defp dispatch(
         %{"type" => "event", "family" => "canvas_scroll", "id" => _id, "data" => data} = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :canvas_scroll,
      id: local,
      scope: scope,
      window_id: window_id,
      data: %{
        x: data["x"],
        y: data["y"],
        delta_x: data["delta_x"],
        delta_y: data["delta_y"]
      }
    }
  end

  # -- Sensor events --

  defp dispatch(
         %{"type" => "event", "family" => "sensor_resize", "id" => _id, "data" => data} = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :sensor_resize,
      id: local,
      scope: scope,
      window_id: window_id,
      data: %{width: data["width"], height: data["height"]}
    }
  end

  # -- PaneGrid events --

  defp dispatch(
         %{"type" => "event", "family" => "pane_resized", "id" => _id, "data" => data} = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :pane_resized,
      id: local,
      scope: scope,
      window_id: window_id,
      data: %{split: data["split"], ratio: data["ratio"]}
    }
  end

  defp dispatch(
         %{"type" => "event", "family" => "pane_dragged", "id" => _id, "data" => data} = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    with {:ok, action} <- Parsers.parse_pane_action(data["action"]),
         {:ok, region} <- Parsers.parse_pane_region(data["region"]),
         {:ok, edge} <- Parsers.parse_pane_region(data["edge"]) do
      %WidgetEvent{
        type: :pane_dragged,
        id: local,
        scope: scope,
        window_id: window_id,
        data: %{
          pane: data["pane"],
          target: data["target"],
          action: action,
          region: region,
          edge: edge
        }
      }
    else
      {:error, reason} -> invalid_pane_dragged_field(data, reason, msg)
    end
  end

  defp dispatch(
         %{"type" => "event", "family" => "pane_clicked", "id" => _id, "data" => data} = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :pane_clicked,
      id: local,
      scope: scope,
      window_id: window_id,
      data: %{pane: data["pane"]}
    }
  end

  defp dispatch(
         %{"type" => "event", "family" => "pane_focus_cycle", "id" => _id, "data" => data} = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :pane_focus_cycle,
      id: local,
      scope: scope,
      window_id: window_id,
      data: %{pane: data["pane"]}
    }
  end

  defp dispatch(%{"type" => "event", "family" => "sort", "id" => _id, "data" => data} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :sort, id: local, scope: scope, window_id: window_id, data: data["column"]}
  end

  defp dispatch(%{"type" => "event", "family" => "scroll", "id" => _id, "data" => data} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :scroll,
      id: local,
      scope: scope,
      window_id: window_id,
      data: %{
        absolute_x: data["absolute_x"],
        absolute_y: data["absolute_y"],
        relative_x: data["relative_x"],
        relative_y: data["relative_y"],
        bounds: {data["bounds_width"], data["bounds_height"]},
        content_bounds: {data["content_width"], data["content_height"]}
      }
    }
  end

  # -- Effect responses --
  #
  # Returns a tagged tuple instead of an EffectEvent struct. The runtime maps
  # the wire ID to the user-provided tag and creates the final %EffectEvent{}.

  defp dispatch(%{
         "type" => "effect_response",
         "id" => id,
         "status" => "ok",
         "result" => result
       }) do
    {:effect_response, id, {:ok, safe_atomize_keys(result)}}
  end

  defp dispatch(%{
         "type" => "effect_response",
         "id" => id,
         "status" => "cancelled"
       }) do
    {:effect_response, id, :cancelled}
  end

  defp dispatch(%{
         "type" => "effect_response",
         "id" => id,
         "status" => "error",
         "error" => reason
       }) do
    {:effect_response, id, {:error, reason}}
  end

  # -- System query responses --

  defp dispatch(%{
         "type" => "op_query_response",
         "kind" => "system_info",
         "tag" => tag,
         "data" => data
       }) do
    %SystemEvent{type: :system_info, tag: tag, data: safe_atomize_keys(data)}
  end

  defp dispatch(%{
         "type" => "op_query_response",
         "kind" => "system_theme",
         "tag" => tag,
         "data" => data
       }) do
    %SystemEvent{type: :system_theme, tag: tag, data: safe_atomize_keys(data)}
  end

  defp dispatch(%{
         "type" => "op_query_response",
         "kind" => "list_images",
         "tag" => tag,
         "data" => data
       }) do
    %SystemEvent{type: :image_list, tag: tag, data: safe_atomize_keys(data)}
  end

  defp dispatch(%{
         "type" => "op_query_response",
         "kind" => "tree_hash",
         "tag" => tag,
         "data" => data
       }) do
    %SystemEvent{type: :tree_hash, tag: tag, data: safe_atomize_keys(data)}
  end

  defp dispatch(%{
         "type" => "op_query_response",
         "kind" => "find_focused",
         "tag" => tag,
         "data" => data
       }) do
    %SystemEvent{type: :find_focused, tag: tag, data: safe_atomize_keys(data)}
  end

  # -- Session events (multiplexed mode) --

  defp dispatch(%{
         "type" => "event",
         "family" => "session_error",
         "session" => session,
         "data" => data
       }) do
    {:session_error, session, data["error"]}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "session_closed",
         "session" => session,
         "data" => data
       }) do
    {:session_closed, session, data["reason"]}
  end

  # -- Announce event (headless/mock: screen reader announcements surface as events) --

  defp dispatch(%{"type" => "event", "family" => "announce", "data" => data}) do
    %SystemEvent{type: :announce, data: data["text"]}
  end

  # -- Duplicate node ID error --

  defp dispatch(%{
         "type" => "event",
         "family" => "error",
         "id" => "duplicate_node_ids",
         "data" => data
       }) do
    %SystemEvent{type: :error, data: %{error: "duplicate_node_ids", details: data}}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "error",
         "id" => "extension_command",
         "data" => %{"reason" => reason} = data
       }) do
    %WidgetCommandError{
      reason: reason,
      node_id: data["node_id"],
      op: data["op"],
      extension: data["extension"],
      message: data["message"]
    }
  end

  defp dispatch(
         %{
           "type" => "event",
           "family" => "error",
           "id" => id
         } = msg
       ) do
    data =
      case Map.get(msg, "data") do
        data when is_map(data) -> Map.put_new(data, "id", id)
        nil -> %{"id" => id}
        other -> %{"id" => id, "details" => other}
      end

    %SystemEvent{type: :error, data: data}
  end

  # -- All windows closed --

  defp dispatch(%{"type" => "event", "family" => "all_windows_closed"}) do
    %SystemEvent{type: :all_windows_closed}
  end

  # -- Hello (internal, never reaches update/2) --

  defp dispatch(
         %{
           "type" => "hello",
           "protocol" => protocol,
           "version" => version,
           "name" => name
         } = msg
       ) do
    {:hello,
     %{
       protocol: protocol,
       version: version,
       name: name,
       backend: Map.get(msg, "backend", "unknown"),
       widgets: Map.get(msg, "extensions", []),
       transport: Map.get(msg, "transport", "stdio")
     }}
  end

  # -- Generic element events --

  # Focus/blur -- simple passthrough with no data payload.
  defp dispatch(%{"type" => "event", "family" => "focused", "id" => _id} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :focused, id: local, scope: scope, window_id: window_id}
  end

  defp dispatch(%{"type" => "event", "family" => "blurred", "id" => _id} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :blurred, id: local, scope: scope, window_id: window_id}
  end

  # Drag -- coordinates and deltas.
  defp dispatch(
         %{
           "type" => "event",
           "family" => "drag",
           "id" => _id,
           "data" => data
         } = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :drag,
      id: local,
      scope: scope,
      window_id: window_id,
      data: %{x: data["x"], y: data["y"], delta_x: data["delta_x"], delta_y: data["delta_y"]}
    }
  end

  # Drag end -- final coordinates.
  defp dispatch(
         %{
           "type" => "event",
           "family" => "drag_end",
           "id" => _id,
           "data" => data
         } = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :drag_end,
      id: local,
      scope: scope,
      window_id: window_id,
      data: %{x: data["x"], y: data["y"]}
    }
  end

  # Key press/release -- parse key and modifiers using type modules.
  defp dispatch(
         %{
           "type" => "event",
           "family" => "key_press",
           "id" => _id,
           "data" => data
         } = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :key_press,
      id: local,
      scope: scope,
      window_id: window_id,
      data: parse_canvas_key_data(data, :press)
    }
  end

  defp dispatch(
         %{
           "type" => "event",
           "family" => "key_release",
           "id" => _id,
           "data" => data
         } = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :key_release,
      id: local,
      scope: scope,
      window_id: window_id,
      data: parse_canvas_key_data(data, :release)
    }
  end

  defp dispatch(%{"type" => "event", "family" => "diagnostic", "data" => data}) do
    %Plushie.Event.SystemEvent{type: :diagnostic, data: data}
  end

  # -- Effect stub ack responses --

  defp dispatch(%{"type" => type, "kind" => kind})
       when type in ["effect_stub_registered", "effect_stub_unregistered"] do
    {:effect_stub_ack, kind}
  end

  defp dispatch(
         %{
           "type" => "screenshot_response",
           "name" => _name,
           "hash" => _hash,
           "width" => _width,
           "height" => _height
         } = msg
       ) do
    {:screenshot_response, msg}
  end

  # -- Outbound command messages (for diagnostics / parity tests) --

  defp dispatch(%{"type" => "image_op", "op" => op} = msg) do
    {:image_op, op, Map.drop(msg, ["type", "op", "session"])}
  end

  defp dispatch(%{"type" => "extension_command", "node_id" => node_id, "op" => op} = msg) do
    {:widget_command, node_id, op, msg["payload"] || %{}}
  end

  defp dispatch(%{"type" => "extension_commands", "commands" => commands})
       when is_list(commands) do
    {:widget_commands, commands}
  end

  defp dispatch(%{
         "type" => "interact",
         "id" => id,
         "action" => action,
         "selector" => selector,
         "payload" => payload
       }) do
    {:interact, id, action, selector, payload}
  end

  defp dispatch(%{"type" => "advance_frame", "timestamp" => timestamp}) do
    {:advance_frame, timestamp}
  end

  defp dispatch(%{"type" => "register_effect_stub", "kind" => kind} = msg) do
    {:register_effect_stub, kind, msg["response"]}
  end

  defp dispatch(%{"type" => "unregister_effect_stub", "kind" => kind}) do
    {:unregister_effect_stub, kind}
  end

  # -- Explicit widget events --

  defp dispatch(%{"type" => "event", "family" => family, "id" => _id} = msg) do
    if Parsers.widget_family?(family) do
      {local, scope, window_id, _family} = event_identity!(msg)

      %WidgetEvent{
        type: family,
        id: local,
        scope: scope,
        window_id: window_id,
        data: msg["data"],
        value: msg["value"]
      }
    else
      {:error, {:unknown_event_family, family, msg}}
    end
  end

  # -- Interact protocol (test/headless mode) --

  # interact_step: intermediate batch of events from a renderer interaction.
  # The runtime processes these events and sends back an updated snapshot.
  defp dispatch(%{"type" => "interact_step", "id" => id, "events" => events}) do
    {:interact_step, id, events}
  end

  # interact_response: final completion signal for an interaction.
  # Carries any remaining events produced by the last step.
  defp dispatch(%{"type" => "interact_response", "id" => id} = msg) do
    {:interact_response, id, msg["events"] || []}
  end

  defp dispatch(msg) do
    {:error, {:unknown_message, msg}}
  end

  defp decode_key_event(%{"data" => %{} = data, "modifiers" => mods} = msg, type) do
    key = data["key"]

    unless is_binary(key) do
      raise Error,
        reason: {:invalid_event_field, "key_#{type}", :key, key, :required, msg},
        format: :msgpack,
        data: <<>>
    end

    %KeyEvent{
      type: type,
      key: Keys.parse_key(key),
      modified_key: Keys.parse_key(data["modified_key"] || key),
      physical_key: Keys.parse_physical_key(data["physical_key"]),
      location: Keys.parse_location(data["location"]),
      modifiers: parse_modifiers(mods),
      text: if(type == :press, do: data["text"], else: nil),
      repeat: if(type == :press, do: data["repeat"] || false, else: false),
      captured: msg["captured"] || false,
      window_id: msg["window_id"]
    }
  end

  defp decode_key_event(%{"data" => %{} = data} = msg, type) do
    # Modifiers at top level missing -- use data-level or empty.
    decode_key_event(Map.put(msg, "modifiers", data["modifiers"] || %{}), type)
  end

  defp decode_key_event(msg, type) do
    raise Error,
      reason: {:invalid_event_field, "key_#{type}", :data, nil, :required, msg},
      format: :msgpack,
      data: <<>>
  end

  defp invalid_event_field(family, field, value, reason, msg) do
    {:error, {:invalid_event_field, family, field, value, reason, msg}}
  end

  defp invalid_pane_dragged_field(data, reason, msg) do
    cond do
      match?({:error, _}, Parsers.parse_pane_action(data["action"])) ->
        invalid_event_field("pane_dragged", :action, data["action"], reason, msg)

      match?({:error, _}, Parsers.parse_pane_region(data["region"])) ->
        invalid_event_field("pane_dragged", :region, data["region"], reason, msg)

      true ->
        invalid_event_field("pane_dragged", :edge, data["edge"], reason, msg)
    end
  end

  # Parses canvas element key event data into an atom-keyed map with
  # parsed key names and %KeyModifiers{} structs, matching the shapes
  # used by top-level %KeyEvent{} events for consistency.
  @spec parse_canvas_key_data(data :: map() | nil, type :: :press | :release) :: map()
  defp parse_canvas_key_data(%{} = data, type) do
    key =
      case Plushie.Type.Key.parse(data["key"]) do
        {:ok, parsed} -> parsed
        :error -> data["key"]
      end

    mods =
      case Plushie.Type.KeyModifiers.parse(data["modifiers"]) do
        {:ok, parsed} -> parsed
        :error -> %Plushie.KeyModifiers{}
      end

    result = %{key: key, modifiers: mods}

    if type == :press do
      Map.put(result, :text, data["text"])
    else
      result
    end
  end

  defp parse_canvas_key_data(_, _type), do: %{key: nil, modifiers: %Plushie.KeyModifiers{}}

  # Parses a canvas button string into an atom. Defaults to :left when
  # nil (canvas press/release events without an explicit button are left clicks).
  @spec parse_canvas_button(button :: String.t() | nil) :: atom()
  defp parse_canvas_button(nil), do: :left

  defp parse_canvas_button(button) when is_binary(button) do
    case Plushie.Type.MouseButton.parse(button) do
      {:ok, parsed} -> parsed
      :error -> :left
    end
  end

  # Recursively converts string-keyed wire data to atom-keyed maps
  # for effect results and query responses. Uses String.to_existing_atom/1
  # to avoid atom table exhaustion from arbitrary renderer data --
  # unknown keys are kept as strings.
  @spec safe_atomize_keys(term()) :: term()
  defp safe_atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) ->
        atom_key =
          try do
            String.to_existing_atom(k)
          rescue
            ArgumentError -> k
          end

        {atom_key, safe_atomize_keys(v)}

      {k, v} ->
        {k, safe_atomize_keys(v)}
    end)
  end

  defp safe_atomize_keys(list) when is_list(list), do: Enum.map(list, &safe_atomize_keys/1)
  defp safe_atomize_keys(other), do: other

  defp safe_dispatch(msg) do
    dispatch(msg)
  rescue
    error in Plushie.Protocol.Error -> {:error, error.reason}
    FunctionClauseError -> {:error, {:unknown_message, msg}}
  end
end
