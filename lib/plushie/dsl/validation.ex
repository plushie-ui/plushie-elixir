defmodule Plushie.DSL.Validation do
  @moduledoc false

  # Shared field validation for struct-based DSL modules.
  #
  # Generic validation logic (prop types, field constraints, reserved
  # names, positional args) extracted from the widget-specific
  # validation module. Reusable by widgets, canvas elements, and any
  # future struct-based DSL.

  # Known field options consumed by DSL macros. Anything else is
  # treated as a type constraint and forwarded to constrain_guard/2.
  @known_field_opts [:doc, :default, :option, :wire_name, :required, :cast, :merge, :__line__]

  @reserved_prop_names [:id, :type, :children, :do]

  @doc false
  def known_field_opts, do: @known_field_opts

  @doc false
  def validate_prop_types!(env, props) do
    for {name, type, opts} <- props do
      unless valid_type?(type) do
        raise CompileError,
          file: env.file,
          line: field_line(opts, env),
          description:
            "unsupported field type #{inspect(type)} for field #{inspect(name)} in #{inspect(env.module)}. " <>
              "Use a primitive shortcut (:string, :float, etc.), a Plushie.Type module, " <>
              "or a composite ({:list, :type})."
      end

      validate_field_constraints!(env, name, type, opts)
    end
  end

  @doc false
  def validate_reserved_names!(env, props) do
    for {name, _type, opts} <- props, name in @reserved_prop_names do
      raise CompileError,
        file: env.file,
        line: field_line(opts, env),
        description:
          "field name #{inspect(name)} is reserved in #{inspect(env.module)}. " <>
            "Reserved names: #{inspect(@reserved_prop_names)}"
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
  def validate_positional!(env, positional, props, line \\ nil) do
    prop_names = Enum.map(props, fn {name, _, _} -> name end)

    for name <- positional do
      unless name in prop_names do
        raise CompileError,
          file: env.file,
          line: line || env.line,
          description:
            "positional #{inspect(name)} is not a declared field in #{inspect(env.module)}. " <>
              "Declared fields: #{inspect(prop_names)}"
      end
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

  @doc false
  def validate_field_constraints!(env, name, type, opts) do
    constraint_opts = Keyword.drop(opts, @known_field_opts)

    case {constraint_opts, Plushie.Type.resolve(type)} do
      {[], _} ->
        :ok

      {_, {:composite, _}} ->
        constraint_error!(
          env,
          name,
          opts,
          constraint_opts,
          "composite types do not support constraints"
        )

      {_, module} ->
        validate_module_constraints!(env, name, module, opts, constraint_opts)
    end
  end

  @doc false
  def validate_module_constraints!(env, name, module, opts, constraint_opts) do
    Code.ensure_compiled(module)

    unless function_exported?(module, :field_options, 0) do
      constraint_error!(
        env,
        name,
        opts,
        constraint_opts,
        "#{inspect(module)} does not support constraints (no field_options/0)"
      )
    end

    allowed = module.field_options()

    for {key, _val} <- constraint_opts, key not in allowed do
      raise CompileError,
        file: env.file,
        line: field_line(opts, env),
        description:
          "field #{inspect(name)} in #{inspect(env.module)} has unknown constraint " <>
            "#{inspect(key)}. #{inspect(module)} supports: #{inspect(allowed)}"
    end
  end

  @doc false
  def constraint_error!(env, name, opts, constraint_opts, reason) do
    raise CompileError,
      file: env.file,
      line: field_line(opts, env),
      description:
        "field #{inspect(name)} in #{inspect(env.module)} has constraint options " <>
          "#{inspect(Keyword.keys(constraint_opts))} but #{reason}"
  end

  defp field_line(opts, env) do
    Keyword.get(opts, :__line__, env.line)
  end
end
