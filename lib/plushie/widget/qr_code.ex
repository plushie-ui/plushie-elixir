defmodule Plushie.Widget.QrCode do
  @moduledoc """
  QR Code, renders a QR code from a data string.
  """

  use Plushie.Widget

  @a11y_defaults %{role: :image}

  widget :qr_code do
    field :data, :string, option: false, doc: "Data to encode in the QR code. Required."
    field :cell_size, :float, doc: "Size of each QR module in pixels. Default: 4.0."
    field :cell_color, Plushie.Type.Color, doc: "Color of dark modules. Default: black."
    field :background, Plushie.Type.Color, doc: "Color of light modules. Default: white."

    field :error_correction, :atom,
      doc: "Error correction level: `:low`, `:medium`, `:quartile`, `:high`."

    field :alt, :string, doc: "Accessible label for the QR code."
    field :description, :string, doc: "Extended accessible description."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."

    positional [:data]
  end
end
