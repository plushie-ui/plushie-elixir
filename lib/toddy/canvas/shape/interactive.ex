defmodule Toddy.Canvas.Shape.Interactive do
  @moduledoc "Interactive shape descriptor for canvas hit testing and event handling."

  @type t :: %__MODULE__{
          id: String.t(),
          on_click: boolean() | nil,
          on_hover: boolean() | nil,
          draggable: boolean() | nil,
          drag_axis: String.t() | nil,
          drag_bounds: map() | nil,
          cursor: String.t() | nil,
          hover_style: map() | nil,
          pressed_style: map() | nil,
          tooltip: String.t() | nil,
          a11y: map() | nil,
          hit_rect: map() | nil
        }

  @enforce_keys [:id]
  defstruct [
    :id,
    :on_click,
    :on_hover,
    :draggable,
    :drag_axis,
    :drag_bounds,
    :cursor,
    :hover_style,
    :pressed_style,
    :tooltip,
    :a11y,
    :hit_rect
  ]

  @known_keys ~w(id on_click on_hover draggable drag_axis drag_bounds cursor hover_style pressed_style tooltip a11y hit_rect)a

  def new(opts) when is_list(opts) do
    for {key, _} <- opts, key not in @known_keys do
      raise ArgumentError,
            "unknown interactive option #{inspect(key)}. Valid options: #{inspect(@known_keys)}"
    end

    %__MODULE__{
      id: Keyword.fetch!(opts, :id),
      on_click: Keyword.get(opts, :on_click),
      on_hover: Keyword.get(opts, :on_hover),
      draggable: Keyword.get(opts, :draggable),
      drag_axis: Keyword.get(opts, :drag_axis),
      drag_bounds: Keyword.get(opts, :drag_bounds),
      cursor: Keyword.get(opts, :cursor),
      hover_style: Keyword.get(opts, :hover_style),
      pressed_style: Keyword.get(opts, :pressed_style),
      tooltip: Keyword.get(opts, :tooltip),
      a11y: Keyword.get(opts, :a11y),
      hit_rect: Keyword.get(opts, :hit_rect)
    }
  end
end

defimpl Toddy.Encode, for: Toddy.Canvas.Shape.Interactive do
  def encode(interactive) do
    interactive
    |> Map.from_struct()
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new(fn {k, v} -> {k, Toddy.Encode.encode(v)} end)
  end
end
