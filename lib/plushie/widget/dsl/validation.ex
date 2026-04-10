defmodule Plushie.Widget.DSL.Validation do
  @moduledoc false

  # Compile-time validation for widget declarations.
  #
  # Called from `Plushie.Widget.__before_compile__/1` to validate
  # accumulated module attributes before code generation.

  # Known field options consumed by the widget macro. Anything else is
  # treated as a type constraint and forwarded to constrain_guard/2.
  @known_field_opts [:doc, :default, :option, :wire_name, :required, :cast, :merge]

  @reserved_prop_names [:id, :type, :children, :do]

  @doc false
  def known_field_opts, do: @known_field_opts

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
  def validate_prop_types!(env, props) do
    for {name, type, opts} <- props do
      unless valid_type?(type) do
        raise CompileError,
          file: env.file,
          line: 0,
          description:
            "unsupported field type #{inspect(type)} for field #{inspect(name)} in #{inspect(env.module)}. " <>
              "Use a primitive shortcut (:string, :float, etc.), a Plushie.Type module, " <>
              "or a composite ({:list, :type})."
      end

      validate_field_constraints!(env, name, type, opts)
    end
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
  def warn_duplicate_props(env, props) do
    prop_names = Enum.map(props, fn {name, _, _} -> name end)
    dupes = prop_names -- Enum.uniq(prop_names)

    if dupes != [] do
      IO.warn(
        "duplicate prop names in #{inspect(env.module)}: #{inspect(Enum.uniq(dupes))}",
        Macro.Env.stacktrace(env)
      )
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
  def validate_reserved_names!(env, props) do
    for {name, _type, _opts} <- props, name in @reserved_prop_names do
      raise CompileError,
        file: env.file,
        line: 0,
        description:
          "field name #{inspect(name)} is reserved in #{inspect(env.module)}. " <>
            "Reserved names: #{inspect(@reserved_prop_names)}"
    end
  end

  @doc false
  def validate_positional!(env, positional, props) do
    prop_names = Enum.map(props, fn {name, _, _} -> name end)

    for name <- positional do
      unless name in prop_names do
        raise CompileError,
          file: env.file,
          line: 0,
          description:
            "positional #{inspect(name)} is not a declared field in #{inspect(env.module)}. " <>
              "Declared fields: #{inspect(prop_names)}"
      end
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

  @doc false
  def valid_type?(type) when is_atom(type) do
    # Known shortcuts are valid by definition (avoids compile-order issues).
    Plushie.Type.shortcut?(type) or type_module?(type)
  end

  def valid_type?({kind, spec}) when is_atom(kind) do
    if Plushie.Type.composite_kind?(kind) do
      Plushie.Type.composite_module(kind).valid_spec?(spec, &valid_type?/1)
    else
      false
    end
  end

  def valid_type?(_), do: false

  @doc false
  def type_module?(module) do
    case Code.ensure_compiled(module) do
      {:module, _} -> function_exported?(module, :typespec, 0)
      {:error, _} -> false
    end
  end

  # -- Private helpers ---------------------------------------------------------

  defp validate_field_constraints!(env, name, type, opts) do
    constraint_opts = Keyword.drop(opts, @known_field_opts)

    case {constraint_opts, Plushie.Type.resolve(type)} do
      {[], _} ->
        :ok

      {_, {:composite, _}} ->
        constraint_error!(
          env,
          name,
          constraint_opts,
          "composite types do not support constraints"
        )

      {_, module} ->
        validate_module_constraints!(env, name, module, constraint_opts)
    end
  end

  defp validate_module_constraints!(env, name, module, constraint_opts) do
    Code.ensure_compiled(module)

    unless function_exported?(module, :field_options, 0) do
      constraint_error!(
        env,
        name,
        constraint_opts,
        "#{inspect(module)} does not support constraints (no field_options/0)"
      )
    end

    allowed = module.field_options()

    for {key, _val} <- constraint_opts, key not in allowed do
      raise CompileError,
        file: env.file,
        line: 0,
        description:
          "field #{inspect(name)} in #{inspect(env.module)} has unknown constraint " <>
            "#{inspect(key)}. #{inspect(module)} supports: #{inspect(allowed)}"
    end
  end

  defp constraint_error!(env, name, constraint_opts, reason) do
    raise CompileError,
      file: env.file,
      line: 0,
      description:
        "field #{inspect(name)} in #{inspect(env.module)} has constraint options " <>
          "#{inspect(Keyword.keys(constraint_opts))} but #{reason}"
  end
end
