defmodule Plushie.Widget.Window do
  @moduledoc """
  Top-level window container node.

  Holds window-level configuration (title, size, position, decorations,
  etc.) and wraps the child widget tree for that window. The runtime
  detects window nodes by their `"window"` type string and synchronizes
  open/close/update operations with the Rust binary via the bridge.
  """

  use Plushie.Widget

  @a11y_defaults %{role: :window}

  widget :window, container: :single do
    field :title, :string, doc: "Window title bar text."

    field :size, {:tuple, [:float, :float]},
      doc: "Initial window size as `{width, height}` tuple."

    field :width, Plushie.Type.Length, doc: "Content width layout. Default: fill."
    field :height, Plushie.Type.Length, doc: "Content height layout. Default: fill."
    field :padding, Plushie.Type.Padding, doc: "Padding inside the window content."
    field :position, {:tuple, [:float, :float]}, doc: "Initial window position as `{x, y}` tuple."

    field :min_size, {:tuple, [:float, :float]},
      doc: "Minimum window dimensions as `{width, height}`."

    field :max_size, {:tuple, [:float, :float]},
      doc: "Maximum window dimensions as `{width, height}`."

    field :maximized, :boolean, doc: "Start maximized."
    field :fullscreen, :boolean, doc: "Start in fullscreen mode."
    field :visible, :boolean, doc: "Whether the window is visible."
    field :resizable, :boolean, doc: "Whether the window can be resized."
    field :closeable, :boolean, doc: "Whether the window close button is shown."
    field :minimizable, :boolean, doc: "Whether the window can be minimized."
    field :decorations, :boolean, doc: "Show window decorations (title bar, borders)."
    field :transparent, :boolean, doc: "Transparent window background."
    field :blur, :boolean, doc: "Blur the window background."

    field :level, {:enum, [:normal, :always_on_top, :always_on_bottom]},
      doc: "Stacking level: `:normal`, `:always_on_top`, `:always_on_bottom`."

    field :exit_on_close_request, :boolean, doc: "Whether closing the window exits the app."

    field :scale_factor, :float, doc: "Window scale factor override."

    field :theme, Plushie.Type.Theme,
      doc: "Per-window theme: built-in atom, `:system`, or custom palette."

    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."
  end
end
