defmodule Plushie.Automation.Screenshot do
  @moduledoc """
  Pixel screenshot for automation and renderer inspection.

  Captures pixel-level rendering data for visual regression testing.
  The `:windowed` backend uses GPU rendering via iced/wgpu and captures real
  RGBA pixel data through `iced::window::screenshot()`. The `:headless`
  backend uses tiny-skia software rendering to produce real RGBA pixel data
  without a display server. The wire protocol uses native msgpack binary
  for pixel data (no base64 overhead) or base64 for JSON mode. The `:mock`
  backend returns empty stubs (hash `""`, no pixel data) because mock
  mode has no real renderer.

  Note that headless screenshots use software rendering (tiny-skia), so
  pixels will not match GPU-rendered output (`:windowed` backend) exactly.
  Use headless screenshots for catching layout regressions and verifying
  rendering pipeline correctness; use full screenshots for pixel-perfect
  visual regression against GPU output.

  `save_png/2` writes raw RGBA data as a minimal valid PNG file using
  pure Elixir (`:zlib` for deflate, `:erlang.crc32` for chunk CRCs).
  """

  @type t :: %__MODULE__{
          name: String.t(),
          hash: String.t(),
          size: {non_neg_integer(), non_neg_integer()},
          rgba_data: binary() | nil,
          backend: Plushie.Automation.backend_mode() | nil
        }

  defstruct [:name, :hash, :size, :rgba_data, :backend]

  @doc "Builds a screenshot from a renderer `screenshot_response` message."
  @spec from_response(
          msg :: map(),
          format :: Plushie.Protocol.format(),
          backend :: Plushie.Automation.backend_mode() | nil
        ) :: t()
  def from_response(msg, format \\ :msgpack, backend \\ nil)

  def from_response(
        %{
          "type" => "screenshot_response",
          "name" => name,
          "hash" => hash,
          "width" => width,
          "height" => height
        } = msg,
        format,
        backend
      )
      when is_binary(name) and is_binary(hash) and is_integer(width) and is_integer(height) do
    rgba =
      case Map.get(msg, "rgba") do
        nil -> nil
        data when is_binary(data) and format == :msgpack -> data
        data when is_binary(data) and format == :json -> Base.decode64!(data)
        other -> raise ArgumentError, "invalid screenshot rgba field: #{inspect(other)}"
      end

    %__MODULE__{name: name, hash: hash, size: {width, height}, rgba_data: rgba, backend: backend}
  end

  def from_response(msg, _format, _backend) do
    raise ArgumentError, "invalid screenshot_response: #{inspect(msg)}"
  end

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
end
