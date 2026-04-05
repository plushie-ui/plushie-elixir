defmodule Plushie.Event do
  @moduledoc "Event types delivered to `update/2`."

  alias Plushie.Event.{
    AsyncEvent,
    EffectEvent,
    ImeEvent,
    KeyEvent,
    ModifiersEvent,
    StreamEvent,
    SystemEvent,
    TimerEvent,
    WidgetCommandError,
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
          | WidgetCommandError.t()
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
          | WidgetCommandError.t()
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

  @doc """
  Strips the window ID from the end of a reversed scope list.

  Events carry a reversed ancestor scope where the window ID appears
  at the tail. Registry keys and scoped IDs do not include the window
  (it is keyed separately). This function removes it so scope can be
  used for registry lookups and path reconstruction.

  Returns the scope unchanged when `window_id` is nil or does not
  appear at the end.
  """
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
