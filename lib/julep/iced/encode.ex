defprotocol Julep.Iced.Encode do
  @moduledoc """
  Protocol for encoding Elixir values to wire-format representations.

  Widget `to_node/1` implementations use `Build.put_if/3` which calls
  `Encode.encode/1` automatically. Widget authors don't need to apply
  manual transforms for atoms, tuples, or custom types.

  ## Built-in implementations

  - **Atom**: `true`/`false`/`nil` pass through; other atoms become strings
  - **BitString**: pass through
  - **Integer**: pass through
  - **Float**: pass through
  - **Tuple**: converted to list with recursive encoding
  - **Map**: values recursively encoded
  - **List**: elements recursively encoded
  - **Any**: raises `Protocol.UndefinedError` (no silent passthrough)
  """

  @fallback_to_any true

  @doc "Encodes a value for JSON wire format."
  @spec encode(value :: term()) :: term()
  def encode(value)
end

defimpl Julep.Iced.Encode, for: Atom do
  def encode(true), do: true
  def encode(false), do: false
  def encode(nil), do: nil
  def encode(atom), do: Atom.to_string(atom)
end

defimpl Julep.Iced.Encode, for: BitString do
  def encode(str), do: str
end

defimpl Julep.Iced.Encode, for: Integer do
  def encode(n), do: n
end

defimpl Julep.Iced.Encode, for: Float do
  def encode(f), do: f
end

defimpl Julep.Iced.Encode, for: Tuple do
  def encode(tuple) do
    tuple |> Tuple.to_list() |> Enum.map(&Julep.Iced.Encode.encode/1)
  end
end

defimpl Julep.Iced.Encode, for: Map do
  def encode(map) do
    Map.new(map, fn {k, v} -> {k, Julep.Iced.Encode.encode(v)} end)
  end
end

defimpl Julep.Iced.Encode, for: List do
  def encode(list) do
    Enum.map(list, &Julep.Iced.Encode.encode/1)
  end
end

defimpl Julep.Iced.Encode, for: Any do
  def encode(%{__struct__: mod} = value) do
    raise Protocol.UndefinedError,
      protocol: Julep.Iced.Encode,
      value: value,
      description: "#{inspect(mod)} does not implement Julep.Iced.Encode"
  end

  def encode(value) do
    raise Protocol.UndefinedError,
      protocol: Julep.Iced.Encode,
      value: value
  end
end

defimpl Julep.Iced.Encode, for: Julep.Iced.Shadow do
  def encode(shadow) do
    %{
      "color" => shadow.color,
      "offset" => [shadow.offset_x, shadow.offset_y],
      "blur_radius" => shadow.blur_radius
    }
  end
end

defimpl Julep.Iced.Encode, for: Julep.Iced.A11y do
  def encode(%Julep.Iced.A11y{} = a11y) do
    a11y
    |> Map.from_struct()
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new(fn {k, v} -> {to_string(k), Julep.Iced.Encode.encode(v)} end)
  end
end
