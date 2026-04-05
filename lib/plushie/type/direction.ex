defmodule Plushie.Type.Direction do
  @moduledoc """
  Orientation for the scrollable `direction` prop and rule widget.

  Maps to iced's horizontal/vertical axis variants.
  """

  use Plushie.Type

  @type t :: :horizontal | :vertical | :both

  enum([:horizontal, :vertical, :both])
end
