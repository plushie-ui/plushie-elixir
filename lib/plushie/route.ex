defmodule Plushie.Route do
  @moduledoc """
  Client-side routing for multi-view apps. Pure data structure
  maintaining a navigation stack of `{path, params}` entries.

  The stack is last-in-first-out. `push/3` adds a new entry on top;
  `pop/1` removes the top entry (never pops the last one). `current/1`
  and `params/1` read from the top of the stack.

  ## Example

      route = Plushie.Route.new(:home)
      route = Plushie.Route.push(route, :settings, %{tab: "general"})
      Plushie.Route.current(route)
      #=> :settings
      Plushie.Route.params(route)
      #=> %{tab: "general"}
      route = Plushie.Route.pop(route)
      Plushie.Route.current(route)
      #=> :home
  """

  defstruct stack: []

  @typedoc "A navigation stack entry: `{path, params}`."
  @type entry :: {term(), map()}

  @type t :: %__MODULE__{stack: [entry()]}

  @doc """
  Creates a new route with `initial_path` at the bottom of the stack.

  `params` defaults to an empty map.
  """
  @spec new(initial_path :: term(), params :: map()) :: t()
  def new(initial_path, params \\ %{}) do
    %__MODULE__{stack: [{initial_path, params}]}
  end

  @doc """
  Pushes a new `path` (with optional `params`) onto the navigation stack.
  """
  @spec push(route :: t(), path :: term(), params :: map()) :: t()
  def push(%__MODULE__{stack: stack} = route, path, params \\ %{}) do
    %{route | stack: [{path, params} | stack]}
  end

  @doc """
  Pops the top entry from the stack. Returns the route unchanged if
  only one entry remains (the root is never popped).
  """
  @spec pop(route :: t()) :: t()
  def pop(%__MODULE__{stack: [_current | rest]} = route) when rest != [] do
    %{route | stack: rest}
  end

  def pop(%__MODULE__{} = route), do: route

  @doc """
  Replaces the top entry with a new `path` and `params`.
  """
  @spec replace_top(route :: t(), path :: term(), params :: map()) :: t()
  def replace_top(%__MODULE__{stack: [_ | rest]} = route, path, params \\ %{}) do
    %{route | stack: [{path, params} | rest]}
  end

  @doc "Returns the current (top) path."
  @spec current(route :: t()) :: term()
  def current(%__MODULE__{stack: [{path, _} | _]}), do: path

  @doc "Returns the params associated with the current (top) path."
  @spec params(route :: t()) :: map()
  def params(%__MODULE__{stack: [{_, params} | _]}), do: params

  @doc "Returns `true` if there is more than one entry on the stack."
  @spec can_go_back?(route :: t()) :: boolean()
  def can_go_back?(%__MODULE__{stack: [_, _ | _]}), do: true
  def can_go_back?(%__MODULE__{}), do: false

  @doc "Returns a list of all paths in the stack, most recent first."
  @spec history(route :: t()) :: [term()]
  def history(%__MODULE__{stack: stack}), do: Enum.map(stack, fn {path, _} -> path end)
end
