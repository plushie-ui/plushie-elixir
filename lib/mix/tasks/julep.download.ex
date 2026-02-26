defmodule Mix.Tasks.Julep.Download do
  @moduledoc "Download a precompiled julep_gui binary for the current platform."
  @shortdoc "Download precompiled julep_gui binary"

  use Mix.Task

  @base_url "https://github.com/julep-ui/julep/releases/download"

  @impl true
  def run(args) do
    Mix.Task.run("app.config")

    version = Mix.Project.config()[:version]
    binary_name = Julep.Binary.binary_name()
    url = "#{@base_url}/v#{version}/#{binary_name}"

    dest_dir = Path.join([Mix.Project.app_path(), "priv", "bin"])
    dest_path = Path.join(dest_dir, binary_name)

    if File.exists?(dest_path) and "--force" not in args do
      Mix.shell().info("Binary already exists at #{dest_path}. Use --force to re-download.")
      :ok
    else
      File.mkdir_p!(dest_dir)
      Mix.shell().info("Downloading #{binary_name} from #{url}...")

      case download(url, dest_path) do
        :ok ->
          File.chmod!(dest_path, 0o755)
          Mix.shell().info("Downloaded to #{dest_path}")

          # Verify checksum if available
          checksum_url = url <> ".sha256"
          verify_checksum(dest_path, checksum_url)

        {:error, reason} ->
          Mix.shell().error("Download failed: #{inspect(reason)}")
          Mix.shell().info("Falling back to source build...")
          Mix.Task.run("julep.build", args)
      end
    end
  end

  defp download(url, dest_path) do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    headers = [
      {~c"user-agent", ~c"julep-mix-task"}
    ]

    case :httpc.request(:get, {String.to_charlist(url), headers}, [
           {:ssl, ssl_opts()}
         ], body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        File.write!(dest_path, body)
        :ok

      {:ok, {{_, status, _}, _, _}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp ssl_opts do
    if Code.ensure_loaded?(:public_key) and
         function_exported?(:public_key, :cacerts_get, 0) do
      [
        verify: :verify_peer,
        cacerts: apply(:public_key, :cacerts_get, []),
        depth: 3,
        customize_hostname_check: [
          match_fun: apply(:public_key, :pkix_verify_hostname_match_fun, [:https])
        ]
      ]
    else
      [verify: :verify_none]
    end
  end

  defp verify_checksum(dest_path, checksum_url) do
    case download_text(checksum_url) do
      {:ok, expected_hash} ->
        actual_hash =
          :crypto.hash(:sha256, File.read!(dest_path)) |> Base.encode16(case: :lower)

        expected = String.trim(expected_hash) |> String.split(" ") |> hd()

        if actual_hash == expected do
          Mix.shell().info("Checksum verified.")
        else
          Mix.shell().error("Checksum mismatch! Expected #{expected}, got #{actual_hash}")
          File.rm!(dest_path)
          Mix.raise("Checksum verification failed")
        end

      {:error, _} ->
        Mix.shell().info("No checksum file found; skipping verification.")
    end
  end

  defp download_text(url) do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    case :httpc.request(:get, {String.to_charlist(url), []}, [
           {:ssl, ssl_opts()}
         ], body_format: :binary) do
      {:ok, {{_, 200, _}, _, body}} -> {:ok, to_string(body)}
      _ -> {:error, :not_found}
    end
  end
end
