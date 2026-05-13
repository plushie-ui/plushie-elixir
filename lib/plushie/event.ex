defmodule Plushie.Event do
  @moduledoc """
  Event types delivered to `update/2`.

  Every event arriving in `update/2` is one of these struct types:

  - `WidgetEvent` - interactions with widgets and canvas elements
    (clicks, input, toggle, slide, drag, focus, etc.)
  - `KeyEvent` - keyboard press and release
  - `ModifiersEvent` - modifier key state changes (Shift, Ctrl, etc.)
  - `ImeEvent` - input method editor composition
  - `WindowEvent` - window lifecycle (opened, closed, resized, moved)
  - `TimerEvent` - timer ticks from subscriptions
  - `AsyncEvent` - results from async commands
  - `StreamEvent` - intermediate values from streaming commands
  - `EffectEvent` - platform effect responses (file dialogs, clipboard)
  - `SystemEvent` - system queries and platform events
  - `DiagnosticMessage` - structured diagnostics from the renderer
  - `CommandError` - command failures

  See the [Events reference](docs/reference/events.md) for the full
  event model and routing details.
  """

  alias Plushie.Event.{
    AsyncEvent,
    CommandError,
    DiagnosticMessage,
    EffectEvent,
    ImeEvent,
    KeyEvent,
    ModifiersEvent,
    StreamEvent,
    SystemEvent,
    TimerEvent,
    WidgetEvent,
    WindowEvent
  }

  @type delivered_t ::
          WidgetEvent.delivered_t()
          | KeyEvent.t()
          | ModifiersEvent.t()
          | ImeEvent.t()
          | WindowEvent.delivered_t()
          | EffectEvent.t()
          | CommandError.t()
          | DiagnosticMessage.t()
          | SystemEvent.delivered_t()
          | TimerEvent.t()
          | AsyncEvent.t()
          | StreamEvent.t()

  @type t ::
          WidgetEvent.t()
          | KeyEvent.t()
          | ModifiersEvent.t()
          | ImeEvent.t()
          | WindowEvent.t()
          | EffectEvent.t()
          | CommandError.t()
          | DiagnosticMessage.t()
          | SystemEvent.t()
          | TimerEvent.t()
          | AsyncEvent.t()
          | StreamEvent.t()

  @doc """
  Returns the full scoped path as a forward-order string.

  Works with any event struct that has `id` and `scope` fields.
  When the event has a `window_id` field, the window_id is stripped
  from the scope (it appears at the end of the scope list but is not
  part of the container path).

  ## Examples

      iex> Plushie.Event.target(%Plushie.Event.WidgetEvent{type: :click, id: "save", scope: ["main"], window_id: "main"})
      "save"

      iex> Plushie.Event.target(%Plushie.Event.WidgetEvent{type: :click, id: "save", scope: ["form", "sidebar", "main"], window_id: "main"})
      "sidebar/form/save"
  """
  @spec target(event :: struct()) :: String.t()
  def target(%{id: id} = event) do
    scope = strip_window_from_scope(Map.get(event, :scope, []), Map.get(event, :window_id))

    case scope do
      [] -> id
      _ -> Enum.join(Enum.reverse([id | scope]), "/")
    end
  end

  @doc false
  @spec strip_window_from_scope(scope :: [String.t()], window_id :: String.t() | nil) ::
          [String.t()]
  def strip_window_from_scope(scope, nil), do: scope
  def strip_window_from_scope([], _window_id), do: []

  def strip_window_from_scope(scope, window_id) do
    case List.last(scope) do
      ^window_id -> List.delete_at(scope, -1)
      _ -> scope
    end
  end
end
