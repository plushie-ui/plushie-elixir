defmodule Plushie.AppTest do
  use ExUnit.Case, async: true

  # ---------------------------------------------------------------------------
  # Inline test module that uses the Plushie.App behaviour with only the
  # required callbacks -- subscribe/1 and handle_renderer_exit/2 are left to
  # the defaults injected by `use Plushie.App`.
  # ---------------------------------------------------------------------------

  defmodule MinimalApp do
    use Plushie.App

    def init(_opts), do: %{count: 0}

    def update(model, {:increment}), do: %{model | count: model.count + 1}
    def update(model, _event), do: model

    def view(model), do: %{tag: "text", value: "Count: #{model.count}"}
  end

  # ---------------------------------------------------------------------------
  # Inline test module that overrides both optional callbacks to confirm they
  # are actually overridable.
  # ---------------------------------------------------------------------------

  defmodule FullApp do
    use Plushie.App

    def init(_opts), do: %{status: :idle}
    def update(model, _event), do: model
    def view(model), do: %{tag: "text", value: inspect(model.status)}

    def subscribe(_model), do: [%{type: "timer", interval: 1000}]
    def handle_renderer_exit(model, _reason), do: %{model | status: :reconnecting}
  end

  # ---------------------------------------------------------------------------
  # Behaviour presence
  # ---------------------------------------------------------------------------

  describe "use Plushie.App -- behaviour injection" do
    test "module declares the Plushie.App behaviour" do
      assert Plushie.App in (MinimalApp.module_info(:attributes)[:behaviour] || [])
    end

    test "module exposes all required callbacks as exported functions" do
      exports = MinimalApp.__info__(:functions)
      assert {:init, 1} in exports
      assert {:update, 2} in exports
      assert {:view, 1} in exports
    end

    test "optional callbacks are also exported because use/1 provides defaults" do
      exports = MinimalApp.__info__(:functions)
      assert {:subscribe, 1} in exports
      assert {:handle_renderer_exit, 2} in exports
    end
  end

  # ---------------------------------------------------------------------------
  # Default subscribe/1
  # ---------------------------------------------------------------------------

  describe "default subscribe/1" do
    test "returns an empty list when not overridden" do
      assert MinimalApp.subscribe(%{count: 0}) == []
    end

    test "returns an empty list regardless of model shape" do
      assert MinimalApp.subscribe(nil) == []
      assert MinimalApp.subscribe(%{anything: :goes}) == []
    end
  end

  # ---------------------------------------------------------------------------
  # Default handle_renderer_exit/2
  # ---------------------------------------------------------------------------

  describe "default handle_renderer_exit/2" do
    test "returns the model unchanged" do
      model = %{count: 42}
      assert MinimalApp.handle_renderer_exit(model, :normal) == model
    end

    test "returns the model unchanged regardless of exit reason" do
      model = %{status: :running}
      assert MinimalApp.handle_renderer_exit(model, {:error, :timeout}) == model
      assert MinimalApp.handle_renderer_exit(model, :killed) == model
    end
  end

  # ---------------------------------------------------------------------------
  # Overriding optional callbacks
  # ---------------------------------------------------------------------------

  describe "overriding optional callbacks" do
    test "subscribe/1 returns the overridden value" do
      result = FullApp.subscribe(%{status: :idle})
      assert result == [%{type: "timer", interval: 1000}]
    end

    test "handle_renderer_exit/2 applies the override logic" do
      model = %{status: :idle}
      result = FullApp.handle_renderer_exit(model, :port_closed)
      assert result == %{status: :reconnecting}
    end
  end

  # ---------------------------------------------------------------------------
  # Required callbacks work correctly
  # ---------------------------------------------------------------------------

  describe "required callbacks -- init/1, update/2, view/1" do
    test "init/1 returns the initial model" do
      assert MinimalApp.init([]) == %{count: 0}
    end

    test "update/2 applies events to the model" do
      model = MinimalApp.init([])
      updated = MinimalApp.update(model, {:increment})
      assert updated == %{count: 1}
    end

    test "update/2 returns model unchanged for unrecognised events" do
      model = %{count: 7}
      assert MinimalApp.update(model, {:unknown_event}) == model
    end

    test "view/1 returns a map representation of the UI" do
      model = %{count: 3}
      assert MinimalApp.view(model) == %{tag: "text", value: "Count: 3"}
    end
  end
end
