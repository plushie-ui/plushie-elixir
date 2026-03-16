defmodule Julep.Event.Widget do
  @moduledoc """
  Events from interactive widgets (buttons, inputs, sliders, etc.).

  ## Pattern matching

      def update(model, %Widget{type: :click, id: "save"}), do: save(model)
      def update(model, %Widget{type: :input, id: "name", value: val}), do: ...
      def update(model, %Widget{type: :toggle, id: "dark", value: on?}), do: ...
  """

  @type event_type ::
          :click | :input | :submit | :toggle | :select | :slide | :slide_release
          | :paste | :open | :close | :option_hovered | :key_binding | :sort | :scroll

  @type t :: %__MODULE__{
          type: event_type(),
          id: String.t(),
          value: term(),
          data: map() | nil
        }

  defstruct [:type, :id, :value, :data]
end
