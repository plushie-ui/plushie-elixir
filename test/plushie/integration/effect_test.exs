defmodule Plushie.Integration.EffectTest do
  use Plushie.Test.Case, app: Plushie.Integration.EffectTest.EffectApp

  alias Plushie.Event.{EffectEvent, WidgetEvent}

  defmodule EffectApp do
    use Plushie.App

    def init(_opts), do: %{clipboard_text: "", got_unsupported: false}

    def update(model, %WidgetEvent{type: :click, id: "read"}) do
      {model, Plushie.Effect.clipboard_read(:read)}
    end

    def update(model, %EffectEvent{tag: :read, result: {:ok, data}}) do
      text = if is_binary(data), do: data, else: ""
      %{model | clipboard_text: text}
    end

    def update(model, %EffectEvent{tag: :read, result: {:error, :unsupported}}) do
      %{model | got_unsupported: true}
    end

    def update(model, _event), do: model

    def view(_model) do
      %{
        id: "main",
        type: "window",
        props: %{},
        children: [
          %{
            id: "auto:EffectApp:root",
            type: "column",
            props: %{},
            children: [
              %{id: "read", type: "button", props: %{label: "Read Clipboard"}, children: []}
            ]
          }
        ]
      }
    end
  end

  test "stubbed effect returns controlled response" do
    register_effect_stub(:clipboard_read, "test data")

    click("#read")

    # The effect response arrives asynchronously after the interact
    # completes. Poll until the model reflects the response.
    assert_eventually(fn -> model().clipboard_text == "test data" end)
  end

  test "unregister removes the stub" do
    register_effect_stub(:clipboard_read, "first")
    unregister_effect_stub(:clipboard_read)

    # Without a stub, clipboard_read in mock mode returns unsupported
    # or an empty response. We just verify no crash occurs.
    click("#read")

    m = model()
    # After unregister, the mock backend has no real clipboard,
    # so we should not get "first" back.
    refute m.clipboard_text == "first"
  end

  defp assert_eventually(condition_fn, timeout \\ 500) do
    deadline = System.monotonic_time(:millisecond) + timeout

    do_assert_eventually(condition_fn, deadline)
  end

  defp do_assert_eventually(condition_fn, deadline) do
    if condition_fn.() do
      :ok
    else
      if System.monotonic_time(:millisecond) >= deadline do
        flunk("Timed out waiting for condition")
      else
        Process.sleep(5)
        do_assert_eventually(condition_fn, deadline)
      end
    end
  end
end
