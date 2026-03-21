defmodule Toddy.Transport.Framing do
  @moduledoc """
  Frame encoding and decoding for the toddy wire protocol.

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
  """

  @doc """
  Encode a protocol message with a 4-byte length prefix (MessagePack mode).

  Returns iodata that can be written to the transport.
  """
  @spec encode_packet(data :: iodata()) :: iodata()
  def encode_packet(data) do
    size = IO.iodata_length(data)
    [<<size::32-big>>, data]
  end

  @doc """
  Decode complete frames from accumulated bytes (MessagePack mode).

  Returns `{complete_messages, remaining_buffer}` where
  `complete_messages` is a list of binaries (each a complete protocol
  message) and `remaining_buffer` is leftover bytes waiting for more
  data.

  ## Examples

      iex> data = <<0, 0, 0, 3, "abc", 0, 0, 0, 2, "de">>
      iex> {messages, _buffer} = Toddy.Transport.Framing.decode_packets(data)
      iex> messages
      ["abc", "de"]

      iex> partial = <<0, 0, 0, 5, "he">>
      iex> {messages, buffer} = Toddy.Transport.Framing.decode_packets(partial)
      iex> {messages, buffer}
      {[], <<0, 0, 0, 5, "he">>}
  """
  @spec decode_packets(buffer :: binary()) :: {[binary()], binary()}
  def decode_packets(buffer) do
    decode_packet_loop(buffer, [])
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
  """
  @spec encode_line(data :: iodata()) :: iodata()
  def encode_line(data) do
    [data, "\n"]
  end

  @doc """
  Decode complete lines from accumulated bytes (JSON mode).

  Returns `{complete_lines, remaining_buffer}`.
  """
  @spec decode_lines(buffer :: binary()) :: {[binary()], binary()}
  def decode_lines(buffer) do
    case :binary.split(buffer, "\n", [:global]) do
      [^buffer] ->
        {[], buffer}

      parts ->
        {lines, [remaining]} = Enum.split(parts, length(parts) - 1)
        {lines, remaining}
    end
  end
end
