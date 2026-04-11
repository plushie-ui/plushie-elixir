defmodule Plushie.Canvas.Layer do
  @moduledoc """
  Canvas layer: a named container that groups shapes for independent
  caching on the renderer side.

  Each layer maps to an iced `Cache` on the Rust side; only changed
  layers are re-tessellated. The `name` prop identifies the layer
  for cache invalidation.

  On the wire this encodes as `type: "__layer__"` to match what the
  renderer expects.

  ## Example

      Layer.new("bg")
      |> Layer.push(rect(0, 0, 800, 600, fill: "#f0f0f0"))
      |> Layer.push(rect(10, 10, 50, 200, fill: "#3498db"))
  """

  use Plushie.Canvas.Element

  element :layer, container: true, wire_type: :__layer__ do
    field :name, :string, doc: "Layer name for renderer cache keying."
  end
end
