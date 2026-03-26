defmodule Plushie.Integration.EffectTest do
  use Plushie.Test.Case, app: Plushie.Integration.EffectTest.EffectApp

  alias Plushie.Event.{Effect, WidgetEvent}

  defmodule EffectApp do
    use Plushie.App

    def init(_opts), do: %{clipboard_text: "", got_unsupported: false}

    def update(model, %WidgetEvent{type: :click, id: "read"}) do
      {model, Plushie.Effects.clipboard_read()}
    end

    def update(model, %Effect{result: {:ok, data}}) do
      text = if is_binary(data), do: data, else: ""
      %{model | clipboard_text: text}
    end

    def update(model, %Effect{result: {:error, :unsupported}}) do
      %{model | got_unsupported: true}
    end

    def update(model, _event), do: model

    def view(_model) do
      %{
        id: "auto:EffectApp:root",
        type: "column",
        props: %{},
        children: [
          %{id: "read", type: "button", props: %{label: "Read Clipboard"}, children: []}
        ]
      }
    end
  end

  test "stubbed effect returns controlled response" do
    register_effect_stub("clipboard_read", "test data")

    click("#read")

    # The effect response arrives asynchronously after the interact
    # completes. Give the runtime a moment to process it.
    Process.sleep(100)

    assert model().clipboard_text == "test data"
  end

  test "unregister removes the stub" do
    register_effect_stub("clipboard_read", "first")
    unregister_effect_stub("clipboard_read")

    # Without a stub, clipboard_read in mock mode returns unsupported
    # or an empty response. We just verify no crash occurs.
    click("#read")

    m = model()
    # After unregister, the mock backend has no real clipboard,
    # so we should not get "first" back.
    refute m.clipboard_text == "first"
  end
end
