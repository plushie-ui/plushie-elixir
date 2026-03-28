defmodule ColorPicker do
  @moduledoc """
  HSV color picker using a stateful widget.

  The color picker widget handles all interaction internally (mouse drag,
  keyboard adjustment, focus tracking). The app receives
  `{:color_picker_widget, :change}` events with the current HSV values.

      mix plushie.gui ColorPicker
  """

  use Plushie.App

  alias Plushie.Event.WidgetEvent

  def init(_opts) do
    %{hue: 0.0, saturation: 1.0, value: 1.0}
  end

  def update(model, event) do
    case event do
      %WidgetEvent{type: {:color_picker_widget, :change}, id: "picker", data: data} ->
        %{model | hue: data.hue, saturation: data.saturation, value: data.value}

      _ ->
        model
    end
  end

  def view(model) do
    import Plushie.UI

    hex = hsv_to_hex(model.hue, model.saturation, model.value)

    window "color_picker", title: "Color Picker" do
      column do
        padding(20)
        spacing(16)
        align_x(:center)

        ColorPickerWidget.new("picker")

        row do
          spacing(16)
          align_y(:center)

          container "swatch" do
            width(48)
            height(48)
            background(hex)

            border do
              width(1)
              color("#cccccc")
              rounded(4)
            end

            a11y(%{role: :image, label: "Selected color: #{hex}"})
          end

          column do
            spacing(4)

            text("hex_display", hex,
              size: 18,
              a11y: %{live: :polite, busy: model == %{hue: 0.0, saturation: 1.0, value: 1.0}}
            )

            text("hsv_display", hsv_label(model), a11y: %{live: :polite})
          end
        end
      end
    end
  end

  defp hsv_label(model) do
    h_int = round(model.hue)
    s_pct = round(model.saturation * 100)
    v_pct = round(model.value * 100)
    "H: #{h_int}  S: #{s_pct}%  V: #{v_pct}%"
  end

  defp hsv_to_hex(h, s, v) do
    h = fmod(h, 360.0)
    h = if h < 0, do: h + 360.0, else: h

    c = v * s
    h_sector = h / 60.0
    x = c * (1.0 - abs(fmod(h_sector, 2.0) - 1.0))
    m = v - c

    {r1, g1, b1} =
      cond do
        h_sector < 1 -> {c, x, 0.0}
        h_sector < 2 -> {x, c, 0.0}
        h_sector < 3 -> {0.0, c, x}
        h_sector < 4 -> {0.0, x, c}
        h_sector < 5 -> {x, 0.0, c}
        true -> {c, 0.0, x}
      end

    r = round((r1 + m) * 255)
    g = round((g1 + m) * 255)
    b = round((b1 + m) * 255)

    "##{hex_byte(r)}#{hex_byte(g)}#{hex_byte(b)}"
  end

  defp hex_byte(n) do
    n
    |> max(0)
    |> min(255)
    |> Integer.to_string(16)
    |> String.pad_leading(2, "0")
    |> String.downcase()
  end

  defp fmod(a, b), do: a - b * Float.floor(a / b)
end
