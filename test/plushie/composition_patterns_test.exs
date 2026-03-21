defmodule Plushie.CompositionPatternsTest do
  @moduledoc """
  Tests for the composition patterns documented in docs/composition-patterns.md.

  Each test defines a minimal app module using the documented pattern, then
  verifies that init/update/view produce valid results.
  """
  use ExUnit.Case, async: true

  alias Plushie.Event.Widget

  # ---------------------------------------------------------------------------
  # 1. Tab bar
  # ---------------------------------------------------------------------------

  defmodule TabApp do
    @behaviour Plushie.App
    alias Plushie.Event.Widget

    def init(_opts), do: %{active_tab: :overview}

    def update(model, %Widget{type: :click, id: "tab:" <> name}) do
      %{model | active_tab: String.to_existing_atom(name)}
    end

    def update(model, _event), do: model

    def view(model) do
      import Plushie.UI

      tabs = [:overview, :details, :settings]

      window "main", title: "Tabs" do
        column width: :fill do
          row spacing: 0 do
            for tab <- tabs do
              button("tab:#{tab}", tab |> Atom.to_string() |> String.capitalize())
            end
          end

          container "content", padding: 20 do
            text("Content for #{model.active_tab}")
          end
        end
      end
    end
  end

  describe "tab bar pattern" do
    test "init sets default active tab" do
      model = TabApp.init([])
      assert model.active_tab == :overview
    end

    test "clicking a tab updates active_tab" do
      model = TabApp.init([])
      model = TabApp.update(model, %Widget{type: :click, id: "tab:details"})
      assert model.active_tab == :details
    end

    test "view produces a valid tree with tab buttons" do
      model = TabApp.init([])
      tree = TabApp.view(model)
      assert is_map(tree)
      assert tree.type == "window"
    end

    test "unknown events are ignored" do
      model = TabApp.init([])
      assert TabApp.update(model, %Widget{type: :click, id: "unknown"}) == model
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Sidebar navigation
  # ---------------------------------------------------------------------------

  defmodule SidebarApp do
    @behaviour Plushie.App
    alias Plushie.Event.Widget

    @nav_items [{:inbox, "Inbox"}, {:sent, "Sent"}, {:drafts, "Drafts"}]

    def init(_opts), do: %{page: :inbox}

    def update(model, %Widget{type: :click, id: "nav:" <> name}) do
      %{model | page: String.to_existing_atom(name)}
    end

    def update(model, _event), do: model

    def view(model) do
      import Plushie.UI

      window "main", title: "Sidebar" do
        row width: :fill, height: :fill do
          container "sidebar", width: 200, height: :fill, padding: 8 do
            column spacing: 4, width: :fill do
              for {id, label} <- @nav_items do
                button("nav:#{id}", label, width: :fill)
              end
            end
          end

          container "main", width: :fill, height: :fill, padding: 24 do
            text("#{model.page} page")
          end
        end
      end
    end
  end

  describe "sidebar navigation pattern" do
    test "init sets default page" do
      model = SidebarApp.init([])
      assert model.page == :inbox
    end

    test "clicking nav item changes page" do
      model = SidebarApp.init([])
      model = SidebarApp.update(model, %Widget{type: :click, id: "nav:sent"})
      assert model.page == :sent
    end

    test "view produces a valid tree" do
      model = SidebarApp.init([])
      tree = SidebarApp.view(model)
      assert is_map(tree)
      assert tree.type == "window"
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Toolbar with toggles
  # ---------------------------------------------------------------------------

  defmodule ToolbarApp do
    @behaviour Plushie.App

    def init(_opts), do: %{bold: false, italic: false}

    def update(model, %Widget{type: :click, id: "tool:bold"}), do: %{model | bold: !model.bold}

    def update(model, %Widget{type: :click, id: "tool:italic"}),
      do: %{model | italic: !model.italic}

    def update(model, _event), do: model

    def view(model) do
      import Plushie.UI

      window "main", title: "Toolbar" do
        column width: :fill do
          row spacing: 2, align_y: :center do
            button("tool:bold", "B", padding: 6)
            button("tool:italic", "I", padding: 6)
            rule(direction: :vertical, height: 20)
            space(width: :fill)
            button("tool:help", "?", padding: 6)
          end

          text("Bold: #{model.bold}, Italic: #{model.italic}")
        end
      end
    end
  end

  describe "toolbar pattern" do
    test "init starts with toggles off" do
      model = ToolbarApp.init([])
      refute model.bold
      refute model.italic
    end

    test "clicking toggles state on and off" do
      model = ToolbarApp.init([])
      model = ToolbarApp.update(model, %Widget{type: :click, id: "tool:bold"})
      assert model.bold
      model = ToolbarApp.update(model, %Widget{type: :click, id: "tool:bold"})
      refute model.bold
    end

    test "view produces a valid tree" do
      model = ToolbarApp.init([])
      tree = ToolbarApp.view(model)
      assert is_map(tree)
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Modal dialog
  # ---------------------------------------------------------------------------

  defmodule ModalApp do
    @behaviour Plushie.App

    def init(_opts), do: %{show_modal: false, confirmed: false}

    def update(model, %Widget{type: :click, id: "open_modal"}), do: %{model | show_modal: true}

    def update(model, %Widget{type: :click, id: "confirm"}),
      do: %{model | show_modal: false, confirmed: true}

    def update(model, %Widget{type: :click, id: "cancel"}), do: %{model | show_modal: false}
    def update(model, _event), do: model

    def view(model) do
      import Plushie.UI

      window "main", title: "Modal" do
        stack width: :fill, height: :fill do
          container "main", width: :fill, height: :fill, padding: 24 do
            column spacing: 12, align_x: :center do
              text("Main content")
              button("open_modal", "Open Dialog")
            end
          end

          if model.show_modal do
            container "overlay", width: :fill, height: :fill, background: "#00000088" do
              column spacing: 16 do
                text("Confirm action")

                row spacing: 8 do
                  button("cancel", "Cancel")
                  button("confirm", "Confirm")
                end
              end
            end
          end
        end
      end
    end
  end

  describe "modal dialog pattern" do
    test "init starts with modal hidden" do
      model = ModalApp.init([])
      refute model.show_modal
      refute model.confirmed
    end

    test "open_modal shows the modal" do
      model = ModalApp.init([])
      model = ModalApp.update(model, %Widget{type: :click, id: "open_modal"})
      assert model.show_modal
    end

    test "confirm closes modal and sets confirmed" do
      model = %{show_modal: true, confirmed: false}
      model = ModalApp.update(model, %Widget{type: :click, id: "confirm"})
      refute model.show_modal
      assert model.confirmed
    end

    test "cancel closes modal without confirming" do
      model = %{show_modal: true, confirmed: false}
      model = ModalApp.update(model, %Widget{type: :click, id: "cancel"})
      refute model.show_modal
      refute model.confirmed
    end

    test "view with modal hidden produces tree without overlay" do
      model = %{show_modal: false, confirmed: false}
      tree = ModalApp.view(model)
      assert is_map(tree)
    end

    test "view with modal shown produces tree with overlay" do
      model = %{show_modal: true, confirmed: false}
      tree = ModalApp.view(model)
      assert is_map(tree)
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Card (reusable helper function)
  # ---------------------------------------------------------------------------

  defmodule CardApp do
    @behaviour Plushie.App

    alias Plushie.Type.Border

    def init(_opts), do: %{}
    def update(model, _event), do: model

    def view(_model) do
      import Plushie.UI

      window "main", title: "Card" do
        column padding: 24, spacing: 16, width: :fill do
          card("info", "System status", fn ->
            [text("All services operational")]
          end)
        end
      end
    end

    defp card(id, title, body_fn) do
      import Plushie.UI

      border = Border.new() |> Border.color("#e0e0e0") |> Border.width(1) |> Border.rounded(8)

      container id,
        width: :fill,
        padding: 16,
        background: "#ffffff",
        border: border do
        column spacing: 8 do
          text("card_title", title, size: 16)
          rule()

          for node <- body_fn.() do
            node
          end
        end
      end
    end
  end

  describe "card pattern" do
    test "view produces a valid tree with card container" do
      model = CardApp.init([])
      tree = CardApp.view(model)
      assert is_map(tree)
      assert tree.type == "window"
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Breadcrumb navigation
  # ---------------------------------------------------------------------------

  defmodule BreadcrumbApp do
    @behaviour Plushie.App
    alias Plushie.Event.Widget

    def init(_opts), do: %{path: ["Home", "Projects", "Plushie"]}

    def update(model, %Widget{type: :click, id: "crumb:" <> index_str}) do
      index = String.to_integer(index_str)
      %{model | path: Enum.take(model.path, index + 1)}
    end

    def update(model, _event), do: model

    def view(model) do
      import Plushie.UI

      window "main", title: "Breadcrumb" do
        column padding: 16 do
          row spacing: 4, align_y: :center do
            for {segment, index} <- Enum.with_index(model.path) do
              last? = index == length(model.path) - 1

              if last? do
                text("crumb_current", segment, size: 14)
              else
                [
                  button("crumb:#{index}", segment, padding: 4),
                  text("sep:#{index}", ">", size: 14, color: "#999999")
                ]
              end
            end
          end
        end
      end
    end
  end

  describe "breadcrumb pattern" do
    test "clicking a crumb truncates the path" do
      model = BreadcrumbApp.init([])
      assert length(model.path) == 3

      model = BreadcrumbApp.update(model, %Widget{type: :click, id: "crumb:0"})
      assert model.path == ["Home"]
    end

    test "clicking intermediate crumb truncates to that point" do
      model = BreadcrumbApp.init([])
      model = BreadcrumbApp.update(model, %Widget{type: :click, id: "crumb:1"})
      assert model.path == ["Home", "Projects"]
    end

    test "view produces a valid tree" do
      model = BreadcrumbApp.init([])
      tree = BreadcrumbApp.view(model)
      assert is_map(tree)
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Badge / chip with toggle selection
  # ---------------------------------------------------------------------------

  defmodule BadgeApp do
    @behaviour Plushie.App
    alias Plushie.Event.Widget

    @tags ["elixir", "rust", "iced"]

    def init(_opts), do: %{selected: MapSet.new(["elixir"])}

    def update(model, %Widget{type: :click, id: "tag:" <> name}) do
      selected =
        if MapSet.member?(model.selected, name) do
          MapSet.delete(model.selected, name)
        else
          MapSet.put(model.selected, name)
        end

      %{model | selected: selected}
    end

    def update(model, _event), do: model

    def view(model) do
      import Plushie.UI

      window "main", title: "Badge" do
        column padding: 24, spacing: 16 do
          row spacing: 6 do
            for tag <- @tags do
              button("tag:#{tag}", tag, padding: 4)
            end
          end

          text("Selected: #{model.selected |> Enum.sort() |> Enum.join(", ")}")
        end
      end
    end
  end

  describe "badge/chip pattern" do
    test "init starts with one selected tag" do
      model = BadgeApp.init([])
      assert MapSet.member?(model.selected, "elixir")
    end

    test "clicking a tag toggles it on" do
      model = BadgeApp.init([])
      model = BadgeApp.update(model, %Widget{type: :click, id: "tag:rust"})
      assert MapSet.member?(model.selected, "rust")
      assert MapSet.member?(model.selected, "elixir")
    end

    test "clicking a selected tag toggles it off" do
      model = BadgeApp.init([])
      model = BadgeApp.update(model, %Widget{type: :click, id: "tag:elixir"})
      refute MapSet.member?(model.selected, "elixir")
    end

    test "view produces a valid tree" do
      model = BadgeApp.init([])
      tree = BadgeApp.view(model)
      assert is_map(tree)
    end
  end
end
