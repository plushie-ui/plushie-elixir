defmodule Plushie.Type.Padding do
  @moduledoc """
  Padding specification with per-side values.

  Maps to iced's `Padding` struct. Accepts a uniform number,
  a `{vertical, horizontal}` tuple, an explicit four-side map,
  or a `%Padding{}` struct with per-side overrides.

  `cast/1` always normalises to the full four-side map.

  ## Struct form

  The struct supports per-side padding via keyword construction:

      Padding.from_opts(top: 4, bottom: 8)

  `nil` fields are stripped during encoding.
  """

  @type t ::
          number()
          | {number(), number()}
          | %__MODULE__{
              top: number() | nil,
              right: number() | nil,
              bottom: number() | nil,
              left: number() | nil
            }

  defstruct [:top, :right, :bottom, :left]

  @known_keys ~w(top right bottom left)a

  def __field_keys__, do: @known_keys

  def __field_types__, do: %{}

  @doc """
  Constructs padding from a keyword list.

  Raises `ArgumentError` if any key is not a valid padding field.
  """
  @spec from_opts(Keyword.t()) :: %__MODULE__{}
  def from_opts(opts) when is_list(opts) do
    for {key, _} <- opts, key not in @known_keys do
      raise ArgumentError,
            "unknown padding field #{inspect(key)}. Valid fields: #{inspect(@known_keys)}"
    end

    %__MODULE__{
      top: Keyword.get(opts, :top),
      right: Keyword.get(opts, :right),
      bottom: Keyword.get(opts, :bottom),
      left: Keyword.get(opts, :left)
    }
  end

  @doc """
  Validates a padding value, returning it in its canonical stored form.

  Numbers and tuples are validated and returned as-is (expansion to the
  four-side map happens during encoding). Structs and maps are validated
  and returned as four-side maps.

  ## Examples

      iex> Plushie.Type.Padding.cast(8)
      {:ok, 8}

      iex> Plushie.Type.Padding.cast({4, 12})
      {:ok, {4, 12}}

      iex> Plushie.Type.Padding.cast(%{top: 1, right: 2, bottom: 3, left: 4})
      {:ok, %{top: 1, right: 2, bottom: 3, left: 4}}
  """
  @behaviour Plushie.Type

  @impl Plushie.Type
  @spec cast(padding :: t()) :: {:ok, map()} | :error

  def cast(n) when is_number(n), do: {:ok, n}

  def cast({vertical, horizontal}) when is_number(vertical) and is_number(horizontal) do
    {:ok, {vertical, horizontal}}
  end

  def cast(%__MODULE__{} = padding) do
    result =
      padding
      |> Map.from_struct()
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()

    {:ok, result}
  end

  def cast(%{top: t, right: r, bottom: b, left: l})
      when is_number(t) and is_number(r) and is_number(b) and is_number(l) do
    {:ok, %{top: t, right: r, bottom: b, left: l}}
  end

  def cast(_), do: :error

  # -- Plushie.Type callbacks --------------------------------------------------

  @doc false
  @impl Plushie.Type
  def typespec do
    quote do: number() | {number(), number()} | %Plushie.Type.Padding{}
  end

  @doc false
  @impl Plushie.Type
  def guard(var) do
    quote do
      is_number(unquote(var)) or is_tuple(unquote(var)) or is_map(unquote(var))
    end
  end

  @impl Plushie.Type
  def encode(n) when is_number(n), do: n

  def encode({vertical, horizontal}) when is_number(vertical) and is_number(horizontal) do
    %{top: vertical, right: horizontal, bottom: vertical, left: horizontal}
  end

  def encode(%__MODULE__{} = padding) do
    padding
    |> Map.from_struct()
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  def encode(%{top: _, right: _, bottom: _, left: _} = map), do: map
end
