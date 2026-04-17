defmodule Plushie.Command do
  @moduledoc """
  Commands describe side effects that `update/2` wants the runtime to perform.

  They are plain data: inspectable, testable, serializable. The runtime
  interprets them after `update/2` returns. Nothing executes inside `update`.

  ## Categories

  - **Basic**: `none/0`, `done/2`, `async/2`, `stream/2`, `cancel/1`, `send_after/2`, `exit/0`
  - **Focus**: `focus/1` (widget command), `focus_next/0`, `focus_previous/0` (widget ops)
  - **Text**: `select_all/1`, `move_cursor_to_front/1`, `move_cursor_to_end/1`,
    `move_cursor_to/2`, `select_range/3` (see `Command.Text`)
  - **Scroll**: `scroll_to/3`, `snap_to/3`, `snap_to_end/1`, `scroll_by/3`
    (see `Command.Scroll`)
  - **Window ops**: `close_window/1`, `resize_window/3`, `move_window/3`,
    `maximize_window/2`, `minimize_window/2`, `set_window_mode/2`,
    `toggle_maximize/1`, `toggle_decorations/1`, `focus_window/1`,
    `set_window_level/2`, `drag_window/1`, `drag_resize_window/2`,
    `request_attention/2`, `screenshot/2`, `set_resizable/2`,
    `set_min_size/3`, `set_max_size/3`, `enable_mouse_passthrough/1`,
    `disable_mouse_passthrough/1`, `show_system_menu/1`, `set_icon/4`,
    `set_resize_increments/3` (see `Command.Window`)
  - **Window queries**: `window_size/2`, `window_position/2`,
    `is_maximized/2`, `is_minimized/2`, `window_mode/2`, `scale_factor/2`,
    `raw_id/2`, `monitor_size/2` (see `Command.WindowQuery`)
  - **System ops**: `allow_automatic_tabbing/1`
  - **System queries**: `system_theme/1`, `system_info/1`
  - **PaneGrid ops**: `pane_split/4`, `pane_close/2`, `pane_swap/3`,
    `pane_maximize/2`, `pane_restore/1`
  - **Image ops**: `create_image/2`, `create_image/4`, `update_image/2`,
    `update_image/4`, `delete_image/1`, `list_images/1`, `clear_images/0`
    (see `Command.Image`)
  - **Queries**: `tree_hash/1`, `find_focused/1`
  - **Font**: `load_font/1`
  - **Accessibility**: `announce/1`
  - **Widget commands**: `widget_command/3`, `widget_batch/1`
  - **Test/Headless**: `advance_frame/1`
  - **Batch**: `batch/1`

  ## Result delivery

  Commands deliver results back to `update/2` through three mechanisms:

  - **Async/Stream**: `async/2` delivers `%Plushie.Event.AsyncEvent{tag: tag, result: result}`.
    `stream/2` delivers `%Plushie.Event.StreamEvent{tag: tag, value: value}` for each chunk.
  - **Window and system queries**: `window_size/2`, `window_mode/2`, etc. deliver
    `%Plushie.Event.SystemEvent{}` structs through `update/2`. The `type` field identifies the
    query kind, `tag` holds the stringified event tag, and `value` holds the result payload.
    For example, `system_theme(:my_tag)` delivers
    `%SystemEvent{type: :system_theme, tag: "my_tag", value: "dark"}`.
  - **Platform effects**: `Plushie.Effect` functions deliver
    `%Plushie.Event.EffectEvent{tag: tag, result: result}`. The `tag` matches the
    atom you provided when creating the effect command. Timeouts deliver the
    same struct with `result: {:error, :timeout}`. See `Plushie.Effect`.

  ## Usage

      def update(model, %Plushie.Event.WidgetEvent{type: :click, id: "save"}) do
        cmd = Plushie.Command.async(fn -> save(model) end, :save_result)
        {model, cmd}
      end

      def update(model, %Plushie.Event.AsyncEvent{tag: :save_result, result: :ok}), do: %{model | saved: true}

  Multiple commands can be issued at once via `batch/1`:

      cmd = Plushie.Command.batch([
        Plushie.Command.focus("name_input"),
        Plushie.Command.send_after(5000, :auto_save)
      ])
  """

  @enforce_keys [:type, :payload]
  defstruct [:type, :payload]

  @typedoc "Stable string identifier for a widget node in the UI tree."
  @type widget_id :: String.t()

  @typedoc "Stable string identifier for a window node in the UI tree."
  @type window_id :: String.t()

  @typedoc "Tag atom used to identify async results in `update/2`."
  @type event_tag :: atom()

  @typedoc """
  A command to be dispatched by the runtime.

  Always a `%Command{}` struct. `batch/1` wraps multiple commands into a
  single struct with `type: :batch`. The runtime normalizes bare lists
  internally, but the public type is always a struct.
  """
  @type t :: %__MODULE__{type: atom(), payload: map()}

  @doc "A no-op command. Returned implicitly when `update/2` returns a bare model."
  @spec none() :: %__MODULE__{}
  def none, do: %__MODULE__{type: :none, payload: %{}}

  @doc """
  Wraps an already-resolved value in a command. The runtime immediately
  dispatches `msg_fn.(value)` through `update/2` without spawning a task.

  Useful for lifting a pure value into the command pipeline.

  The mapper receives only the value, not the model. Do not capture the
  current model in the closure: it will be stale by the time the event
  is processed. The mapper should produce an event struct that `update/2`
  handles by reading the current model at that point.
  """
  @spec dispatch(value :: term(), msg_fn :: (term() -> term())) :: %__MODULE__{}
  def dispatch(value, msg_fn) when is_function(msg_fn, 1) do
    %__MODULE__{type: :dispatch, payload: %{value: value, mapper: msg_fn}}
  end

  @doc """
  Run `fun` asynchronously in a Task. When it returns, the runtime dispatches
  `%Plushie.Event.AsyncEvent{tag: event_tag, result: result}` through `update/2`.

  Only one task per tag can be active. If a task with the same tag is
  already running, it is killed and replaced. Use unique tags if you
  need concurrent tasks.
  """
  @spec async(fun :: fun(), event_tag :: atom()) :: %__MODULE__{}
  def async(fun, event_tag) when is_function(fun) and is_atom(event_tag) do
    %__MODULE__{type: :async, payload: %{fun: fun, tag: event_tag}}
  end

  @doc """
  Focus the widget or canvas element identified by `widget_id`.

  Supports scoped paths for canvas elements: `"canvas/element"`
  focuses the element within the canvas. Supports window-qualified
  paths: `"main#email"` or `"main#canvas/element"`.
  """
  @spec focus(widget_id :: widget_id()) :: %__MODULE__{}
  def focus(widget_id) when is_binary(widget_id) do
    widget_command(widget_id, "focus")
  end

  @doc "Move focus to the next focusable widget."
  @spec focus_next() :: %__MODULE__{}
  def focus_next, do: %__MODULE__{type: :widget_op, payload: %{op: "focus_next"}}

  @doc "Move focus to the previous focusable widget."
  @spec focus_previous() :: %__MODULE__{}
  def focus_previous, do: %__MODULE__{type: :widget_op, payload: %{op: "focus_previous"}}

  @doc """
  Move focus to the next focusable widget within the subtree rooted at
  `scope`. Only widgets that are descendants of the scope widget are
  considered; focus wraps at the subtree boundary.

  Useful for menus, pane grids, and any other keyboard container that
  wants a bounded Tab cycle without leaking focus to siblings.

  ## Example

      Command.focus_next_within("main#menu")
  """
  @spec focus_next_within(scope :: widget_id()) :: %__MODULE__{}
  def focus_next_within(scope) when is_binary(scope) do
    %__MODULE__{type: :widget_op, payload: %{op: "focus_next_within", scope: scope}}
  end

  @doc """
  Move focus to the previous focusable widget within the subtree rooted
  at `scope`. See `focus_next_within/1` for semantics.
  """
  @spec focus_previous_within(scope :: widget_id()) :: %__MODULE__{}
  def focus_previous_within(scope) when is_binary(scope) do
    %__MODULE__{type: :widget_op, payload: %{op: "focus_previous_within", scope: scope}}
  end

  @doc """
  Send `event` through `update/2` after `delay_ms` milliseconds.

  If a timer with the same event term is already pending, the previous
  timer is canceled and replaced. This prevents duplicate deliveries
  when `send_after` is called repeatedly for the same event.
  """
  @spec send_after(delay_ms :: non_neg_integer(), event :: term()) :: %__MODULE__{}
  def send_after(delay_ms, event) when is_integer(delay_ms) and delay_ms >= 0 do
    %__MODULE__{type: :send_after, payload: %{delay: delay_ms, event: event}}
  end

  # ---------------------------------------------------------------------------
  # Delegated: Text (Command.Text)
  # ---------------------------------------------------------------------------

  defdelegate select_all(widget_id), to: __MODULE__.Text
  defdelegate move_cursor_to_front(widget_id), to: __MODULE__.Text
  defdelegate move_cursor_to_end(widget_id), to: __MODULE__.Text
  defdelegate move_cursor_to(widget_id, value), to: __MODULE__.Text
  defdelegate select_range(widget_id, start_pos, end_pos), to: __MODULE__.Text

  # ---------------------------------------------------------------------------
  # Delegated: Scroll (Command.Scroll)
  # ---------------------------------------------------------------------------

  defdelegate scroll_to(widget_id, x, y), to: __MODULE__.Scroll
  defdelegate snap_to(widget_id, x, y), to: __MODULE__.Scroll
  defdelegate snap_to_end(widget_id), to: __MODULE__.Scroll
  defdelegate scroll_by(widget_id, x, y), to: __MODULE__.Scroll

  # ---------------------------------------------------------------------------
  # Delegated: Window operations (Command.Window)
  # ---------------------------------------------------------------------------

  defdelegate close_window(window_id), to: __MODULE__.Window
  defdelegate set_icon(window_id, rgba_data, width, height), to: __MODULE__.Window
  defdelegate resize_window(window_id, width, height), to: __MODULE__.Window
  defdelegate move_window(window_id, x, y), to: __MODULE__.Window
  defdelegate maximize_window(window_id, maximized \\ true), to: __MODULE__.Window
  defdelegate minimize_window(window_id, minimized \\ true), to: __MODULE__.Window
  defdelegate set_window_mode(window_id, mode), to: __MODULE__.Window
  defdelegate toggle_maximize(window_id), to: __MODULE__.Window
  defdelegate toggle_decorations(window_id), to: __MODULE__.Window
  defdelegate focus_window(window_id), to: __MODULE__.Window
  defdelegate set_window_level(window_id, level), to: __MODULE__.Window
  defdelegate drag_window(window_id), to: __MODULE__.Window
  defdelegate drag_resize_window(window_id, direction), to: __MODULE__.Window
  defdelegate request_attention(window_id, urgency \\ nil), to: __MODULE__.Window
  defdelegate screenshot(window_id, tag), to: __MODULE__.Window
  defdelegate set_resizable(window_id, resizable), to: __MODULE__.Window
  defdelegate set_min_size(window_id, width, height), to: __MODULE__.Window
  defdelegate set_max_size(window_id, width, height), to: __MODULE__.Window
  defdelegate enable_mouse_passthrough(window_id), to: __MODULE__.Window
  defdelegate disable_mouse_passthrough(window_id), to: __MODULE__.Window
  defdelegate show_system_menu(window_id), to: __MODULE__.Window
  defdelegate set_resize_increments(window_id, width, height), to: __MODULE__.Window

  # ---------------------------------------------------------------------------
  # Delegated: Window queries (Command.WindowQuery)
  # ---------------------------------------------------------------------------

  defdelegate window_size(window_id, tag), to: __MODULE__.WindowQuery
  defdelegate window_position(window_id, tag), to: __MODULE__.WindowQuery
  defdelegate is_maximized(window_id, tag), to: __MODULE__.WindowQuery
  defdelegate is_minimized(window_id, tag), to: __MODULE__.WindowQuery
  defdelegate window_mode(window_id, tag), to: __MODULE__.WindowQuery
  defdelegate scale_factor(window_id, tag), to: __MODULE__.WindowQuery
  defdelegate raw_id(window_id, tag), to: __MODULE__.WindowQuery
  defdelegate monitor_size(window_id, tag), to: __MODULE__.WindowQuery

  # ---------------------------------------------------------------------------
  # Delegated: Image operations (Command.Image)
  # ---------------------------------------------------------------------------

  defdelegate create_image(handle, data), to: __MODULE__.Image
  defdelegate create_image(handle, width, height, pixels), to: __MODULE__.Image
  defdelegate update_image(handle, data), to: __MODULE__.Image
  defdelegate update_image(handle, width, height, pixels), to: __MODULE__.Image
  defdelegate delete_image(handle), to: __MODULE__.Image
  defdelegate list_images(tag), to: __MODULE__.Image
  defdelegate clear_images(), to: __MODULE__.Image

  @doc "Exit the application."
  @spec exit() :: %__MODULE__{}
  def exit, do: %__MODULE__{type: :exit, payload: %{}}

  @doc """
  Sets whether the system can automatically organize windows into tabs.

  This is a macOS-specific setting. On other platforms it is a no-op.
  See: https://developer.apple.com/documentation/appkit/nswindow/1646657-allowsautomaticwindowtabbing
  """
  @spec allow_automatic_tabbing(enabled :: boolean()) :: %__MODULE__{}
  def allow_automatic_tabbing(enabled) when is_boolean(enabled) do
    %__MODULE__{
      type: :system_op,
      payload: %{op: "allow_automatic_tabbing", enabled: enabled}
    }
  end

  # ---------------------------------------------------------------------------
  # System queries (results arrive as events)
  # ---------------------------------------------------------------------------

  @doc """
  Query the current system theme (light/dark mode).

  The result arrives in `update/2` as
  `%Plushie.Event.SystemEvent{type: :system_theme, tag: tag, value: mode}` where
  `tag` is the stringified event tag and `mode` is `"light"`, `"dark"`, or
  `"none"` (when no system preference is detected). Returns `"none"` on
  Linux systems without a desktop environment. Apps should provide a theme
  fallback.

  ## Example

      def update(model, %Plushie.Event.WidgetEvent{type: :click, id: "check_theme"}) do
        {model, Plushie.Command.system_theme(:theme_result)}
      end

      def update(model, %Plushie.Event.SystemEvent{type: :system_theme, tag: "theme_result", value: mode}) do
        %{model | theme_mode: mode}
      end
  """
  @spec system_theme(tag :: event_tag()) :: %__MODULE__{}
  def system_theme(tag) do
    %__MODULE__{
      type: :system_query,
      payload: %{op: "get_system_theme", tag: to_string(tag)}
    }
  end

  @doc """
  Query system information (OS, CPU, memory, graphics).

  The result arrives in `update/2` as
  `%Plushie.Event.SystemEvent{type: :system_info, tag: tag, value: info}` where `tag`
  is the stringified event tag and `info` is a map with keys:
  `"system_name"`, `"system_kernel"`, `"system_version"`,
  `"system_short_version"`, `"cpu_brand"`, `"cpu_cores"`, `"memory_total"`,
  `"memory_used"`, `"graphics_backend"`, `"graphics_adapter"`.

  System info is always available (the `sysinfo` iced feature is enabled
  unconditionally).

  ## Example

      def update(model, %Plushie.Event.WidgetEvent{type: :click, id: "sys_info"}) do
        {model, Plushie.Command.system_info(:sys_info)}
      end

      def update(model, %Plushie.Event.SystemEvent{type: :system_info, tag: "sys_info", value: info}) do
        %{model | system: info}
      end
  """
  @spec system_info(tag :: event_tag()) :: %__MODULE__{}
  def system_info(tag) do
    %__MODULE__{
      type: :system_query,
      payload: %{op: "get_system_info", tag: to_string(tag)}
    }
  end

  # ---------------------------------------------------------------------------
  # Accessibility
  # ---------------------------------------------------------------------------

  @doc """
  Triggers a screen reader announcement without a visible widget.

  The text is announced by assistive technology as a live-region
  update. The default politeness is `:polite` which is the correct
  choice for most toast-style feedback (saves, confirmations,
  counts). Pass `:assertive` to interrupt the user's current
  announcement for urgent context.

  ## Example

      Command.announce("File saved successfully")
      Command.announce("3 search results found", :polite)
      Command.announce("Connection lost", :assertive)
  """
  @spec announce(text :: String.t(), politeness :: :polite | :assertive) :: %__MODULE__{}
  def announce(text, politeness \\ :polite)
      when is_binary(text) and politeness in [:polite, :assertive] do
    %__MODULE__{
      type: :widget_op,
      payload: %{op: "announce", text: text, politeness: Atom.to_string(politeness)}
    }
  end

  # ---------------------------------------------------------------------------
  # PaneGrid operations
  # ---------------------------------------------------------------------------

  @doc "Split a pane in the pane grid along the given axis."
  @spec pane_split(
          pane_grid_id :: widget_id(),
          pane_id :: String.t(),
          axis :: atom() | String.t(),
          new_pane_id :: String.t()
        ) :: %__MODULE__{}
  def pane_split(pane_grid_id, pane_id, axis, new_pane_id) do
    widget_command(pane_grid_id, "pane_split", %{
      pane: pane_id,
      axis: to_string(axis),
      new_pane_id: new_pane_id
    })
  end

  @doc "Close a pane in the pane grid."
  @spec pane_close(pane_grid_id :: widget_id(), pane_id :: String.t()) :: %__MODULE__{}
  def pane_close(pane_grid_id, pane_id) do
    widget_command(pane_grid_id, "pane_close", %{pane: pane_id})
  end

  @doc "Swap two panes in the pane grid."
  @spec pane_swap(pane_grid_id :: widget_id(), pane_a :: String.t(), pane_b :: String.t()) ::
          %__MODULE__{}
  def pane_swap(pane_grid_id, pane_a, pane_b) do
    widget_command(pane_grid_id, "pane_swap", %{a: pane_a, b: pane_b})
  end

  @doc "Maximize a pane in the pane grid."
  @spec pane_maximize(pane_grid_id :: widget_id(), pane_id :: String.t()) :: %__MODULE__{}
  def pane_maximize(pane_grid_id, pane_id) do
    widget_command(pane_grid_id, "pane_maximize", %{pane: pane_id})
  end

  @doc "Restore all panes from maximized state."
  @spec pane_restore(pane_grid_id :: widget_id()) :: %__MODULE__{}
  def pane_restore(pane_grid_id) do
    widget_command(pane_grid_id, "pane_restore")
  end

  @doc """
  Run `fun` as a streaming async task. The function receives an `emit` callback
  that sends intermediate results to `update/2` as
  `%Plushie.Event.StreamEvent{tag: event_tag, value: value}`. The function's final
  return value is delivered as `%Plushie.Event.AsyncEvent{tag: event_tag, result: result}`.

  Only one task per tag can be active. If a task with the same tag is
  already running, it is killed and replaced. Use unique tags if you
  need concurrent streams.

  This is sugar over spawning a process manually. You can achieve the same
  thing with bare `Task` and `send/2` if you prefer direct Elixir patterns.

  ## Example

      Command.stream(fn emit ->
        for chunk <- File.stream!("big.csv") do
          emit.({:chunk, process(chunk)})
        end
        :done
      end, :file_import)
  """
  @spec stream(fun :: ((term() -> :ok) -> term()), event_tag :: atom()) :: %__MODULE__{}
  def stream(fun, event_tag) when is_function(fun, 1) and is_atom(event_tag) do
    %__MODULE__{type: :stream, payload: %{fun: fun, tag: event_tag}}
  end

  @doc """
  Cancel a running async or stream command by its tag.

  If the task has already completed, this is a no-op. The runtime tracks
  running tasks by their event tag and terminates the associated process.

  ## Example

      Command.cancel(:file_import)
  """
  @spec cancel(event_tag :: atom()) :: %__MODULE__{}
  def cancel(event_tag) when is_atom(event_tag) do
    %__MODULE__{type: :cancel, payload: %{tag: event_tag}}
  end

  @doc """
  Computes a SHA-256 hash of the renderer's current tree state.

  The result arrives in `update/2` as
  `%SystemEvent{type: :tree_hash, tag: tag, value: %{"hash" => "..."}}`.
  """
  @spec tree_hash(tag :: atom()) :: %__MODULE__{}
  def tree_hash(tag) when is_atom(tag) do
    %__MODULE__{
      type: :widget_op,
      payload: %{op: "tree_hash", tag: Atom.to_string(tag)}
    }
  end

  @doc """
  Queries which widget currently has focus.

  The result arrives in `update/2` as
  `%SystemEvent{type: :find_focused, tag: tag, value: %{"focused" => "..." | nil}}`.

  Note: if no widget is focused, the `"focused"` field may be `nil`.
  """
  @spec find_focused(tag :: atom()) :: %__MODULE__{}
  def find_focused(tag) when is_atom(tag) do
    %__MODULE__{
      type: :widget_op,
      payload: %{op: "find_focused", tag: Atom.to_string(tag)}
    }
  end

  @doc """
  Loads a font at runtime from binary data.

  The font data should be the raw bytes of a TrueType (.ttf) or OpenType
  (.otf) font file. Once loaded, the font can be referenced by name in
  widget `font` props.

  ## Example

      font_data = File.read!("path/to/CustomFont.ttf")
      Plushie.Command.load_font(font_data)
  """
  @spec load_font(data :: binary()) :: %__MODULE__{}
  def load_font(data) when is_binary(data) do
    %__MODULE__{
      type: :widget_op,
      payload: %{op: "load_font", data: data}
    }
  end

  # ---------------------------------------------------------------------------
  # Widget commands
  # ---------------------------------------------------------------------------

  @doc """
  Send a command to a widget by ID.

  Commands use the unified wire format matching events:

      {"type": "command", "id": "gauge", "family": "set_value", "value": 72.0}

  The `value` defaults to nil for commands with no payload (e.g. reset).
  The `family` string identifies the operation. For native widgets, it
  maps to the Rust widget's `handle_widget_op` dispatch. For built-in
  widgets, the renderer handles it directly.
  """
  @spec widget_command(id :: String.t(), family :: String.t(), value :: term()) ::
          %__MODULE__{}
  def widget_command(id, family, value \\ nil)
      when is_binary(id) and is_binary(family) do
    %__MODULE__{
      type: :command,
      payload: %{id: id, family: family, value: value}
    }
  end

  @doc """
  Send a batch of widget commands processed atomically in one cycle.

  Each command in the list is a `{id, family, value}` tuple. All commands
  are applied before any resulting events are emitted.
  """
  @spec widget_batch(commands :: [{String.t(), String.t(), term()}]) :: %__MODULE__{}
  def widget_batch(commands) when is_list(commands) do
    %__MODULE__{type: :commands, payload: %{commands: commands}}
  end

  @doc """
  Advance the animation clock by one frame in headless/test mode.

  Sends an `advance_frame` message to the renderer with the given
  `timestamp` (monotonic milliseconds). If `on_animation_frame` is
  subscribed, the renderer emits an `animation_frame` event back.

  This is a test/headless-only command. In normal daemon mode the
  renderer drives animation frames from the display vsync.

  ## Example

      Plushie.Command.advance_frame(16)
  """
  @spec advance_frame(timestamp :: non_neg_integer()) :: %__MODULE__{}
  def advance_frame(timestamp) when is_integer(timestamp) and timestamp >= 0 do
    %__MODULE__{
      type: :advance_frame,
      payload: %{timestamp: timestamp}
    }
  end

  @doc """
  Issue multiple commands. Commands in the batch execute sequentially
  in list order, with state threaded through each.

  Accepts a single command, a list of commands, or a nested list; anything
  `List.wrap/1` can normalize.
  """
  @spec batch(commands :: t() | [t()]) :: %__MODULE__{}
  def batch(commands) do
    %__MODULE__{type: :batch, payload: %{commands: List.wrap(commands)}}
  end

  # ---------------------------------------------------------------------------
  # use Plushie.Command (standalone command DSL)
  # ---------------------------------------------------------------------------

  @doc """
  Standalone DSL for declaring typed command functions.

  Use this in any module to generate command builder functions from
  typed declarations. The same `command` macro used in native widgets
  works here, producing functions that return `%Command{}` structs.

  ## Example

      defmodule Plushie.Command.Text do
        use Plushie.Command

        command :select_all
        command :move_cursor_to, value: :integer
        command :select_range, fields: [start_pos: :integer, end_pos: :integer]
      end

  Generates:

      def select_all(widget_id) when is_binary(widget_id)
      def move_cursor_to(widget_id, value) when is_binary(widget_id) and is_integer(value)
      def select_range(widget_id, start_pos, end_pos) when is_binary(widget_id) and ...
  """
  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :_widget_commands, accumulate: true)

      import Plushie.DSL.Widget.Macro,
        only: [command: 1, command: 2, field: 2, field: 3]

      @before_compile Plushie.Command
    end
  end

  defmacro __before_compile__(env) do
    commands = Module.get_attribute(env.module, :_widget_commands) |> Enum.reverse()

    Plushie.DSL.Widget.Codegen.generate_commands(commands)
  end
end
