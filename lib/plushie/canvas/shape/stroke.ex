defmodule Plushie.Canvas.Shape.Stroke do
  @moduledoc "Canvas stroke descriptor with color, width, and optional cap/join/dash."

  alias Plushie.Canvas.Shape.Dash

  @type t :: %__MODULE__{
          color: String.t(),
          width: number(),
          cap: String.t() | nil,
          join: String.t() | nil,
          dash: Dash.t() | nil
        }

  @enforce_keys [:color, :width]
  defstruct [:color, :width, :cap, :join, :dash]

  @behaviour Plushie.DSL.Buildable

  @known_keys ~w(color width cap join dash)a

  @impl Plushie.DSL.Buildable
  def __field_keys__, do: @known_keys

  @impl Plushie.DSL.Buildable
  def __field_types__ do
    %{dash: Dash}
  end

  @doc "Constructs a stroke from a keyword list."
  @impl Plushie.DSL.Buildable
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
end

defimpl Plushie.Encode, for: Plushie.Canvas.Shape.Stroke do
  def encode(stroke) do
    %{color: Plushie.Encode.encode(stroke.color), width: stroke.width}
    |> put_if(:cap, stroke.cap)
    |> put_if(:join, stroke.join)
    |> put_if(:dash, stroke.dash)
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, val), do: Map.put(map, key, Plushie.Encode.encode(val))
end
