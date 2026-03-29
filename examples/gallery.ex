defmodule Gallery do
  @moduledoc """
  Widget gallery for the Plushie Pad.

  Demonstrates common widget types with static initial values. Interact
  with each widget and watch the event log in the pad to see the events
  they produce.

      mix plushie.gui Gallery
  """

  use Plushie.App

  alias Plushie.Event.WidgetEvent

  import Plushie.UI

  def init(_opts) do
    %{
      input_value: "",
      submit_value: "",
      checked: false,
      toggled: false,
      slider_value: 50,
      selected: "Apple",
      radio: "A"
    }
  end

  def update(model, %WidgetEvent{type: :input, id: "input", value: v}) do
    %{model | input_value: v}
  end

  def update(model, %WidgetEvent{type: :input, id: "submit-input", value: v}) do
    %{model | submit_value: v}
  end

  def update(model, %WidgetEvent{type: :submit, id: "submit-input"}) do
    %{model | submit_value: ""}
  end

  def update(model, %WidgetEvent{type: :toggle, id: "check", value: v}) do
    %{model | checked: v}
  end

  def update(model, %WidgetEvent{type: :toggle, id: "toggler", value: v}) do
    %{model | toggled: v}
  end

  def update(model, %WidgetEvent{type: :slide, id: "slide", value: v}) do
    %{model | slider_value: v}
  end

  def update(model, %WidgetEvent{type: :select, id: "pick", value: v}) do
    %{model | selected: v}
  end

  def update(model, %WidgetEvent{type: :select, id: "radio-" <> _, value: v}) do
    %{model | radio: v}
  end

  def update(model, _event), do: model

  def view(model) do
    window "main", title: "Widget Gallery" do
      scrollable "gallery", height: :fill do
        column padding: 16, spacing: 16 do
          text("title", "Widget Gallery", size: 20)

          text("h-buttons", "Buttons", size: 14, color: "#888")
          row spacing: 8 do
            button("btn-default", "Default")
            button("btn-primary", "Primary", style: :primary)
            button("btn-danger", "Danger", style: :danger)
            button("btn-text", "Text", style: :text)
          end

          text("h-input", "Text Input", size: 14, color: "#888")
          text_input("input", model.input_value, placeholder: "Type here...")
          text_input("submit-input", model.submit_value,
            placeholder: "Press Enter (on_submit)",
            on_submit: true
          )

          text("h-toggles", "Toggles", size: 14, color: "#888")
          row spacing: 16 do
            checkbox("check", model.checked)
            toggler("toggler", model.toggled)
          end

          text("h-slider", "Slider", size: 14, color: "#888")
          slider("slide", {0, 100}, model.slider_value)
          text("slide-value", "Value: #{model.slider_value}", size: 12)

          text("h-select", "Selection", size: 14, color: "#888")
          pick_list("pick", ["Apple", "Banana", "Cherry"], model.selected)
          row spacing: 8 do
            radio("radio-a", "A", model.radio)
            radio("radio-b", "B", model.radio)
            radio("radio-c", "C", model.radio)
          end

          text("h-display", "Display", size: 14, color: "#888")
          progress_bar("progress", {0, 100}, 65)
          rule()
          text("styled", "Styled text", size: 18, color: "#3b82f6")
        end
      end
    end
  end
end
