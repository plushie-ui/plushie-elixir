defmodule ColorPicker do
  @moduledoc """
  HSV color picker using a custom canvas widget.

  A hue ring surrounds a saturation/value square. Drag the ring to select
  a hue; drag the square to adjust saturation and value. The selected color
  is displayed as a swatch and hex string below the canvas.

      mix plushie.gui ColorPicker
  """

  use Plushie.App

  alias Plushie.Event.Canvas

  # -- App callbacks -----------------------------------------------------------

  def init(_opts) do
    %{hue: 0.0, saturation: 1.0, value: 1.0, drag: :none}
  end

  def update(model, %Canvas{type: :press, id: "picker", x: x, y: y, button: "left"}) do
    dx = x - ColorPickerWidget.cx()
    dy = y - ColorPickerWidget.cy()
    dist = :math.sqrt(dx * dx + dy * dy)

    cond do
      dist >= ColorPickerWidget.inner_r() and dist <= ColorPickerWidget.outer_r() ->
        %{model | drag: :ring, hue: hue_from_point(dx, dy)}

      in_square?(x, y) ->
        apply_sv(%{model | drag: :square}, x, y)

      true ->
        model
    end
  end

  def update(model, %Canvas{type: :move, id: "picker", x: x, y: y}) do
    case model.drag do
      :ring -> %{model | hue: hue_from_point(x - ColorPickerWidget.cx(), y - ColorPickerWidget.cy())}
      :square -> apply_sv(model, x, y)
      :none -> model
    end
  end

  def update(model, %Canvas{type: :release, id: "picker"}) do
    %{model | drag: :none}
  end

  def update(model, _event), do: model

  def view(model) do
    import Plushie.UI

    hex = hsv_to_hex(model.hue, model.saturation, model.value)

    window "color_picker", title: "Color Picker" do
      column do
        padding 20
        spacing 16
        align_x :center

        ColorPickerWidget.render("picker", model.hue, model.saturation, model.value)

        row do
          spacing 16
          align_y :center

          container "swatch" do
            width 48
            height 48
            background(hex)

            border do
              width 1
              color "#cccccc"
              rounded 4
            end
          end

          column do
            spacing 4
            text("hex_display", hex, size: 18)
            text("hsv_display", hsv_label(model))
          end
        end
      end
    end
  end

  # -- Hit testing -------------------------------------------------------------

  defp in_square?(x, y) do
    origin = ColorPickerWidget.sq_origin()
    size = ColorPickerWidget.sq_size()

    x >= origin and x <= origin + size and
      y >= origin and y <= origin + size
  end

  # -- Coordinate math ---------------------------------------------------------

  defp hue_from_point(dx, dy) do
    angle = :math.atan2(dy, dx)
    hue = angle + :math.pi() / 2
    hue = if hue < 0, do: hue + 2 * :math.pi(), else: hue
    hue * 180.0 / :math.pi()
  end

  defp apply_sv(model, x, y) do
    origin = ColorPickerWidget.sq_origin()
    size = ColorPickerWidget.sq_size()
    s = clamp((x - origin) / size, 0.0, 1.0)
    v = clamp(1.0 - (y - origin) / size, 0.0, 1.0)
    %{model | saturation: s, value: v}
  end

  defp clamp(val, lo, hi), do: max(lo, min(hi, val))

  # -- Display helpers ---------------------------------------------------------

  defp hsv_label(model) do
    h_int = round(model.hue)
    s_pct = round(model.saturation * 100)
    v_pct = round(model.value * 100)
    "H: #{h_int}  S: #{s_pct}%  V: #{v_pct}%"
  end

  # -- Color conversion --------------------------------------------------------

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
