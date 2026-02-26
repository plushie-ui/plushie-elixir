defmodule Julep.Command do
  @moduledoc """
  Commands describe side effects that `update/2` wants the runtime to perform.

  They are plain data -- inspectable, testable, serializable. The runtime
  interprets them after `update/2` returns. Nothing executes inside `update`.

  ## Usage

      def update(model, {:click, "save"}) do
        cmd = Julep.Command.async(fn -> save(model) end, :save_result)
        {model, cmd}
      end

      def update(model, {:save_result, :ok}), do: %{model | saved: true}

  Multiple commands can be issued at once via `batch/1`:

      cmd = Julep.Command.batch([
        Julep.Command.focus("name_input"),
        Julep.Command.send_after(5000, :auto_save)
      ])
  """

  @enforce_keys [:type, :payload]
  defstruct [:type, :payload]

  @type t :: %__MODULE__{type: atom(), payload: map()} | [%__MODULE__{}]

  @doc "A no-op command. Returned implicitly when `update/2` returns a bare model."
  @spec none() :: %__MODULE__{}
  def none, do: %__MODULE__{type: :none, payload: %{}}

  @doc """
  Run `fun` asynchronously in a Task. When it returns, the runtime dispatches
  `{event_tag, result}` through `update/2`.
  """
  @spec async(fun(), atom()) :: %__MODULE__{}
  def async(fun, event_tag) when is_function(fun) and is_atom(event_tag) do
    %__MODULE__{type: :async, payload: %{fun: fun, tag: event_tag}}
  end

  @doc "Focus the widget identified by `widget_id`."
  @spec focus(term()) :: %__MODULE__{}
  def focus(widget_id) do
    %__MODULE__{type: :focus, payload: %{target: widget_id}}
  end

  @doc "Move focus to the next focusable widget."
  @spec focus_next() :: %__MODULE__{}
  def focus_next, do: %__MODULE__{type: :focus_next, payload: %{}}

  @doc "Move focus to the previous focusable widget."
  @spec focus_previous() :: %__MODULE__{}
  def focus_previous, do: %__MODULE__{type: :focus_previous, payload: %{}}

  @doc "Select all text in the widget identified by `widget_id`."
  @spec select_all(term()) :: %__MODULE__{}
  def select_all(widget_id) do
    %__MODULE__{type: :select_all, payload: %{target: widget_id}}
  end

  @doc "Scroll the widget identified by `widget_id` to `offset`."
  @spec scroll_to(term(), term()) :: %__MODULE__{}
  def scroll_to(widget_id, offset) do
    %__MODULE__{type: :scroll_to, payload: %{target: widget_id, offset: offset}}
  end

  @doc "Send `event` through `update/2` after `delay_ms` milliseconds."
  @spec send_after(non_neg_integer(), term()) :: %__MODULE__{}
  def send_after(delay_ms, event) when is_integer(delay_ms) and delay_ms >= 0 do
    %__MODULE__{type: :send_after, payload: %{delay: delay_ms, event: event}}
  end

  @doc "Close the window identified by `window_id`."
  @spec close_window(term()) :: %__MODULE__{}
  def close_window(window_id) do
    %__MODULE__{type: :close_window, payload: %{window_id: window_id}}
  end

  @doc """
  Issue multiple commands. Commands in the batch execute concurrently.

  Accepts a single command, a list of commands, or a nested list -- anything
  `List.wrap/1` can normalize.
  """
  @spec batch(t()) :: %__MODULE__{}
  def batch(commands) do
    %__MODULE__{type: :batch, payload: %{commands: List.wrap(commands)}}
  end
end
