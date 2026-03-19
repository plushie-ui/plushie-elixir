defmodule Julep.Test.Backend.CommandProcessor do
  @moduledoc """
  Synchronous command processor shared by all test backends.

  Executes async, stream, done, and batch commands synchronously so that
  `update/2` side effects resolve immediately in tests. Widget ops, window
  ops, timers, and cancel are silently skipped (they need a renderer).

  Used by `:mock`, `:headless`, and `:windowed` backends. Since execution is
  synchronous, `await_async/3` correctly returns `:ok` immediately -- the
  commands have already completed by the time it is called.
  """

  @max_command_depth 100

  @doc """
  Process a list of commands synchronously, threading model state through
  each `update/2` dispatch. Returns the final model.
  """
  @spec process(app :: module(), model :: term(), commands :: [Julep.Command.t()]) :: term()
  def process(app, model, commands) do
    do_process(app, model, normalize_commands(commands), 0)
  end

  defp do_process(_app, model, [], _depth), do: model
  defp do_process(_app, model, _commands, depth) when depth > @max_command_depth, do: model

  defp do_process(app, model, commands, depth) do
    Enum.reduce(commands, model, fn
      %Julep.Command{type: :async, payload: %{fun: fun, tag: tag}}, acc ->
        result = fun.()

        {new_model, new_commands} =
          dispatch_update(app, acc, %Julep.Event.Async{tag: tag, result: result})

        do_process(app, new_model, new_commands, depth + 1)

      %Julep.Command{type: :stream, payload: %{fun: fun, tag: tag}}, acc ->
        ref = make_ref()
        parent = self()
        emit = fn value -> send(parent, {:cp_stream, ref, value}) end
        final = fun.(emit)

        acc = drain_stream(app, acc, tag, ref, depth)

        {new_model, new_commands} =
          dispatch_update(app, acc, %Julep.Event.Async{tag: tag, result: final})

        do_process(app, new_model, new_commands, depth + 1)

      %Julep.Command{type: :done, payload: %{value: value, mapper: mapper}}, acc ->
        event = mapper.(value)
        {new_model, new_commands} = dispatch_update(app, acc, event)
        do_process(app, new_model, new_commands, depth + 1)

      %Julep.Command{type: :batch, payload: %{commands: cmds}}, acc ->
        do_process(app, acc, cmds, depth + 1)

      %Julep.Command{type: :none}, acc ->
        acc

      %Julep.Command{}, acc ->
        # Widget ops, window ops, timers, cancel -- skip (needs renderer)
        acc
    end)
  end

  defp drain_stream(app, model, tag, ref, depth) do
    receive do
      {:cp_stream, ^ref, value} ->
        {new_model, new_commands} =
          dispatch_update(app, model, %Julep.Event.Stream{tag: tag, value: value})

        new_model = do_process(app, new_model, new_commands, depth + 1)
        drain_stream(app, new_model, tag, ref, depth)
    after
      0 -> model
    end
  end

  @doc false
  def dispatch_update(app, model, event) do
    case app.update(model, event) do
      {model, commands} when is_list(commands) -> {model, commands}
      {model, %Julep.Command{} = cmd} -> {model, [cmd]}
      model -> {model, []}
    end
  end

  defp normalize_commands(commands) when is_list(commands), do: commands
  defp normalize_commands(%Julep.Command{} = cmd), do: [cmd]
  defp normalize_commands(_), do: []
end
