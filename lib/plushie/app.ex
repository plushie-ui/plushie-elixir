defmodule Plushie.App do
  @moduledoc """
  Behaviour for Plushie apps following the Elm architecture.

  Implement this behaviour to define a desktop application. The runtime calls
  `init/1` once at startup, then repeatedly calls `update/2` and `view/1` as
  events arrive from the renderer and subscriptions.

  ## Minimal example

      defmodule MyApp do
        use Plushie.App

        alias Plushie.Event.WidgetEvent

        def init(_opts), do: %{count: 0}

        def update(model, %WidgetEvent{type: :click, id: "increment"}),
          do: %{model | count: model.count + 1}

        def update(model, _event), do: model

        def view(model) do
          import Plushie.UI

          window "counter", title: "Counter" do
            column do
              text("count", "Count: \#{model.count}")
              button("increment", "Increment")
            end
          end
        end
      end

  ## Return values

  `init/1` and `update/2` both accept two return shapes:

  - Bare model: no side effects needed.
  - `{model, command}` or `{model, [command]}`: schedule async work, widget
    operations, window management, or timers. See `Plushie.Command` for the
    full command API.

  ## Commands

  Return a `{model, command}` tuple from `update/2` or `init/1` to schedule
  side effects:

      def init(_opts) do
        model = %{data: nil, loading: true}
        {model, Command.task(fn -> load_initial_data() end, :loaded)}
      end

      def update(model, %WidgetEvent{type: :click, id: "save"}) do
        {model, Command.task(fn -> save_to_disk(model) end, :save_result)}
      end

  See `Plushie.Command` for the full command API and result delivery.

  ## Subscriptions

  Override `subscribe/1` to receive ongoing events. The runtime diffs the
  subscription list after each update and starts or stops subscriptions as
  needed.

      def subscribe(model) do
        subs = [Plushie.Subscription.on_key(:key_events)]

        if model.auto_refresh do
          [Plushie.Subscription.every(5000, :refresh) | subs]
        else
          subs
        end
      end

  See `Plushie.Subscription` for all subscription types.

  ## Error handling

  Exceptions in `update/2` and `view/1` are caught by the runtime and logged;
  the model reverts to its pre-exception state. You do not need to wrap your
  callbacks in try/rescue. After 100 consecutive errors, the runtime suppresses
  further log messages to prevent log flooding.

  ## Optional callbacks

  `subscribe/1`, `handle_renderer_exit/2`, `window_config/1`, and `settings/0`
  are optional. `use Plushie.App` provides default implementations that can be
  overridden.
  """

  @type model :: term()

  @typedoc """
  Events delivered to `update/2`.

  Most events are `Plushie.Event` structs from the renderer and
  subscriptions. The `term()` case covers bare values delivered by
  `Command.send_after/2` and `Command.dispatch/2`.
  """
  @type event :: Plushie.Event.t() | term()

  @type command :: Plushie.Command.t() | [Plushie.Command.t()]
  @type window_view ::
          Plushie.Widget.Window.t() | map() | [Plushie.Widget.Window.t() | map()] | nil

  @doc """
  Called once at startup. Returns the initial model, optionally with
  commands for loading initial data or configuring the UI.
  """
  @callback init(opts :: keyword()) :: model | {model, command}

  @doc """
  Called on every event. Returns the next model, optionally with commands.

  Events are `Plushie.Event` structs (widget interactions, key presses,
  window lifecycle, async results, timer ticks, etc.) or bare terms from
  `Command.send_after/2`. Include a catch-all clause for unhandled events.
  """
  @callback update(model, event) :: model | {model, command}

  @doc """
  Called after every update. Returns a window node or a list of window nodes.

  The top level must be explicit windows. Single-window apps return one
  `window(...)` node. Multi-window apps return a list of `window(...)` nodes.
  `nil` or `[]` is allowed when the app intentionally has no open windows.
  """
  @callback view(model) :: window_view()

  @doc """
  Called after every update. Returns the list of active subscriptions.
  The runtime diffs this list and starts or stops subscriptions as needed.
  Default: `[]`.
  """
  @callback subscribe(model) :: [Plushie.Subscription.t()]

  @doc """
  Called when the renderer process exits unexpectedly. Receives a
  `%Plushie.RendererExit{}` struct with `:type`, `:message`, and `:details`.
  Return the model to use when the renderer restarts.
  Default: return model unchanged.
  """
  @callback handle_renderer_exit(model, reason :: Plushie.RendererExit.t()) :: model

  @doc """
  Called on runtime startup to configure window properties. Also called
  on renderer restart whenever windows need re-opening. Per-window props
  set in the view tree override these defaults.

  ## Supported keys

  `title`, `size`, `width`, `height`, `position`, `min_size`, `max_size`,
  `maximized`, `fullscreen`, `visible`, `resizable`, `closeable`,
  `minimizable`, `decorations`, `transparent`, `blur`, `level`,
  `exit_on_close_request`.

  See `Plushie.Widget.Window` for details on each property.

  ## Example

      def window_config(_model) do
        %{title: "My App", width: 800, height: 600, min_size: {400, 300}}
      end

  Default: empty config (the renderer uses its own defaults).
  """
  @callback window_config(model) :: map()

  @doc """
  Called once at startup to provide application-level settings to the
  renderer.

  ## Typography

  - `default_font`: font specification map (same format as font props)
  - `default_text_size`: base text size in pixels
  - `fonts`: list of font file paths to load at startup

  ## Theming

  - `theme`: built-in theme atom (e.g. `:dark`, `:nord`), `:system`
    to follow the OS light/dark preference, or a custom palette map.
    See `Plushie.Type.Theme`.

  ## Rendering

  - `antialiasing`: boolean
  - `vsync`: boolean (default `true`). Synchronizes frame presentation
    with the display refresh rate. Disabling can improve performance on
    some platforms.
  - `scale_factor`: number (default `1.0`). Multiplier on top of OS
    DPI scaling. Per-window overrides via the `scale_factor` window prop.

  ## Performance

  - `default_event_rate`: integer, max events per second for coalescable
    event types (mouse moves, scroll, slider drags, etc.). Omit for
    unlimited. Set to 60 for most apps, lower for dashboards or remote
    rendering. Per-subscription `max_rate` and per-widget `event_rate`
    override this default.

  ## Native widgets

  - `widget_config`: map of namespace -> config for native widgets.
    Each key matches a widget's `namespace()` on the Rust side. The
    config is passed to `PlushieWidget::init()` via `InitCtx.config`.
    Also configurable via `config :plushie, :widget_config`.

  Default: `%{}` (renderer uses its own defaults).
  """
  @callback settings() :: map()

  @optional_callbacks handle_renderer_exit: 2, settings: 0, subscribe: 1, window_config: 1

  defmacro __using__(_opts) do
    quote do
      @behaviour Plushie.App

      def subscribe(_model), do: []
      def handle_renderer_exit(model, _reason), do: model
      def window_config(_model), do: %{}
      def settings, do: %{}

      defoverridable subscribe: 1, handle_renderer_exit: 2, window_config: 1, settings: 0
    end
  end
end
