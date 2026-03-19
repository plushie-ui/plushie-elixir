defmodule Toddy.Event.Ime do
  @moduledoc """
  Input Method Editor events from subscriptions.

  IME events are emitted during CJK and other complex text input. The
  lifecycle is: `:opened` -> one or more `:preedit` -> `:commit` -> `:closed`.

  ## Fields

    * `type` - `:opened`, `:preedit`, `:commit`, or `:closed`
    * `text` - composition text (preedit) or final committed string (commit)
    * `cursor` - `{start, end}` byte offsets within the preedit text
    * `captured` - whether a subscription captured this event

  ## Pattern matching

      def update(model, %Ime{type: :preedit, text: text, cursor: {start, _end}}) do
        show_composition(model, text, start)
      end

      def update(model, %Ime{type: :commit, text: text}) do
        insert_text(model, text)
      end
  """

  @type t :: %__MODULE__{
          type: :opened | :preedit | :commit | :closed,
          text: String.t() | nil,
          cursor: {non_neg_integer(), non_neg_integer()} | nil,
          captured: boolean()
        }

  @enforce_keys [:type]
  defstruct [:type, :text, :cursor, captured: false]
end
