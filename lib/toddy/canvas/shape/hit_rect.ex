defmodule Toddy.Canvas.Shape.HitRect do
  @moduledoc "Explicit hit test rectangle override for interactive canvas shapes."

  @type t :: %__MODULE__{
          x: number(),
          y: number(),
          w: number(),
          h: number()
        }

  @enforce_keys [:x, :y, :w, :h]
  defstruct [:x, :y, :w, :h]

  @known_keys ~w(x y w h)a

  @doc false
  def __field_keys__, do: @known_keys

  @doc false
  def __field_types__, do: %{}

  @doc "Constructs a hit rect from a keyword list."
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

defimpl Toddy.Encode, for: Toddy.Canvas.Shape.HitRect do
  def encode(rect) do
    %{x: rect.x, y: rect.y, w: rect.w, h: rect.h}
  end
end
