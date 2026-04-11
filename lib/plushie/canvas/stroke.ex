defmodule Plushie.Canvas.Stroke do
  @moduledoc "Canvas stroke descriptor with color, width, and optional cap/join/dash."

  alias Plushie.Canvas.Dash

  @type t :: %__MODULE__{
          color: String.t(),
          width: number(),
          cap: String.t() | nil,
          join: String.t() | nil,
          dash: Dash.t() | nil
        }

  use Plushie.Type

  @enforce_keys [:color, :width]
  defstruct [:color, :width, :cap, :join, :dash]

  @known_keys ~w(color width cap join dash)a

  def __field_keys__, do: @known_keys

  def __field_types__ do
    %{dash: Dash}
  end

  @doc "Constructs a stroke from a keyword list."
  @spec from_opts(keyword()) :: t()
  def from_opts(opts) when is_list(opts) do
    for {key, _} <- opts, key not in @known_keys do
      raise ArgumentError,
            "unknown stroke field #{inspect(key)}. Valid fields: #{inspect(@known_keys)}"
    end

    dash_val =
      case Keyword.get(opts, :dash) do
        nil -> nil
        %Dash{} = d -> d
        kw when is_list(kw) -> Dash.from_opts(kw)
        {segments, offset} -> %Dash{segments: segments, offset: offset}
      end

    %__MODULE__{
      color: Keyword.fetch!(opts, :color),
      width: Keyword.fetch!(opts, :width),
      cap: Keyword.get(opts, :cap),
      join: Keyword.get(opts, :join),
      dash: dash_val
    }
  end

  # -- Plushie.Type callbacks --------------------------------------------------

  @impl Plushie.Type
  def cast(%__MODULE__{} = stroke), do: {:ok, stroke}

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
    quote do: %Plushie.Canvas.Stroke{}
  end

  @impl Plushie.Type
  def castable do
    quote do: %Plushie.Canvas.Stroke{} | keyword() | map()
  end

  @impl Plushie.Type
  def guard(var) do
    quote do
      is_struct(unquote(var), Plushie.Canvas.Stroke) or is_list(unquote(var)) or
        is_map(unquote(var))
    end
  end

  @impl Plushie.Type
  def encode(%__MODULE__{} = stroke) do
    %{color: Plushie.Type.encode_value(stroke.color), width: stroke.width}
    |> put_if(:cap, stroke.cap)
    |> put_if(:join, stroke.join)
    |> put_if(:dash, stroke.dash)
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, val), do: Map.put(map, key, Plushie.Type.encode_value(val))
end
