defmodule Toddy.Type.Padding do
  @moduledoc """
  Padding specification with per-side values.

  Maps to iced's `Padding` struct. Accepts a uniform number,
  a `{vertical, horizontal}` tuple, an explicit four-side map,
  or a `%Padding{}` struct with per-side overrides.

  `encode/1` always normalises to the full four-side map.

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

  @behaviour Toddy.DSL.Buildable

  @known_keys ~w(top right bottom left)a

  @impl Toddy.DSL.Buildable
  def __field_keys__, do: @known_keys

  @impl Toddy.DSL.Buildable
  def __field_types__, do: %{}

  @doc """
  Constructs padding from a keyword list.

  Raises `ArgumentError` if any key is not a valid padding field.
  """
  @impl Toddy.DSL.Buildable
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
  Normalises a padding value to the canonical four-side map with atom keys.

  ## Examples

      iex> Toddy.Type.Padding.encode(8)
      %{top: 8, right: 8, bottom: 8, left: 8}

      iex> Toddy.Type.Padding.encode({4, 12})
      %{top: 4, right: 12, bottom: 4, left: 12}

      iex> Toddy.Type.Padding.encode(%{top: 1, right: 2, bottom: 3, left: 4})
      %{top: 1, right: 2, bottom: 3, left: 4}
  """
  @spec encode(padding :: t()) :: map()
  def encode(n) when is_number(n) do
    %{top: n, right: n, bottom: n, left: n}
  end

  def encode({vertical, horizontal}) when is_number(vertical) and is_number(horizontal) do
    %{top: vertical, right: horizontal, bottom: vertical, left: horizontal}
  end

  def encode(%__MODULE__{} = padding) do
    padding
    |> Map.from_struct()
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  def encode(%{top: t, right: r, bottom: b, left: l})
      when is_number(t) and is_number(r) and is_number(b) and is_number(l) do
    %{top: t, right: r, bottom: b, left: l}
  end
end

defimpl Toddy.Encode, for: Toddy.Type.Padding do
  def encode(%Toddy.Type.Padding{} = padding) do
    Toddy.Type.Padding.encode(padding)
  end
end
