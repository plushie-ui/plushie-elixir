defmodule Shortcuts do
  @moduledoc """
  Keyboard shortcuts example showing a scrollable log of key presses.

  Demonstrates:
  - `Plushie.Subscription.on_key_press/1` for global keyboard events
  - Pattern matching on `%KeyEvent{type: :press}` with modifier inspection
  - `scrollable` for overflow content with dynamic list items
  - Capped log buffer (`@max_log_entries`)
  """

  use Plushie.App

  alias Plushie.Event.KeyEvent
  alias Plushie.KeyModifiers
  alias Plushie.Subscription

  @max_log_entries 50

  # -- init ------------------------------------------------------------------

  def init(_opts) do
    %{log: [], count: 0}
  end

  # -- update ----------------------------------------------------------------

  def update(model, %KeyEvent{type: :press} = event) do
    entry = format_key_event(event, model.count + 1)

    %{
      model
      | log: Enum.take([entry | model.log], @max_log_entries),
        count: model.count + 1
    }
  end

  def update(model, _event), do: model

  # -- subscribe -------------------------------------------------------------

  def subscribe(_model) do
    [Subscription.on_key_press(:keys)]
  end

  # -- view ------------------------------------------------------------------

  def view(model) do
    import Plushie.UI

    window "main", title: "Keyboard Shortcuts" do
      column padding: 16, spacing: 12, width: :fill do
        text("header", "Press any key", size: 20)
        text("count", "#{model.count} key events captured", size: 12, color: "#888888")

        rule()

        scrollable "log", height: :fill do
          column spacing: 2, width: :fill do
            for {entry, index} <- Enum.with_index(model.log) do
              text("log_#{index}", entry, size: 13)
            end
          end
        end
      end
    end
  end

  # -- private ---------------------------------------------------------------

  defp format_key_event(event, n) do
    mods = format_modifiers(event.modifiers)
    key = inspect(event.key)
    prefix = if mods == "", do: "", else: mods <> "+"
    "##{n}: #{prefix}#{key}"
  end

  defp format_modifiers(%KeyModifiers{} = m) do
    []
    |> then(fn acc -> if m.ctrl, do: ["Ctrl" | acc], else: acc end)
    |> then(fn acc -> if m.alt, do: ["Alt" | acc], else: acc end)
    |> then(fn acc -> if m.shift, do: ["Shift" | acc], else: acc end)
    |> then(fn acc -> if m.logo, do: ["Super" | acc], else: acc end)
    |> Enum.reverse()
    |> Enum.join("+")
  end
end
