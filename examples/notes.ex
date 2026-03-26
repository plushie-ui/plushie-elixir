defmodule Notes do
  @moduledoc """
  Notes application demonstrating all 5 state helpers working together.

  Demonstrates:
  - `Plushie.State` for nested state management
  - `Plushie.Undo` for reversible edits with labels
  - `Plushie.Selection` for multi-select with toggle
  - `Plushie.Route` for stack-based view navigation
  - `Plushie.Data.query/2` for full-text search across fields
  - View helper extraction (`view_list/1`, `view_edit/1`)
  """

  use Plushie.App

  alias Plushie.{Data, Route, Selection, State, Undo}
  alias Plushie.Event.WidgetEvent

  # -- init ------------------------------------------------------------------

  def init(_opts) do
    %{
      state:
        State.new(%{
          notes: [],
          next_id: 1,
          search_query: "",
          editing_id: nil
        }),
      selection: Selection.new(mode: :multi),
      undo: Undo.new(%{text: "", title: ""}),
      route: Route.new("/list")
    }
  end

  # -- update ----------------------------------------------------------------

  def update(model, %WidgetEvent{type: :click, id: "new_note"}) do
    state = model.state
    id = State.get(state, [:next_id])

    note = %{id: id, title: "", body: ""}

    state =
      state
      |> State.update([:notes], fn notes -> notes ++ [note] end)
      |> State.put([:next_id], id + 1)
      |> State.put([:editing_id], id)

    %{
      model
      | state: state,
        undo: Undo.new(%{title: "", text: ""}),
        route: Route.push(model.route, "/edit")
    }
  end

  def update(model, %WidgetEvent{type: :click, id: "note:" <> id_str}) do
    id = String.to_integer(id_str)
    notes = State.get(model.state, [:notes])
    note = Enum.find(notes, fn n -> n.id == id end)

    if note do
      state = State.put(model.state, [:editing_id], id)

      %{
        model
        | state: state,
          undo: Undo.new(%{title: note.title, text: note.body}),
          route: Route.push(model.route, "/edit")
      }
    else
      model
    end
  end

  def update(model, %WidgetEvent{type: :click, id: "back"}) do
    model = save_current_edit(model)
    state = State.put(model.state, [:editing_id], nil)

    %{model | state: state, route: Route.pop(model.route)}
  end

  def update(model, %WidgetEvent{type: :click, id: "delete_selected"}) do
    selected = Selection.selected(model.selection)

    state =
      State.update(model.state, [:notes], fn notes ->
        Enum.reject(notes, fn n -> MapSet.member?(selected, n.id) end)
      end)

    %{model | state: state, selection: Selection.clear(model.selection)}
  end

  def update(model, %WidgetEvent{type: :input, id: "search", value: query}) do
    %{model | state: State.put(model.state, [:search_query], query)}
  end

  def update(model, %WidgetEvent{type: :input, id: "title", value: value}) do
    old_title = Undo.current(model.undo).title

    cmd = %{
      apply: fn current -> %{current | title: value} end,
      undo: fn current -> %{current | title: old_title} end,
      label: "edit title"
    }

    %{model | undo: Undo.apply(model.undo, cmd)}
  end

  def update(model, %WidgetEvent{type: :input, id: "body", value: value}) do
    old_text = Undo.current(model.undo).text

    cmd = %{
      apply: fn current -> %{current | text: value} end,
      undo: fn current -> %{current | text: old_text} end,
      label: "edit body"
    }

    %{model | undo: Undo.apply(model.undo, cmd)}
  end

  def update(model, %WidgetEvent{type: :click, id: "undo"}) do
    %{model | undo: Undo.undo(model.undo)}
  end

  def update(model, %WidgetEvent{type: :click, id: "redo"}) do
    %{model | undo: Undo.redo(model.undo)}
  end

  def update(model, %WidgetEvent{type: :toggle, id: "note_select:" <> id_str}) do
    id = String.to_integer(id_str)
    %{model | selection: Selection.toggle(model.selection, id)}
  end

  def update(model, _event), do: model

  # -- view ------------------------------------------------------------------

  def view(model) do

    case Route.current(model.route) do
      "/list" -> view_list(model)
      "/edit" -> view_edit(model)
    end
  end

  defp view_list(model) do
    import Plushie.UI

    search_query = State.get(model.state, [:search_query])
    notes = State.get(model.state, [:notes])

    filtered =
      if search_query == "" do
        notes
      else
        result = Data.query(notes, search: {[:title, :body], search_query})
        result.entries
      end

    window "main", title: "Notes" do
      column do
        padding 16
        spacing 12
        width :fill

        text("heading", "Notes", size: 24)

        text_input("search", search_query, placeholder: "Search notes...")

        scrollable "notes_list", height: :fill do
          column spacing: 4, width: :fill do
            for note <- filtered do
              row spacing: 8, width: :fill, id: "note_row:#{note.id}" do
                checkbox(
                  "note_select:#{note.id}",
                  Selection.selected?(model.selection, note.id),
                  label: note.title
                )

                button("note:#{note.id}", "Edit")
              end
            end
          end
        end

        row spacing: 8 do
          button("new_note", "New Note")
          button("delete_selected", "Delete Selected")
        end
      end
    end
  end

  defp view_edit(model) do
    import Plushie.UI

    current = Undo.current(model.undo)

    window "main", title: "Edit Note" do
      column do
        padding 16
        spacing 12
        width :fill

        row spacing: 8 do
          button("back", "Back")
          button("undo", "Undo")
          button("redo", "Redo")
        end

        text_input("title", current.title, placeholder: "Note title")
        text_editor("body", current.text, width: :fill, height: :fill)
      end
    end
  end

  # -- private ---------------------------------------------------------------

  defp save_current_edit(model) do
    editing_id = State.get(model.state, [:editing_id])

    if editing_id do
      current = Undo.current(model.undo)

      state =
        State.update(model.state, [:notes], fn notes ->
          Enum.map(notes, fn
            %{id: ^editing_id} = note ->
              %{note | title: current.title, body: current.text}

            note ->
              note
          end)
        end)

      %{model | state: state}
    else
      model
    end
  end
end
