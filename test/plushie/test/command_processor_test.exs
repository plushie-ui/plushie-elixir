defmodule Plushie.Test.Backend.CommandProcessorTest do
  use ExUnit.Case, async: true

  alias Plushie.Event.Widget

  alias Plushie.Test.Backend.CommandProcessor

  # -- Test apps --

  defmodule AsyncApp do
    use Plushie.App

    def init(_opts), do: {%{status: :idle, data: nil}, []}

    def update(model, %Widget{type: :click, id: "fetch"}) do
      cmd = Plushie.Command.async(fn -> {:ok, "fetched"} end, :data_loaded)
      {model, cmd}
    end

    def update(model, %Plushie.Event.Async{tag: :data_loaded, result: result}),
      do: %{model | status: :done, data: result}

    def update(model, _event), do: model

    def view(model) do
      %{
        id: "root",
        type: "column",
        props: %{},
        children: [
          %{id: "status", type: "text", props: %{content: "#{model.status}"}, children: []},
          %{id: "fetch", type: "button", props: %{label: "Fetch"}, children: []}
        ]
      }
    end
  end

  defmodule StreamApp do
    use Plushie.App

    def init(_opts), do: {%{items: []}, []}

    def update(model, %Widget{type: :click, id: "stream"}) do
      cmd =
        Plushie.Command.stream(
          fn emit ->
            emit.(:a)
            emit.(:b)
            :done
          end,
          :streamed
        )

      {model, cmd}
    end

    def update(model, %Plushie.Event.Async{tag: :streamed, result: :done}),
      do: %{model | items: model.items ++ [:final]}

    def update(model, %Plushie.Event.Stream{tag: :streamed, value: item}),
      do: %{model | items: model.items ++ [item]}

    def update(model, _event), do: model

    def view(model) do
      %{id: "root", type: "text", props: %{content: inspect(model.items)}, children: []}
    end
  end

  defmodule BatchApp do
    use Plushie.App

    def init(_opts), do: {%{a: false, b: false}, []}

    def update(model, %Widget{type: :click, id: "both"}) do
      cmd =
        Plushie.Command.batch([
          Plushie.Command.done(:set_a, fn v -> {:got_a, v} end),
          Plushie.Command.done(:set_b, fn v -> {:got_b, v} end)
        ])

      {model, cmd}
    end

    def update(model, {:got_a, _}), do: %{model | a: true}
    def update(model, {:got_b, _}), do: %{model | b: true}
    def update(model, _event), do: model

    def view(model) do
      %{id: "root", type: "text", props: %{content: inspect(model)}, children: []}
    end
  end

  defmodule DoneApp do
    use Plushie.App

    def init(_opts), do: {%{result: nil}, []}

    def update(model, %Widget{type: :click, id: "go"}) do
      cmd = Plushie.Command.done(42, fn v -> {:computed, v * 2} end)
      {model, cmd}
    end

    def update(model, {:computed, v}), do: %{model | result: v}
    def update(model, _event), do: model

    def view(model) do
      %{id: "root", type: "text", props: %{content: inspect(model.result)}, children: []}
    end
  end

  defmodule NoneApp do
    use Plushie.App

    def init(_opts), do: {%{count: 0}, [Plushie.Command.none()]}

    def update(model, _event), do: model

    def view(model) do
      %{id: "root", type: "text", props: %{content: "#{model.count}"}, children: []}
    end
  end

  defmodule InitCommandApp do
    use Plushie.App

    def init(_opts) do
      cmd = Plushie.Command.async(fn -> "loaded" end, :init_data)
      {%{data: nil}, cmd}
    end

    def update(model, %Plushie.Event.Async{tag: :init_data, result: data}),
      do: %{model | data: data}

    def update(model, _event), do: model

    def view(model) do
      %{id: "root", type: "text", props: %{content: inspect(model.data)}, children: []}
    end
  end

  defmodule SingleCommandApp do
    use Plushie.App

    def init(_opts) do
      cmd = Plushie.Command.done(:hello, fn v -> {:init_done, v} end)
      {%{initialized: false}, cmd}
    end

    def update(model, {:init_done, _}), do: %{model | initialized: true}
    def update(model, _event), do: model

    def view(model) do
      %{id: "root", type: "text", props: %{content: "#{model.initialized}"}, children: []}
    end
  end

  describe "process/3" do
    test "processes async commands synchronously" do
      {model, _commands} = AsyncApp.init([])

      {model, commands} =
        CommandProcessor.dispatch_update(AsyncApp, model, %Widget{type: :click, id: "fetch"})

      model = CommandProcessor.process(AsyncApp, model, commands)

      assert model.status == :done
      assert model.data == {:ok, "fetched"}
    end

    test "processes stream commands with intermediate values" do
      {model, _commands} = StreamApp.init([])

      {model, commands} =
        CommandProcessor.dispatch_update(StreamApp, model, %Widget{type: :click, id: "stream"})

      model = CommandProcessor.process(StreamApp, model, commands)

      assert model.items == [:a, :b, :final]
    end

    test "processes batch commands" do
      {model, _commands} = BatchApp.init([])

      {model, commands} =
        CommandProcessor.dispatch_update(BatchApp, model, %Widget{type: :click, id: "both"})

      model = CommandProcessor.process(BatchApp, model, commands)

      assert model.a == true
      assert model.b == true
    end

    test "processes done commands" do
      {model, _commands} = DoneApp.init([])

      {model, commands} =
        CommandProcessor.dispatch_update(DoneApp, model, %Widget{type: :click, id: "go"})

      model = CommandProcessor.process(DoneApp, model, commands)

      assert model.result == 84
    end

    test "handles none commands" do
      model = CommandProcessor.process(NoneApp, %{count: 0}, [Plushie.Command.none()])
      assert model.count == 0
    end

    test "handles empty command list" do
      model = CommandProcessor.process(NoneApp, %{count: 5}, [])
      assert model.count == 5
    end

    test "handles non-list input gracefully" do
      model = CommandProcessor.process(NoneApp, %{count: 5}, nil)
      assert model.count == 5
    end

    test "handles single command struct" do
      cmd = Plushie.Command.done(42, fn v -> {:computed, v * 2} end)
      model = CommandProcessor.process(DoneApp, %{result: nil}, cmd)
      assert model.result == 84
    end

    test "respects max recursion depth" do
      # An app that always returns more commands -- should not loop forever
      defmodule InfiniteApp do
        use Plushie.App
        def init(_), do: %{depth: 0}

        def update(model, {:go, _}) do
          {%{model | depth: model.depth + 1},
           Plushie.Command.done(:again, fn _ -> {:go, :again} end)}
        end

        def update(model, _), do: model

        def view(model),
          do: %{id: "r", type: "text", props: %{content: "#{model.depth}"}, children: []}
      end

      cmd = Plushie.Command.done(:start, fn _ -> {:go, :first} end)
      model = CommandProcessor.process(InfiniteApp, %{depth: 0}, cmd)

      # Should have stopped at max depth (100), not loop forever
      assert model.depth > 0
      assert model.depth <= 101
    end
  end

  describe "dispatch_update/3" do
    test "normalizes bare model return" do
      {model, commands} = CommandProcessor.dispatch_update(NoneApp, %{count: 0}, :whatever)
      assert model == %{count: 0}
      assert commands == []
    end

    test "normalizes {model, commands} list return" do
      {model, commands} =
        CommandProcessor.dispatch_update(AsyncApp, %{status: :idle, data: nil}, %Widget{
          type: :click,
          id: "fetch"
        })

      assert model.status == :idle
      assert [%Plushie.Command{type: :async}] = commands
    end

    test "normalizes {model, single_command} return" do
      {model, commands} =
        CommandProcessor.dispatch_update(
          SingleCommandApp,
          %{initialized: false},
          %Widget{type: :click, id: "nope"}
        )

      # SingleCommandApp.update returns bare model for unknown events
      assert model == %{initialized: false}
      assert commands == []
    end
  end

  describe "integration with mock backend" do
    test "mock backend processes init commands" do
      alias Plushie.Test.Backend.MockRenderer

      {:ok, pid} = MockRenderer.start(InitCommandApp, pool: Plushie.TestPool)
      model = MockRenderer.model(pid)

      assert model.data == "loaded"
      MockRenderer.stop(pid)
    end

    test "mock backend processes single command from init" do
      alias Plushie.Test.Backend.MockRenderer

      {:ok, pid} = MockRenderer.start(SingleCommandApp, pool: Plushie.TestPool)
      model = MockRenderer.model(pid)

      assert model.initialized == true
      MockRenderer.stop(pid)
    end

    test "mock backend processes commands from interactions" do
      alias Plushie.Test.Backend.MockRenderer

      {:ok, pid} = MockRenderer.start(AsyncApp, pool: Plushie.TestPool)
      MockRenderer.click(pid, "#fetch")
      model = MockRenderer.model(pid)

      assert model.status == :done
      assert model.data == {:ok, "fetched"}
      MockRenderer.stop(pid)
    end
  end
end
