defmodule Plushie.Tree.NormalizeCtx do
  @moduledoc false
  @enforce_keys [:scope, :window_id]
  defstruct scope: "",
            window_id: nil,
            widget_states: %{},
            depth: 0,
            memo_prev: %{},
            memo: %{},
            widget_view_prev: %{},
            widget_view: %{}

  @type t :: %__MODULE__{
          scope: String.t(),
          window_id: String.t() | nil,
          widget_states: map(),
          depth: non_neg_integer(),
          memo_prev: map(),
          memo: map(),
          widget_view_prev: map(),
          widget_view: map()
        }
end
