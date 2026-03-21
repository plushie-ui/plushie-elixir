defprotocol Plushie.Encode do
  @moduledoc """
  Protocol for encoding Elixir values to wire-safe representations.

  This protocol is called during `Tree.normalize/1`, the single value
  encoding pass that converts raw Elixir values into wire-compatible
  forms. Widget builders (`Build.put_if/3`) do NOT call this protocol --
  values stay as raw Elixir terms (atoms, tuples, structs) until
  normalization.

  Key stringification (atom keys to string keys) is NOT handled here.
  That happens at the wire boundary in `Protocol.Encode.stringify_keys/1`,
  which runs just before serialization.

  Extension authors should implement this protocol for custom value
  types that need special wire encoding (e.g. a struct that should
  become a specific map shape on the wire).

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

  Struct implementations live alongside their struct definitions:

  - `Plushie.Type.A11y` -- strips nil fields, converts atom keys to strings
  - `Plushie.Type.Border` -- encodes per-corner radius to string-keyed map
  - `Plushie.Type.Shadow` -- encodes offset as `[x, y]` list
  - `Plushie.Type.Font` -- encodes struct to wire font map (strips nils)
  - `Plushie.Type.Padding` -- encodes struct to per-side map (strips nils)
  - `Plushie.Type.StyleMap` -- encodes status overrides and nested structs
  """

  @fallback_to_any true

  @doc "Encodes a value for JSON wire format."
  @spec encode(value :: term()) :: term()
  def encode(value)
end

defimpl Plushie.Encode, for: Atom do
  def encode(true), do: true
  def encode(false), do: false
  def encode(nil), do: nil
  def encode(atom), do: Atom.to_string(atom)
end

defimpl Plushie.Encode, for: BitString do
  def encode(str), do: str
end

defimpl Plushie.Encode, for: Integer do
  def encode(n), do: n
end

defimpl Plushie.Encode, for: Float do
  def encode(f), do: f
end

defimpl Plushie.Encode, for: Tuple do
  def encode(tuple) do
    tuple |> Tuple.to_list() |> Enum.map(&Plushie.Encode.encode/1)
  end
end

defimpl Plushie.Encode, for: Map do
  def encode(map) do
    Map.new(map, fn {k, v} -> {k, Plushie.Encode.encode(v)} end)
  end
end

defimpl Plushie.Encode, for: List do
  def encode(list) do
    Enum.map(list, &Plushie.Encode.encode/1)
  end
end

defimpl Plushie.Encode, for: Any do
  def encode(%{__struct__: mod} = value) do
    raise Protocol.UndefinedError,
      protocol: Plushie.Encode,
      value: value,
      description: "#{inspect(mod)} does not implement Plushie.Encode"
  end

  def encode(value) do
    raise Protocol.UndefinedError,
      protocol: Plushie.Encode,
      value: value
  end
end
