defmodule Plushie.Test.Screenshot do
  @moduledoc """
  Pixel screenshot for visual regression testing.

  Captures pixel-level rendering data for visual regression testing.
  The `:windowed` backend uses GPU rendering via iced/wgpu and captures real
  RGBA pixel data through `iced::window::screenshot()`. The `:headless`
  backend uses tiny-skia software rendering to produce real RGBA pixel data
  without a display server. The wire protocol uses native msgpack binary
  for pixel data (no base64 overhead) or base64 for JSON mode. The `:pooled_mock`
  backend returns empty stubs (hash `""`, no pixel data) because it has
  no renderer.

  Note that headless screenshots use software rendering (tiny-skia), so
  pixels will not match GPU-rendered output (`:windowed` backend) exactly.
  Use headless screenshots for catching layout regressions and verifying
  rendering pipeline correctness; use full screenshots for pixel-perfect
  visual regression against GPU output.

  `assert_match/2` silently accepts empty hashes, so tests using
  `assert_screenshot` work on all backends without conditional logic --
  the assertion simply skips on mock.

  `save_png/2` writes raw RGBA data as a minimal valid PNG file using
  pure Elixir (`:zlib` for deflate, `:erlang.crc32` for chunk CRCs).

  ## Golden file workflow

  On first run, creates a `.sha256` file in `test/screenshots/`. On subsequent
  runs, compares the current hash against the stored one. Set
  `PLUSHIE_UPDATE_SCREENSHOTS=1` to force-update golden files.

  Screenshots with an empty hash (from mock backend) are silently accepted --
  no golden file is created or compared.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          hash: String.t(),
          size: {non_neg_integer(), non_neg_integer()},
          rgba_data: binary() | nil
        }

  defstruct [:name, :hash, :size, :rgba_data]

  @doc """
  Save the screenshot as a PNG file.

  Writes a minimal but valid PNG with 8-bit RGBA color. Returns `:ok`.
  No-op when `rgba_data` is nil (mock backend stubs).
  """
  @spec save_png(screenshot :: t(), path :: String.t()) :: :ok
  def save_png(%__MODULE__{rgba_data: nil}, _path), do: :ok
  def save_png(%__MODULE__{size: {0, _}}, _path), do: :ok
  def save_png(%__MODULE__{size: {_, 0}}, _path), do: :ok

  def save_png(%__MODULE__{rgba_data: data, size: {w, h}}, path) do
    # PNG signature
    signature = <<137, 80, 78, 71, 13, 10, 26, 10>>

    # IHDR: width, height, bit_depth=8, color_type=6 (RGBA),
    # compression=0, filter=0, interlace=0
    ihdr_data = <<w::32, h::32, 8, 6, 0, 0, 0>>
    ihdr = png_chunk("IHDR", ihdr_data)

    # IDAT: filter byte 0 (none) prepended to each row, then zlib compressed
    row_size = w * 4

    filtered =
      for row <- 0..(h - 1), into: <<>> do
        row_data = binary_part(data, row * row_size, row_size)
        <<0, row_data::binary>>
      end

    compressed = :zlib.compress(filtered)
    idat = png_chunk("IDAT", compressed)

    # IEND
    iend = png_chunk("IEND", <<>>)

    File.write!(path, signature <> ihdr <> idat <> iend)
    :ok
  end

  defp png_chunk(type, data) do
    crc = :erlang.crc32(<<type::binary, data::binary>>)
    <<byte_size(data)::32, type::binary, data::binary, crc::32>>
  end

  @doc """
  Asserts that a screenshot matches its golden file.

  Screenshots with an empty hash (from mock backend) are silently accepted.
  Otherwise, creates or compares golden files in `golden_dir`.
  Set `PLUSHIE_UPDATE_SCREENSHOTS=1` to force-update golden files.
  """
  @spec assert_match(screenshot :: t(), golden_dir :: String.t()) :: :ok
  def assert_match(%__MODULE__{hash: ""}, _golden_dir), do: :ok

  def assert_match(%__MODULE__{} = screenshot, golden_dir) do
    File.mkdir_p!(golden_dir)
    golden_path = Path.join(golden_dir, "#{screenshot.name}.sha256")

    cond do
      System.get_env("PLUSHIE_UPDATE_SCREENSHOTS") == "1" ->
        File.write!(golden_path, screenshot.hash)
        :ok

      not File.exists?(golden_path) ->
        File.write!(golden_path, screenshot.hash)
        :ok

      true ->
        expected = String.trim(File.read!(golden_path))

        if expected == screenshot.hash do
          :ok
        else
          raise ExUnit.AssertionError,
            message: """
            Screenshot mismatch for "#{screenshot.name}".

            Expected hash: #{expected}
            Actual hash:   #{screenshot.hash}

            Run with PLUSHIE_UPDATE_SCREENSHOTS=1 to update the golden file.
            Golden file: #{golden_path}
            """
        end
    end
  end
end
