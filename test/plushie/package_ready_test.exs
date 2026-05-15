defmodule Plushie.PackageReadyTest do
  use ExUnit.Case, async: false

  @moduletag capture_log: true

  alias Plushie.Event.WidgetEvent

  defmodule SimpleApp do
    use Plushie.App

    def init(_opts), do: %{value: 0}

    def update(model, %WidgetEvent{type: :click, id: "inc"}),
      do: %{model | value: model.value + 1}

    def update(model, _event), do: model

    def view(model) do
      import Plushie.UI

      window "main" do
        text("Value: #{model.value}")
      end
    end
  end

  test "writes package readiness file after renderer hello" do
    ready_file =
      Path.join([
        System.tmp_dir!(),
        "plushie-ready-#{System.unique_integer([:positive])}",
        "ready"
      ])

    previous = System.get_env("PLUSHIE_PACKAGE_READY_FILE")
    System.put_env("PLUSHIE_PACKAGE_READY_FILE", ready_file)

    on_exit(fn ->
      if previous,
        do: System.put_env("PLUSHIE_PACKAGE_READY_FILE", previous),
        else: System.delete_env("PLUSHIE_PACKAGE_READY_FILE")

      File.rm_rf!(Path.dirname(ready_file))
    end)

    {runtime, _bridge} = start_runtime(SimpleApp)
    Plushie.Runtime.sync(runtime)

    send(
      runtime,
      {:renderer_event,
       {:hello,
        %{
          protocol: 1,
          version: Plushie.Binary.plushie_rust_version(),
          name: "plushie",
          mode: "mock",
          backend: "test",
          transport: "spawn",
          native_widgets: [],
          widgets: []
        }}}
    )

    Plushie.Runtime.sync(runtime)
    assert File.read!(ready_file) == "ready\n"
  end

  defp start_runtime(app) do
    tag = System.unique_integer([:positive])
    bridge_name = :"mock_bridge_#{tag}"
    runtime_name = :"runtime_#{tag}"

    {:ok, _bridge} = Plushie.Test.InternalMockBridge.start_link(name: bridge_name)
    {:ok, runtime} = Plushie.Runtime.start_link(app: app, bridge: bridge_name, name: runtime_name)

    {runtime, bridge_name}
  end
end
