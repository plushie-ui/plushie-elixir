defmodule Plushie.Animation.SpringIntegrationTest do
  @moduledoc """
  Integration tests for spring animations through the binary.
  """

  use Plushie.Test.Case, app: Plushie.Animation.SpringIntegrationTest.SpringApp

  alias Plushie.Event.WidgetEvent

  defmodule SpringApp do
    use Plushie.App
    import Plushie.UI

    def init(_opts), do: %{bounced: false}

    def update(model, %WidgetEvent{type: :click, id: "bounce"}),
      do: %{model | bounced: not model.bounced}

    def update(model, _event), do: model

    def view(model) do
      target = if model.bounced, do: 200, else: 100

      window "main", title: "Spring Test" do
        column spacing: 8 do
          container "box", max_width: spring(to: target, preset: :bouncy) do
            text("label", "Width: #{target}")
          end

          container "custom-spring",
            max_width: spring(to: target, stiffness: 300, damping: 15) do
            text("custom-label", "Custom spring")
          end

          button("bounce", "Bounce")
        end
      end
    end
  end

  describe "spring descriptor resolution" do
    test "preset spring resolves to target" do
      box = find!("#box")
      assert box.props[:max_width] == 100
    end

    test "custom spring resolves to target" do
      box = find!("#custom-spring")
      assert box.props[:max_width] == 100
    end

    test "spring target changes on click" do
      click("#bounce")

      box = find!("#box")
      assert box.props[:max_width] == 200
    end

    test "tree renders all elements" do
      assert_exists("#box")
      assert_exists("#custom-spring")
      assert_exists("#bounce")
      assert_text("#label", "Width: 100")
    end
  end
end
