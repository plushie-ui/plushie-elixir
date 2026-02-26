defmodule Julep.Route do
  @moduledoc """
  Client-side routing for multi-view apps. Pure data structure
  maintaining a navigation stack of {path, params} entries.
  """

  defstruct stack: []

  def new(initial_path, params \\ %{}) do
    %__MODULE__{stack: [{initial_path, params}]}
  end

  def push(%__MODULE__{stack: stack} = route, path, params \\ %{}) do
    %{route | stack: [{path, params} | stack]}
  end

  def pop(%__MODULE__{stack: [_current | rest]} = route) when rest != [] do
    %{route | stack: rest}
  end

  def pop(%__MODULE__{} = route), do: route

  def current(%__MODULE__{stack: [{path, _} | _]}), do: path

  def params(%__MODULE__{stack: [{_, params} | _]}), do: params

  def can_go_back?(%__MODULE__{stack: stack}), do: length(stack) > 1

  def history(%__MODULE__{stack: stack}), do: Enum.map(stack, fn {path, _} -> path end)
end
