defmodule Plushie.Canvas.Shape.HitRect do
  @moduledoc "Explicit hit test rectangle override for interactive canvas shapes."

  @type t :: %__MODULE__{
          x: number(),
          y: number(),
          w: number(),
          h: number()
        }

  @enforce_keys [:x, :y, :w, :h]
  defstruct [:x, :y, :w, :h]

  @behaviour Plushie.DSL.Buildable

  @known_keys ~w(x y w h)a

  @impl Plushie.DSL.Buildable
  def __field_keys__, do: @known_keys

  @impl Plushie.DSL.Buildable
  def __field_types__, do: %{}

  @doc "Constructs a hit rect from a keyword list."
  @impl Plushie.DSL.Buildable
  @spec from_opts(keyword()) :: t()
  def from_opts(opts) when is_list(opts) do
    for {key, _} <- opts, key not in @known_keys do
      raise ArgumentError,
            "unknown hit rect field #{inspect(key)}. Valid fields: #{inspect(@known_keys)}"
    end

    %__MODULE__{
      x: Keyword.fetch!(opts, :x),
      y: Keyword.fetch!(opts, :y),
      w: Keyword.fetch!(opts, :w),
      h: Keyword.fetch!(opts, :h)
    }
  end
end

defimpl Plushie.Encode, for: Plushie.Canvas.Shape.HitRect do
  def encode(rect) do
    %{x: rect.x, y: rect.y, w: rect.w, h: rect.h}
  end
end
