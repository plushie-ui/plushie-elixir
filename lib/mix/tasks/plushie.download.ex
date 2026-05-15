defmodule Mix.Tasks.Plushie.Download do
  @moduledoc """
  Download precompiled plushie artifacts for the current platform.

  ## Usage

      mix plushie.download              # download native binary (default)
      mix plushie.download --wasm       # download WASM renderer only
      mix plushie.download --bin --wasm # download both

  ## Options

  - `--bin` - Download the native binary
  - `--wasm` - Download the WASM renderer
  - `--bin-file PATH` - Override native binary destination
  - `--wasm-dir PATH` - Override WASM output directory
  - `--force` - Re-download even if files already exist

  ## Config

  All options can be set in `config.exs` so commands work without flags:

      config :plushie,
        artifacts: [:bin, :wasm],       # which artifacts to install
        bin_file: "bin/plushie-renderer",       # binary destination
        wasm_dir: "priv/static"         # WASM output directory

  CLI flags override config. Default artifacts: `[:bin]`.
  """
  @shortdoc "Download precompiled plushie binary and/or WASM"

  use Mix.Task

  @base_url "https://github.com/plushie-ui/plushie-rust/releases/download"
  @wasm_archive "plushie-renderer-wasm.tar.gz"

  @switches [
    bin: :boolean,
    wasm: :boolean,
    force: :boolean,
    bin_file: :string,
    wasm_dir: :string
  ]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.config")

    {opts, _rest} = OptionParser.parse!(args, strict: @switches)

    Mix.PlushieHelpers.warn_if_unconfigured()
    check_native_widgets!()

    force? = opts[:force] || false
    {want_bin?, want_wasm?} = Mix.PlushieHelpers.resolve_artifacts(opts)

    if want_bin?, do: download_bin(opts, force?)
    if want_wasm?, do: download_wasm(opts, force?)
  end

  # Refuse to download a precompiled binary when native widgets are
  # detected; the stock binary won't have them registered.
  defp check_native_widgets! do
    Mix.PlushieHelpers.compile_project!()

    native = Plushie.WidgetRegistry.native_widgets()

    if native != [] do
      names = Enum.map_join(native, ", ", &inspect/1)

      Mix.raise("""
      Cannot download a precompiled binary when native widgets are detected.

      Native widgets: #{names}

      These require a custom build that includes the widget crates.
      Use `mix plushie.build` instead.
      """)
    end
  end

  # -- Native binary ----------------------------------------------------------

  defp download_bin(opts, force?) do
    dest_path = Mix.PlushieHelpers.resolve_bin_file(opts)
    default_path = Path.join(Plushie.Binary.download_dir(), Plushie.Binary.download_name())

    if dest_path == default_path do
      sync_renderer_with_tool(force?)
    else
      download_renderer_direct(dest_path, force?)
    end
  end

  defp sync_renderer_with_tool(force?) do
    {tool_path, prefix_args} = resolve_tool(force?)
    args = ["tools", "sync", "--required-version", Plushie.Binary.plushie_rust_version()]
    args = if force?, do: args ++ ["--force"], else: args

    Mix.shell().info("Syncing renderer through #{tool_path}...")

    case System.cmd(tool_path, prefix_args ++ args, stderr_to_stdout: true) do
      {output, 0} ->
        if output != "", do: Mix.shell().info(String.trim_trailing(output))

        Mix.shell().info(
          "Installed native binary to #{Path.join(Plushie.Binary.download_dir(), Plushie.Binary.download_name())}"
        )

      {output, status} ->
        Mix.raise("""
        Renderer sync failed with status #{status}:
        #{output}
        """)
    end
  end

  defp resolve_tool(force?) do
    case Mix.PlushieHelpers.source_path() do
      nil ->
        {download_tool(force?), []}

      source_path ->
        manifest = Path.join(source_path, "Cargo.toml")

        unless File.exists?(manifest) do
          Mix.raise(
            "PLUSHIE_RUST_SOURCE_PATH points to #{inspect(source_path)} but no Cargo.toml at #{manifest}"
          )
        end

        {"cargo",
         [
           "run",
           "--manifest-path",
           manifest,
           "-p",
           "cargo-plushie",
           "--bin",
           "plushie",
           "--release",
           "--quiet",
           "--"
         ]}
    end
  end

  defp download_tool(force?) do
    name = Plushie.Binary.tool_release_name()
    url = release_url(name)
    dest_path = Path.join(Plushie.Binary.download_dir(), Plushie.Binary.tool_name())

    if File.exists?(dest_path) and not force? do
      dest_path
    else
      File.mkdir_p!(Path.dirname(dest_path))
      Mix.shell().info("Downloading #{name}...")

      case download_to_file(url, dest_path) do
        :ok ->
          File.chmod!(dest_path, 0o755)
          verify_checksum!(dest_path, url <> ".sha256", "mix plushie.download --force")
          Mix.shell().info("Installed plushie tool to #{dest_path}")
          dest_path

        {:error, reason} ->
          error = format_download_error_reason(reason)

          Mix.raise("""
          Plushie tool download failed: #{error}

          To build from source instead:
            mix plushie.build
          """)
      end
    end
  end

  defp download_renderer_direct(dest_path, force?) do
    name = Plushie.Binary.release_name()
    url = release_url(name)

    if File.exists?(dest_path) and not force? do
      Mix.shell().info("Binary already exists at #{dest_path}. Use --force to re-download.")
    else
      File.mkdir_p!(Path.dirname(dest_path))
      Mix.shell().info("Downloading #{name}...")

      case download_to_file(url, dest_path) do
        :ok ->
          File.chmod!(dest_path, 0o755)
          verify_checksum!(dest_path, url <> ".sha256", "mix plushie.build")
          Mix.shell().info("Installed native binary to #{dest_path}")

        {:error, reason} ->
          error = format_download_error_reason(reason)

          Mix.raise("""
          Download failed: #{error}

          To build from source instead:
            mix plushie.build

          To use an existing binary:
            export PLUSHIE_BINARY_PATH=/path/to/plushie
          """)
      end
    end
  end

  # -- WASM -------------------------------------------------------------------

  defp download_wasm(opts, force?) do
    url = release_url(@wasm_archive)
    extract_dir = Mix.PlushieHelpers.resolve_wasm_dir(opts)
    tarball_path = Path.join(extract_dir, @wasm_archive)

    js_path = Path.join(extract_dir, "plushie_renderer_wasm.js")
    wasm_path = Path.join(extract_dir, "plushie_renderer_wasm_bg.wasm")

    if File.exists?(js_path) and File.exists?(wasm_path) and not force? do
      Mix.shell().info("WASM files already exist in #{extract_dir}. Use --force to re-download.")
    else
      File.mkdir_p!(extract_dir)
      Mix.shell().info("Downloading #{@wasm_archive}...")

      case download_to_file(url, tarball_path) do
        :ok ->
          verify_checksum!(tarball_path, url <> ".sha256", "mix plushie.build --wasm")
          extract_tarball!(tarball_path, extract_dir)
          File.rm(tarball_path)
          Mix.shell().info("Installed WASM files to #{extract_dir}")

        {:error, reason} ->
          error = format_download_error_reason(reason)

          Mix.raise("""
          WASM download failed: #{error}

          To build from source instead:
            mix plushie.build --wasm
          """)
      end
    end
  end

  defp extract_tarball!(tarball, dest_dir) do
    case :erl_tar.extract(String.to_charlist(tarball), [
           :compressed,
           {:cwd, String.to_charlist(dest_dir)},
           {:safe_relative_path, true}
         ]) do
      :ok ->
        :ok

      {:error, reason} ->
        File.rm(tarball)
        Mix.raise("Failed to extract #{tarball}: #{inspect(reason)}")
    end
  end

  # -- Shared helpers ---------------------------------------------------------

  defp release_url(artifact) do
    "#{@base_url}/v#{Plushie.Binary.plushie_rust_version()}/#{artifact}"
  end

  defp download_to_file(url, dest_path) do
    case fetch(url) do
      {:ok, body} ->
        File.write!(dest_path, body)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  @spec format_download_error_reason(reason :: term()) :: String.t()
  def format_download_error_reason({:http_status, status}) do
    "server returned HTTP #{status}"
  end

  def format_download_error_reason(:too_many_redirects) do
    "too many redirects while following the download URL"
  end

  def format_download_error_reason({:redirect_without_location, status}) do
    "server returned HTTP #{status} redirect without a Location header"
  end

  def format_download_error_reason(reason)
      when reason in [:nxdomain, :timeout, :econnrefused, :closed] do
    format_transport_reason(reason)
  end

  def format_download_error_reason({:failed_connect, details}) do
    case find_transport_reason(details) do
      nil -> "could not connect to the download host: #{format_nested_reason(details)}"
      reason -> format_transport_reason(reason)
    end
  end

  def format_download_error_reason({:failed_connect, _details, reason}) do
    format_download_error_reason(reason)
  end

  def format_download_error_reason(reason) do
    "unexpected download error: #{inspect(reason)}"
  end

  @max_redirects 5

  defp fetch(url, redirects_left \\ @max_redirects)

  defp fetch(_url, 0), do: {:error, :too_many_redirects}

  defp fetch(url, redirects_left) do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    headers = [{~c"user-agent", ~c"plushie-mix-task"}]

    case :httpc.request(
           :get,
           {String.to_charlist(url), headers},
           [{:ssl, ssl_opts()}, {:autoredirect, false}],
           body_format: :binary
         ) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        {:ok, body}

      {:ok, {{_, status, _}, resp_headers, _body}} when status in [301, 302, 303, 307, 308] ->
        case List.keyfind(resp_headers, ~c"location", 0) do
          {_, location} -> fetch(to_string(location), redirects_left - 1)
          nil -> {:error, {:redirect_without_location, status}}
        end

      {:ok, {{_, status, _}, _, _}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp ssl_opts do
    unless Code.ensure_loaded?(:public_key) and
             function_exported?(:public_key, :cacerts_get, 0) do
      Mix.raise("""
      TLS certificate verification requires :public_key with cacerts_get/0.

      This is available on OTP 25+. Check your Erlang/OTP installation.
      """)
    end

    [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      depth: 3,
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]
  end

  defp verify_checksum!(file_path, checksum_url, build_command) do
    case fetch(checksum_url) do
      {:ok, body} ->
        expected = body |> to_string() |> String.trim() |> String.split(" ") |> hd()

        actual =
          :crypto.hash(:sha256, File.read!(file_path)) |> Base.encode16(case: :lower)

        if actual == expected do
          Mix.shell().info("Checksum verified.")
        else
          Mix.shell().error("Checksum mismatch! Expected #{expected}, got #{actual}")
          File.rm!(file_path)
          Mix.raise("Checksum verification failed")
        end

      {:error, reason} ->
        File.rm(file_path)
        error = format_download_error_reason(reason)

        Mix.raise("""
        SHA256 checksum file could not be downloaded: #{error}

        Refusing to use unverified artifact.
        URL: #{checksum_url}

        To build from source instead:
          #{build_command}
        """)
    end
  end

  defp format_transport_reason(:nxdomain), do: "download host could not be resolved"
  defp format_transport_reason(:timeout), do: "network request timed out"
  defp format_transport_reason(:econnrefused), do: "connection was refused by the download host"
  defp format_transport_reason(:closed), do: "connection closed before the download finished"

  defp format_transport_reason({:tls_alert, details}) do
    "TLS handshake failed: #{inspect(details)}"
  end

  defp format_transport_reason(reason) do
    "network request failed: #{inspect(reason)}"
  end

  defp find_transport_reason(reason)
       when reason in [:nxdomain, :timeout, :econnrefused, :closed] do
    reason
  end

  defp find_transport_reason({:tls_alert, _details} = reason), do: reason

  defp find_transport_reason(tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> find_transport_reason()
  end

  defp find_transport_reason(list) when is_list(list) do
    Enum.find_value(list, &find_transport_reason/1)
  end

  defp find_transport_reason(_reason), do: nil

  defp format_nested_reason([_ | _] = list) do
    list
    |> Enum.reject(fn
      {:to_address, _address} -> true
      _other -> false
    end)
    |> case do
      [] -> "no detailed reason was provided"
      remaining -> inspect(remaining)
    end
  end

  defp format_nested_reason(reason), do: inspect(reason)
end
