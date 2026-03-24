defmodule ColorPicker do
  @moduledoc """
  HSV color picker using a custom canvas widget.

  A hue ring surrounds a saturation/value square. Drag the ring to select
  a hue; drag the square to adjust saturation and value. The selected color
  is displayed as a swatch and hex string below the canvas.

  ## Keyboard controls

  Tab into the canvas to focus the hue or SV cursor.

  **Hue cursor:**

  | Key               | Action                      |
  |-------------------|-----------------------------|
  | Arrow Right/Up    | Increase hue (+1 degree)    |
  | Arrow Left/Down   | Decrease hue (-1 degree)    |
  | Shift + Arrow     | Coarse hue step (+/-15)     |
  | Page Up/Down      | Coarse hue step (+/-15)     |
  | Home              | Hue to 0                    |
  | End               | Hue to 359                  |

  **Saturation/value cursor:**

  | Key               | Action                      |
  |-------------------|-----------------------------|
  | Arrow Right/Left  | Saturation +/- 1%           |
  | Arrow Up/Down     | Value (brightness) +/- 1%   |
  | Shift + Arrow     | Coarse step (+/- 10%)       |
  | Page Up/Down      | Value coarse step (+/- 10%) |
  | Shift + PgUp/PgDn | Saturation coarse (+/- 10%) |
  | Home / End        | Value to max / min          |
  | Shift + Home/End  | Saturation to min / max     |

      mix plushie.gui ColorPicker
  """

  use Plushie.App

  alias Plushie.Event.{Canvas, Key, Widget}

  # Step sizes for keyboard adjustment
  @fine_step 1
  @coarse_step 15
  @sv_fine_step 0.01
  @sv_coarse_step 0.1

  # -- App callbacks -----------------------------------------------------------

  def init(_opts) do
    %{hue: 0.0, saturation: 1.0, value: 1.0, drag: :none, focus: nil}
  end

  def update(model, event) do
    case event do
      # -- Mouse: ring/square drag -----------------------------------------------

      %Canvas{type: :press, id: "picker", x: x, y: y, button: "left"} ->
        handle_press(model, x, y)

      %Canvas{type: :move, id: "picker", x: x, y: y} ->
        handle_move(model, x, y)

      %Canvas{type: :release, id: "picker"} ->
        %{model | drag: :none}

      # -- Canvas element focus tracking -----------------------------------------

      %Widget{type: :canvas_element_focused, id: "picker", data: %{"element_id" => eid}} ->
        %{model | focus: eid}

      %Widget{type: :canvas_element_blurred, id: "picker", data: %{"element_id" => _}} ->
        %{model | focus: nil}

      # -- Keyboard adjustment ---------------------------------------------------

      %Key{type: :press, captured: false} ->
        handle_key(model, event)

      _ ->
        model
    end
  end

  def subscribe(model) do
    if model.focus do
      [Plushie.Subscription.on_key_press(:picker_keys)]
    else
      []
    end
  end

  # -- View --------------------------------------------------------------------

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

            a11y %{role: :image, label: "Selected color: #{hex}"}
          end

          column do
            spacing 4

            text("hex_display", hex,
              size: 18,
              a11y: %{live: :polite, label: "Hex color value"}
            )

            text("hsv_display", hsv_label(model),
              a11y: %{live: :polite, label: "HSV color values"}
            )
          end
        end
      end
    end
  end

  # -- Mouse interaction -------------------------------------------------------

  defp handle_press(model, x, y) do
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

  defp handle_move(model, x, y) do
    case model.drag do
      :ring -> %{model | hue: hue_from_point(x - ColorPickerWidget.cx(), y - ColorPickerWidget.cy())}
      :square -> apply_sv(model, x, y)
      :none -> model
    end
  end

  # -- Keyboard interaction ----------------------------------------------------

  defp handle_key(%{focus: nil} = model, _event), do: model

  defp handle_key(%{focus: "hue-cursor"} = model, %Key{} = key) do
    step = if key.modifiers.shift, do: @coarse_step, else: @fine_step

    case key.key do
      k when k in [:arrow_right, :arrow_up] -> %{model | hue: fmod(model.hue + step, 360.0)}
      k when k in [:arrow_left, :arrow_down] -> %{model | hue: fmod(model.hue - step + 360.0, 360.0)}
      :page_up -> %{model | hue: fmod(model.hue + @coarse_step, 360.0)}
      :page_down -> %{model | hue: fmod(model.hue - @coarse_step + 360.0, 360.0)}
      :home -> %{model | hue: 0.0}
      :end -> %{model | hue: 359.0}
      _ -> model
    end
  end

  defp handle_key(%{focus: "sv-cursor"} = model, %Key{} = key) do
    step = if key.modifiers.shift, do: @sv_coarse_step, else: @sv_fine_step
    shift? = key.modifiers.shift

    case key.key do
      :arrow_right -> %{model | saturation: clamp(model.saturation + step, 0.0, 1.0)}
      :arrow_left -> %{model | saturation: clamp(model.saturation - step, 0.0, 1.0)}
      :arrow_up -> %{model | value: clamp(model.value + step, 0.0, 1.0)}
      :arrow_down -> %{model | value: clamp(model.value - step, 0.0, 1.0)}
      :page_up when shift? -> %{model | saturation: clamp(model.saturation + @sv_coarse_step, 0.0, 1.0)}
      :page_down when shift? -> %{model | saturation: clamp(model.saturation - @sv_coarse_step, 0.0, 1.0)}
      :page_up -> %{model | value: clamp(model.value + @sv_coarse_step, 0.0, 1.0)}
      :page_down -> %{model | value: clamp(model.value - @sv_coarse_step, 0.0, 1.0)}
      :home when shift? -> %{model | saturation: 0.0}
      :end when shift? -> %{model | saturation: 1.0}
      :home -> %{model | value: 1.0}
      :end -> %{model | value: 0.0}
      _ -> model
    end
  end

  defp handle_key(model, _key), do: model

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
