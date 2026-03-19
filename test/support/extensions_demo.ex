if Code.ensure_loaded?(JulepSparkline) and Code.ensure_loaded?(JulepHexView) and
     Code.ensure_loaded?(JulepCodeView) and Code.ensure_loaded?(JulepPlot) and
     Code.ensure_loaded?(JulepTimeline) do
  defmodule Julep.Examples.ExtensionsDemo do
    @moduledoc """
    Demo app using all 5 extension widgets simultaneously.

    Verifies coexistence: no type name collisions, correct config routing,
    correct command routing, and independent rendering.

    Only compiled when extension deps are available (dev/test).
    """

    use Julep.App

    alias Julep.Event.Timer
    alias Julep.Event.Widget
    import Julep.UI

    @impl true
    def init(_flags) do
      %{
        tick: 0,
        paused: false,
        hex_text: "Hello, Julep!",
        code: "fn main() {\n    println!(\"Hello!\");\n}",
        language: "rust",
        selected_interval: nil
      }
    end

    @impl true
    def update(model, message) do
      case message do
        %Timer{tag: :tick} ->
          if model.paused do
            model
          else
            tick = model.tick + 1
            value = :math.sin(tick * 0.1) * 50 + 50
            {%{model | tick: tick}, [JulepSparkline.push("spark", value)]}
          end

        %Widget{type: :click, id: "timeline"} ->
          %{model | selected_interval: "clicked"}

        _ ->
          model
      end
    end

    @impl true
    def view(model) do
      window "extensions-demo", title: "Extensions Demo" do
        column padding: 10, spacing: 10 do
          text("demo_title", "All 5 Extension Widgets", size: 24)

          # Row 1: Sparkline + Hex View
          row spacing: 20 do
            column spacing: 5 do
              text("sparkline_label", "Sparkline", size: 16)

              JulepSparkline.new("spark")
              |> JulepSparkline.color("#4FC3F7")
              |> JulepSparkline.width(200)
              |> JulepSparkline.height(60)
            end

            column spacing: 5 do
              text("hex_label", "Hex View", size: 16)

              JulepHexView.new("hex",
                data: model.hex_text,
                bytes_per_row: 8,
                height: 80
              )
            end
          end

          # Row 2: Code View
          column spacing: 5 do
            text("code_label", "Code View", size: 16)

            JulepCodeView.new("code",
              code: model.code,
              language: model.language,
              line_numbers: true,
              height: 120
            )
          end

          # Row 3: Plot
          column spacing: 5 do
            text("plot_label", "Plot", size: 16)

            JulepPlot.new("plot",
              series: [
                %{
                  name: "sine",
                  data: for(i <- 0..20, do: {i, :math.sin(i * 0.3) * 50 + 50}),
                  color: "#4FC3F7"
                },
                %{
                  name: "cosine",
                  data: for(i <- 0..20, do: {i, :math.cos(i * 0.3) * 50 + 50}),
                  color: "#FF7043"
                }
              ],
              width: :fill,
              height: 150
            )
          end

          # Row 4: Timeline
          column spacing: 5 do
            text("timeline_label", "Timeline", size: 16)

            JulepTimeline.new("timeline",
              intervals: [
                JulepTimeline.interval("req-1", "GET /api", 0, 150,
                  lane: 0,
                  color: "#4FC3F7"
                ),
                JulepTimeline.interval("db-1", "SELECT users", 20, 80,
                  lane: 1,
                  color: "#66BB6A"
                ),
                JulepTimeline.interval("job-1", "SendEmail", 100, 300,
                  lane: 2,
                  color: "#FF7043"
                )
              ],
              width: :fill,
              height: 120
            )
          end
        end
      end
    end

    @impl true
    def subscribe(model) do
      if model.paused do
        []
      else
        [Julep.Subscription.every(100, :tick)]
      end
    end
  end
end
