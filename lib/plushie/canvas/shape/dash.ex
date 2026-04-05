defmodule Plushie.Canvas.Shape.Dash do
  @moduledoc "Dash pattern for canvas shape strokes."

  @type t :: %__MODULE__{
          segments: [number()],
          offset: number()
        }

  @enforce_keys [:segments, :offset]
  defstruct [:segments, :offset]

  @known_keys ~w(segments offset)a

  def __field_keys__, do: @known_keys

  def __field_types__, do: %{}

  @doc "Constructs a dash pattern from a keyword list."
  @spec from_opts(keyword()) :: t()
  def from_opts(opts) when is_list(opts) do
    for {key, _} <- opts, key not in @known_keys do
      raise ArgumentError,
            "unknown dash field #{inspect(key)}. Valid fields: #{inspect(@known_keys)}"
    end

    %__MODULE__{
      segments: Keyword.fetch!(opts, :segments),
      offset: Keyword.fetch!(opts, :offset)
    }
  end
end

defimpl Plushie.Encode, for: Plushie.Canvas.Shape.Dash do
  def encode(dash) do
    %{segments: dash.segments, offset: dash.offset}
  end
end
