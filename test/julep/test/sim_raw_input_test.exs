defmodule Julep.Test.SimRawInputTest do
  use ExUnit.Case, async: true

  alias Julep.Test.Backend.Sim

  defmodule KeyApp do
    use Julep.App

    def init(_opts), do: %{events: [], cursor: {0, 0}}

    def update(model, {:key_press, %Julep.KeyEvent{} = event}) do
      %{model | events: model.events ++ [{:press, event.key, event.modifiers}]}
    end

    def update(model, {:key_release, %Julep.KeyEvent{} = event}) do
      %{model | events: model.events ++ [{:release, event.key, event.modifiers}]}
    end

    def update(model, {:cursor_moved, x, y}) do
      %{model | cursor: {x, y}}
    end

    def update(model, _event), do: model

    def view(model) do
      %{
        id: "root",
        type: "column",
        props: %{},
        children: [
          %{id: "info", type: "text", props: %{"content" => inspect(model)}, children: []}
        ]
      }
    end
  end

  setup do
    {:ok, pid} = Sim.start(KeyApp)
    on_exit(fn -> if Process.alive?(pid), do: Sim.stop(pid) end)
    {:ok, pid: pid}
  end

  describe "press/2" do
    test "dispatches key_press event", %{pid: pid} do
      Sim.press(pid, "a")
      model = Sim.model(pid)

      assert [{:press, "a", %Julep.KeyModifiers{ctrl: false, shift: false}}] = model.events
    end

    test "parses modifier keys", %{pid: pid} do
      Sim.press(pid, "ctrl+s")
      model = Sim.model(pid)

      [{:press, key, mods}] = model.events
      assert key == "s"
      assert mods.ctrl == true
      assert mods.command == true
      assert mods.shift == false
    end

    test "parses shift+enter", %{pid: pid} do
      Sim.press(pid, "shift+enter")
      model = Sim.model(pid)

      [{:press, key, mods}] = model.events
      assert key == :enter
      assert mods.shift == true
      assert mods.ctrl == false
    end

    test "parses multiple modifiers", %{pid: pid} do
      Sim.press(pid, "ctrl+shift+z")
      model = Sim.model(pid)

      [{:press, key, mods}] = model.events
      assert key == "z"
      assert mods.ctrl == true
      assert mods.shift == true
    end
  end

  describe "release/2" do
    test "dispatches key_release event", %{pid: pid} do
      Sim.release(pid, "escape")
      model = Sim.model(pid)

      assert [{:release, :escape, _mods}] = model.events
    end
  end

  describe "type_key/2" do
    test "dispatches both press and release events", %{pid: pid} do
      Sim.type_key(pid, "enter")
      model = Sim.model(pid)

      assert [
               {:press, :enter, _},
               {:release, :enter, _}
             ] = model.events
    end

    test "preserves modifiers across press and release", %{pid: pid} do
      Sim.type_key(pid, "ctrl+c")
      model = Sim.model(pid)

      assert [
               {:press, "c", press_mods},
               {:release, "c", release_mods}
             ] = model.events

      assert press_mods.ctrl == true
      assert release_mods.ctrl == true
    end
  end

  describe "move_to/3" do
    test "dispatches cursor_moved event", %{pid: pid} do
      Sim.move_to(pid, 100, 200)
      model = Sim.model(pid)

      assert model.cursor == {100, 200}
    end
  end

  describe "named keys" do
    test "maps named key strings to atoms", %{pid: pid} do
      for {name, expected} <- [
            {"tab", :tab},
            {"backspace", :backspace},
            {"space", :space},
            {"delete", :delete},
            {"up", :up},
            {"down", :down},
            {"left", :left},
            {"right", :right},
            {"home", :home},
            {"end", :end},
            {"page_up", :page_up},
            {"page_down", :page_down},
            {"f1", :f1},
            {"f12", :f12}
          ] do
        Sim.press(pid, name)
        model = Sim.model(pid)
        {_, key, _} = List.last(model.events)
        assert key == expected, "Expected #{inspect(expected)} for #{name}, got #{inspect(key)}"
      end
    end

    test "single characters pass through as strings", %{pid: pid} do
      Sim.press(pid, "x")
      model = Sim.model(pid)

      [{:press, key, _}] = model.events
      assert key == "x"
    end
  end

  describe "key event struct" do
    test "sets text for single character keys", %{pid: pid} do
      # We need a more detailed app to check the full KeyEvent
      defmodule DetailKeyApp do
        use Julep.App
        def init(_), do: %{event: nil}
        def update(model, {:key_press, event}), do: %{model | event: event}
        def update(model, _), do: model

        def view(model) do
          %{id: "r", type: "text", props: %{"content" => inspect(model)}, children: []}
        end
      end

      {:ok, pid2} = Sim.start(DetailKeyApp)
      Sim.press(pid2, "a")
      model = Sim.model(pid2)

      assert model.event.key == "a"
      assert model.event.text == "a"
      assert model.event.repeat == false
      assert model.event.location == :standard

      Sim.press(pid2, "enter")
      model = Sim.model(pid2)
      assert model.event.key == :enter
      assert model.event.text == nil

      Sim.stop(pid2)
    end
  end
end
