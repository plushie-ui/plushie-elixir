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
        bin_file: "priv/bin/plushie-renderer",  # binary destination
        wasm_dir: "priv/static"         # WASM output directory

  CLI flags override config. Default artifacts: `[:bin]`.
  """
  @shortdoc "Download precompiled plushie binary and/or WASM"

  use Mix.Task

  @base_url "https://github.com/plushie-ui/plushie-renderer/releases/download"
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
    Mix.Task.run("compile", [])

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
    name = Plushie.Binary.download_name()
    url = release_url(name)
    dest_path = Mix.PlushieHelpers.resolve_bin_file(opts)

    if File.exists?(dest_path) and not force? do
      Mix.shell().info("Binary already exists at #{dest_path}. Use --force to re-download.")
    else
      File.mkdir_p!(Path.dirname(dest_path))
      Mix.shell().info("Downloading #{name}...")

      case download_to_file(url, dest_path) do
        :ok ->
          File.chmod!(dest_path, 0o755)
          verify_checksum!(dest_path, url <> ".sha256")
          create_symlink(dest_path)
          Mix.shell().info("Installed native binary to #{dest_path}")

        {:error, reason} ->
          Mix.raise("""
          Download failed: #{inspect(reason)}

          To build from source instead:
            mix plushie.build

          To use an existing binary:
            export PLUSHIE_BINARY_PATH=/path/to/plushie
          """)
      end
    end
  end

  # Create a bin/plushie-renderer symlink so scripts can reference a
  # stable path without the platform-specific name.
  defp create_symlink(dest_path) do
    link_dir = "bin"
    link_path = Path.join(link_dir, "plushie-renderer")
    target = Path.relative_to(Path.expand(dest_path), Path.expand(link_dir))

    File.mkdir_p!(link_dir)
    File.rm(link_path)

    case File.ln_s(target, link_path) do
      :ok ->
        Mix.shell().info("Symlinked bin/plushie-renderer -> #{target}")

      {:error, reason} ->
        Mix.shell().info("Could not create symlink bin/plushie-renderer: #{inspect(reason)}")
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
          verify_checksum!(tarball_path, url <> ".sha256")
          extract_tarball!(tarball_path, extract_dir)
          File.rm(tarball_path)
          Mix.shell().info("Installed WASM files to #{extract_dir}")

        {:error, reason} ->
          Mix.raise("""
          WASM download failed: #{inspect(reason)}

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
      cacerts: apply(:public_key, :cacerts_get, []),
      depth: 3,
      customize_hostname_check: [
        match_fun: apply(:public_key, :pkix_verify_hostname_match_fun, [:https])
      ]
    ]
  end

  defp verify_checksum!(file_path, checksum_url) do
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

        Mix.raise(
          "SHA256 checksum file could not be downloaded (#{inspect(reason)}). " <>
            "Refusing to use unverified artifact. URL: #{checksum_url}"
        )
    end
  end
end
