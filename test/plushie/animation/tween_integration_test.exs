defmodule Plushie.Animation.TweenIntegrationTest do
  @moduledoc """
  Integration tests for Plushie.Animation.Tween through the real
  renderer binary. Tests the model-level animation lifecycle and
  tree rendering.
  """

  use Plushie.Test.Case, app: Plushie.Animation.TweenIntegrationTest.AnimApp

  alias Plushie.Animation.Tween
  alias Plushie.Event.WidgetEvent

  defmodule AnimApp do
    use Plushie.App
    import Plushie.UI

    alias Plushie.Animation.Tween
    alias Plushie.Event.WidgetEvent

    def init(_opts) do
      anim = Tween.new(from: 0.0, to: 100.0, duration: 200, easing: :linear)
      %{anim: anim, value: 0.0, started: false}
    end

    def update(model, %WidgetEvent{type: :click, id: "start"}) do
      # Simulate starting the animation at timestamp 0
      anim = Tween.start(model.anim, 0)
      %{model | anim: anim, started: true}
    end

    def update(model, %WidgetEvent{type: :click, id: "advance"}) do
      # Advance by 100ms
      anim = Tween.advance(model.anim, 100)
      %{model | anim: anim, value: Tween.value(anim)}
    end

    def update(model, %WidgetEvent{type: :click, id: "finish"}) do
      # Advance past completion
      anim = Tween.advance(model.anim, 300)
      %{model | anim: anim, value: Tween.value(anim)}
    end

    def update(model, _event), do: model

    def view(model) do
      window "main", title: "SDK Animation" do
        column padding: 16, spacing: 8 do
          text("value", "Value: #{Float.round(model.value, 1)}")
          text("finished", "Finished: #{Tween.finished?(model.anim)}")
          text("running", "Running: #{Tween.running?(model.anim)}")
          button("start", "Start")
          button("advance", "Advance")
          button("finish", "Finish")
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Initial state through binary
  # ---------------------------------------------------------------------------

  describe "initial state" do
    test "animation starts at from value" do
      assert model().value == 0.0
    end

    test "tree shows initial values" do
      assert_text("#value", "Value: 0.0")
      assert_text("#finished", "Finished: false")
      assert_text("#running", "Running: false")
    end
  end

  # ---------------------------------------------------------------------------
  # Animation lifecycle through click-driven updates
  # ---------------------------------------------------------------------------

  describe "animation through binary" do
    test "start sets running state" do
      click("#start")

      assert model().started == true
      assert Tween.running?(model().anim)
      assert_text("#running", "Running: true")
    end

    test "advance progresses the value" do
      click("#start")
      click("#advance")

      m = model()
      assert_in_delta m.value, 50.0, 1.0
      refute Tween.finished?(m.anim)
    end

    test "finish completes the animation" do
      click("#start")
      click("#finish")

      m = model()
      assert_in_delta m.value, 100.0, 1.0
      assert Tween.finished?(m.anim)
      assert_text("#finished", "Finished: true")
    end

    test "tree reflects animated value" do
      click("#start")
      click("#advance")

      # Value should be around 50.0
      label = find!("#value")
      content = Plushie.Automation.Element.text(label)
      assert content =~ "50"
    end
  end
end
