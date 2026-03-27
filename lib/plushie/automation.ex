defmodule Plushie.Automation do
  @moduledoc """
  Runtime automation for Plushie apps.

  This namespace covers attached interaction sessions, selector resolution,
  screenshots, replay, and `.plushie` file execution.

  Use `Plushie.Automation.Session` to drive a running app directly, and
  `Plushie.Automation.File` when you need to parse the `.plushie` file format.
  """

  @typedoc "Renderer mode supported by Plushie automation."
  @type backend_mode :: :mock | :headless | :windowed
end
