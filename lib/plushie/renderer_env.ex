defmodule Plushie.RendererEnv do
  @moduledoc """
  Builds a safe, whitelisted environment for the renderer binary.

  The renderer is spawned as a child process via `Port.open/2`. Erlang ports
  inherit the parent's full environment by default, which can leak sensitive
  variables (API keys, database credentials, tokens) to the renderer.

  This module builds an explicit environment from a whitelist. Variables not
  on the whitelist are actively unset (set to `false` in Erlang port terms)
  so the child process receives only what it needs.

  ## Usage

      env = Plushie.RendererEnv.build(rust_log: "plushie=error")
      Port.open({:spawn_executable, path}, [{:env, env} | other_opts])

  ## How it works

  Erlang's `{:env, list}` option _extends_ the parent environment rather
  than replacing it. To enforce a whitelist, `build/1` emits `{name, false}`
  entries for every parent variable that is NOT whitelisted. This causes
  Erlang to unset those variables in the child process.

  ## Whitelist

  The whitelist covers:

    * **Display** -- `DISPLAY`, `WAYLAND_DISPLAY`, `WAYLAND_SOCKET`,
      `WINIT_UNIX_BACKEND`, `XDG_RUNTIME_DIR`
    * **Rendering** -- `WGPU_BACKEND`, `MESA_*`, `LIBGL_*`, `__GLX_*`,
      `VK_*`, `GALLIUM_*`
    * **Library loading** -- `PATH`, `LD_LIBRARY_PATH`, `DYLD_LIBRARY_PATH`,
      `DYLD_FALLBACK_LIBRARY_PATH`
    * **Locale** -- `LANG`, `LANGUAGE`, `LC_*`
    * **Accessibility** -- `DBUS_SESSION_BUS_ADDRESS`, `AT_SPI_*`,
      `GTK_MODULES`, `NO_AT_BRIDGE`
    * **Font** -- `FONTCONFIG_*`, `XDG_DATA_DIRS`, `XDG_DATA_HOME`
    * **Renderer** -- `RUST_LOG`, `RUST_BACKTRACE`
    * **Home** -- `HOME`, `USER`
  """

  @typedoc "A single entry for the `:env` option of `Port.open/2`."
  @type env_entry :: {charlist(), charlist()} | {charlist(), false}

  # Exact variable names to forward.
  @exact_names MapSet.new(~w[
    DISPLAY
    WAYLAND_DISPLAY
    WAYLAND_SOCKET
    WINIT_UNIX_BACKEND
    XDG_RUNTIME_DIR
    XDG_DATA_DIRS
    XDG_DATA_HOME
    PATH
    LD_LIBRARY_PATH
    DYLD_LIBRARY_PATH
    DYLD_FALLBACK_LIBRARY_PATH
    LANG
    LANGUAGE
    DBUS_SESSION_BUS_ADDRESS
    GTK_MODULES
    NO_AT_BRIDGE
    WGPU_BACKEND
    RUST_LOG
    RUST_BACKTRACE
    HOME
    USER
  ])

  # Prefixes -- any variable starting with one of these is forwarded.
  @prefixes ~w[
    LC_
    MESA_
    LIBGL_
    __GLX_
    VK_
    GALLIUM_
    AT_SPI_
    FONTCONFIG_
  ]

  @doc """
  Builds a whitelisted environment for the renderer Port.

  Returns a list of `{charlist_name, charlist_value | false}` tuples suitable
  for the `:env` option of `Port.open/2`. Non-whitelisted variables from the
  parent environment are explicitly unset (`false`).

  ## Options

    * `:rust_log` -- sets `RUST_LOG`. When provided, overrides any inherited
      value. When `nil`, the parent's `RUST_LOG` is forwarded if present.
    * `:extra` -- additional `{charlist_name, charlist_value | false}` pairs
      to merge (e.g. for tests that need to unset specific variables).
  """
  @spec build(keyword()) :: [env_entry()]
  def build(opts \\ []) do
    parent_env = System.get_env()

    # Partition parent env into whitelisted (keep) and non-whitelisted (unset).
    {keep, unset} =
      Enum.split_with(parent_env, fn {name, _value} -> whitelisted?(name) end)

    base =
      Enum.map(keep, fn {name, value} ->
        {String.to_charlist(name), String.to_charlist(value)}
      end)

    # Unset all non-whitelisted variables so they don't leak to the child.
    unset_entries =
      Enum.map(unset, fn {name, _value} ->
        {String.to_charlist(name), false}
      end)

    env = base ++ unset_entries

    # Apply :rust_log override (takes precedence over inherited RUST_LOG).
    env =
      case Keyword.get(opts, :rust_log) do
        nil ->
          env

        level ->
          env
          |> Enum.reject(fn {name, _} -> name == ~c"RUST_LOG" end)
          |> Kernel.++([{~c"RUST_LOG", String.to_charlist(level)}])
      end

    # Apply :extra overrides last.
    case Keyword.get(opts, :extra, []) do
      [] ->
        env

      extra ->
        extra_names = MapSet.new(extra, fn {name, _} -> name end)

        env
        |> Enum.reject(fn {name, _} -> MapSet.member?(extra_names, name) end)
        |> Kernel.++(extra)
    end
  end

  @doc """
  Returns `true` if `name` is on the whitelist.
  """
  @spec whitelisted?(String.t()) :: boolean()
  def whitelisted?(name) do
    MapSet.member?(@exact_names, name) or
      Enum.any?(@prefixes, &String.starts_with?(name, &1))
  end
end
