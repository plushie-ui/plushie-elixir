defmodule Plushie.Canvas.Shape.Group do
  @moduledoc """
  Canvas group: a structural container for transforms, clips, and
  visual grouping.

  Groups carry an ordered `transforms` list and an optional `clip`
  rect. The optional `id` is for tree diffing and targeting, not
  interactivity.

  For interactive canvas elements (click, hover, drag, focus, a11y),
  use `Plushie.Canvas.Shape.Interactive` via the `interactive` macro.
  """

  alias Plushie.Canvas.Clip
  alias Plushie.Canvas.Shape.{Rotate, Scale, Translate}

  @type t :: %__MODULE__{
          children: [term()],
          transforms: [Translate.t() | Rotate.t() | Scale.t()] | nil,
          clip: Clip.t() | nil,
          id: String.t() | nil
        }

  @enforce_keys [:children]
  defstruct [
    :children,
    :transforms,
    :clip,
    :id
  ]

  @doc false
  def encode(%__MODULE__{} = group) do
    base = %{type: "group", children: Enum.map(group.children, &Plushie.Type.encode_value/1)}

    base
    |> encode_transforms(group.transforms)
    |> put_if(:clip, group.clip)
    |> put_if(:id, group.id)
  end

  defp encode_transforms(map, nil), do: map
  defp encode_transforms(map, []), do: map

  defp encode_transforms(map, transforms) do
    Map.put(map, :transforms, Enum.map(transforms, &Plushie.Type.encode_value/1))
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, val), do: Map.put(map, key, Plushie.Type.encode_value(val))
end
