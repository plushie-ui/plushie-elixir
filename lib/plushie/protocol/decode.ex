defmodule Plushie.Protocol.Decode do
  @moduledoc false

  # Protocol decoding: deserialize wire bytes, then dispatch into event structs.

  alias Plushie.Protocol.{Error, Keys, Parsers}

  alias Plushie.Event.{
    Canvas,
    Effect,
    ExtensionCommandError,
    Ime,
    Key,
    Modifiers,
    Mouse,
    MouseArea,
    Pane,
    Sensor,
    System,
    Touch,
    WidgetEvent,
    Window
  }

  @doc """
  Decodes a wire-format binary into a string-keyed map without dispatch.

  Unlike `decode_message/2` which dispatches into Elixir event structs, this
  returns the raw deserialized map. Used by test backends that handle
  renderer responses (query_response, interact_response, etc.) directly.
  """
  @spec decode(data :: binary(), format :: Plushie.Protocol.format()) ::
          {:ok, map()} | {:error, term()}
  def decode(data, format \\ :msgpack), do: deserialize(data, format)

  @doc """
  Decodes a protocol message into an event struct or tuple.

  Returns `{:error, reason}` on parse failure or an unrecognised message shape.

  ## Examples

      iex> Plushie.Protocol.Decode.decode_message(~s({"type":"event","family":"click","id":"btn_save"}), :json)
      %Plushie.Event.WidgetEvent{type: :click, id: "btn_save", value: nil, data: nil}

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
        local = List.last(parts)
        scope = parts |> List.delete_at(-1) |> Enum.reverse()
        {local, scope}
    end
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

  # -- Widget events --

  defp dispatch(%{"type" => "event", "family" => "click", "id" => id} = msg) do
    {local, scope} = split_scoped_id(id)
    # data is nil for standard widget clicks, populated for canvas
    # element clicks (which carry button, x, y coordinates).
    %WidgetEvent{type: :click, id: local, scope: scope, data: msg["data"]}
  end

  defp dispatch(%{"type" => "event", "family" => "input", "id" => id, "value" => value}) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :input, id: local, scope: scope, value: value}
  end

  defp dispatch(%{"type" => "event", "family" => "submit", "id" => id, "value" => value}) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :submit, id: local, scope: scope, value: value}
  end

  defp dispatch(%{"type" => "event", "family" => "toggle", "id" => id, "value" => value}) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :toggle, id: local, scope: scope, value: value}
  end

  defp dispatch(%{"type" => "event", "family" => "select", "id" => id, "value" => value}) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :select, id: local, scope: scope, value: value}
  end

  defp dispatch(%{"type" => "event", "family" => "slide", "id" => id, "value" => value}) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :slide, id: local, scope: scope, value: value}
  end

  defp dispatch(%{"type" => "event", "family" => "slide_release", "id" => id, "value" => value}) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :slide_release, id: local, scope: scope, value: value}
  end

  defp dispatch(%{"type" => "event", "family" => "paste", "id" => id, "value" => text}) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :paste, id: local, scope: scope, value: text}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "option_hovered",
         "id" => id,
         "value" => value
       }) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :option_hovered, id: local, scope: scope, value: value}
  end

  defp dispatch(%{"type" => "event", "family" => "open", "id" => id}) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :open, id: local, scope: scope}
  end

  defp dispatch(%{"type" => "event", "family" => "close", "id" => id}) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :close, id: local, scope: scope}
  end

  defp dispatch(%{"type" => "event", "family" => "key_binding", "id" => id, "data" => data}) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :key_binding, id: local, scope: scope, data: data}
  end

  # -- Keyboard events --
  # Rust emits family "key_press"/"key_release" with the logical key in "data.key",
  # modifiers at top level in "modifiers", and extra fields in "data".

  defp dispatch(
         %{
           "type" => "event",
           "family" => "key_press"
         } = msg
       ),
       do: decode_key_event(msg, :press)

  defp dispatch(
         %{
           "type" => "event",
           "family" => "key_release"
         } = msg
       ),
       do: decode_key_event(msg, :release)

  defp dispatch(
         %{
           "type" => "event",
           "family" => "modifiers_changed",
           "modifiers" => mods
         } = msg
       ) do
    %Modifiers{modifiers: parse_modifiers(mods), captured: msg["captured"] || false}
  end

  # -- Mouse events --

  defp dispatch(
         %{"type" => "event", "family" => "cursor_moved", "data" => %{"x" => x, "y" => y}} = msg
       ) do
    %Mouse{type: :moved, x: x, y: y, captured: msg["captured"] || false}
  end

  defp dispatch(%{"type" => "event", "family" => "cursor_entered"} = msg) do
    %Mouse{type: :entered, captured: msg["captured"] || false}
  end

  defp dispatch(%{"type" => "event", "family" => "cursor_left"} = msg) do
    %Mouse{type: :left, captured: msg["captured"] || false}
  end

  defp dispatch(%{"type" => "event", "family" => "button_pressed", "value" => button} = msg) do
    case Parsers.parse_mouse_button(button) do
      {:ok, parsed_button} ->
        %Mouse{
          type: :button_pressed,
          button: parsed_button,
          captured: msg["captured"] || false
        }

      {:error, reason} ->
        invalid_event_field("button_pressed", :button, button, reason, msg)
    end
  end

  defp dispatch(%{"type" => "event", "family" => "button_released", "value" => button} = msg) do
    case Parsers.parse_mouse_button(button) do
      {:ok, parsed_button} ->
        %Mouse{
          type: :button_released,
          button: parsed_button,
          captured: msg["captured"] || false
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
        %Mouse{
          type: :wheel_scrolled,
          delta_x: dx,
          delta_y: dy,
          unit: parsed_unit,
          captured: msg["captured"] || false
        }

      {:error, reason} ->
        invalid_event_field("wheel_scrolled", :unit, unit, reason, msg)
    end
  end

  # -- IME events --
  # Each IME lifecycle step is now its own family (no more kind discriminator in data).

  defp dispatch(%{"type" => "event", "family" => "ime_opened", "id" => id} = msg) do
    {local_id, scope} = split_scoped_id(id)
    %Ime{type: :opened, id: local_id, scope: scope, captured: msg["captured"] || false}
  end

  defp dispatch(%{"type" => "event", "family" => "ime_preedit", "id" => id, "data" => data} = msg) do
    {local_id, scope} = split_scoped_id(id)
    cursor = parse_ime_cursor(data["cursor"])

    %Ime{
      type: :preedit,
      id: local_id,
      scope: scope,
      text: data["text"],
      cursor: cursor,
      captured: msg["captured"] || false
    }
  end

  defp dispatch(%{"type" => "event", "family" => "ime_commit", "id" => id, "data" => data} = msg) do
    {local_id, scope} = split_scoped_id(id)

    %Ime{
      type: :commit,
      id: local_id,
      scope: scope,
      text: data["text"],
      captured: msg["captured"] || false
    }
  end

  defp dispatch(%{"type" => "event", "family" => "ime_closed", "id" => id} = msg) do
    {local_id, scope} = split_scoped_id(id)
    %Ime{type: :closed, id: local_id, scope: scope, captured: msg["captured"] || false}
  end

  # -- Touch events --

  defp dispatch(
         %{
           "type" => "event",
           "family" => "finger_pressed",
           "data" => %{"id" => finger_id, "x" => x, "y" => y}
         } = msg
       ) do
    %Touch{type: :pressed, finger_id: finger_id, x: x, y: y, captured: msg["captured"] || false}
  end

  defp dispatch(
         %{
           "type" => "event",
           "family" => "finger_moved",
           "data" => %{"id" => finger_id, "x" => x, "y" => y}
         } = msg
       ) do
    %Touch{type: :moved, finger_id: finger_id, x: x, y: y, captured: msg["captured"] || false}
  end

  defp dispatch(
         %{
           "type" => "event",
           "family" => "finger_lifted",
           "data" => %{"id" => finger_id, "x" => x, "y" => y}
         } = msg
       ) do
    %Touch{type: :lifted, finger_id: finger_id, x: x, y: y, captured: msg["captured"] || false}
  end

  defp dispatch(
         %{
           "type" => "event",
           "family" => "finger_lost",
           "data" => %{"id" => finger_id, "x" => x, "y" => y}
         } = msg
       ) do
    %Touch{type: :lost, finger_id: finger_id, x: x, y: y, captured: msg["captured"] || false}
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

    %Window{
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
    %Window{type: :closed, window_id: window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_close_requested",
         "data" => %{"window_id" => window_id}
       }) do
    %Window{type: :close_requested, window_id: window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_moved",
         "data" => %{"window_id" => window_id, "x" => x, "y" => y}
       }) do
    %Window{type: :moved, window_id: window_id, x: x, y: y}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_resized",
         "data" => %{"window_id" => window_id, "width" => width, "height" => height}
       }) do
    %Window{type: :resized, window_id: window_id, width: width, height: height}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_focused",
         "data" => %{"window_id" => window_id}
       }) do
    %Window{type: :focused, window_id: window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_unfocused",
         "data" => %{"window_id" => window_id}
       }) do
    %Window{type: :unfocused, window_id: window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_rescaled",
         "data" => %{"window_id" => window_id, "scale_factor" => scale_factor}
       }) do
    %Window{type: :rescaled, window_id: window_id, scale_factor: scale_factor}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "file_hovered",
         "data" => %{"window_id" => window_id, "path" => path}
       }) do
    %Window{type: :file_hovered, window_id: window_id, path: path}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "file_dropped",
         "data" => %{"window_id" => window_id, "path" => path}
       }) do
    %Window{type: :file_dropped, window_id: window_id, path: path}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "files_hovered_left",
         "data" => %{"window_id" => window_id}
       }) do
    %Window{type: :files_hovered_left, window_id: window_id}
  end

  # -- Animation / theme / system events --

  defp dispatch(%{
         "type" => "event",
         "family" => "animation_frame",
         "data" => %{"timestamp" => timestamp}
       }) do
    %System{type: :animation_frame, data: timestamp}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "theme_changed",
         "value" => mode
       }) do
    %System{type: :theme_changed, data: mode}
  end

  # -- MouseArea events --

  defp dispatch(%{"type" => "event", "family" => "mouse_right_press", "id" => id}) do
    {local, scope} = split_scoped_id(id)
    %MouseArea{type: :right_press, id: local, scope: scope}
  end

  defp dispatch(%{"type" => "event", "family" => "mouse_right_release", "id" => id}) do
    {local, scope} = split_scoped_id(id)
    %MouseArea{type: :right_release, id: local, scope: scope}
  end

  defp dispatch(%{"type" => "event", "family" => "mouse_middle_press", "id" => id}) do
    {local, scope} = split_scoped_id(id)
    %MouseArea{type: :middle_press, id: local, scope: scope}
  end

  defp dispatch(%{"type" => "event", "family" => "mouse_middle_release", "id" => id}) do
    {local, scope} = split_scoped_id(id)
    %MouseArea{type: :middle_release, id: local, scope: scope}
  end

  defp dispatch(%{"type" => "event", "family" => "mouse_double_click", "id" => id}) do
    {local, scope} = split_scoped_id(id)
    %MouseArea{type: :double_click, id: local, scope: scope}
  end

  defp dispatch(%{"type" => "event", "family" => "mouse_enter", "id" => id}) do
    {local, scope} = split_scoped_id(id)
    %MouseArea{type: :enter, id: local, scope: scope}
  end

  defp dispatch(%{"type" => "event", "family" => "mouse_exit", "id" => id}) do
    {local, scope} = split_scoped_id(id)
    %MouseArea{type: :exit, id: local, scope: scope}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "mouse_move",
         "id" => id,
         "data" => %{"x" => x, "y" => y}
       }) do
    {local, scope} = split_scoped_id(id)
    %MouseArea{type: :move, id: local, scope: scope, x: x, y: y}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "mouse_scroll",
         "id" => id,
         "data" => %{"delta_x" => dx, "delta_y" => dy}
       }) do
    {local, scope} = split_scoped_id(id)
    %MouseArea{type: :scroll, id: local, scope: scope, delta_x: dx, delta_y: dy}
  end

  # -- Canvas events --

  defp dispatch(%{"type" => "event", "family" => "canvas_press", "id" => id, "data" => data}) do
    {local, scope} = split_scoped_id(id)

    %Canvas{
      type: :press,
      id: local,
      scope: scope,
      x: data["x"],
      y: data["y"],
      button: Map.get(data, "button", "left")
    }
  end

  defp dispatch(%{"type" => "event", "family" => "canvas_release", "id" => id, "data" => data}) do
    {local, scope} = split_scoped_id(id)

    %Canvas{
      type: :release,
      id: local,
      scope: scope,
      x: data["x"],
      y: data["y"],
      button: Map.get(data, "button", "left")
    }
  end

  defp dispatch(%{"type" => "event", "family" => "canvas_move", "id" => id, "data" => data}) do
    {local, scope} = split_scoped_id(id)
    %Canvas{type: :move, id: local, scope: scope, x: data["x"], y: data["y"]}
  end

  defp dispatch(%{"type" => "event", "family" => "canvas_scroll", "id" => id, "data" => data}) do
    {local, scope} = split_scoped_id(id)

    %Canvas{
      type: :scroll,
      id: local,
      scope: scope,
      x: data["x"],
      y: data["y"],
      delta_x: data["delta_x"],
      delta_y: data["delta_y"]
    }
  end

  # -- Sensor events --

  defp dispatch(%{"type" => "event", "family" => "sensor_resize", "id" => id, "data" => data}) do
    {local, scope} = split_scoped_id(id)
    %Sensor{type: :resize, id: local, scope: scope, width: data["width"], height: data["height"]}
  end

  # -- PaneGrid events --

  defp dispatch(%{"type" => "event", "family" => "pane_resized", "id" => id, "data" => data}) do
    {local, scope} = split_scoped_id(id)
    %Pane{type: :resized, id: local, scope: scope, split: data["split"], ratio: data["ratio"]}
  end

  defp dispatch(
         %{"type" => "event", "family" => "pane_dragged", "id" => id, "data" => data} = msg
       ) do
    {local, scope} = split_scoped_id(id)

    with {:ok, action} <- Parsers.parse_pane_action(data["action"]),
         {:ok, region} <- Parsers.parse_pane_region(data["region"]),
         {:ok, edge} <- Parsers.parse_pane_region(data["edge"]) do
      %Pane{
        type: :dragged,
        id: local,
        scope: scope,
        pane: data["pane"],
        target: data["target"],
        action: action,
        region: region,
        edge: edge
      }
    else
      {:error, reason} -> invalid_pane_dragged_field(data, reason, msg)
    end
  end

  defp dispatch(%{"type" => "event", "family" => "pane_clicked", "id" => id, "data" => data}) do
    {local, scope} = split_scoped_id(id)
    %Pane{type: :clicked, id: local, scope: scope, pane: data["pane"]}
  end

  defp dispatch(%{"type" => "event", "family" => "pane_focus_cycle", "id" => id, "data" => data}) do
    {local, scope} = split_scoped_id(id)
    %Pane{type: :focus_cycle, id: local, scope: scope, pane: data["pane"]}
  end

  defp dispatch(%{"type" => "event", "family" => "sort", "id" => id, "data" => data}) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :sort, id: local, scope: scope, data: data["column"]}
  end

  defp dispatch(%{"type" => "event", "family" => "scroll", "id" => id, "data" => data}) do
    {local, scope} = split_scoped_id(id)

    %WidgetEvent{
      type: :scroll,
      id: local,
      scope: scope,
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

  defp dispatch(%{
         "type" => "effect_response",
         "id" => id,
         "status" => "ok",
         "result" => result
       }) do
    %Effect{request_id: id, result: {:ok, result}}
  end

  defp dispatch(%{
         "type" => "effect_response",
         "id" => id,
         "status" => "cancelled"
       }) do
    %Effect{request_id: id, result: :cancelled}
  end

  defp dispatch(%{
         "type" => "effect_response",
         "id" => id,
         "status" => "error",
         "error" => reason
       }) do
    %Effect{request_id: id, result: {:error, reason}}
  end

  # -- System query responses --

  defp dispatch(%{
         "type" => "op_query_response",
         "kind" => "system_info",
         "tag" => tag,
         "data" => data
       }) do
    %System{type: :system_info, tag: tag, data: data}
  end

  defp dispatch(%{
         "type" => "op_query_response",
         "kind" => "system_theme",
         "tag" => tag,
         "data" => data
       }) do
    %System{type: :system_theme, tag: tag, data: data}
  end

  defp dispatch(%{
         "type" => "op_query_response",
         "kind" => "list_images",
         "tag" => tag,
         "data" => data
       }) do
    %System{type: :image_list, tag: tag, data: data}
  end

  defp dispatch(%{
         "type" => "op_query_response",
         "kind" => "tree_hash",
         "tag" => tag,
         "data" => data
       }) do
    %System{type: :tree_hash, tag: tag, data: data}
  end

  defp dispatch(%{
         "type" => "op_query_response",
         "kind" => "find_focused",
         "tag" => tag,
         "data" => data
       }) do
    %System{type: :find_focused, tag: tag, data: data}
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
    %System{type: :announce, data: data["text"]}
  end

  # -- Duplicate node ID error --

  defp dispatch(%{
         "type" => "event",
         "family" => "error",
         "id" => "duplicate_node_ids",
         "data" => data
       }) do
    %System{type: :error, data: %{error: "duplicate_node_ids", details: data}}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "error",
         "id" => "extension_command",
         "data" => %{"reason" => reason} = data
       }) do
    %ExtensionCommandError{
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

    %System{type: :error, data: data}
  end

  # -- All windows closed --

  defp dispatch(%{"type" => "event", "family" => "all_windows_closed"}) do
    %System{type: :all_windows_closed}
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
       extensions: Map.get(msg, "extensions", []),
       transport: Map.get(msg, "transport", "stdio")
     }}
  end

  # -- Canvas shape events --

  defp dispatch(%{
         "type" => "event",
         "family" => "canvas_element_enter",
         "id" => id,
         "data" => data
       }) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :canvas_element_enter, id: local, scope: scope, data: data}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "canvas_element_leave",
         "id" => id,
         "data" => data
       }) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :canvas_element_leave, id: local, scope: scope, data: data}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "canvas_element_click",
         "id" => id,
         "data" => data
       }) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :canvas_element_click, id: local, scope: scope, data: data}
  end

  # NOTE: canvas_element_key_press carries key name as a wire string
  # (e.g. "ArrowRight") and modifiers as a string-keyed map, unlike
  # %Key{} which uses parsed atoms and %KeyModifiers{}. Should be
  # unified when canvas elements become first-class widget events.
  defp dispatch(%{
         "type" => "event",
         "family" => "canvas_element_key_press",
         "id" => id,
         "data" => data
       }) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :canvas_element_key_press, id: local, scope: scope, data: data}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "canvas_element_key_release",
         "id" => id,
         "data" => data
       }) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :canvas_element_key_release, id: local, scope: scope, data: data}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "canvas_element_drag",
         "id" => id,
         "data" => data
       }) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :canvas_element_drag, id: local, scope: scope, data: data}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "canvas_element_drag_end",
         "id" => id,
         "data" => data
       }) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :canvas_element_drag_end, id: local, scope: scope, data: data}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "canvas_element_focused",
         "id" => id,
         "data" => data
       }) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :canvas_element_focused, id: local, scope: scope, data: data}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "canvas_element_blurred",
         "id" => id,
         "data" => data
       }) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :canvas_element_blurred, id: local, scope: scope, data: data}
  end

  defp dispatch(%{"type" => "event", "family" => "canvas_focused", "id" => id}) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :canvas_focused, id: local, scope: scope}
  end

  defp dispatch(%{"type" => "event", "family" => "canvas_blurred", "id" => id}) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :canvas_blurred, id: local, scope: scope}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "canvas_group_focused",
         "id" => id,
         "data" => data
       }) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :canvas_group_focused, id: local, scope: scope, data: data}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "canvas_group_blurred",
         "id" => id,
         "data" => data
       }) do
    {local, scope} = split_scoped_id(id)
    %WidgetEvent{type: :canvas_group_blurred, id: local, scope: scope, data: data}
  end

  defp dispatch(%{"type" => "event", "family" => "diagnostic", "data" => data}) do
    %Plushie.Event.System{type: :diagnostic, data: data}
  end

  # -- Effect stub ack responses --

  defp dispatch(%{"type" => type, "kind" => kind})
       when type in ["effect_stub_registered", "effect_stub_unregistered"] do
    {:effect_stub_ack, kind}
  end

  # -- Outbound command messages (for diagnostics / parity tests) --

  defp dispatch(%{"type" => "image_op", "op" => op} = msg) do
    {:image_op, op, Map.drop(msg, ["type", "op", "session"])}
  end

  defp dispatch(%{"type" => "extension_command", "node_id" => node_id, "op" => op} = msg) do
    {:extension_command, node_id, op, msg["payload"] || %{}}
  end

  defp dispatch(%{"type" => "extension_commands", "commands" => commands})
       when is_list(commands) do
    {:extension_commands, commands}
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

  # -- Explicit extension events --

  defp dispatch(%{"type" => "event", "family" => family, "id" => id} = msg) do
    if Parsers.extension_family?(family) do
      {local, scope} = split_scoped_id(id)

      %WidgetEvent{
        type: family,
        id: local,
        scope: scope,
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

  defp decode_key_event(msg, type) do
    data = normalize_key_data(msg["data"])
    mods = msg["modifiers"] || data["modifiers"] || %{}
    key = data["key"] || data["value"] || msg["value"]

    if is_binary(key) do
      %Key{
        type: type,
        key: Keys.parse_key(key),
        modified_key: Keys.parse_key(data["modified_key"] || key),
        physical_key: Keys.parse_physical_key(data["physical_key"]),
        location: Keys.parse_location(data["location"]),
        modifiers: parse_modifiers(mods),
        text: if(type == :press, do: data["text"], else: nil),
        repeat: if(type == :press, do: data["repeat"] || false, else: false),
        captured: msg["captured"] || false
      }
    else
      {:error, {:unknown_message, msg}}
    end
  end

  defp normalize_key_data(%{} = data), do: data
  defp normalize_key_data(_), do: %{}

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

  defp safe_dispatch(msg) do
    dispatch(msg)
  rescue
    FunctionClauseError -> {:error, {:unknown_message, msg}}
  end
end
