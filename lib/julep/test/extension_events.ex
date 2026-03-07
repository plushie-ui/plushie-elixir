defmodule Julep.Test.ExtensionEvents do
  @moduledoc """
  Registry for extension sim event dispatch.

  When the sim test backend encounters a widget type not handled by the
  built-in `EventMap`, it consults this registry. Extensions that implement
  the optional `Julep.Extension.sim_events/3` callback can register here
  so their custom widget types participate in sim testing.

  Registration is keyed by type name (string) in `:persistent_term`.
  """

  require Logger

  alias Julep.Test.Element

  @doc """
  Registers an extension module for sim event dispatch.

  Stores the module in `:persistent_term` keyed by each type name
  returned by `module.type_names/0`.

  Raises if any type name is already claimed by a different module.
  Re-registering the same module for the same type is a no-op.
  """
  @spec register(module :: module()) :: :ok
  def register(module) do
    for type_name <- module.type_names() do
      case :persistent_term.get({__MODULE__, type_name}, :not_found) do
        :not_found ->
          :persistent_term.put({__MODULE__, type_name}, module)

        ^module ->
          # Already registered by the same module -- idempotent
          :ok

        other_module ->
          raise "Extension type name collision: #{inspect(type_name)} is claimed by " <>
                  "#{inspect(other_module)} and #{inspect(module)}"
      end
    end

    :ok
  end

  @doc """
  Dispatches a sim verb to the extension registered for the element's type.

  Returns `:not_handled` when no extension is registered for the type or
  when the registered module does not implement `sim_events/3`.
  """
  @spec dispatch(verb :: atom(), element :: Element.t(), args :: list()) ::
          {:ok, tuple()} | {:error, String.t()} | :not_handled
  def dispatch(verb, %Element{type: type} = element, args) do
    case lookup(type) do
      {:ok, module} ->
        if function_exported?(module, :sim_events, 3) do
          module.sim_events(verb, element, args)
        else
          :not_handled
        end

      :error ->
        :not_handled
    end
  end

  @doc """
  Removes all extension registrations.

  Useful for test cleanup. Scans `:persistent_term` for keys matching
  this module's namespace and erases them.
  """
  @spec clear() :: :ok
  def clear do
    for {{__MODULE__, _type_name} = key, _mod} <- :persistent_term.get() do
      :persistent_term.erase(key)
    end

    :ok
  end

  @doc """
  Discovers all loaded modules implementing `Julep.Extension` and registers them.

  This is a convenience that mirrors `Mix.Tasks.Julep.Build.configured_extensions/0`
  but does not depend on Mix. Safe to call multiple times (idempotent).

  Skips modules whose type names collide with an already-registered extension
  (logs a warning). Use `register/1` directly for strict collision checking.
  """
  @spec register_all() :: :ok
  def register_all do
    for {mod, _} <- :code.all_loaded(),
        extension?(mod) do
      try do
        register(mod)
      rescue
        e in RuntimeError ->
          Logger.warning("Skipping extension #{inspect(mod)}: #{Exception.message(e)}")
      end
    end

    :ok
  end

  # -- Private ----------------------------------------------------------------

  defp lookup(type) do
    case :persistent_term.get({__MODULE__, type}, :not_found) do
      :not_found -> :error
      module -> {:ok, module}
    end
  end

  # NOTE: This logic is duplicated in Mix.Tasks.Julep.Build.mod_behaviours/1.
  # We intentionally avoid depending on Mix here since this module is used in
  # test runtime, not build tooling.
  defp extension?(mod) do
    if function_exported?(mod, :module_info, 1) do
      behaviours =
        (mod.module_info(:attributes)[:behaviour] || []) ++
          (mod.module_info(:attributes)[:behavior] || [])

      Julep.Extension in behaviours
    else
      false
    end
  rescue
    _ -> false
  end
end
