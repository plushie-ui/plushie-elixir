defmodule Plushie.Canvas.ShapeStyle do
  @moduledoc "Style overrides for interactive canvas shape states (hover, pressed)."

  @type t :: %__MODULE__{
          fill: String.t() | map() | nil,
          stroke: String.t() | map() | nil,
          opacity: number() | nil
        }

  use Plushie.Type

  defstruct [:fill, :stroke, :opacity]

  @known_keys ~w(fill stroke opacity)a

  def __field_keys__, do: @known_keys

  def __field_types__, do: %{}

  @doc "Constructs a shape style from a keyword list."
  @spec from_opts(keyword()) :: t()
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

  # -- Plushie.Type callbacks --------------------------------------------------

  @impl Plushie.Type
  def cast(%__MODULE__{} = style), do: {:ok, style}

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
    quote do: %Plushie.Canvas.ShapeStyle{}
  end

  @impl Plushie.Type
  def castable do
    quote do: %Plushie.Canvas.ShapeStyle{} | keyword() | map()
  end

  @impl Plushie.Type
  def guard(var) do
    quote do
      is_struct(unquote(var), Plushie.Canvas.ShapeStyle) or is_list(unquote(var)) or
        is_map(unquote(var))
    end
  end

  @impl Plushie.Type
  def encode(%__MODULE__{} = style) do
    style
    |> Map.from_struct()
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new(fn {k, v} -> {k, Plushie.Type.encode_value(v)} end)
  end
end
