defmodule Plushie.ModalFocusTest do
  use Plushie.Test.Case, app: ModalFocusApp

  @moduletag capture_log: true

  # -- Test app ---------------------------------------------------------------

  defmodule ModalFocusApp do
    use Plushie.App

    def init(_opts), do: %{last_focused: nil}

    def update(model, _event), do: model

    def view(_model) do
      %{
        id: "main",
        type: "window",
        props: %{},
        children: [
          %{
            id: "layout",
            type: "column",
            props: %{},
            children: [
              %{id: "outside1", type: "button", props: %{label: "Outside 1"}, children: []},
              %{
                id: "modal",
                type: "container",
                props: %{a11y: %{modal: true}},
                children: [
                  %{
                    id: "modal_col",
                    type: "column",
                    props: %{},
                    children: [
                      %{id: "inside1", type: "button", props: %{label: "Inside 1"}, children: []},
                      %{id: "inside2", type: "button", props: %{label: "Inside 2"}, children: []}
                    ]
                  }
                ]
              },
              %{id: "outside2", type: "button", props: %{label: "Outside 2"}, children: []}
            ]
          }
        ]
      }
    end
  end

  # -- Tests ------------------------------------------------------------------

  describe "modal focus trapping" do
    @tag backend: :windowed
    test "Tab cycles focus within modal container" do
      # Focus the first button inside the modal
      click("#inside1")
      focused = find_focused()
      assert focused != nil
      assert focused.id =~ "inside1"

      # Tab should move to inside2
      type_key("Tab")
      focused = find_focused()
      assert focused != nil
      assert focused.id =~ "inside2"

      # Tab again should wrap back to inside1 (not escape to outside)
      type_key("Tab")
      focused = find_focused()
      assert focused != nil
      assert focused.id =~ "inside1"
    end
  end
end
