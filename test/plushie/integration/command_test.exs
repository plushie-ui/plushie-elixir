defmodule Plushie.Integration.CommandTest do
  use ExUnit.Case, async: true

  alias Plushie.Event.{AsyncEvent, StreamEvent, TimerEvent, WidgetEvent}

  # ---------------------------------------------------------------------------
  # send_after: fires from init
  # ---------------------------------------------------------------------------

  defmodule SendAfterApp do
    use Plushie.App

    def init(_opts) do
      cmd = Plushie.Command.send_after(20, %TimerEvent{tag: :init_timer, timestamp: 0})
      {%{value: 0}, cmd}
    end

    def update(model, %TimerEvent{tag: :init_timer}) do
      %{model | value: model.value + 1}
    end

    def update(model, _event), do: model

    def view(_model) do
      %{
        id: "main",
        type: "window",
        props: %{},
        children: [
          %{
            id: "auto:SendAfterApp:root",
            type: "column",
            props: %{},
            children: [%{id: "hi", type: "text", props: %{content: "hello"}, children: []}]
          }
        ]
      }
    end
  end

  test "send_after fires from init" do
    session = Plushie.Test.Session.start(SendAfterApp)

    await_model_condition(session, fn m -> m.value >= 1 end)

    Plushie.Test.Session.stop(session)
  end

  # ---------------------------------------------------------------------------
  # async: fires on click, delivers result through update
  # ---------------------------------------------------------------------------

  defmodule AsyncApp do
    use Plushie.App

    def init(_opts), do: %{result: 0}

    def update(model, %WidgetEvent{type: :click, id: "go"}) do
      cmd = Plushie.Command.task(fn -> 42 end, :compute)
      {model, cmd}
    end

    def update(model, %AsyncEvent{tag: :compute, result: value}) do
      %{model | result: value}
    end

    def update(model, _event), do: model

    def view(_model) do
      %{
        id: "main",
        type: "window",
        props: %{},
        children: [
          %{
            id: "auto:AsyncApp:root",
            type: "column",
            props: %{},
            children: [%{id: "go", type: "button", props: %{label: "Go"}, children: []}]
          }
        ]
      }
    end
  end

  test "async completes and dispatches result" do
    session = Plushie.Test.Session.start(AsyncApp)

    Plushie.Test.Session.click(session, "#go")
    Plushie.Test.Session.await_async(session, :compute, 2000)

    m = Plushie.Test.Session.model(session)
    assert m.result == 42

    Plushie.Test.Session.stop(session)
  end

  # ---------------------------------------------------------------------------
  # batch: multiple send_after commands from init
  # ---------------------------------------------------------------------------

  defmodule BatchApp do
    use Plushie.App

    def init(_opts) do
      cmd =
        Plushie.Command.batch([
          Plushie.Command.send_after(15, %TimerEvent{tag: :batch_a, timestamp: 0}),
          Plushie.Command.send_after(15, %TimerEvent{tag: :batch_b, timestamp: 0})
        ])

      {%{a: false, b: false}, cmd}
    end

    def update(model, %TimerEvent{tag: :batch_a}), do: %{model | a: true}
    def update(model, %TimerEvent{tag: :batch_b}), do: %{model | b: true}
    def update(model, _event), do: model

    def view(_model) do
      %{
        id: "main",
        type: "window",
        props: %{},
        children: [
          %{
            id: "auto:BatchApp:root",
            type: "column",
            props: %{},
            children: [%{id: "hi", type: "text", props: %{content: "hello"}, children: []}]
          }
        ]
      }
    end
  end

  test "batch commands all execute from init" do
    session = Plushie.Test.Session.start(BatchApp)

    await_model_condition(session, fn m -> m.a == true and m.b == true end)

    Plushie.Test.Session.stop(session)
  end

  # ---------------------------------------------------------------------------
  # stream: emits intermediate values, then completes
  # ---------------------------------------------------------------------------

  defmodule StreamApp do
    use Plushie.App

    def init(_opts), do: %{chunks: [], done: false}

    def update(model, %WidgetEvent{type: :click, id: "go"}) do
      cmd =
        Plushie.Command.stream(
          fn emit ->
            emit.("a")
            emit.("b")
            emit.("c")
            "done"
          end,
          :chunks
        )

      {model, cmd}
    end

    def update(model, %StreamEvent{tag: :chunks, value: v}) do
      %{model | chunks: model.chunks ++ [v]}
    end

    def update(model, %AsyncEvent{tag: :chunks}) do
      %{model | done: true}
    end

    def update(model, _event), do: model

    def view(_model) do
      %{
        id: "main",
        type: "window",
        props: %{},
        children: [
          %{
            id: "auto:StreamApp:root",
            type: "column",
            props: %{},
            children: [%{id: "go", type: "button", props: %{label: "Go"}, children: []}]
          }
        ]
      }
    end
  end

  test "stream emits intermediate values then completes" do
    session = Plushie.Test.Session.start(StreamApp)

    Plushie.Test.Session.click(session, "#go")
    Plushie.Test.Session.await_async(session, :chunks, 2000)

    m = Plushie.Test.Session.model(session)
    assert m.done == true
    assert m.chunks == ["a", "b", "c"]

    Plushie.Test.Session.stop(session)
  end

  # Polls the session model until condition_fn returns true or timeout expires.
  defp await_model_condition(session, condition_fn, timeout \\ 500) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_await_model_condition(session, condition_fn, deadline)
  end

  defp do_await_model_condition(session, condition_fn, deadline) do
    model = Plushie.Test.Session.model(session)

    if condition_fn.(model) do
      model
    else
      if System.monotonic_time(:millisecond) >= deadline do
        raise ExUnit.AssertionError,
          message: "Timed out waiting for model condition. Last model: #{inspect(model)}"
      else
        Process.sleep(5)
        do_await_model_condition(session, condition_fn, deadline)
      end
    end
  end
end
