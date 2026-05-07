defmodule Plushie.CommandImageTest do
  use ExUnit.Case, async: true

  alias Plushie.Command
  alias Plushie.Protocol

  describe "create_image/2 (encoded PNG/JPEG bytes)" do
    test "returns a command struct with image_op type" do
      png_data = <<137, 80, 78, 71>>
      cmd = Command.create_image("logo", png_data)

      assert %Command{type: :image_op} = cmd
      assert cmd.payload.op == "create_image"
      assert cmd.payload.handle == "logo"
      assert cmd.payload.data == png_data
    end
  end

  describe "create_image_rgba/4 (raw RGBA pixels)" do
    test "returns a command struct with dimensions and pixel data" do
      # 2x2 red RGBA pixels
      pixels = <<255, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255>>
      cmd = Command.create_image_rgba("sprite", 2, 2, pixels)

      assert %Command{type: :image_op} = cmd
      assert cmd.payload.op == "create_image"
      assert cmd.payload.handle == "sprite"
      assert cmd.payload.width == 2
      assert cmd.payload.height == 2
      assert cmd.payload.pixels == pixels
      refute Map.has_key?(cmd.payload, :data)
    end
  end

  describe "update_image/2 (encoded bytes)" do
    test "returns a command struct for replacing image data" do
      new_data = <<0, 1, 2, 3>>
      cmd = Command.update_image("logo", new_data)

      assert %Command{type: :image_op} = cmd
      assert cmd.payload.op == "update_image"
      assert cmd.payload.handle == "logo"
      assert cmd.payload.data == new_data
    end
  end

  describe "update_image_rgba/4 (raw RGBA pixels)" do
    test "returns a command struct with new dimensions and pixels" do
      pixels = <<0, 0, 0, 255>>
      cmd = Command.update_image_rgba("sprite", 1, 1, pixels)

      assert %Command{type: :image_op} = cmd
      assert cmd.payload.op == "update_image"
      assert cmd.payload.handle == "sprite"
      assert cmd.payload.width == 1
      assert cmd.payload.height == 1
      assert cmd.payload.pixels == pixels
    end
  end

  describe "delete_image/1" do
    test "returns a command struct with just the handle" do
      cmd = Command.delete_image("old_texture")

      assert %Command{type: :image_op} = cmd
      assert cmd.payload.op == "delete_image"
      assert cmd.payload.handle == "old_texture"
      refute Map.has_key?(cmd.payload, :data)
      refute Map.has_key?(cmd.payload, :pixels)
    end
  end

  describe "encode_image_op/3 with :json format" do
    test "base64-encodes the data field" do
      raw = <<1, 2, 3, 4, 5>>
      encoded = Protocol.encode_image_op("create_image", %{handle: "img", data: raw}, :json)

      # JSON serialization ends with newline
      assert String.ends_with?(encoded, "\n")

      decoded = Jason.decode!(encoded)
      assert decoded["type"] == "image_op"
      assert decoded["op"] == "create_image"
      assert decoded["payload"]["handle"] == "img"
      assert decoded["payload"]["data"] == Base.encode64(raw)
    end

    test "base64-encodes the pixels field" do
      pixels = <<255, 0, 0, 255>>

      encoded =
        Protocol.encode_image_op(
          "create_image",
          %{handle: "px", width: 1, height: 1, pixels: pixels},
          :json
        )

      decoded = Jason.decode!(encoded)
      assert decoded["payload"]["pixels"] == Base.encode64(pixels)
      assert decoded["payload"]["width"] == 1
      assert decoded["payload"]["height"] == 1
    end
  end

  describe "encode_image_op/3 with :msgpack format" do
    test "wraps data field in Msgpax.Bin" do
      raw = <<10, 20, 30>>
      encoded = Protocol.encode_image_op("create_image", %{handle: "img", data: raw}, :msgpack)

      # Msgpack output is a binary blob; decode it and verify the data is raw bytes
      {:ok, decoded} = Msgpax.unpack(encoded)
      assert decoded["type"] == "image_op"
      assert decoded["op"] == "create_image"
      assert decoded["payload"]["handle"] == "img"
      # Msgpax.Bin round-trips as raw binary
      assert decoded["payload"]["data"] == raw
    end

    test "wraps pixels field in Msgpax.Bin" do
      pixels = <<0, 0, 0, 255>>

      encoded =
        Protocol.encode_image_op(
          "create_image",
          %{handle: "px", width: 1, height: 1, pixels: pixels},
          :msgpack
        )

      {:ok, decoded} = Msgpax.unpack(encoded)
      assert decoded["payload"]["pixels"] == pixels
    end

    test "delete_image has no binary fields to encode" do
      encoded = Protocol.encode_image_op("delete_image", %{handle: "gone"}, :msgpack)

      {:ok, decoded} = Msgpax.unpack(encoded)
      assert decoded["type"] == "image_op"
      assert decoded["op"] == "delete_image"
      assert decoded["payload"]["handle"] == "gone"
    end
  end

  describe "list_images/1" do
    test "returns an image_op command with op \"list\" and string tag" do
      cmd = Command.list_images(:my_tag)

      assert %Command{type: :image_op} = cmd
      assert cmd.payload.op == "list"
      assert cmd.payload.tag == "my_tag"
    end

    test "encodes to the typed image_op wire envelope (json)" do
      encoded = Protocol.encode_image_op("list", %{tag: "my_tag"}, :json)

      decoded = Jason.decode!(encoded)
      assert decoded["type"] == "image_op"
      assert decoded["op"] == "list"
      assert decoded["payload"] == %{"tag" => "my_tag"}
    end

    test "encodes to the typed image_op wire envelope (msgpack)" do
      encoded = Protocol.encode_image_op("list", %{tag: "my_tag"}, :msgpack)

      {:ok, decoded} = Msgpax.unpack(encoded)
      assert decoded["type"] == "image_op"
      assert decoded["op"] == "list"
      assert decoded["payload"] == %{"tag" => "my_tag"}
    end
  end

  describe "clear_images/0" do
    test "returns an image_op command with op \"clear\"" do
      cmd = Command.clear_images()

      assert %Command{type: :image_op} = cmd
      assert cmd.payload == %{op: "clear"}
    end

    test "encodes to the typed image_op wire envelope (json)" do
      encoded = Protocol.encode_image_op("clear", %{}, :json)

      decoded = Jason.decode!(encoded)
      assert decoded["type"] == "image_op"
      assert decoded["op"] == "clear"
      assert decoded["payload"] == %{}
    end
  end

  describe "pixel buffer validation" do
    test "create_image_rgba/4 rejects wrong buffer size" do
      assert_raise ArgumentError, ~r/pixel buffer size mismatch/, fn ->
        Command.create_image_rgba("sprite", 2, 2, <<0, 0, 0>>)
      end
    end

    test "update_image_rgba/4 rejects wrong buffer size" do
      assert_raise ArgumentError, ~r/pixel buffer size mismatch/, fn ->
        Command.update_image_rgba("sprite", 2, 2, <<0, 0, 0>>)
      end
    end

    test "create_image_rgba/4 accepts correct buffer size" do
      pixels = :binary.copy(<<255, 0, 0, 255>>, 4)
      cmd = Command.create_image_rgba("sprite", 2, 2, pixels)
      assert cmd.payload.op == "create_image"
    end
  end
end
