defmodule Toddy.App do
  @moduledoc """
  Behaviour for Toddy apps following the Elm architecture.

  Implement this behaviour to define a desktop application. The runtime calls
  `init/1` once at startup, then repeatedly calls `update/2` and `view/1` as
  events arrive from the renderer and subscriptions.

  ## Minimal example

      defmodule MyApp do
        use Toddy.App

        alias Toddy.Event.Widget

        def init(_opts), do: %{count: 0}

        def update(model, %Widget{type: :click, id: "increment"}), do: %{model | count: model.count + 1}
        def update(model, _event), do: model

        def view(model) do
          import Toddy.UI
          column do
            text("Count: \#{model.count}")
            button("increment", "Increment")
          end
        end
      end

  ## Return values

  `init/1` and `update/2` both accept two return shapes:

  - Bare model -- no side effects needed.
  - `{model, command}` or `{model, [command]}` -- schedule async work, widget
    operations, window management, or timers. See `Toddy.Command` for the full
    command API.

  ## Returning commands

  `update/2` can return a `{model, command}` tuple to schedule side effects:

      def update(model, %Widget{type: :click, id: "save"}) do
        {model, Command.async(fn -> save_to_disk(model) end, :save_result)}
      end

  See `Toddy.Command` for the full command API and result delivery mechanisms.

  ## Error handling

  Exceptions in `update/2` and `view/1` are caught by the runtime and logged;
  the model reverts to its pre-exception state. You do not need to wrap your
  callbacks in try/rescue. After 100 consecutive errors, the runtime suppresses
  further log messages to prevent log flooding.

  ## Optional callbacks

  `subscribe/1` and `handle_renderer_exit/2` are optional. `use Toddy.App`
  provides default implementations that can be overridden.
  """

  @type model :: term()
  @type event :: Toddy.Event.t() | term()
  @type command :: Toddy.Command.t() | [Toddy.Command.t()]

  @doc """
  Called once at startup. Returns the initial model, optionally with commands.
  """
  @callback init(opts :: keyword()) :: model | {model, command}

  @doc """
  Called on every event. Returns the next model, optionally with commands.

  In addition to `Toddy.Event` structs from the renderer and subscriptions,
  `update/2` may receive internal tuple events (e.g. async results, stream
  chunks, effect responses). Pattern match broadly or include a catch-all clause.
  """
  @callback update(model, event) :: model | {model, command}

  @doc """
  Called after every update. Returns a UI tree as a plain map.
  """
  @callback view(model) :: Toddy.Widget.ui_node()

  @doc """
  Called after every update. Returns the list of active subscriptions.
  The runtime diffs this list and starts or stops subscriptions as needed.
  Default: `[]`.
  """
  @callback subscribe(model) :: [Toddy.Subscription.t()]

  @doc """
  Called when the renderer process exits unexpectedly. Return the model to
  use when the renderer restarts. Default: return model unchanged.
  """
  @callback handle_renderer_exit(model, reason :: term()) :: model

  @doc """
  Called on runtime startup to configure window properties. Also called
  on renderer restart whenever windows need re-opening. Per-window props
  set in the view tree override these defaults.

  ## Supported keys

  `title`, `size`, `width`, `height`, `position`, `min_size`, `max_size`,
  `maximized`, `fullscreen`, `visible`, `resizable`, `closeable`,
  `minimizable`, `decorations`, `transparent`, `blur`, `level`,
  `exit_on_close_request`.

  See `Toddy.Widget.Window` for details on each property.

  ## Example

      def window_config(_model) do
        %{title: "My App", width: 800, height: 600, min_size: {400, 300}}
      end

  Default: empty config (the renderer uses its own defaults).
  """
  @callback window_config(model) :: map()

  @doc """
  Called once at startup to provide application-level settings to the renderer.

  Supported keys:
  - `default_font` -- a font specification map (same format as font props)
  - `default_text_size` -- a number (pixels)
  - `antialiasing` -- boolean
  - `vsync` -- boolean (defaults to `true`). When enabled, the renderer
    synchronizes frame presentation with the display refresh rate. Disabling
    it can improve rendering performance on some platforms.
  - `scale_factor` -- number (defaults to `1.0`). Multiplier on top of OS
    DPI scaling. Setting `2.0` on a 2x HiDPI display gives 4x physical
    pixels per logical pixel. Per-window overrides are supported via the
    `scale_factor` prop on window nodes.
  - `theme` -- built-in theme atom (e.g. `:dark`, `:nord`), `:system` to
    follow the OS light/dark preference, or a custom palette map.
    See `Toddy.Type.Theme`.
  - `fonts` -- list of font paths to load
  - `default_event_rate` -- integer, maximum events per second for
    coalescable event types. Omit for unlimited (default). Affects mouse
    moves, scroll, animation frames, slider drags, etc. Set to 60 for
    most apps, lower for dashboards or remote rendering. Per-subscription
    `max_rate` and per-widget `event_rate` override this default.

  Default: `[]` (renderer uses its own defaults).
  """
  @callback settings() :: keyword()

  @optional_callbacks subscribe: 1, handle_renderer_exit: 2, window_config: 1, settings: 0

  defmacro __using__(_opts) do
    quote do
      @behaviour Toddy.App

      def subscribe(_model), do: []
      def handle_renderer_exit(model, _reason), do: model
      def window_config(_model), do: %{}
      def settings, do: []

      defoverridable subscribe: 1, handle_renderer_exit: 2, window_config: 1, settings: 0
    end
  end
end
