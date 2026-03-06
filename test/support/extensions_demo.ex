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
        :tick ->
          if model.paused do
            model
          else
            tick = model.tick + 1
            value = :math.sin(tick * 0.1) * 50 + 50
            {%{model | tick: tick}, [JulepSparkline.Command.push("spark", value)]}
          end

        :toggle_pause ->
          %{model | paused: not model.paused}

        {:hex_input, text} ->
          %{model | hex_text: text}

        {:code_input, text} ->
          %{model | code: text}

        {:timeline_click, _id, interval_id} ->
          %{model | selected_interval: interval_id}

        _ ->
          model
      end
    end

    @impl true
    def view(model) do
      window "extensions-demo", title: "Extensions Demo" do
        column padding: 10, spacing: 10 do
          text("All 5 Extension Widgets", size: 24)

          # Row 1: Sparkline + Hex View
          row spacing: 20 do
            column spacing: 5 do
              text("Sparkline", size: 16)

              JulepSparkline.Sparkline.new("spark")
              |> JulepSparkline.Sparkline.color("#4FC3F7")
              |> JulepSparkline.Sparkline.width(200)
              |> JulepSparkline.Sparkline.height(60)
              |> JulepSparkline.Sparkline.build()
            end

            column spacing: 5 do
              text("Hex View", size: 16)

              JulepHexView.HexView.new("hex", model.hex_text)
              |> JulepHexView.HexView.bytes_per_row(8)
              |> JulepHexView.HexView.height(80)
              |> JulepHexView.HexView.build()
            end
          end

          # Row 2: Code View
          column spacing: 5 do
            text("Code View", size: 16)

            JulepCodeView.CodeView.new("code", model.code,
              language: model.language,
              line_numbers: true
            )
            |> JulepCodeView.CodeView.height(120)
            |> JulepCodeView.CodeView.build()
          end

          # Row 3: Plot
          column spacing: 5 do
            text("Plot", size: 16)

            JulepPlot.Plot.new("plot",
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
              ]
            )
            |> JulepPlot.Plot.width("fill")
            |> JulepPlot.Plot.height(150)
            |> JulepPlot.Plot.build()
          end

          # Row 4: Timeline
          column spacing: 5 do
            text("Timeline", size: 16)

            JulepTimeline.Timeline.new("timeline",
              intervals: [
                JulepTimeline.Timeline.interval("req-1", "GET /api", 0, 150,
                  lane: 0,
                  color: "#4FC3F7"
                ),
                JulepTimeline.Timeline.interval("db-1", "SELECT users", 20, 80,
                  lane: 1,
                  color: "#66BB6A"
                ),
                JulepTimeline.Timeline.interval("job-1", "SendEmail", 100, 300,
                  lane: 2,
                  color: "#FF7043"
                )
              ]
            )
            |> JulepTimeline.Timeline.width("fill")
            |> JulepTimeline.Timeline.height(120)
            |> JulepTimeline.Timeline.build()
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
