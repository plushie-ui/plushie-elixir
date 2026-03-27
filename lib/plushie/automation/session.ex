defmodule Plushie.Automation.Session do
  @moduledoc """
  An automation client attached to a running Plushie app.

  The script layer does not start apps itself. Start the app with
  `Plushie.start_link/2` or a mix task, then attach to the running instance
  or runtime process and drive it through the real runtime and bridge.
  """

  alias Plushie.Automation.{Element, Screenshot, Selector}

  @typedoc """
  Automation selector.

  String selectors follow these rules:
  - `"#save"` matches a unique local widget ID
  - `"#form/save"` matches an exact scoped ID
  - bare strings like `"Save"` match visible text
  """
  @type selector :: String.t() | {:role, String.t()} | {:label, String.t()} | :focused

  @type runtime_ref :: GenServer.server()
  @type bridge_ref :: GenServer.server() | nil

  @type t :: %__MODULE__{runtime: runtime_ref(), bridge: bridge_ref()}
  defstruct [:runtime, :bridge]

  @doc """
  Attaches to a running Plushie app.

  Accepted options:
  - `:instance` -- Plushie instance name; resolves runtime and bridge automatically
  - `:runtime` -- runtime pid or registered name
  - `:bridge` -- bridge pid or registered name
  """
  @spec attach(opts :: keyword()) :: t()
  def attach(opts) do
    {runtime, bridge} = resolve_targets(opts)
    %__MODULE__{runtime: runtime, bridge: bridge}
  end

  @spec find(session :: t(), selector :: selector()) :: Element.t() | nil
  def find(%__MODULE__{runtime: runtime}, selector) do
    runtime
    |> Plushie.Runtime.get_tree()
    |> Selector.find(selector)
  end

  @spec find!(session :: t(), selector :: selector()) :: Element.t()
  def find!(%__MODULE__{} = session, selector) do
    case find(session, selector) do
      nil -> raise "element not found: #{inspect(selector)}"
      element -> element
    end
  end

  @spec click(session :: t(), selector :: selector()) :: :ok
  def click(%__MODULE__{} = session, selector), do: interact(session, "click", selector, %{})

  @spec type_text(session :: t(), selector :: selector(), text :: String.t()) :: :ok
  def type_text(%__MODULE__{} = session, selector, text),
    do: interact(session, "type_text", selector, %{text: text})

  @spec submit(session :: t(), selector :: selector()) :: :ok
  def submit(%__MODULE__{} = session, selector) do
    value = read_prop(session, selector, :submit_value)
    interact(session, "submit", selector, %{value: value})
  end

  @spec toggle(session :: t(), selector :: selector(), value :: boolean() | nil) :: :ok
  def toggle(%__MODULE__{} = session, selector, value \\ nil) do
    target =
      if is_boolean(value), do: value, else: not read_prop(session, selector, :toggle_value)

    interact(session, "toggle", selector, %{value: target})
  end

  @spec select(session :: t(), selector :: selector(), value :: term()) :: :ok
  def select(%__MODULE__{} = session, selector, value),
    do: interact(session, "select", selector, %{value: value})

  @spec slide(session :: t(), selector :: selector(), value :: number()) :: :ok
  def slide(%__MODULE__{} = session, selector, value),
    do: interact(session, "slide", selector, %{value: value})

  @spec model(session :: t()) :: term()
  def model(%__MODULE__{runtime: runtime}), do: Plushie.Runtime.get_model(runtime)

  @spec tree(session :: t()) :: map()
  def tree(%__MODULE__{runtime: runtime}), do: Plushie.Runtime.get_tree(runtime)

  @spec screenshot(session :: t(), name :: String.t(), opts :: keyword()) :: Screenshot.t()
  def screenshot(session, name, opts \\ [])

  def screenshot(%__MODULE__{bridge: nil}, _name, _opts) do
    raise ArgumentError,
          "session is not attached to a bridge; screenshot requires :instance or :bridge"
  end

  def screenshot(%__MODULE__{bridge: bridge}, name, opts) do
    response = Plushie.Bridge.screenshot(bridge, name, opts)
    Screenshot.from_response(response)
  end

  @spec await_async(session :: t(), tag :: atom(), timeout :: non_neg_integer()) :: :ok
  def await_async(%__MODULE__{runtime: runtime}, tag, timeout \\ 5000),
    do: Plushie.Runtime.await_async(runtime, tag, timeout)

  @spec press(session :: t(), key :: String.t()) :: :ok
  def press(%__MODULE__{} = session, key) do
    {key_name, mods} = parse_key(key)
    interact(session, "press", nil, %{key: key_name, modifiers: mods})
  end

  @spec release(session :: t(), key :: String.t()) :: :ok
  def release(%__MODULE__{} = session, key) do
    {key_name, mods} = parse_key(key)
    interact(session, "release", nil, %{key: key_name, modifiers: mods})
  end

  @spec move_to(session :: t(), x :: number(), y :: number()) :: :ok
  def move_to(%__MODULE__{} = session, x, y), do: interact(session, "move_to", nil, %{x: x, y: y})

  @spec type_key(session :: t(), key :: String.t()) :: :ok
  def type_key(%__MODULE__{} = session, key) do
    {key_name, mods} = parse_key(key)
    interact(session, "type_key", nil, %{key: key_name, modifiers: mods})
  end

  @spec scroll(
          session :: t(),
          selector :: selector(),
          delta_x :: number(),
          delta_y :: number()
        ) :: :ok
  def scroll(%__MODULE__{} = session, selector, delta_x \\ 0, delta_y \\ 0),
    do: interact(session, "scroll", selector, %{delta_x: delta_x, delta_y: delta_y})

  @spec paste(session :: t(), selector :: selector(), text :: String.t()) :: :ok
  def paste(%__MODULE__{} = session, selector, text),
    do: interact(session, "paste", selector, %{text: text})

  @spec sort(
          session :: t(),
          selector :: selector(),
          column :: String.t(),
          direction :: String.t()
        ) :: :ok
  def sort(%__MODULE__{} = session, selector, column, direction \\ "asc"),
    do: interact(session, "sort", selector, %{column: column, direction: direction})

  @spec canvas_press(
          session :: t(),
          selector :: selector(),
          x :: number(),
          y :: number(),
          button :: String.t()
        ) :: :ok
  def canvas_press(%__MODULE__{} = session, selector, x, y, button \\ "left"),
    do: interact(session, "canvas_press", selector, %{x: x, y: y, button: button})

  @spec canvas_release(
          session :: t(),
          selector :: selector(),
          x :: number(),
          y :: number(),
          button :: String.t()
        ) :: :ok
  def canvas_release(%__MODULE__{} = session, selector, x, y, button \\ "left"),
    do: interact(session, "canvas_release", selector, %{x: x, y: y, button: button})

  @spec canvas_move(session :: t(), selector :: selector(), x :: number(), y :: number()) :: :ok
  def canvas_move(%__MODULE__{} = session, selector, x, y),
    do: interact(session, "canvas_move", selector, %{x: x, y: y})

  @spec pane_focus_cycle(session :: t(), selector :: selector()) :: :ok
  def pane_focus_cycle(%__MODULE__{} = session, selector),
    do: interact(session, "pane_focus_cycle", selector, %{})

  @spec register_effect_stub(session :: t(), kind :: String.t(), response :: term()) :: :ok
  def register_effect_stub(%__MODULE__{runtime: runtime}, kind, response),
    do: Plushie.Runtime.register_effect_stub(runtime, kind, response)

  @spec unregister_effect_stub(session :: t(), kind :: String.t()) :: :ok
  def unregister_effect_stub(%__MODULE__{runtime: runtime}, kind),
    do: Plushie.Runtime.unregister_effect_stub(runtime, kind)

  @spec get_diagnostics(session :: t()) :: [Plushie.Event.SystemEvent.t()]
  def get_diagnostics(%__MODULE__{runtime: runtime}), do: Plushie.Runtime.get_diagnostics(runtime)

  defp resolve_targets(opts) do
    case Keyword.fetch(opts, :instance) do
      {:ok, instance} ->
        {Plushie.runtime_for(instance), Plushie.bridge_for(instance)}

      :error ->
        runtime = Keyword.fetch!(opts, :runtime)
        {runtime, Keyword.get(opts, :bridge)}
    end
  end

  defp interact(%__MODULE__{runtime: runtime}, action, selector, payload) do
    tree = Plushie.Runtime.get_tree(runtime)
    encoded = Selector.encode(selector, tree)

    case Plushie.Runtime.interact(runtime, action, encoded, payload) do
      :ok -> :ok
      {:error, reason} -> raise "interaction failed: #{inspect(reason)}"
    end
  catch
    :exit, reason -> raise "runtime crashed during interaction: #{inspect(reason)}"
  end

  defp read_prop(%__MODULE__{} = session, selector, :toggle_value) do
    props = selector_props(session, selector)
    props[:is_toggled] || props["is_toggled"] || props[:checked] || props["checked"] || false
  end

  defp read_prop(%__MODULE__{} = session, selector, :submit_value) do
    props = selector_props(session, selector)
    props[:value] || props["value"] || ""
  end

  defp selector_props(%__MODULE__{} = session, selector) do
    node =
      session
      |> tree()
      |> Selector.find_node(selector)

    (node && (node[:props] || node["props"])) || %{}
  end

  @valid_modifiers %{
    "shift" => :shift,
    "ctrl" => :ctrl,
    "alt" => :alt,
    "logo" => :logo,
    "command" => :command
  }

  @named_key_lookup Plushie.Protocol.Keys.named_key_names()
                    |> Enum.map(fn name -> {String.downcase(name), name} end)
                    |> Map.new()

  defp parse_key(key) when is_binary(key) do
    parts = String.split(key, "+")
    {mods, [key_name]} = Enum.split(parts, -1)

    modifiers =
      for mod <- mods, into: %{} do
        case Map.get(@valid_modifiers, String.downcase(mod)) do
          nil ->
            raise ArgumentError,
                  "unknown modifier #{inspect(mod)} in key #{inspect(key)}. Valid: shift, ctrl, alt, logo, command"

          atom ->
            {atom, true}
        end
      end

    key_name =
      cond do
        String.length(key_name) == 1 ->
          String.downcase(key_name)

        resolved = Map.get(@named_key_lookup, String.downcase(key_name)) ->
          resolved

        true ->
          raise ArgumentError,
                "unknown key #{inspect(key_name)} in #{inspect(key)}. See Plushie.Protocol.Keys for valid names"
      end

    {key_name, modifiers}
  end
end
