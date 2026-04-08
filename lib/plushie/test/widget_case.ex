defmodule Plushie.Test.WidgetCase do
  @moduledoc """
  ExUnit case template for testing stateful widgets.

  Hosts the widget in a parameterized harness app and records emitted
  events. The widget is initialized in a `setup` block via
  `init_widget/2`, which starts a real Plushie session (Runtime +
  Bridge) connected to the renderer binary.

  ## Usage

      defmodule ColorPickerWidgetTest do
        use Plushie.Test.WidgetCase, widget: ColorPickerWidget

        setup do
          init_widget("picker")
        end

        test "drag on hue ring emits :change" do
          canvas_press("#picker", 370.0, 200.0)
          assert last_event().type == :change
          assert_in_delta last_event().data.hue, 90.0, 2.0
        end

        test "model reflects emitted data" do
          canvas_press("#picker", 370.0, 200.0)
          assert_in_delta model().hue, 90.0, 2.0
        end
      end

  ## How it works

  The case template uses a static harness app module parameterized
  via `init_arg`. The harness:

  - Hosts a single widget instance in a `window > column` layout
  - Records the most recent `%WidgetEvent{}` event in `model().last_event`
  - Merges emitted event data into the model for direct assertions

  The `init_widget/2` function must be called in a `setup` block. It
  configures the widget ID and props, then starts the session. All
  standard test helpers (`click`, `find!`, `canvas_press`, `model`,
  `assert_text`, etc.) are available.

  ## Widget-specific helpers

  - `last_event/0` -- returns the most recent `%WidgetEvent{}` event
    emitted by the widget, or `nil` if none
  - `events/0` -- returns all emitted events (newest first)
  """

  use ExUnit.CaseTemplate

  alias Plushie.Test.Session

  using opts do
    widget_module = Keyword.fetch!(opts, :widget)

    quote do
      import Plushie.Test.Helpers
      import Plushie.Test.WidgetCase.Helpers

      @__widget_module__ unquote(widget_module)

      @doc """
      Initialize the widget under test with the given ID and options.

      Must be called in a `setup` block. Starts a real Plushie session
      with a harness app that hosts the widget.

          setup do
            init_widget("picker", rating: 3)
          end
      """
      def init_widget(id, opts \\ []) when is_binary(id) do
        Plushie.Test.WidgetCase.init_widget(@__widget_module__, id, opts)
      end
    end
  end

  @doc false
  def init_widget(widget_module, widget_id, widget_opts) do
    Plushie.Test.DiagnosticCollector.attach()

    session =
      Session.start(Plushie.Test.WidgetCase.HarnessApp,
        init_arg: [widget_module: widget_module, widget_id: widget_id, widget_opts: widget_opts]
      )

    Process.put(:plushie_test_session, session)

    on_exit(fn ->
      diagnostics = Plushie.Test.DiagnosticCollector.flush()
      Plushie.Test.DiagnosticCollector.detach()

      try do
        Session.stop(session)
      catch
        :exit, _ -> :ok
      end

      if diagnostics != [] do
        details =
          Enum.map_join(diagnostics, "\n", fn d ->
            "  - [#{d[:level]}] #{d[:code]}: #{d[:message]}"
          end)

        raise ExUnit.AssertionError,
          message: "Prop validation diagnostics detected during test:\n#{details}"
      end
    end)

    {:ok, session: session, widget_id: widget_id}
  end
end

defmodule Plushie.Test.WidgetCase.HarnessApp do
  @moduledoc false
  use Plushie.App

  @impl true
  def init(opts) do
    widget_module = Keyword.fetch!(opts, :widget_module)
    widget_id = Keyword.fetch!(opts, :widget_id)
    widget_opts = Keyword.get(opts, :widget_opts, [])

    %{
      widget_module: widget_module,
      widget_id: widget_id,
      widget_opts: widget_opts,
      last_value: %{},
      events: [],
      last_event: nil
    }
  end

  @impl true
  def update(model, %Plushie.Event.WidgetEvent{} = event) do
    data = if is_map(event.value), do: event.value, else: %{}

    model
    |> Map.put(:last_value, atomize_data(data))
    |> Map.put(:events, [event | model.events])
    |> Map.put(:last_event, event)
  end

  def update(model, _event), do: model

  @impl true
  def view(model) do
    import Plushie.UI

    wmod = model.widget_module
    wid = model.widget_id
    wopts = model.widget_opts

    window "test_harness", title: "Widget Test" do
      column do
        wmod.new(wid, wopts)
      end
    end
  end

  defp atomize_data(data) when is_map(data) do
    Map.new(data, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
      {k, v} -> {k, v}
    end)
  end
end

defmodule Plushie.Test.WidgetCase.Helpers do
  @moduledoc false

  @doc """
  Returns the most recent event emitted by the widget under test.

  Returns `nil` if no events have been emitted yet.
  """
  @spec last_event() :: Plushie.Event.WidgetEvent.t() | nil
  def last_event do
    Plushie.Test.Helpers.model().last_event
  end

  @doc """
  Returns all events emitted by the widget (newest first).
  """
  @spec events() :: [Plushie.Event.WidgetEvent.t()]
  def events do
    Plushie.Test.Helpers.model().events
  end
end
