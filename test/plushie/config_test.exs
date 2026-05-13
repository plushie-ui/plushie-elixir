defmodule Plushie.ConfigTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  # async: false because we manipulate application config and check
  # supervisor children.

  defmodule ConfigTestApp do
    use Plushie.App

    def init(_opts), do: %{value: 0}
    def update(model, _event), do: model

    def view(_model) do
      import Plushie.UI

      window "main" do
        column do
          text("ok")
        end
      end
    end
  end

  describe "code_reloader config" do
    setup do
      previous = Application.get_env(:plushie, :code_reloader)
      Application.delete_env(:plushie, :code_reloader)

      on_exit(fn ->
        if previous != nil do
          Application.put_env(:plushie, :code_reloader, previous)
        else
          Application.delete_env(:plushie, :code_reloader)
        end
      end)

      :ok
    end

    test "DevServer is not started when code_reloader is not configured" do
      Application.delete_env(:plushie, :code_reloader)
      name = :"config_test_#{System.unique_integer([:positive])}"

      capture_log(fn ->
        {:ok, pid} = Plushie.start_link(ConfigTestApp, name: name)

        child_modules =
          pid
          |> Supervisor.which_children()
          |> Enum.map(fn {id, _, _, _} -> id end)

        refute Plushie.Dev.DevServer in child_modules
        Plushie.stop(name)
      end)
    end

    test "DevServer is started when code_reloader is set to true" do
      Application.put_env(:plushie, :code_reloader, true)
      name = :"config_test_#{System.unique_integer([:positive])}"

      capture_log(fn ->
        {:ok, pid} = Plushie.start_link(ConfigTestApp, name: name)

        child_modules =
          pid
          |> Supervisor.which_children()
          |> Enum.map(fn {id, _, _, _} -> id end)

        assert Plushie.Dev.DevServer in child_modules
        Plushie.stop(name)
      end)
    end

    test "DevServer is started when code_reloader is a keyword list" do
      Application.put_env(:plushie, :code_reloader, debounce_ms: 200)
      name = :"config_test_#{System.unique_integer([:positive])}"

      capture_log(fn ->
        {:ok, pid} = Plushie.start_link(ConfigTestApp, name: name)

        child_modules =
          pid
          |> Supervisor.which_children()
          |> Enum.map(fn {id, _, _, _} -> id end)

        assert Plushie.Dev.DevServer in child_modules
        Plushie.stop(name)
      end)
    end

    test "DevServer is not started when code_reloader is nil" do
      Application.put_env(:plushie, :code_reloader, nil)
      name = :"config_test_#{System.unique_integer([:positive])}"

      capture_log(fn ->
        {:ok, pid} = Plushie.start_link(ConfigTestApp, name: name)

        child_modules =
          pid
          |> Supervisor.which_children()
          |> Enum.map(fn {id, _, _, _} -> id end)

        refute Plushie.Dev.DevServer in child_modules
        Plushie.stop(name)
      end)
    end
  end

  describe "start_link option validation" do
    test "rejects non-atom :name" do
      assert_raise ArgumentError, ~r/expected :name to be an atom/, fn ->
        Plushie.start_link(ConfigTestApp, name: "gui")
      end
    end

    test "rejects non-module :app" do
      Process.flag(:trap_exit, true)

      result =
        try do
          Plushie.start_link("NotAModule", name: :val_test_1)
        catch
          :exit, reason -> {:exit, reason}
        end

      assert match?({:exit, _}, result) or match?({:error, _}, result)
      Process.flag(:trap_exit, false)
    end

    test "rejects module without App behaviour" do
      Process.flag(:trap_exit, true)

      result =
        try do
          Plushie.start_link(String, name: :val_test_2)
        catch
          :exit, reason -> {:exit, reason}
        end

      assert match?({:exit, _}, result) or match?({:error, _}, result)
      Process.flag(:trap_exit, false)
    end

    test "rejects invalid transport" do
      Process.flag(:trap_exit, true)

      result =
        try do
          Plushie.start_link(ConfigTestApp, name: :val_test_3, transport: :invalid)
        catch
          :exit, reason -> {:exit, reason}
        end

      assert match?({:exit, _}, result) or match?({:error, _}, result)
      Process.flag(:trap_exit, false)
    end
  end
end
