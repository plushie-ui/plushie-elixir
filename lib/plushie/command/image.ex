defmodule Plushie.Command.Image do
  @moduledoc """
  In-memory image commands: create, update, delete, list, and clear.

  Images are referenced by handle name in widget `source` props:

      image("my-img", source: %{handle: "avatar"}, ...)

  ## Example

      # Create from encoded file bytes
      data = File.read!("photo.png")
      Command.create_image("avatar", data)

      # Create from raw RGBA pixels
      Command.create_image_rgba("gradient", 256, 1, rgba_pixels)

      # Update existing encoded image
      Command.update_image("avatar", new_data)

      # Update existing raw image
      Command.update_image_rgba("gradient", 256, 1, new_rgba_pixels)

      # Clean up
      Command.delete_image("avatar")
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
  @spec create_image_rgba(
          handle :: String.t(),
          width :: pos_integer(),
          height :: pos_integer(),
          pixels :: binary()
        ) :: Command.t()
  def create_image_rgba(handle, width, height, pixels)
      when is_binary(handle) and is_integer(width) and width > 0 and is_integer(height) and
             height > 0 and is_binary(pixels) do
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
  @spec update_image_rgba(
          handle :: String.t(),
          width :: pos_integer(),
          height :: pos_integer(),
          pixels :: binary()
        ) :: Command.t()
  def update_image_rgba(handle, width, height, pixels)
      when is_binary(handle) and is_integer(width) and width > 0 and is_integer(height) and
             height > 0 and is_binary(pixels) do
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
  @spec list_images(tag :: Command.event_tag()) :: Command.t()
  def list_images(tag) when is_atom(tag) do
    %Command{
      type: :image_op,
      payload: %{op: "list", tag: Atom.to_string(tag)}
    }
  end

  @doc "Clears all in-memory images."
  @spec clear_images() :: Command.t()
  def clear_images do
    %Command{
      type: :image_op,
      payload: %{op: "clear"}
    }
  end
end
