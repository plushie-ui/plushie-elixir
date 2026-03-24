defmodule Plushie.Test.WidgetCase do
  @moduledoc """
  ExUnit case template for testing canvas_widget extensions.

  Generates a harness app that hosts the widget and records emitted
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
          assert_in_delta last_event().data["hue"], 90.0, 2.0
        end

        test "model reflects emitted data" do
          canvas_press("#picker", 370.0, 200.0)
          assert_in_delta model().hue, 90.0, 2.0
        end
      end

  ## How it works

  The case template generates a harness app module scoped to the test
  module. The harness:

  - Hosts a single widget instance in a `window > column` layout
  - Records the most recent `%Widget{}` event in `model().last_event`
  - Merges emitted event data into the model for direct assertions

  The `init_widget/2` function must be called in a `setup` block. It
  configures the widget ID and props, then starts the session. All
  standard test helpers (`click`, `find!`, `canvas_press`, `model`,
  `assert_text`, etc.) are available.

  ## Widget-specific helpers

  - `last_event/0` -- returns the most recent `%Widget{}` event
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
        harness = Plushie.Test.WidgetCase.build_harness(@__widget_module__, id, opts)
        session = Session.start(harness)
        Process.put(:plushie_test_session, session)

        on_exit(fn ->
          try do
            Session.stop(session)
          catch
            :exit, _ -> :ok
          end
        end)

        {:ok, session: session, widget_id: id}
      end
    end
  end

  @doc false
  def build_harness(widget_module, widget_id, widget_opts) do
    # Create a unique harness module name per widget + ID to avoid
    # module name collisions across concurrent test modules.
    hash = :erlang.phash2({widget_module, widget_id, self()})

    harness_name =
      Module.concat([
        Plushie.Test.WidgetCase.Harness,
        :"#{inspect(widget_module)}_#{hash}"
      ])

    # Define the harness module dynamically. It wraps the widget
    # in a minimal app that records emitted events.
    unless Code.ensure_loaded?(harness_name) do
      defmodule harness_name do
        use Plushie.App

        Module.put_attribute(__MODULE__, :__widget_module__, widget_module)
        Module.put_attribute(__MODULE__, :__widget_id__, widget_id)
        Module.put_attribute(__MODULE__, :__widget_opts__, widget_opts)

        def init(_opts) do
          %{events: [], last_event: nil}
        end

        # Canvas framework event types that are internal to the
        # renderer/canvas lifecycle -- not semantic widget events.
        @canvas_framework_types ~w(
          canvas_focused canvas_blurred
          canvas_element_focused canvas_element_blurred
          canvas_group_focused canvas_group_blurred
          canvas_element_enter canvas_element_leave
        )a

        def update(model, %Plushie.Event.Widget{type: type} = event)
            when type not in @canvas_framework_types do
          data = event.data || %{}

          model
          |> Map.merge(atomize_data(data))
          |> Map.put(:events, [event | model.events])
          |> Map.put(:last_event, event)
        end

        def update(model, _event), do: model

        def view(_model) do
          import Plushie.UI

          wmod = @__widget_module__
          wid = @__widget_id__
          wopts = @__widget_opts__

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
    end

    harness_name
  end
end

defmodule Plushie.Test.WidgetCase.Helpers do
  @moduledoc false

  @doc """
  Returns the most recent event emitted by the widget under test.

  Returns `nil` if no events have been emitted yet.
  """
  @spec last_event() :: Plushie.Event.Widget.t() | nil
  def last_event do
    Plushie.Test.Helpers.model().last_event
  end

  @doc """
  Returns all events emitted by the widget (newest first).
  """
  @spec events() :: [Plushie.Event.Widget.t()]
  def events do
    Plushie.Test.Helpers.model().events
  end
end
