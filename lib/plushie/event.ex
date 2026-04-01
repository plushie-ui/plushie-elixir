defmodule Plushie.Event do
  @moduledoc "Event types delivered to `update/2`."

  alias Plushie.Event.{
    AsyncEvent,
    EffectEvent,
    ImeEvent,
    KeyEvent,
    ModifiersEvent,
    MouseEvent,
    StreamEvent,
    SystemEvent,
    TimerEvent,
    TouchEvent,
    WidgetCommandError,
    WidgetEvent,
    WindowEvent
  }

  @type delivered_t ::
          WidgetEvent.delivered_t()
          | KeyEvent.t()
          | ModifiersEvent.t()
          | MouseEvent.t()
          | TouchEvent.t()
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
          | MouseEvent.t()
          | TouchEvent.t()
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

  ## Examples

      iex> Plushie.Event.target(%Plushie.Event.WidgetEvent{type: :click, id: "save", scope: []})
      "save"

      iex> Plushie.Event.target(%Plushie.Event.WidgetEvent{type: :click, id: "save", scope: ["form", "sidebar"]})
      "sidebar/form/save"
  """
  @spec target(event :: struct()) :: String.t()
  def target(%{id: id, scope: []}), do: id
  def target(%{id: id, scope: scope}), do: Enum.join(Enum.reverse([id | scope]), "/")
end
