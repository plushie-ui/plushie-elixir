defmodule Plushie.Canvas.HitRect do
  @moduledoc "Explicit hit test rectangle override for interactive canvas shapes."

  @type t :: %__MODULE__{
          x: number(),
          y: number(),
          w: number(),
          h: number()
        }

  use Plushie.Type

  @enforce_keys [:x, :y, :w, :h]
  defstruct [:x, :y, :w, :h]

  @known_keys ~w(x y w h)a

  def __field_keys__, do: @known_keys

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

  # -- Plushie.Type callbacks --------------------------------------------------

  @impl Plushie.Type
  def cast(%__MODULE__{} = rect), do: {:ok, rect}

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
    quote do: %Plushie.Canvas.HitRect{}
  end

  @impl Plushie.Type
  def castable do
    quote do: %Plushie.Canvas.HitRect{} | keyword() | map()
  end

  @impl Plushie.Type
  def guard(var) do
    quote do
      is_struct(unquote(var), Plushie.Canvas.HitRect) or is_list(unquote(var)) or
        is_map(unquote(var))
    end
  end

  @impl Plushie.Type
  def encode(%__MODULE__{} = rect) do
    %{x: rect.x, y: rect.y, w: rect.w, h: rect.h}
  end
end
