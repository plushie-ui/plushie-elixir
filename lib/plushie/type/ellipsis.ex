defmodule Plushie.Type.Ellipsis do
  @moduledoc """
  Text truncation ellipsis position.
  """

  use Plushie.Type

  @type t :: :none | :start | :middle | :end

  enum([:none, :start, :middle, :end])
end
