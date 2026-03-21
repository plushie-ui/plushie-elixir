defmodule Plushie.Event.Widget do
  @moduledoc """
  Events from interactive widgets (buttons, inputs, sliders, etc.).

  The `scope` field contains the ancestor scope chain in reverse order
  (nearest parent first). Use `Plushie.Event.target/1` to reconstruct the
  full forward-order scoped path.

  ## Pattern matching

      def update(model, %Widget{type: :click, id: "save"}), do: save(model)
      def update(model, %Widget{type: :input, id: "name", value: val}), do: ...
      def update(model, %Widget{type: :toggle, id: "dark", value: on?}), do: ...

      # Match on scope for disambiguation
      def update(model, %Widget{type: :click, id: "save", scope: ["form" | _]}), do: ...
  """

  @type event_type ::
          :click
          | :input
          | :submit
          | :toggle
          | :select
          | :slide
          | :slide_release
          | :paste
          | :open
          | :close
          | :option_hovered
          | :key_binding
          | :sort
          | :scroll
          | String.t()

  @type t :: %__MODULE__{
          type: event_type(),
          id: String.t(),
          scope: [String.t()],
          value: term(),
          data: map() | nil
        }

  @enforce_keys [:type, :id]
  defstruct [:type, :id, :value, :data, scope: []]

  defimpl Inspect do
    def inspect(event, _opts) do
      target = Plushie.Event.target(event)
      parts = [inspect(event.type), " ", inspect(target)]

      parts =
        if event.value != nil,
          do: parts ++ [" value=", Kernel.inspect(event.value)],
          else: parts

      IO.iodata_to_binary(["#Widget<" | parts] ++ [">"])
    end
  end
end
