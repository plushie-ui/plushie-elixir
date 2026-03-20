defprotocol Toddy.Encode do
  @moduledoc """
  Protocol for encoding Elixir values to wire-format representations.

  Widget `to_node/1` implementations use `Build.put_if/3` which calls
  `Encode.encode/1` automatically. Widget authors don't need to apply
  manual transforms for atoms, tuples, or custom types.

  ## Primitive implementations

  - **Atom**: `true`/`false`/`nil` pass through; other atoms become strings
  - **BitString**: pass through
  - **Integer**: pass through
  - **Float**: pass through
  - **Tuple**: converted to list with recursive encoding
  - **Map**: values recursively encoded
  - **List**: elements recursively encoded
  - **Any**: raises `Protocol.UndefinedError` (no silent passthrough)

  ## Struct implementations

  - `Toddy.Type.A11y` -- strips nil fields, converts atom keys to strings
  - `Toddy.Type.Border` -- encodes per-corner radius to string-keyed map
  - `Toddy.Type.Shadow` -- encodes offset as `[x, y]` list
  - `Toddy.Type.StyleMap` -- encodes status overrides and nested structs
  """

  @fallback_to_any true

  @doc "Encodes a value for JSON wire format."
  @spec encode(value :: term()) :: term()
  def encode(value)
end

defimpl Toddy.Encode, for: Atom do
  def encode(true), do: true
  def encode(false), do: false
  def encode(nil), do: nil
  def encode(atom), do: Atom.to_string(atom)
end

defimpl Toddy.Encode, for: BitString do
  def encode(str), do: str
end

defimpl Toddy.Encode, for: Integer do
  def encode(n), do: n
end

defimpl Toddy.Encode, for: Float do
  def encode(f), do: f
end

defimpl Toddy.Encode, for: Tuple do
  def encode(tuple) do
    tuple |> Tuple.to_list() |> Enum.map(&Toddy.Encode.encode/1)
  end
end

defimpl Toddy.Encode, for: Map do
  def encode(map) do
    Map.new(map, fn {k, v} -> {k, Toddy.Encode.encode(v)} end)
  end
end

defimpl Toddy.Encode, for: List do
  def encode(list) do
    Enum.map(list, &Toddy.Encode.encode/1)
  end
end

defimpl Toddy.Encode, for: Any do
  def encode(%{__struct__: mod} = value) do
    raise Protocol.UndefinedError,
      protocol: Toddy.Encode,
      value: value,
      description: "#{inspect(mod)} does not implement Toddy.Encode"
  end

  def encode(value) do
    raise Protocol.UndefinedError,
      protocol: Toddy.Encode,
      value: value
  end
end

defimpl Toddy.Encode, for: Toddy.Type.Shadow do
  def encode(shadow) do
    %{
      "color" => shadow.color,
      "offset" => [shadow.offset_x, shadow.offset_y],
      "blur_radius" => shadow.blur_radius
    }
  end
end

defimpl Toddy.Encode, for: Toddy.Type.A11y do
  def encode(%Toddy.Type.A11y{} = a11y) do
    a11y
    |> Map.from_struct()
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new(fn {k, v} -> {to_string(k), Toddy.Encode.encode(v)} end)
  end
end
