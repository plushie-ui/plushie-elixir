defmodule Mix.Tasks.Plushie.DownloadTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Plushie.Download

  describe "release_url/1" do
    test "uses the configured release base URL" do
      previous = System.get_env("PLUSHIE_RELEASE_BASE_URL")

      try do
        System.put_env("PLUSHIE_RELEASE_BASE_URL", "file:///tmp/plushie-releases/")

        assert Download.release_url("plushie-renderer-linux-x86_64") ==
                 "file:///tmp/plushie-releases/v#{Plushie.Binary.plushie_rust_version()}/plushie-renderer-linux-x86_64"
      after
        if previous do
          System.put_env("PLUSHIE_RELEASE_BASE_URL", previous)
        else
          System.delete_env("PLUSHIE_RELEASE_BASE_URL")
        end
      end
    end
  end

  describe "format_download_error_reason/1" do
    test "formats HTTP status errors" do
      assert Download.format_download_error_reason({:http_status, 404}) ==
               "server returned HTTP 404"
    end

    test "formats redirect errors" do
      assert Download.format_download_error_reason(:too_many_redirects) ==
               "too many redirects while following the download URL"

      assert Download.format_download_error_reason({:redirect_without_location, 302}) ==
               "server returned HTTP 302 redirect without a Location header"
    end

    test "formats file URL errors" do
      assert Download.format_download_error_reason({:file_read, "/tmp/missing", :enoent}) ==
               "could not read file URL /tmp/missing: no such file or directory"

      assert Download.format_download_error_reason({:unsupported_file_url, "file://host/path"}) ==
               "unsupported file URL: file://host/path"
    end

    test "formats common transport errors" do
      assert Download.format_download_error_reason(:nxdomain) ==
               "download host could not be resolved"

      assert Download.format_download_error_reason(:timeout) ==
               "network request timed out"

      assert Download.format_download_error_reason(:econnrefused) ==
               "connection was refused by the download host"

      assert Download.format_download_error_reason(:closed) ==
               "connection closed before the download finished"
    end

    test "finds common transport errors inside failed connection details" do
      reason =
        {:failed_connect,
         [
           {:to_address, {~c"example.com", 443}},
           {:inet, [:inet], :nxdomain}
         ]}

      assert Download.format_download_error_reason(reason) ==
               "download host could not be resolved"
    end

    test "formats TLS failures inside failed connection details" do
      reason =
        {:failed_connect,
         [
           {:to_address, {~c"example.com", 443}},
           {:inet, [:inet], {:tls_alert, {:bad_certificate, ~c"selfsigned_peer"}}}
         ]}

      assert Download.format_download_error_reason(reason) ==
               "TLS handshake failed: {:bad_certificate, ~c\"selfsigned_peer\"}"
    end

    test "keeps unknown errors readable" do
      assert Download.format_download_error_reason({:tls_alert, :unknown_ca}) ==
               "unexpected download error: {:tls_alert, :unknown_ca}"
    end
  end
end
