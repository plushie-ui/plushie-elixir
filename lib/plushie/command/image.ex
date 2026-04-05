defmodule Plushie.Command.Image do
  @moduledoc """
  Image commands: create, update, delete, list, and clear in-memory images.
  """

  alias Plushie.Command

  @doc """
  Creates an in-memory image from encoded PNG/JPEG bytes.

  The raw binary is stored as-is in the command payload. The protocol layer
  handles format-specific encoding (native binary for msgpack, base64 for JSON).
  """
  @spec create_image(handle :: String.t(), data :: binary()) :: Command.t()
  def create_image(handle, data) when is_binary(handle) and is_binary(data) do
    %Command{
      type: :image_op,
      payload: %{op: "create_image", handle: handle, data: data}
    }
  end

  @doc """
  Creates an in-memory image from raw RGBA pixel data.

  The raw binary is stored as-is in the command payload. The protocol layer
  handles format-specific encoding (native binary for msgpack, base64 for JSON).
  """
  @spec create_image(
          handle :: String.t(),
          width :: pos_integer(),
          height :: pos_integer(),
          pixels :: binary()
        ) :: Command.t()
  def create_image(handle, width, height, pixels)
      when is_binary(handle) and is_integer(width) and is_integer(height) and is_binary(pixels) do
    expected = width * height * 4

    if byte_size(pixels) != expected do
      raise ArgumentError,
            "pixel buffer size mismatch: expected #{expected} bytes " <>
              "(#{width}x#{height}x4 RGBA) but got #{byte_size(pixels)}"
    end

    %Command{
      type: :image_op,
      payload: %{
        op: "create_image",
        handle: handle,
        width: width,
        height: height,
        pixels: pixels
      }
    }
  end

  @doc """
  Updates an existing in-memory image with new encoded PNG/JPEG bytes.

  The raw binary is stored as-is in the command payload. The protocol layer
  handles format-specific encoding (native binary for msgpack, base64 for JSON).
  """
  @spec update_image(handle :: String.t(), data :: binary()) :: Command.t()
  def update_image(handle, data) when is_binary(handle) and is_binary(data) do
    %Command{
      type: :image_op,
      payload: %{op: "update_image", handle: handle, data: data}
    }
  end

  @doc """
  Updates an existing in-memory image with new raw RGBA pixel data.

  The raw binary is stored as-is in the command payload. The protocol layer
  handles format-specific encoding (native binary for msgpack, base64 for JSON).
  """
  @spec update_image(
          handle :: String.t(),
          width :: pos_integer(),
          height :: pos_integer(),
          pixels :: binary()
        ) :: Command.t()
  def update_image(handle, width, height, pixels)
      when is_binary(handle) and is_integer(width) and is_integer(height) and is_binary(pixels) do
    expected = width * height * 4

    if byte_size(pixels) != expected do
      raise ArgumentError,
            "pixel buffer size mismatch: expected #{expected} bytes " <>
              "(#{width}x#{height}x4 RGBA) but got #{byte_size(pixels)}"
    end

    %Command{
      type: :image_op,
      payload: %{
        op: "update_image",
        handle: handle,
        width: width,
        height: height,
        pixels: pixels
      }
    }
  end

  @doc "Deletes an in-memory image by handle name."
  @spec delete_image(handle :: String.t()) :: Command.t()
  def delete_image(handle) when is_binary(handle) do
    %Command{
      type: :image_op,
      payload: %{op: "delete_image", handle: handle}
    }
  end

  @doc """
  Lists all in-memory image handles.

  The result arrives in `update/2` as
  `%SystemEvent{type: :image_list, tag: tag, value: %{"handles" => [...]}}`.
  """
  @spec list_images(tag :: atom()) :: Command.t()
  def list_images(tag) when is_atom(tag) do
    %Command{
      type: :widget_op,
      payload: %{op: "list_images", tag: Atom.to_string(tag)}
    }
  end

  @doc "Clears all in-memory images."
  @spec clear_images() :: Command.t()
  def clear_images do
    %Command{
      type: :widget_op,
      payload: %{op: "clear_images"}
    }
  end
end
