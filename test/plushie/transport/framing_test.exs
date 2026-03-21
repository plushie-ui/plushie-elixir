defmodule Plushie.Transport.FramingTest do
  use ExUnit.Case, async: true

  alias Plushie.Transport.Framing

  describe "encode_packet/1" do
    test "prefixes data with 4-byte big-endian length" do
      encoded = IO.iodata_to_binary(Framing.encode_packet("hello"))
      assert <<0, 0, 0, 5, "hello">> = encoded
    end

    test "handles empty data" do
      encoded = IO.iodata_to_binary(Framing.encode_packet(""))
      assert <<0, 0, 0, 0>> = encoded
    end

    test "accepts iodata" do
      encoded = IO.iodata_to_binary(Framing.encode_packet(["he", "llo"]))
      assert <<0, 0, 0, 5, "hello">> = encoded
    end
  end

  describe "decode_packets/1" do
    test "decodes a single complete frame" do
      buffer = <<0, 0, 0, 3, "abc">>
      assert {["abc"], ""} = Framing.decode_packets(buffer)
    end

    test "decodes multiple complete frames" do
      buffer = <<0, 0, 0, 3, "abc", 0, 0, 0, 2, "de">>
      assert {["abc", "de"], ""} = Framing.decode_packets(buffer)
    end

    test "returns partial frame as remaining buffer" do
      partial = <<0, 0, 0, 5, "he">>
      assert {[], ^partial} = Framing.decode_packets(partial)
    end

    test "handles empty buffer" do
      assert {[], ""} = Framing.decode_packets("")
    end

    test "handles complete frames followed by partial" do
      buffer = <<0, 0, 0, 2, "ok", 0, 0, 0, 10, "par">>
      {messages, remaining} = Framing.decode_packets(buffer)
      assert messages == ["ok"]
      assert remaining == <<0, 0, 0, 10, "par">>
    end

    test "handles incomplete length prefix" do
      buffer = <<0, 0>>
      assert {[], ^buffer} = Framing.decode_packets(buffer)
    end
  end

  describe "encode_line/1" do
    test "appends newline" do
      encoded = IO.iodata_to_binary(Framing.encode_line("hello"))
      assert encoded == "hello\n"
    end

    test "accepts iodata" do
      encoded = IO.iodata_to_binary(Framing.encode_line(["he", "llo"]))
      assert encoded == "hello\n"
    end
  end

  describe "decode_lines/1" do
    test "decodes complete lines" do
      buffer = "line1\nline2\n"
      assert {["line1", "line2"], ""} = Framing.decode_lines(buffer)
    end

    test "returns partial line as remaining buffer" do
      buffer = "line1\npartial"
      assert {["line1"], "partial"} = Framing.decode_lines(buffer)
    end

    test "handles buffer with no newlines" do
      buffer = "incomplete"
      assert {[], "incomplete"} = Framing.decode_lines(buffer)
    end

    test "handles empty buffer" do
      assert {[], ""} = Framing.decode_lines("")
    end

    test "handles multiple consecutive newlines" do
      buffer = "a\n\nb\n"
      assert {["a", "", "b"], ""} = Framing.decode_lines(buffer)
    end
  end

  describe "round-trip" do
    test "encode_packet then decode_packets recovers original data" do
      messages = ["hello", "world", "test"]

      encoded =
        messages
        |> Enum.map(&Framing.encode_packet/1)
        |> IO.iodata_to_binary()

      assert {^messages, ""} = Framing.decode_packets(encoded)
    end

    test "encode_line then decode_lines recovers original data" do
      messages = ["hello", "world", "test"]

      encoded =
        messages
        |> Enum.map(&Framing.encode_line/1)
        |> IO.iodata_to_binary()

      assert {^messages, ""} = Framing.decode_lines(encoded)
    end
  end
end
