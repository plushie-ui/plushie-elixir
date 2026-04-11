defmodule Plushie.Canvas.DragBounds do
  @moduledoc "Drag constraint bounds for interactive canvas shapes."

  @type t :: %__MODULE__{
          min_x: number() | nil,
          max_x: number() | nil,
          min_y: number() | nil,
          max_y: number() | nil
        }

  use Plushie.Type

  defstruct [:min_x, :max_x, :min_y, :max_y]

  @known_keys ~w(min_x max_x min_y max_y)a

  def __field_keys__, do: @known_keys

  def __field_types__, do: %{}

  @doc "Constructs drag bounds from a keyword list."
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

  # -- Plushie.Type callbacks --------------------------------------------------

  @impl Plushie.Type
  def cast(%__MODULE__{} = bounds), do: {:ok, bounds}

  def cast(opts) when is_list(opts) do
    {:ok, from_opts(opts)}
  rescue
    ArgumentError -> :error
  end

  def cast(%{} = map) do
    {:ok, from_opts(Enum.to_list(map))}
  rescue
    ArgumentError -> :error
  end

  def cast(_), do: :error

  @impl Plushie.Type
  def typespec do
    quote do: %Plushie.Canvas.DragBounds{}
  end

  @impl Plushie.Type
  def castable do
    quote do: %Plushie.Canvas.DragBounds{} | keyword() | map()
  end

  @impl Plushie.Type
  def guard(var) do
    quote do
      is_struct(unquote(var), Plushie.Canvas.DragBounds) or is_list(unquote(var)) or
        is_map(unquote(var))
    end
  end

  @impl Plushie.Type
  def encode(%__MODULE__{} = bounds) do
    bounds
    |> Map.from_struct()
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new(fn {k, v} -> {k, Plushie.Type.encode_value(v)} end)
  end
end
