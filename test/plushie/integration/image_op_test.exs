defmodule Plushie.Integration.ImageOpTest do
  @moduledoc """
  Drives the real renderer to verify that the typed `image_op` wire
  channel carries `list` and `clear` correctly. The renderer rejects
  the older `widget_op` shapes for these ops, so a passing test means
  the SDK is producing the canonical wire envelope.

  `clear` followed by `list` confirms both ops by observing the
  registry going from empty to empty through the same channel.
  """

  use ExUnit.Case, async: true

  alias Plushie.Command
  alias Plushie.Event.{SystemEvent, WidgetEvent}

  defmodule ImageApp do
    use Plushie.App

    def init(_opts), do: %{handles: nil}

    def update(model, %WidgetEvent{type: :click, id: "go"}) do
      # `clear` is a no-op against an empty registry; the round-trip
      # exercises the typed image_op channel without depending on
      # large binary payloads (which take a different code path).
      cmd =
        Command.batch([
          Command.clear_images(),
          Command.list_images(:after_clear)
        ])

      {model, cmd}
    end

    def update(model, %SystemEvent{type: :image_list, tag: "after_clear", value: value}) do
      %{model | handles: handles(value)}
    end

    def update(model, _event), do: model

    defp handles(%{handles: h}), do: h
    defp handles(%{"handles" => h}), do: h
    defp handles(_), do: []

    def view(_model) do
      %{
        id: "main",
        type: "window",
        props: %{},
        children: [
          %{
            id: "auto:ImageApp:root",
            type: "column",
            props: %{},
            children: [
              %{id: "go", type: "button", props: %{label: "Go"}, children: []}
            ]
          }
        ]
      }
    end
  end

  test "image_op list/clear roundtrip the typed channel end-to-end" do
    session = Plushie.Test.Session.start(ImageApp)

    Plushie.Test.Session.click(session, "#go")

    await_model_condition(session, fn m -> is_list(m.handles) end)

    m = Plushie.Test.Session.model(session)
    assert m.handles == []

    Plushie.Test.Session.stop(session)
  end

  defp await_model_condition(session, condition_fn, timeout \\ 1000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_await(session, condition_fn, deadline)
  end

  defp do_await(session, condition_fn, deadline) do
    model = Plushie.Test.Session.model(session)

    cond do
      condition_fn.(model) ->
        model

      System.monotonic_time(:millisecond) >= deadline ->
        raise ExUnit.AssertionError,
          message: "Timed out waiting for model condition. Last model: #{inspect(model)}"

      true ->
        Process.sleep(5)
        do_await(session, condition_fn, deadline)
    end
  end
end
