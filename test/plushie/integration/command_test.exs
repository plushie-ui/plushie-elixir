defmodule Plushie.Integration.CommandTest do
  use ExUnit.Case, async: true

  alias Plushie.Event.{Async, Stream, Timer, Widget}

  @moduletag :integration

  # ---------------------------------------------------------------------------
  # send_after: fires from init
  # ---------------------------------------------------------------------------

  defmodule SendAfterApp do
    use Plushie.App

    def init(_opts) do
      cmd = Plushie.Command.send_after(20, %Timer{tag: :init_timer, timestamp: 0})
      {%{value: 0}, cmd}
    end

    def update(model, %Timer{tag: :init_timer}) do
      %{model | value: model.value + 1}
    end

    def update(model, _event), do: model

    def view(_model) do
      %{
        id: "auto:SendAfterApp:root",
        type: "column",
        props: %{},
        children: [%{id: "hi", type: "text", props: %{content: "hello"}, children: []}]
      }
    end
  end

  test "send_after fires from init" do
    session = Plushie.Test.Session.start(SendAfterApp)

    Process.sleep(100)
    m = Plushie.Test.Session.model(session)
    assert m.value >= 1

    Plushie.Test.Session.stop(session)
  end

  # ---------------------------------------------------------------------------
  # async: fires on click, delivers result through update
  # ---------------------------------------------------------------------------

  defmodule AsyncApp do
    use Plushie.App

    def init(_opts), do: %{result: 0}

    def update(model, %Widget{type: :click, id: "go"}) do
      cmd = Plushie.Command.async(fn -> 42 end, :compute)
      {model, cmd}
    end

    def update(model, %Async{tag: :compute, result: value}) do
      %{model | result: value}
    end

    def update(model, _event), do: model

    def view(_model) do
      %{
        id: "auto:AsyncApp:root",
        type: "column",
        props: %{},
        children: [%{id: "go", type: "button", props: %{label: "Go"}, children: []}]
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
          Plushie.Command.send_after(15, %Timer{tag: :batch_a, timestamp: 0}),
          Plushie.Command.send_after(15, %Timer{tag: :batch_b, timestamp: 0})
        ])

      {%{a: false, b: false}, cmd}
    end

    def update(model, %Timer{tag: :batch_a}), do: %{model | a: true}
    def update(model, %Timer{tag: :batch_b}), do: %{model | b: true}
    def update(model, _event), do: model

    def view(_model) do
      %{
        id: "auto:BatchApp:root",
        type: "column",
        props: %{},
        children: [%{id: "hi", type: "text", props: %{content: "hello"}, children: []}]
      }
    end
  end

  test "batch commands all execute from init" do
    session = Plushie.Test.Session.start(BatchApp)

    Process.sleep(100)
    m = Plushie.Test.Session.model(session)
    assert m.a == true
    assert m.b == true

    Plushie.Test.Session.stop(session)
  end

  # ---------------------------------------------------------------------------
  # stream: emits intermediate values, then completes
  # ---------------------------------------------------------------------------

  defmodule StreamApp do
    use Plushie.App

    def init(_opts), do: %{chunks: [], done: false}

    def update(model, %Widget{type: :click, id: "go"}) do
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

    def update(model, %Stream{tag: :chunks, value: v}) do
      %{model | chunks: model.chunks ++ [v]}
    end

    def update(model, %Async{tag: :chunks}) do
      %{model | done: true}
    end

    def update(model, _event), do: model

    def view(_model) do
      %{
        id: "auto:StreamApp:root",
        type: "column",
        props: %{},
        children: [%{id: "go", type: "button", props: %{label: "Go"}, children: []}]
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
end
