defmodule Toddy.Canvas.Shape.ShapeStyle do
  @moduledoc "Style overrides for interactive canvas shape states (hover, pressed)."

  @type t :: %__MODULE__{
          fill: String.t() | map() | nil,
          stroke: String.t() | map() | nil,
          opacity: number() | nil
        }

  defstruct [:fill, :stroke, :opacity]

  @known_keys ~w(fill stroke opacity)a

  @doc false
  def __field_keys__, do: @known_keys

  @doc false
  def __field_types__, do: %{}

  @doc "Constructs a shape style from a keyword list."
  def from_opts(opts) when is_list(opts) do
    for {key, _} <- opts, key not in @known_keys do
      raise ArgumentError,
            "unknown shape style field #{inspect(key)}. Valid fields: #{inspect(@known_keys)}"
    end

    %__MODULE__{
      fill: Keyword.get(opts, :fill),
      stroke: Keyword.get(opts, :stroke),
      opacity: Keyword.get(opts, :opacity)
    }
  end
end

defimpl Toddy.Encode, for: Toddy.Canvas.Shape.ShapeStyle do
  def encode(style) do
    style
    |> Map.from_struct()
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new(fn {k, v} -> {k, Toddy.Encode.encode(v)} end)
  end
end
