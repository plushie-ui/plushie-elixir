defmodule Julep.App do
  @moduledoc """
  Behaviour for Julep apps following the Elm architecture.

  Implement this behaviour to define a desktop application. The runtime calls
  `init/1` once at startup, then repeatedly calls `update/2` and `view/1` as
  events arrive from the renderer and subscriptions.

  ## Minimal example

      defmodule MyApp do
        use Julep.App

        def init(_opts), do: %{count: 0}

        def update(model, {:click, "increment"}), do: %{model | count: model.count + 1}
        def update(model, _event), do: model

        def view(model) do
          import Julep.UI
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
    operations, window management, or timers. See `Julep.Command` for the full
    command API.

  ## Optional callbacks

  `subscribe/1` and `handle_renderer_exit/2` are optional. `use Julep.App`
  provides default implementations that can be overridden.
  """

  @type model :: term()
  @type event :: tuple()
  @type command :: Julep.Command.t() | [Julep.Command.t()]

  @doc """
  Called once at startup. Returns the initial model, optionally with commands.
  """
  @callback init(opts :: keyword()) :: model | {model, command}

  @doc """
  Called on every event. Returns the next model, optionally with commands.
  """
  @callback update(model, event) :: model | {model, command}

  @doc """
  Called after every update. Returns a UI tree as a plain map.
  """
  @callback view(model) :: map()

  @doc """
  Called after every update. Returns the list of active subscriptions.
  The runtime diffs this list and starts or stops subscriptions as needed.
  Default: `[]`.
  """
  @callback subscribe(model) :: [map()]

  @doc """
  Called when the renderer process exits unexpectedly. Return the model to
  use when the renderer restarts. Default: return model unchanged.
  """
  @callback handle_renderer_exit(model, reason :: term()) :: model

  @doc """
  Called on runtime startup to configure window properties. Default:
  empty config (the renderer uses its own defaults).
  """
  @callback window_config(model) :: map()

  @doc """
  Called once at startup to provide application-level settings to the renderer.

  Supported keys:
  - `default_font` -- a font specification map (same format as font props)
  - `default_text_size` -- a number (pixels)
  - `antialiasing` -- boolean
  - `fonts` -- list of font paths to load

  Default: `[]` (renderer uses its own defaults).
  """
  @callback settings() :: keyword()

  @optional_callbacks subscribe: 1, handle_renderer_exit: 2, window_config: 1, settings: 0

  defmacro __using__(_opts) do
    quote do
      @behaviour Julep.App

      def subscribe(_model), do: []
      def handle_renderer_exit(model, _reason), do: model
      def window_config(_model), do: %{}
      def settings, do: []

      defoverridable subscribe: 1, handle_renderer_exit: 2, window_config: 1, settings: 0
    end
  end
end
