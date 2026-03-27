defmodule Plushie.Integration.WindowTest do
  use Plushie.Test.Case, app: Plushie.Integration.WindowTest.WindowApp

  alias Plushie.Event.WidgetEvent

  defmodule WindowApp do
    use Plushie.App

    def init(_opts), do: %{show_secondary: false}

    def update(model, %WidgetEvent{type: :click, id: "toggle"}) do
      %{model | show_secondary: !model.show_secondary}
    end

    def update(model, _event), do: model

    def view(model) do
      main_children = [
        %{id: "toggle", type: "button", props: %{label: "Toggle"}, children: []},
        %{id: "info", type: "text", props: %{content: "main"}, children: []}
      ]

      main = %{
        id: "main",
        type: "window",
        props: %{title: "Main Window"},
        children: main_children
      }

      if model.show_secondary do
        secondary = %{
          id: "secondary",
          type: "window",
          props: %{title: "Secondary"},
          children: [
            %{id: "sec_text", type: "text", props: %{content: "second"}, children: []}
          ]
        }

        [main, secondary]
      else
        main
      end
    end
  end

  test "app starts with single window" do
    assert model().show_secondary == false

    tree = tree()
    assert tree != nil
    assert tree.type == "window"
    assert tree.id == "main"
  end

  test "toggling secondary window on and off" do
    click("#toggle")
    assert model().show_secondary == true

    click("#toggle")
    assert model().show_secondary == false
  end
end
