defmodule Plushie.DSL.Widget.Validation do
  @moduledoc false

  # Widget-specific compile-time validation.
  #
  # Generic field validation (prop types, constraints, reserved names,
  # positional args) lives in `Plushie.DSL.Validation`. This module
  # handles widget-specific concerns: declarations, commands, events,
  # and view callbacks.

  alias Plushie.DSL.Validation, as: SharedValidation

  # -- Delegated to Plushie.DSL.Validation ------------------------------------

  defdelegate known_field_opts(), to: SharedValidation
  defdelegate validate_prop_types!(env, props), to: SharedValidation
  defdelegate validate_reserved_names!(env, props), to: SharedValidation
  defdelegate warn_duplicate_props(env, props), to: SharedValidation
  defdelegate validate_positional!(env, positional, props), to: SharedValidation
  defdelegate valid_type?(type), to: SharedValidation
  defdelegate type_module?(module), to: SharedValidation

  # -- Widget-specific validation ---------------------------------------------

  @doc false
  def validate_declarations!(env, kind, widget_type, _events) do
    unless widget_type do
      raise CompileError,
        file: env.file,
        line: 0,
        description: "missing `widget :type_name` declaration in #{inspect(env.module)}"
    end

    if kind == :native_widget do
      unless Module.get_attribute(env.module, :_rust_crate) do
        raise CompileError,
          file: env.file,
          line: 0,
          description: "missing `rust_crate \"path\"` in #{inspect(env.module)}"
      end

      unless Module.get_attribute(env.module, :_rust_constructor) do
        raise CompileError,
          file: env.file,
          line: 0,
          description: "missing `rust_constructor \"expr\"` in #{inspect(env.module)}"
      end
    end

    # All widget kinds can declare events via the event macro.
  end

  @doc false
  def validate_command_types!(commands) do
    for {cmd_name, params} <- commands, {param_name, type} <- params do
      unless valid_type?(type) do
        raise CompileError,
          description:
            "unsupported command param type #{inspect(type)} for param #{inspect(param_name)} in command #{inspect(cmd_name)}"
      end
    end
  end

  @doc false
  def warn_duplicate_events(env, events) do
    dupes = events -- Enum.uniq(events)

    if dupes != [] do
      IO.warn(
        "duplicate event names in #{inspect(env.module)}: #{inspect(Enum.uniq(dupes))}",
        Macro.Env.stacktrace(env)
      )
    end
  end

  @doc false
  def validate_widget_callbacks!(env, has_view_3) do
    has_view_2 = Module.defines?(env.module, {:view, 2})

    unless has_view_2 or has_view_3 do
      raise CompileError,
        file: env.file,
        line: 0,
        description: "#{inspect(env.module)} must define view/2 or view/3."
    end

    has_handle_event = Module.defines?(env.module, {:handle_event, 2})
    state_fields = Module.get_attribute(env.module, :_widget_state_fields) || []

    if has_view_3 and not has_view_2 and state_fields == [] and not has_handle_event do
      raise CompileError,
        file: env.file,
        line: 0,
        description:
          "#{inspect(env.module)} defines view/3 (stateful) but declares no state fields. " <>
            "Use `state field_name: default` to declare state, or define view/2 for stateless widgets."
    end
  end
end
