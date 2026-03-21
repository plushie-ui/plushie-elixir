defmodule Plushie.Canvas.Shape.DragBounds do
  @moduledoc "Drag constraint bounds for interactive canvas shapes."

  @type t :: %__MODULE__{
          min_x: number() | nil,
          max_x: number() | nil,
          min_y: number() | nil,
          max_y: number() | nil
        }

  defstruct [:min_x, :max_x, :min_y, :max_y]

  @behaviour Plushie.DSL.Buildable

  @known_keys ~w(min_x max_x min_y max_y)a

  @impl Plushie.DSL.Buildable
  def __field_keys__, do: @known_keys

  @impl Plushie.DSL.Buildable
  def __field_types__, do: %{}

  @doc "Constructs drag bounds from a keyword list."
  @impl Plushie.DSL.Buildable
  @spec from_opts(keyword()) :: t()
  def from_opts(opts) when is_list(opts) do
    for {key, _} <- opts, key not in @known_keys do
      raise ArgumentError,
            "unknown drag bounds field #{inspect(key)}. Valid fields: #{inspect(@known_keys)}"
    end

    %__MODULE__{
      min_x: Keyword.get(opts, :min_x),
      max_x: Keyword.get(opts, :max_x),
      min_y: Keyword.get(opts, :min_y),
      max_y: Keyword.get(opts, :max_y)
    }
  end
end

defimpl Plushie.Encode, for: Plushie.Canvas.Shape.DragBounds do
  def encode(bounds) do
    bounds
    |> Map.from_struct()
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new(fn {k, v} -> {k, Plushie.Encode.encode(v)} end)
  end
end
