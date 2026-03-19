defmodule Toddy.Iced.ContentFit do
  @moduledoc """
  Scaling mode for the `content_fit` prop on image and SVG widgets.

  Maps to iced's `ContentFit` enum.
  """

  @type t :: :contain | :cover | :fill | :none | :scale_down

  @valid [:contain, :cover, :fill, :none, :scale_down]

  @doc """
  Encodes a content fit value to the wire format.

  ## Examples

      iex> Toddy.Iced.ContentFit.encode(:contain)
      "contain"

      iex> Toddy.Iced.ContentFit.encode(:cover)
      "cover"

      iex> Toddy.Iced.ContentFit.encode(:fill)
      "fill"

      iex> Toddy.Iced.ContentFit.encode(:none)
      "none"

      iex> Toddy.Iced.ContentFit.encode(:scale_down)
      "scale_down"
  """
  @spec encode(content_fit :: t()) :: String.t()
  def encode(value) when value in @valid, do: Atom.to_string(value)
end
