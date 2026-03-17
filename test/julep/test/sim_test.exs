defmodule Julep.Test.SimTest do
  use ExUnit.Case, async: true

  alias Julep.Event.Widget

  alias Julep.Test.Backend.Sim
  alias Julep.Test.Element
  alias Julep.Test.Screenshot
  alias Julep.Test.Session
  alias Julep.Test.Snapshot

  defmodule CounterApp do
    use Julep.App

    def init(_opts), do: %{count: 0}

    def update(model, %Widget{type: :click, id: "increment"}),
      do: %{model | count: model.count + 1}

    def update(model, %Widget{type: :click, id: "decrement"}),
      do: %{model | count: model.count - 1}

    def update(model, _event), do: model

    def view(model) do
      %{
        id: "root",
        type: "column",
        props: %{},
        children: [
          %{
            id: "count",
            type: "text",
            props: %{"content" => "Count: #{model.count}"},
            children: []
          },
          %{id: "increment", type: "button", props: %{"label" => "+"}, children: []},
          %{id: "decrement", type: "button", props: %{"label" => "-"}, children: []}
        ]
      }
    end
  end

  setup do
    {:ok, pid} = Sim.start(CounterApp)

    on_exit(fn ->
      if Process.alive?(pid), do: Sim.stop(pid)
    end)

    {:ok, pid: pid}
  end

  describe "find/2" do
    test "finds element by ID selector", %{pid: pid} do
      element = Sim.find(pid, "#count")
      assert %Element{} = element
      assert element.id == "count"
      assert element.type == "text"
    end

    test "returns nil for missing element", %{pid: pid} do
      assert Sim.find(pid, "#nonexistent") == nil
    end

    test "finds element by text content", %{pid: pid} do
      element = Sim.find(pid, "Count: 0")
      assert %Element{} = element
      assert element.id == "count"
    end
  end

  describe "find!/2" do
    test "returns element when found", %{pid: pid} do
      assert %Element{id: "increment"} = Sim.find!(pid, "#increment")
    end

    test "raises for missing element", %{pid: pid} do
      assert_raise RuntimeError, ~r/not found/, fn ->
        Sim.find!(pid, "#ghost")
      end
    end
  end

  describe "click/2" do
    test "clicking increment updates model", %{pid: pid} do
      Sim.click(pid, "#increment")
      assert Sim.model(pid).count == 1
    end

    test "clicking decrement updates model", %{pid: pid} do
      Sim.click(pid, "#decrement")
      assert Sim.model(pid).count == -1
    end

    test "multiple clicks accumulate", %{pid: pid} do
      Sim.click(pid, "#increment")
      Sim.click(pid, "#increment")
      Sim.click(pid, "#increment")
      assert Sim.model(pid).count == 3
    end

    test "mixed clicks accumulate correctly", %{pid: pid} do
      Sim.click(pid, "#increment")
      Sim.click(pid, "#increment")
      Sim.click(pid, "#decrement")
      assert Sim.model(pid).count == 1
    end
  end

  describe "model/1" do
    test "returns initial model", %{pid: pid} do
      assert Sim.model(pid) == %{count: 0}
    end

    test "returns updated model after interaction", %{pid: pid} do
      Sim.click(pid, "#increment")
      assert Sim.model(pid) == %{count: 1}
    end
  end

  describe "tree/1" do
    test "returns normalized tree with string keys", %{pid: pid} do
      tree = Sim.tree(pid)
      assert is_map(tree)
      assert tree["id"] || tree[:id]
    end

    test "tree reflects current model state", %{pid: pid} do
      Sim.click(pid, "#increment")
      tree = Sim.tree(pid)

      # Find the count text node in the tree
      count_node = find_node(tree, "count")
      assert count_node
      props = count_node[:props] || count_node["props"]
      assert props["content"] == "Count: 1"
    end
  end

  describe "reset/1" do
    test "restores initial state", %{pid: pid} do
      Sim.click(pid, "#increment")
      Sim.click(pid, "#increment")
      assert Sim.model(pid).count == 2

      Sim.reset(pid)
      assert Sim.model(pid).count == 0
    end

    test "tree reflects reset state", %{pid: pid} do
      Sim.click(pid, "#increment")
      Sim.reset(pid)

      element = Sim.find(pid, "#count")
      assert Element.text(element) == "Count: 0"
    end
  end

  describe "snapshot/2" do
    test "returns a Snapshot struct with a non-empty hash", %{pid: pid} do
      snap = Sim.snapshot(pid, "my-snapshot")
      assert %Snapshot{} = snap
      assert snap.name == "my-snapshot"
      assert snap.hash != ""
      assert String.length(snap.hash) == 64
    end

    test "produces consistent hashes for the same tree state", %{pid: pid} do
      snap1 = Sim.snapshot(pid, "a")
      snap2 = Sim.snapshot(pid, "b")
      assert snap1.hash == snap2.hash
    end

    test "produces different hashes after state changes", %{pid: pid} do
      snap_before = Sim.snapshot(pid, "before")
      Sim.click(pid, "#increment")
      snap_after = Sim.snapshot(pid, "after")
      refute snap_before.hash == snap_after.hash
    end
  end

  describe "screenshot/2" do
    test "returns a Screenshot struct with empty hash (no-op)", %{pid: pid} do
      shot = Sim.screenshot(pid, "my-screenshot")
      assert %Screenshot{} = shot
      assert shot.name == "my-screenshot"
      assert shot.hash == ""
      assert shot.size == {0, 0}
      assert shot.rgba_data == nil
    end

    test "assert_screenshot is a no-op on sim (empty hash accepted)", %{pid: pid} do
      session = %Session{backend: Sim, pid: pid}
      Process.put(:julep_test_session, session)

      assert Julep.Test.Helpers.assert_screenshot("sim-noop-test") == :ok
      refute File.exists?("test/screenshots/sim-noop-test.sha256")
    end
  end

  describe "command processing" do
    defmodule AsyncApp do
      use Julep.App

      def init(_opts), do: %{value: nil}

      def update(model, %Widget{type: :click, id: "fetch"}) do
        cmd = Julep.Command.async(fn -> 42 end, :fetched)
        {model, cmd}
      end

      def update(model, %Julep.Event.Async{tag: :fetched, result: result}),
        do: %{model | value: result}

      def update(model, _event), do: model

      def view(model) do
        %{
          id: "root",
          type: "column",
          props: %{},
          children: [
            %{
              id: "display",
              type: "text",
              props: %{"content" => "Value: #{inspect(model.value)}"},
              children: []
            },
            %{id: "fetch", type: "button", props: %{"label" => "Fetch"}, children: []}
          ]
        }
      end
    end

    test "async command is executed and result dispatched through update" do
      {:ok, pid} = Sim.start(AsyncApp)
      on_exit(fn -> if Process.alive?(pid), do: Sim.stop(pid) end)

      assert Sim.model(pid).value == nil

      Sim.click(pid, "#fetch")
      assert Sim.model(pid).value == 42
    end

    defmodule DoneApp do
      use Julep.App

      def init(_opts), do: %{greeting: nil}

      def update(model, %Widget{type: :click, id: "greet"}) do
        cmd = Julep.Command.done("world", fn name -> {:greeted, "hello #{name}"} end)
        {model, cmd}
      end

      def update(model, {:greeted, msg}), do: %{model | greeting: msg}
      def update(model, _event), do: model

      def view(model) do
        %{
          id: "root",
          type: "column",
          props: %{},
          children: [
            %{
              id: "msg",
              type: "text",
              props: %{"content" => inspect(model.greeting)},
              children: []
            },
            %{id: "greet", type: "button", props: %{"label" => "Greet"}, children: []}
          ]
        }
      end
    end

    test "done command maps value and dispatches through update" do
      {:ok, pid} = Sim.start(DoneApp)
      on_exit(fn -> if Process.alive?(pid), do: Sim.stop(pid) end)

      Sim.click(pid, "#greet")
      assert Sim.model(pid).greeting == "hello world"
    end

    defmodule SkippedOpsApp do
      use Julep.App

      def init(_opts), do: %{clicked: false}

      def update(model, %Widget{type: :click, id: "go"}) do
        cmds = [
          Julep.Command.focus("some_input"),
          Julep.Command.scroll_to("scroller", 0),
          Julep.Command.close_window("win"),
          Julep.Command.none()
        ]

        {%{model | clicked: true}, cmds}
      end

      def update(model, _event), do: model

      def view(model) do
        %{
          id: "root",
          type: "column",
          props: %{},
          children: [
            %{id: "go", type: "button", props: %{"label" => "Go"}, children: []},
            %{
              id: "status",
              type: "text",
              props: %{"content" => "clicked=#{model.clicked}"},
              children: []
            }
          ]
        }
      end
    end

    test "widget ops and window ops are silently skipped" do
      {:ok, pid} = Sim.start(SkippedOpsApp)
      on_exit(fn -> if Process.alive?(pid), do: Sim.stop(pid) end)

      Sim.click(pid, "#go")
      assert Sim.model(pid).clicked == true
    end

    defmodule ChainedAsyncApp do
      use Julep.App

      def init(_opts), do: %{steps: []}

      def update(model, %Widget{type: :click, id: "start"}) do
        cmd = Julep.Command.async(fn -> :step_1 end, :chain)
        {model, cmd}
      end

      def update(model, %Julep.Event.Async{tag: :chain, result: :step_1}) do
        model = %{model | steps: model.steps ++ [:step_1]}
        cmd = Julep.Command.async(fn -> :step_2 end, :chain)
        {model, cmd}
      end

      def update(model, %Julep.Event.Async{tag: :chain, result: :step_2}) do
        model = %{model | steps: model.steps ++ [:step_2]}
        cmd = Julep.Command.async(fn -> :step_3 end, :chain)
        {model, cmd}
      end

      def update(model, %Julep.Event.Async{tag: :chain, result: :step_3}) do
        %{model | steps: model.steps ++ [:step_3]}
      end

      def update(model, _event), do: model

      def view(model) do
        %{
          id: "root",
          type: "column",
          props: %{},
          children: [
            %{id: "start", type: "button", props: %{"label" => "Start"}, children: []},
            %{
              id: "steps",
              type: "text",
              props: %{"content" => inspect(model.steps)},
              children: []
            }
          ]
        }
      end
    end

    test "chained async commands are processed to completion" do
      {:ok, pid} = Sim.start(ChainedAsyncApp)
      on_exit(fn -> if Process.alive?(pid), do: Sim.stop(pid) end)

      Sim.click(pid, "#start")
      assert Sim.model(pid).steps == [:step_1, :step_2, :step_3]
    end

    defmodule BatchApp do
      use Julep.App

      def init(_opts), do: %{a: nil, b: nil}

      def update(model, %Widget{type: :click, id: "go"}) do
        cmds =
          Julep.Command.batch([
            Julep.Command.async(fn -> :val_a end, :got_a),
            Julep.Command.async(fn -> :val_b end, :got_b)
          ])

        {model, cmds}
      end

      def update(model, %Julep.Event.Async{tag: :got_a, result: val}), do: %{model | a: val}
      def update(model, %Julep.Event.Async{tag: :got_b, result: val}), do: %{model | b: val}
      def update(model, _event), do: model

      def view(_model) do
        %{
          id: "root",
          type: "column",
          props: %{},
          children: [
            %{id: "go", type: "button", props: %{"label" => "Go"}, children: []}
          ]
        }
      end
    end

    test "batch commands are unwrapped and each sub-command is processed" do
      {:ok, pid} = Sim.start(BatchApp)
      on_exit(fn -> if Process.alive?(pid), do: Sim.stop(pid) end)

      Sim.click(pid, "#go")
      model = Sim.model(pid)
      assert model.a == :val_a
      assert model.b == :val_b
    end

    defmodule StreamApp do
      use Julep.App

      def init(_opts), do: %{chunks: [], final: nil}

      def update(model, %Widget{type: :click, id: "stream"}) do
        cmd =
          Julep.Command.stream(
            fn emit ->
              emit.({:chunk, "a"})
              emit.({:chunk, "b"})
              emit.({:chunk, "c"})
              :done
            end,
            :import
          )

        {model, cmd}
      end

      def update(model, %Julep.Event.Stream{tag: :import, value: {:chunk, val}}) do
        %{model | chunks: model.chunks ++ [val]}
      end

      def update(model, %Julep.Event.Async{tag: :import, result: :done}) do
        %{model | final: :done}
      end

      def update(model, _event), do: model

      def view(_model) do
        %{
          id: "root",
          type: "column",
          props: %{},
          children: [
            %{id: "stream", type: "button", props: %{"label" => "Stream"}, children: []}
          ]
        }
      end
    end

    test "stream command processes emitted values and final result" do
      {:ok, pid} = Sim.start(StreamApp)
      on_exit(fn -> if Process.alive?(pid), do: Sim.stop(pid) end)

      Sim.click(pid, "#stream")
      model = Sim.model(pid)
      assert model.chunks == ["a", "b", "c"]
      assert model.final == :done
    end

    defmodule InitCommandApp do
      use Julep.App

      def init(_opts) do
        cmd = Julep.Command.async(fn -> "loaded" end, :init_data)
        {%{data: nil}, cmd}
      end

      def update(model, %Julep.Event.Async{tag: :init_data, result: val}),
        do: %{model | data: val}

      def update(model, _event), do: model

      def view(model) do
        %{
          id: "root",
          type: "text",
          props: %{"content" => inspect(model.data)},
          children: []
        }
      end
    end

    test "commands from init are processed" do
      {:ok, pid} = Sim.start(InitCommandApp)
      on_exit(fn -> if Process.alive?(pid), do: Sim.stop(pid) end)

      assert Sim.model(pid).data == "loaded"
    end

    test "await_async is a no-op (work is already done synchronously)" do
      {:ok, pid} = Sim.start(AsyncApp)
      on_exit(fn -> if Process.alive?(pid), do: Sim.stop(pid) end)

      assert Sim.await_async(pid, :whatever) == :ok
    end
  end

  # -- Helpers --

  defp find_node(nil, _id), do: nil

  defp find_node(%{} = node, id) do
    node_id = node[:id] || node["id"]

    if node_id == id do
      node
    else
      children = node[:children] || node["children"] || []
      Enum.find_value(children, &find_node(&1, id))
    end
  end
end
