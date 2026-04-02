defmodule Plushie.Type.Pointer do
  @moduledoc """
  Event field types for unified pointer events.

  Provides pointer type and button parsing for the unified pointer event
  model that replaces the old canvas_*/mouse_*/sensor_* event families.

  ## Pointer types

  - `:mouse` -- standard mouse input
  - `:touch` -- touchscreen finger
  - `:pen` -- stylus or pen tablet

  ## Buttons

  - `:left`, `:right`, `:middle` -- standard three-button mouse
  - `:back`, `:forward` -- extended navigation buttons

  ## Examples

      iex> Plushie.Type.Pointer.parse_pointer("mouse")
      {:ok, :mouse}

      iex> Plushie.Type.Pointer.parse_button("right")
      {:ok, :right}
  """

  @behaviour Plushie.Event.EventType

  @type pointer_type :: :mouse | :touch | :pen
  @type button :: :left | :right | :middle | :back | :forward

  @pointers %{
    "mouse" => :mouse,
    "touch" => :touch,
    "pen" => :pen
  }

  @buttons %{
    "left" => :left,
    "right" => :right,
    "middle" => :middle,
    "back" => :back,
    "forward" => :forward
  }

  @doc """
  Parses a wire-format pointer type string into an atom.

  Returns `{:ok, pointer_type}` or `:error`.
  """
  @spec parse_pointer(value :: term()) :: {:ok, pointer_type()} | :error
  def parse_pointer(value) when is_binary(value) do
    case Map.fetch(@pointers, value) do
      {:ok, pointer} -> {:ok, pointer}
      :error -> :error
    end
  end

  def parse_pointer(nil), do: {:ok, :mouse}
  def parse_pointer(_), do: :error

  @doc """
  Parses a wire-format button string into an atom.

  Returns `{:ok, button}` or `:error`. Defaults to `:left` when nil
  (press/release events without an explicit button are left clicks).
  """
  @spec parse_button(value :: term()) :: {:ok, button()} | :error
  def parse_button(value) when is_binary(value) do
    case Map.fetch(@buttons, value) do
      {:ok, button} -> {:ok, button}
      :error -> :error
    end
  end

  def parse_button(nil), do: {:ok, :left}
  def parse_button(_), do: :error

  # EventType implementation -- parse/1 handles pointer type strings
  # for use in event spec field type declarations.
  @impl true
  @spec parse(value :: term()) :: {:ok, pointer_type()} | :error
  def parse(value), do: parse_pointer(value)
end
