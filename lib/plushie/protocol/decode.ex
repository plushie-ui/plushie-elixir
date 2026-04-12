defmodule Plushie.Protocol.Decode do
  @moduledoc """
  Wire protocol decoding.

  Deserializes binary payloads (MessagePack or JSON) into string-keyed
  maps, then dispatches them into typed Elixir event structs. Handles
  scoped ID splitting, binary field normalization, and the full set of
  renderer protocol message types.
  """

  alias Plushie.Protocol.{Error, Keys, Parsers}

  alias Plushie.Event.{
    ImeEvent,
    KeyEvent,
    ModifiersEvent,
    SystemEvent,
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
      %Plushie.Event.WidgetEvent{type: :click, id: "btn_save", window_id: "main", value: nil}

      iex> match?({:error, {:decode_failed, _}}, Plushie.Protocol.Decode.decode_message("not json"))
      true
  """
  @spec decode_message(data :: binary(), format :: Plushie.Protocol.format()) ::
          Plushie.Protocol.decode_result()
  def decode_message(data, format \\ :msgpack) do
    case deserialize(data, format) do
      {:ok, msg} ->
        case safe_dispatch(msg) do
          {:error, _} = error -> error
          message -> normalize_binary_fields(message, format)
        end

      {:error, reason} ->
        {:error, {:decode_failed, reason}}
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

  # Parse a wire ID into {local_id, scope_list, window_id}.
  # Handles the canonical "window#scope/path/id" format.
  # Falls back to separate "window_id" field for compatibility.
  defp split_scoped_id(id) when is_binary(id) do
    # Split window from path on #
    {window, path} =
      case String.split(id, "#", parts: 2) do
        [win, rest] when win != "" -> {win, rest}
        _ -> {nil, id}
      end

    # Split path into scope chain
    {local, scope} =
      case String.split(path, "/") do
        [single] -> {single, []}

        parts ->
          {scope_fwd, [local]} = Enum.split(parts, -1)
          {local, Enum.reverse(scope_fwd)}
      end

    {local, scope, window}
  end

  defp append_window_scope(scope, nil), do: scope
  defp append_window_scope(scope, window_id) when is_binary(window_id), do: scope ++ [window_id]

  defp event_identity!(%{"family" => family, "id" => id} = msg) when is_binary(id) do
    {local, scope, window_from_id} = split_scoped_id(id)

    # Prefer window from # in ID; fall back to separate field
    window_id = window_from_id || msg["window_id"]

    scope = if window_id, do: scope ++ [window_id], else: scope
    {local, scope, window_id, family}
  end

  defp event_identity!(%{"family" => family, "id" => id} = msg) do
    raise Plushie.Protocol.Error,
      reason: {:invalid_event_field, family, "id", id, :expected_binary, msg},
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
    # value is nil for standard widget clicks, populated for canvas
    # element clicks (which carry button, x, y coordinates).
    wire_data = msg["value"]
    click_value = if is_map(wire_data), do: safe_atomize_keys(wire_data), else: wire_data
    %WidgetEvent{type: :click, id: local, scope: scope, window_id: window_id, value: click_value}
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
         %{"type" => "event", "family" => "key_binding", "id" => _id, "value" => data} = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :key_binding,
      id: local,
      scope: scope,
      window_id: window_id,
      value: safe_atomize_keys(data)
    }
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

  # -- Subscription pointer events --
  # Delivered as WidgetEvents with id = window_id and scope = [].

  defp dispatch(
         %{"type" => "event", "family" => "cursor_moved", "value" => %{"x" => x, "y" => y}} = msg
       ) do
    window_id = msg["window_id"]

    %WidgetEvent{
      type: :move,
      id: window_id || "__global__",
      scope: [],
      window_id: window_id,
      value: %{
        x: x,
        y: y,
        pointer: :mouse,
        captured: msg["captured"] || false,
        modifiers: parse_modifiers(msg["modifiers"])
      }
    }
  end

  defp dispatch(%{"type" => "event", "family" => "cursor_entered"} = msg) do
    window_id = msg["window_id"]

    %WidgetEvent{
      type: :enter,
      id: window_id || "__global__",
      scope: [],
      window_id: window_id,
      value: %{captured: msg["captured"] || false}
    }
  end

  defp dispatch(%{"type" => "event", "family" => "cursor_left"} = msg) do
    window_id = msg["window_id"]

    %WidgetEvent{
      type: :exit,
      id: window_id || "__global__",
      scope: [],
      window_id: window_id,
      value: %{captured: msg["captured"] || false}
    }
  end

  defp dispatch(%{"type" => "event", "family" => "button_pressed", "value" => button} = msg) do
    case Parsers.parse_mouse_button(button) do
      {:ok, parsed_button} ->
        window_id = msg["window_id"]

        %WidgetEvent{
          type: :press,
          id: window_id || "__global__",
          scope: [],
          window_id: window_id,
          value: %{
            button: parsed_button,
            pointer: :mouse,
            x: nil,
            y: nil,
            captured: msg["captured"] || false,
            modifiers: parse_modifiers(msg["modifiers"])
          }
        }

      {:error, reason} ->
        invalid_event_field("button_pressed", :button, button, reason, msg)
    end
  end

  defp dispatch(%{"type" => "event", "family" => "button_released", "value" => button} = msg) do
    case Parsers.parse_mouse_button(button) do
      {:ok, parsed_button} ->
        window_id = msg["window_id"]

        %WidgetEvent{
          type: :release,
          id: window_id || "__global__",
          scope: [],
          window_id: window_id,
          value: %{
            button: parsed_button,
            pointer: :mouse,
            x: nil,
            y: nil,
            captured: msg["captured"] || false,
            modifiers: parse_modifiers(msg["modifiers"])
          }
        }

      {:error, reason} ->
        invalid_event_field("button_released", :button, button, reason, msg)
    end
  end

  defp dispatch(
         %{
           "type" => "event",
           "family" => "wheel_scrolled",
           "value" => %{"delta_x" => dx, "delta_y" => dy, "unit" => unit}
         } = msg
       ) do
    case Parsers.parse_scroll_unit(unit) do
      {:ok, parsed_unit} ->
        window_id = msg["window_id"]

        %WidgetEvent{
          type: :scroll,
          id: window_id || "__global__",
          scope: [],
          window_id: window_id,
          value: %{
            delta_x: dx,
            delta_y: dy,
            unit: parsed_unit,
            pointer: :mouse,
            captured: msg["captured"] || false,
            modifiers: parse_modifiers(msg["modifiers"])
          }
        }

      {:error, reason} ->
        invalid_event_field("wheel_scrolled", :unit, unit, reason, msg)
    end
  end

  # -- IME events --
  # Each IME lifecycle step is now its own family (no more kind discriminator in data).

  defp dispatch(%{"type" => "event", "family" => "ime_opened", "id" => id} = msg) do
    {local_id, scope, _window} = split_scoped_id(id)
    window_id = msg["window_id"]

    %ImeEvent{
      type: :opened,
      id: local_id,
      scope: append_window_scope(scope, window_id),
      captured: msg["captured"] || false,
      window_id: window_id
    }
  end

  defp dispatch(%{"type" => "event", "family" => "ime_preedit", "id" => id, "value" => data} = msg) do
    {local_id, scope, _window} = split_scoped_id(id)
    cursor = parse_ime_cursor(data["cursor"])
    window_id = msg["window_id"]

    %ImeEvent{
      type: :preedit,
      id: local_id,
      scope: append_window_scope(scope, window_id),
      text: data["text"],
      cursor: cursor,
      captured: msg["captured"] || false,
      window_id: window_id
    }
  end

  defp dispatch(%{"type" => "event", "family" => "ime_commit", "id" => id, "value" => data} = msg) do
    {local_id, scope, _window} = split_scoped_id(id)
    window_id = msg["window_id"]

    %ImeEvent{
      type: :commit,
      id: local_id,
      scope: append_window_scope(scope, window_id),
      text: data["text"],
      captured: msg["captured"] || false,
      window_id: window_id
    }
  end

  defp dispatch(%{"type" => "event", "family" => "ime_closed", "id" => id} = msg) do
    {local_id, scope, _window} = split_scoped_id(id)
    window_id = msg["window_id"]

    %ImeEvent{
      type: :closed,
      id: local_id,
      scope: append_window_scope(scope, window_id),
      captured: msg["captured"] || false,
      window_id: window_id
    }
  end

  # -- Touch events (subscription) --
  # Delivered as WidgetEvents with pointer: :touch.

  defp dispatch(
         %{
           "type" => "event",
           "family" => "finger_pressed",
           "value" => %{"id" => finger_id, "x" => x, "y" => y}
         } = msg
       ) do
    window_id = msg["window_id"]

    %WidgetEvent{
      type: :press,
      id: window_id || "__global__",
      scope: [],
      window_id: window_id,
      value: %{
        pointer: :touch,
        finger: finger_id,
        x: x,
        y: y,
        button: :left,
        captured: msg["captured"] || false,
        modifiers: parse_modifiers(msg["modifiers"])
      }
    }
  end

  defp dispatch(
         %{
           "type" => "event",
           "family" => "finger_moved",
           "value" => %{"id" => finger_id, "x" => x, "y" => y}
         } = msg
       ) do
    window_id = msg["window_id"]

    %WidgetEvent{
      type: :move,
      id: window_id || "__global__",
      scope: [],
      window_id: window_id,
      value: %{
        pointer: :touch,
        finger: finger_id,
        x: x,
        y: y,
        captured: msg["captured"] || false,
        modifiers: parse_modifiers(msg["modifiers"])
      }
    }
  end

  defp dispatch(
         %{
           "type" => "event",
           "family" => "finger_lifted",
           "value" => %{"id" => finger_id, "x" => x, "y" => y}
         } = msg
       ) do
    window_id = msg["window_id"]

    %WidgetEvent{
      type: :release,
      id: window_id || "__global__",
      scope: [],
      window_id: window_id,
      value: %{
        pointer: :touch,
        finger: finger_id,
        x: x,
        y: y,
        button: :left,
        captured: msg["captured"] || false,
        modifiers: parse_modifiers(msg["modifiers"])
      }
    }
  end

  defp dispatch(
         %{
           "type" => "event",
           "family" => "finger_lost",
           "value" => %{"id" => finger_id, "x" => x, "y" => y}
         } = msg
       ) do
    window_id = msg["window_id"]

    %WidgetEvent{
      type: :release,
      id: window_id || "__global__",
      scope: [],
      window_id: window_id,
      value: %{
        pointer: :touch,
        finger: finger_id,
        x: x,
        y: y,
        button: :left,
        lost: true,
        captured: msg["captured"] || false,
        modifiers: parse_modifiers(msg["modifiers"])
      }
    }
  end

  # -- Window lifecycle events --

  defp dispatch(%{
         "type" => "event",
         "family" => "window_opened",
         "value" => %{"window_id" => window_id, "width" => width, "height" => height} = data
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
         "value" => %{"window_id" => window_id}
       }) do
    %WindowEvent{type: :closed, window_id: window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_close_requested",
         "value" => %{"window_id" => window_id}
       }) do
    %WindowEvent{type: :close_requested, window_id: window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_moved",
         "value" => %{"window_id" => window_id, "x" => x, "y" => y}
       }) do
    %WindowEvent{type: :moved, window_id: window_id, x: x, y: y}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_resized",
         "value" => %{"window_id" => window_id, "width" => width, "height" => height}
       }) do
    %WindowEvent{type: :resized, window_id: window_id, width: width, height: height}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_focused",
         "value" => %{"window_id" => window_id}
       }) do
    %WindowEvent{type: :focused, window_id: window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_unfocused",
         "value" => %{"window_id" => window_id}
       }) do
    %WindowEvent{type: :unfocused, window_id: window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_rescaled",
         "value" => %{"window_id" => window_id, "scale_factor" => scale_factor}
       }) do
    %WindowEvent{type: :rescaled, window_id: window_id, scale_factor: scale_factor}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "file_hovered",
         "value" => %{"window_id" => window_id, "path" => path}
       }) do
    %WindowEvent{type: :file_hovered, window_id: window_id, path: path}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "file_dropped",
         "value" => %{"window_id" => window_id, "path" => path}
       }) do
    %WindowEvent{type: :file_dropped, window_id: window_id, path: path}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "files_hovered_left",
         "value" => %{"window_id" => window_id}
       }) do
    %WindowEvent{type: :files_hovered_left, window_id: window_id}
  end

  # -- Animation / theme / system events --

  defp dispatch(%{
         "type" => "event",
         "family" => "animation_frame",
         "value" => %{"timestamp" => timestamp}
       }) do
    %SystemEvent{type: :animation_frame, value: timestamp}
  end

  defp dispatch(
         %{"type" => "event", "family" => "transition_complete", "id" => _id, "value" => data} =
           msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    tag =
      if data["tag"] do
        try do
          String.to_existing_atom(data["tag"])
        rescue
          ArgumentError ->
            reraise Error.exception(
                      reason:
                        {:invalid_event_field, "transition_complete", :tag, data["tag"],
                         :unknown_atom, msg},
                      format: :msgpack,
                      data: <<>>
                    ),
                    __STACKTRACE__
        end
      end

    %WidgetEvent{
      type: :transition_complete,
      id: local,
      scope: scope,
      window_id: window_id,
      value: %{tag: tag, prop: data["prop"]}
    }
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "theme_changed",
         "value" => mode
       }) do
    %SystemEvent{type: :theme_changed, value: mode}
  end

  # -- Unified pointer events --
  # New wire format: press, release, move, scroll, enter, exit, double_click, resize.
  # These replace canvas_*, mouse_*, and sensor_* events.

  defp dispatch(%{"type" => "event", "family" => "press", "id" => _id, "value" => data} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :press,
      id: local,
      scope: scope,
      window_id: window_id,
      value: %{
        x: data["x"],
        y: data["y"],
        button: parse_pointer_button(data["button"]),
        pointer: parse_pointer_type(data["pointer"]),
        finger: data["finger"],
        modifiers: parse_modifiers(data["modifiers"])
      }
    }
  end

  defp dispatch(%{"type" => "event", "family" => "release", "id" => _id, "value" => data} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :release,
      id: local,
      scope: scope,
      window_id: window_id,
      value: %{
        x: data["x"],
        y: data["y"],
        button: parse_pointer_button(data["button"]),
        pointer: parse_pointer_type(data["pointer"]),
        finger: data["finger"],
        modifiers: parse_modifiers(data["modifiers"])
      }
    }
  end

  defp dispatch(%{"type" => "event", "family" => "move", "id" => _id, "value" => data} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :move,
      id: local,
      scope: scope,
      window_id: window_id,
      value: %{
        x: data["x"],
        y: data["y"],
        pointer: parse_pointer_type(data["pointer"]),
        finger: data["finger"],
        modifiers: parse_modifiers(data["modifiers"])
      }
    }
  end

  # Pointer scroll (unified pointer event).
  defp dispatch(
         %{
           "type" => "event",
           "family" => "scroll",
           "id" => _id,
           "value" => data
         } = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :scroll,
      id: local,
      scope: scope,
      window_id: window_id,
      value: %{
        x: data["x"],
        y: data["y"],
        delta_x: data["delta_x"],
        delta_y: data["delta_y"],
        pointer: parse_pointer_type(data["pointer"]),
        modifiers: parse_modifiers(data["modifiers"])
      }
    }
  end

  defp dispatch(%{"type" => "event", "family" => "enter", "id" => _id} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :enter, id: local, scope: scope, window_id: window_id}
  end

  defp dispatch(%{"type" => "event", "family" => "exit", "id" => _id} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    %WidgetEvent{type: :exit, id: local, scope: scope, window_id: window_id}
  end

  defp dispatch(
         %{"type" => "event", "family" => "double_click", "id" => _id, "value" => data} = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :double_click,
      id: local,
      scope: scope,
      window_id: window_id,
      value: %{
        x: data["x"],
        y: data["y"],
        pointer: parse_pointer_type(data["pointer"]),
        modifiers: parse_modifiers(data["modifiers"])
      }
    }
  end

  defp dispatch(%{"type" => "event", "family" => "resize", "id" => _id, "value" => data} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :resize,
      id: local,
      scope: scope,
      window_id: window_id,
      value: %{width: data["width"], height: data["height"]}
    }
  end

  # -- PaneGrid events --

  defp dispatch(
         %{"type" => "event", "family" => "pane_resized", "id" => _id, "value" => data} = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :pane_resized,
      id: local,
      scope: scope,
      window_id: window_id,
      value: %{split: data["split"], ratio: data["ratio"]}
    }
  end

  defp dispatch(
         %{"type" => "event", "family" => "pane_dragged", "id" => _id, "value" => data} = msg
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
        value: %{
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
         %{"type" => "event", "family" => "pane_clicked", "id" => _id, "value" => data} = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :pane_clicked,
      id: local,
      scope: scope,
      window_id: window_id,
      value: %{pane: data["pane"]}
    }
  end

  defp dispatch(
         %{"type" => "event", "family" => "pane_focus_cycle", "id" => _id, "value" => data} = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :pane_focus_cycle,
      id: local,
      scope: scope,
      window_id: window_id,
      value: %{pane: data["pane"]}
    }
  end

  defp dispatch(%{"type" => "event", "family" => "sort", "id" => _id, "value" => data} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :sort,
      id: local,
      scope: scope,
      window_id: window_id,
      value: %{column: data["column"]}
    }
  end

  defp dispatch(%{"type" => "event", "family" => "scrolled", "id" => _id, "value" => data} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :scrolled,
      id: local,
      scope: scope,
      window_id: window_id,
      value: %{
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

  defp dispatch(%{
         "type" => "effect_response",
         "id" => id,
         "status" => "unsupported"
       }) do
    {:effect_response, id, {:error, :unsupported}}
  end

  # -- System query responses --

  defp dispatch(%{
         "type" => "op_query_response",
         "kind" => "system_info",
         "tag" => tag,
         "value" => data
       }) do
    %SystemEvent{type: :system_info, tag: tag, value: safe_atomize_keys(data)}
  end

  defp dispatch(%{
         "type" => "op_query_response",
         "kind" => "system_theme",
         "tag" => tag,
         "value" => data
       }) do
    %SystemEvent{type: :system_theme, tag: tag, value: safe_atomize_keys(data)}
  end

  defp dispatch(%{
         "type" => "op_query_response",
         "kind" => "list_images",
         "tag" => tag,
         "value" => data
       }) do
    %SystemEvent{type: :image_list, tag: tag, value: safe_atomize_keys(data)}
  end

  defp dispatch(%{
         "type" => "op_query_response",
         "kind" => "tree_hash",
         "tag" => tag,
         "value" => data
       }) do
    %SystemEvent{type: :tree_hash, tag: tag, value: safe_atomize_keys(data)}
  end

  defp dispatch(%{
         "type" => "op_query_response",
         "kind" => "find_focused",
         "tag" => tag,
         "value" => data
       }) do
    %SystemEvent{type: :find_focused, tag: tag, value: safe_atomize_keys(data)}
  end

  # -- Session events (multiplexed mode) --

  defp dispatch(%{
         "type" => "event",
         "family" => "session_error",
         "session" => session,
         "value" => data
       }) do
    {:session_error, session, data["error"]}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "session_closed",
         "session" => session,
         "value" => data
       }) do
    {:session_closed, session, data["reason"]}
  end

  # -- Announce event (headless/mock: screen reader announcements surface as events) --

  defp dispatch(%{"type" => "event", "family" => "announce", "value" => data}) do
    %SystemEvent{type: :announce, value: data["text"]}
  end

  # -- Duplicate node ID error --

  defp dispatch(%{
         "type" => "event",
         "family" => "error",
         "id" => "duplicate_node_ids",
         "value" => data
       }) do
    %SystemEvent{type: :error, value: %{error: "duplicate_node_ids", details: data}}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "error",
         "id" => "widget_command",
         "value" => %{"reason" => reason} = data
       }) do
    %WidgetCommandError{
      reason: reason,
      node_id: data["node_id"],
      op: data["op"],
      widget_type: data["widget_type"],
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

    %SystemEvent{type: :error, value: data}
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
           "name" => name,
           "mode" => mode,
           "backend" => backend,
           "transport" => transport,
           "native_widgets" => native_widgets,
           "widgets" => widgets
         } = msg
       ) do
    {:hello,
     %{
       protocol: protocol,
       version: version,
       name: name,
       mode: mode,
       backend: backend,
       transport: transport,
       native_widgets: native_widgets,
       widget_sets: Map.get(msg, "widget_sets", []),
       widgets: widgets
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

  defp dispatch(%{"type" => "event", "family" => "status", "id" => _id} = msg) do
    {local, scope, window_id, _family} = event_identity!(msg)
    value = msg["value"] || msg["value"]
    %WidgetEvent{type: :status, id: local, scope: scope, window_id: window_id, value: value}
  end

  # Drag -- coordinates and deltas.
  defp dispatch(
         %{
           "type" => "event",
           "family" => "drag",
           "id" => _id,
           "value" => data
         } = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :drag,
      id: local,
      scope: scope,
      window_id: window_id,
      value: %{x: data["x"], y: data["y"], delta_x: data["delta_x"], delta_y: data["delta_y"]}
    }
  end

  # Drag end -- final coordinates.
  defp dispatch(
         %{
           "type" => "event",
           "family" => "drag_end",
           "id" => _id,
           "value" => data
         } = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :drag_end,
      id: local,
      scope: scope,
      window_id: window_id,
      value: %{x: data["x"], y: data["y"]}
    }
  end

  # Key press/release -- parse key and modifiers using type modules.
  defp dispatch(
         %{
           "type" => "event",
           "family" => "key_press",
           "id" => _id,
           "value" => data
         } = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :key_press,
      id: local,
      scope: scope,
      window_id: window_id,
      value: parse_canvas_key_data(data, :press)
    }
  end

  defp dispatch(
         %{
           "type" => "event",
           "family" => "key_release",
           "id" => _id,
           "value" => data
         } = msg
       ) do
    {local, scope, window_id, _family} = event_identity!(msg)

    %WidgetEvent{
      type: :key_release,
      id: local,
      scope: scope,
      window_id: window_id,
      value: parse_canvas_key_data(data, :release)
    }
  end

  defp dispatch(%{"type" => "event", "family" => "diagnostic", "value" => data} = msg) do
    %Plushie.Event.SystemEvent{
      type: :diagnostic,
      tag: data["code"],
      value: safe_atomize_keys(data),
      id: msg["id"],
      window_id: msg["window_id"]
    }
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

  defp dispatch(%{"type" => "widget_command", "node_id" => node_id, "op" => op} = msg) do
    {:widget_command, node_id, op, msg["payload"] || %{}}
  end

  defp dispatch(%{"type" => "widget_commands", "commands" => commands})
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

      wire_value = msg["value"]
      resolved_value =
        if is_map(wire_value), do: safe_atomize_keys(wire_value), else: wire_value

      %WidgetEvent{
        type: family,
        id: local,
        scope: scope,
        window_id: window_id,
        value: resolved_value
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

  defp decode_key_event(%{"value" => %{} = data, "modifiers" => mods} = msg, type) do
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

  defp decode_key_event(%{"value" => %{} = data} = msg, type) do
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

  # Parses a unified pointer button string. Defaults to :left when nil.
  @spec parse_pointer_button(value :: String.t() | nil) :: atom()
  defp parse_pointer_button(nil), do: :left

  defp parse_pointer_button(value) when is_binary(value) do
    case Plushie.Type.Pointer.parse_button(value) do
      {:ok, parsed} -> parsed
      :error -> :left
    end
  end

  # Parses a pointer type string. Defaults to :mouse when nil.
  @spec parse_pointer_type(value :: String.t() | nil) :: atom()
  defp parse_pointer_type(nil), do: :mouse

  defp parse_pointer_type(value) when is_binary(value) do
    case Plushie.Type.Pointer.parse_pointer(value) do
      {:ok, parsed} -> parsed
      :error -> :mouse
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

  # Normalizes format-specific binary representations so consumers do not
  # need to know the wire format. JSON encodes raw bytes as base64 strings;
  # this decodes them back to raw binaries after dispatch.
  @spec normalize_binary_fields(Plushie.Protocol.decoded_message(), Plushie.Protocol.format()) ::
          Plushie.Protocol.decoded_message()
  defp normalize_binary_fields({:screenshot_response, %{"rgba" => rgba} = msg}, :json)
       when is_binary(rgba) do
    case Base.decode64(rgba) do
      {:ok, decoded} ->
        {:screenshot_response, %{msg | "rgba" => decoded}}

      :error ->
        {:error, {:decode_failed, {:invalid_base64, "screenshot_response.rgba"}}}
    end
  end

  defp normalize_binary_fields(message, _format), do: message
end
