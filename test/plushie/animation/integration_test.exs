defmodule Plushie.Animation.IntegrationTest do
  @moduledoc """
  Integration tests for the animation system through the real renderer binary.

  These tests exercise the full pipeline: Elixir view -> encode ->
  wire -> renderer -> tree query. They verify that transition
  descriptors survive the round-trip and resolve correctly.
  """

  use Plushie.Test.Case, app: Plushie.Animation.IntegrationTest.TransitionApp

  alias Plushie.Event.WidgetEvent

  # ---------------------------------------------------------------------------
  # Test app with transitions, springs, loops, and exit
  # ---------------------------------------------------------------------------

  defmodule TransitionApp do
    use Plushie.App
    import Plushie.UI

    def init(_opts) do
      %{expanded: true, show_item: true, pulse: false}
    end

    def update(model, %WidgetEvent{type: :click, id: "toggle"}) do
      %{model | expanded: not model.expanded}
    end

    def update(model, %WidgetEvent{type: :click, id: "remove"}) do
      %{model | show_item: false}
    end

    def update(model, %WidgetEvent{type: :click, id: "pulse"}) do
      %{model | pulse: true}
    end

    def update(model, _event), do: model

    def view(model) do
      target = if model.expanded, do: 400, else: 200
      spring_target = if model.expanded, do: 300, else: 100

      window "main", title: "Animation Test" do
        column padding: 16, spacing: 8 do
          # Timed transition on max_width
          container "panel", max_width: transition(300, to: target) do
            text("panel-text", "Panel content")
          end

          # Spring on max_height
          container "spring-box", max_height: spring(to: spring_target, preset: :snappy) do
            text("spring-text", "Spring content")
          end

          # Enter animation with from:
          container "enter-box", max_width: transition(200, to: 300, from: 0) do
            text("enter-text", "Entered!")
          end

          # Loop
          if model.pulse do
            container "pulse-box", max_width: loop(800, to: 250, from: 300) do
              text("pulse-text", "Pulsing")
            end
          end

          # Item with exit animation
          if model.show_item do
            container "removable", max_width: transition(200, to: 300, from: 0) do
              text("removable-text", "Removable item")
            end
          end

          # Sequence
          container "seq-box",
            max_width:
              sequence([
                transition(100, to: 200, from: 0),
                transition(100, to: 300)
              ]) do
            text("seq-text", "Sequence")
          end

          # Controls
          button("toggle", "Toggle")
          button("remove", "Remove Item")
          button("pulse", "Start Pulse")
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Basic rendering: descriptors resolve to target values
  # ---------------------------------------------------------------------------

  describe "transition props resolve through binary" do
    test "timed transition resolves to target value" do
      panel = find!("#panel")
      # In mock mode, the descriptor resolves to its target
      assert panel.props[:max_width] == 400
    end

    test "spring resolves to target value" do
      box = find!("#spring-box")
      assert box.props[:max_height] == 300
    end

    test "enter animation resolves to target (not from)" do
      box = find!("#enter-box")
      assert box.props[:max_width] == 300
    end

    test "sequence resolves to final step target" do
      box = find!("#seq-box")
      assert box.props[:max_width] == 300
    end
  end

  # ---------------------------------------------------------------------------
  # Model changes trigger new targets
  # ---------------------------------------------------------------------------

  describe "model changes update transition targets" do
    test "toggling model changes the resolved target" do
      assert find!("#panel").props[:max_width] == 400

      click("#toggle")

      assert find!("#panel").props[:max_width] == 200
    end

    test "spring target updates on model change" do
      assert find!("#spring-box").props[:max_height] == 300

      click("#toggle")

      assert find!("#spring-box").props[:max_height] == 100
    end
  end

  # ---------------------------------------------------------------------------
  # Conditional rendering with transitions
  # ---------------------------------------------------------------------------

  describe "conditional widgets with transitions" do
    test "pulse container appears when activated" do
      assert find("#pulse-box") == nil

      click("#pulse")

      assert_exists("#pulse-box")
      # Loop resolves to its to: value
      box = find!("#pulse-box")
      assert box.props[:max_width] == 250
    end

    test "removable item disappears from model on remove" do
      assert_exists("#removable")
      assert model().show_item == true

      click("#remove")

      assert model().show_item == false
    end
  end

  # ---------------------------------------------------------------------------
  # Tree structure remains correct with transitions
  # ---------------------------------------------------------------------------

  describe "tree structure" do
    test "root is a window" do
      t = tree()
      assert t.type == "window"
    end

    test "all expected elements exist" do
      assert_exists("#panel")
      assert_exists("#spring-box")
      assert_exists("#enter-box")
      assert_exists("#seq-box")
      assert_exists("#toggle")
      assert_exists("#remove")
    end

    test "text content renders correctly" do
      assert_text("#panel-text", "Panel content")
      assert_text("#spring-text", "Spring content")
      assert_text("#enter-text", "Entered!")
    end
  end

  # ---------------------------------------------------------------------------
  # Removable widget
  # ---------------------------------------------------------------------------

  describe "removable widget" do
    test "removable item renders initially" do
      assert find("#removable") != nil
      box = find!("#removable")
      assert box.props[:max_width] == 300
    end
  end
end
