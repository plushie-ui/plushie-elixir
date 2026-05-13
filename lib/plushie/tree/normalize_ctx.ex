defmodule Plushie.Tree.NormalizeCtx do
  @moduledoc false

  defstruct scope: "",
            window_id: nil,
            widget_states: %{},
            depth: 0,
            memo_prev: %{},
            memo: %{},
            widget_view_prev: %{},
            widget_view: %{},
            widget_handlers: %{},
            widget_events: %{},
            window_ids: []

  @type t :: %__MODULE__{
          scope: String.t(),
          window_id: String.t() | nil,
          widget_states: map(),
          depth: non_neg_integer(),
          memo_prev: map(),
          memo: map(),
          widget_view_prev: map(),
          widget_view: map(),
          widget_handlers: map(),
          widget_events: map(),
          window_ids: [String.t()]
        }
end
