defmodule Plushie.Event do
  @moduledoc "Event types delivered to `update/2`."

  alias Plushie.Event.{
    Async,
    Effect,
    ExtensionCommandError,
    Ime,
    Key,
    Modifiers,
    Mouse,
    Stream,
    SystemEvent,
    Timer,
    Touch,
    WidgetEvent,
    WindowEvent
  }

  @type delivered_t ::
          WidgetEvent.delivered_t()
          | Key.t()
          | Modifiers.t()
          | Mouse.t()
          | Touch.t()
          | Ime.t()
          | WindowEvent.delivered_t()
          | Effect.t()
          | ExtensionCommandError.t()
          | SystemEvent.delivered_t()
          | Timer.t()
          | Async.t()
          | Stream.t()

  @type t ::
          WidgetEvent.t()
          | Key.t()
          | Modifiers.t()
          | Mouse.t()
          | Touch.t()
          | Ime.t()
          | WindowEvent.t()
          | Effect.t()
          | ExtensionCommandError.t()
          | SystemEvent.t()
          | Timer.t()
          | Async.t()
          | Stream.t()

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
