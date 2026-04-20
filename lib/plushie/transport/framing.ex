defmodule Plushie.Transport.Framing do
  @moduledoc """
  Frame encoding and decoding for the plushie wire protocol.

  Transports that deliver raw byte streams (SSH channels, raw sockets)
  need to frame protocol messages. This module provides the framing
  logic for both MessagePack (4-byte length prefix) and JSON (newline
  delimiter) modes.

  Transports with built-in framing (e.g., `:gen_tcp` with `{:packet, 4}`,
  Erlang Ports with `{:packet, 4}`) don't need this module.

  ## MessagePack framing

  Each message is prefixed with a 4-byte big-endian unsigned integer
  indicating the payload size:

      <<size::32-big, payload::binary-size(size)>>

  ## JSON framing

  Each message is terminated by a newline character (`\\n`). Messages
  must not contain embedded newlines.

  ## Size cap

  Both framings reject messages larger than
  `#{__MODULE__}.max_message_size/0` (64 MiB) by raising
  `Plushie.Transport.BufferOverflowError`. Oversized frames are a
  protocol violation: silently dropping them risks desync, and the
  payload cannot legitimately exceed the cap.
  """

  @max_message_size 64 * 1024 * 1024

  @doc """
  The per-message size cap in bytes.

  Matches the renderer's cap so both ends reject the same threshold.
  """
  @spec max_message_size() :: pos_integer()
  def max_message_size, do: @max_message_size

  @doc """
  Encode a protocol message with a 4-byte length prefix (MessagePack mode).

  Returns iodata that can be written to the transport.

  Raises `Plushie.Transport.BufferOverflowError` when the payload
  exceeds the 64 MiB cap.
  """
  @spec encode_packet(data :: iodata()) :: iodata()
  def encode_packet(data) do
    size = IO.iodata_length(data)

    if size > @max_message_size do
      raise Plushie.Transport.BufferOverflowError,
        size: size,
        limit: @max_message_size
    end

    [<<size::32-big>>, data]
  end

  @doc """
  Decode complete frames from accumulated bytes (MessagePack mode).

  Returns `{complete_messages, remaining_buffer}` where
  `complete_messages` is a list of binaries (each a complete protocol
  message) and `remaining_buffer` is leftover bytes waiting for more
  data.

  Raises `Plushie.Transport.BufferOverflowError` when a length prefix
  declares a frame larger than the 64 MiB cap.

  ## Examples

      iex> data = <<0, 0, 0, 3, "abc", 0, 0, 0, 2, "de">>
      iex> {messages, _buffer} = Plushie.Transport.Framing.decode_packets(data)
      iex> messages
      ["abc", "de"]

      iex> partial = <<0, 0, 0, 5, "he">>
      iex> {messages, buffer} = Plushie.Transport.Framing.decode_packets(partial)
      iex> {messages, buffer}
      {[], <<0, 0, 0, 5, "he">>}
  """
  @spec decode_packets(buffer :: binary()) :: {[binary()], binary()}
  def decode_packets(buffer) do
    decode_packet_loop(buffer, [])
  end

  defp decode_packet_loop(<<size::32-big, _rest::binary>>, _acc)
       when size > @max_message_size do
    raise Plushie.Transport.BufferOverflowError,
      size: size,
      limit: @max_message_size
  end

  defp decode_packet_loop(<<size::32-big, rest::binary>>, acc)
       when byte_size(rest) >= size do
    <<frame::binary-size(size), remaining::binary>> = rest
    decode_packet_loop(remaining, [frame | acc])
  end

  defp decode_packet_loop(buffer, acc) do
    {Enum.reverse(acc), buffer}
  end

  @doc """
  Encode a protocol message with a newline terminator (JSON mode).

  Raises `Plushie.Transport.BufferOverflowError` when the encoded
  line exceeds the 64 MiB cap.
  """
  @spec encode_line(data :: iodata()) :: iodata()
  def encode_line(data) do
    size = IO.iodata_length(data)

    if size > @max_message_size do
      raise Plushie.Transport.BufferOverflowError,
        size: size,
        limit: @max_message_size
    end

    [data, "\n"]
  end

  @doc """
  Decode complete lines from accumulated bytes (JSON mode).

  Returns `{complete_lines, remaining_buffer}`.

  Raises `Plushie.Transport.BufferOverflowError` when a completed
  line exceeds the 64 MiB cap, or when the partial tail has already
  grown past the cap without a newline.
  """
  @spec decode_lines(buffer :: binary()) :: {[binary()], binary()}
  def decode_lines(buffer) do
    {lines, remaining} =
      case :binary.split(buffer, "\n", [:global]) do
        [^buffer] ->
          {[], buffer}

        parts ->
          {lines, [remaining]} = Enum.split(parts, length(parts) - 1)
          {lines, remaining}
      end

    Enum.each(lines, fn line ->
      if byte_size(line) > @max_message_size do
        raise Plushie.Transport.BufferOverflowError,
          size: byte_size(line),
          limit: @max_message_size
      end
    end)

    if byte_size(remaining) > @max_message_size do
      raise Plushie.Transport.BufferOverflowError,
        size: byte_size(remaining),
        limit: @max_message_size
    end

    {lines, remaining}
  end
end
