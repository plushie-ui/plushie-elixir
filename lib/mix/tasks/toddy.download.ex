defmodule Mix.Tasks.Toddy.Download do
  @moduledoc "Download a precompiled toddy binary for the current platform."
  @shortdoc "Download precompiled toddy binary"

  use Mix.Task

  @base_url "https://github.com/toddy-ui/toddy/releases/download"
  @binary_version Mix.Project.config()[:binary_version] ||
                    raise("missing :binary_version in project config (mix.exs)")

  @impl true
  def run(args) do
    Mix.Task.run("app.config")

    name = Toddy.Binary.download_name()
    url = "#{@base_url}/v#{@binary_version}/#{name}"

    dest_dir = Path.join([Mix.Project.app_path(), "priv", "bin"])
    dest_path = Path.join(dest_dir, name)

    if File.exists?(dest_path) and "--force" not in args do
      Mix.shell().info("Binary already exists at #{dest_path}. Use --force to re-download.")
      :ok
    else
      File.mkdir_p!(dest_dir)
      Mix.shell().info("Downloading #{name} from #{url}...")

      case download(url, dest_path) do
        :ok ->
          File.chmod!(dest_path, 0o755)
          Mix.shell().info("Downloaded to #{dest_path}")

          # Verify checksum (mandatory -- fails if checksum file is missing or mismatched)
          checksum_url = url <> ".sha256"
          verify_checksum(dest_path, checksum_url)

        {:error, reason} ->
          Mix.raise("""
          Download failed: #{inspect(reason)}

          To build from source instead:
            mix toddy.build

          To use an existing binary:
            export TODDY_BINARY_PATH=/path/to/toddy
          """)
      end
    end
  end

  defp download(url, dest_path) do
    case download_binary(url) do
      {:ok, body} ->
        File.write!(dest_path, body)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @max_redirects 5

  defp download_binary(url, redirects_left \\ @max_redirects)

  defp download_binary(_url, 0), do: {:error, :too_many_redirects}

  defp download_binary(url, redirects_left) do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    headers = [
      {~c"user-agent", ~c"toddy-mix-task"}
    ]

    case :httpc.request(
           :get,
           {String.to_charlist(url), headers},
           [
             {:ssl, ssl_opts()},
             {:autoredirect, false}
           ],
           body_format: :binary
         ) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        {:ok, body}

      {:ok, {{_, status, _}, resp_headers, _body}} when status in [301, 302, 303, 307, 308] ->
        case List.keyfind(resp_headers, ~c"location", 0) do
          {_, location} ->
            download_binary(to_string(location), redirects_left - 1)

          nil ->
            {:error, {:redirect_without_location, status}}
        end

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

      {:error, reason} ->
        File.rm(dest_path)

        Mix.raise(
          "SHA256 checksum file could not be downloaded (#{inspect(reason)}). " <>
            "Refusing to use unverified binary. URL: #{checksum_url}"
        )
    end
  end

  defp download_text(url) do
    case download_binary(url) do
      {:ok, body} -> {:ok, to_string(body)}
      {:error, reason} -> {:error, reason}
    end
  end
end
