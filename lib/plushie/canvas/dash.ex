defmodule Plushie.Canvas.Dash do
  @moduledoc "Dash pattern for canvas shape strokes."

  @type t :: %__MODULE__{
          segments: [number()],
          offset: number()
        }

  use Plushie.Type

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

  # -- Plushie.Type callbacks --------------------------------------------------

  @impl Plushie.Type
  def cast(%__MODULE__{} = dash), do: {:ok, dash}

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

  def cast({segments, offset}) when is_list(segments) and is_number(offset) do
    {:ok, %__MODULE__{segments: segments, offset: offset}}
  end

  def cast(_), do: :error

  @impl Plushie.Type
  def typespec do
    quote do: %Plushie.Canvas.Dash{}
  end

  @impl Plushie.Type
  def castable do
    quote do: %Plushie.Canvas.Dash{} | keyword() | map() | {list(), number()}
  end

  @impl Plushie.Type
  def guard(var) do
    quote do:
            is_struct(unquote(var), Plushie.Canvas.Dash) or is_list(unquote(var)) or
              is_map(unquote(var)) or is_tuple(unquote(var))
  end

  @impl Plushie.Type
  def encode(%__MODULE__{} = dash) do
    %{segments: dash.segments, offset: dash.offset}
  end
end
