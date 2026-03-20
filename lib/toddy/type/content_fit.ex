defmodule Toddy.Type.ContentFit do
  @moduledoc """
  Scaling mode for the `content_fit` prop on image and SVG widgets.

  Maps to iced's `ContentFit` enum.
  """

  @type t :: :contain | :cover | :fill | :none | :scale_down

  @valid [:contain, :cover, :fill, :none, :scale_down]

  @doc """
  Encodes a content fit value to the wire format.

  ## Examples

      iex> Toddy.Type.ContentFit.encode(:contain)
      "contain"

      iex> Toddy.Type.ContentFit.encode(:cover)
      "cover"

      iex> Toddy.Type.ContentFit.encode(:fill)
      "fill"

      iex> Toddy.Type.ContentFit.encode(:none)
      "none"

      iex> Toddy.Type.ContentFit.encode(:scale_down)
      "scale_down"
  """
  @spec encode(content_fit :: t()) :: String.t()
  def encode(value) when value in @valid, do: Atom.to_string(value)
end
