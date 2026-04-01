defmodule Plushie.Widget.Window do
  @moduledoc """
  Top-level window container node.

  Holds window-level configuration (title, size, position, decorations,
  etc.) and wraps the child widget tree for that window. The runtime
  detects window nodes by their `"window"` type string and synchronizes
  open/close/update operations with the Rust binary via the bridge.

  ## Props

  - `title` (string) -- window title bar text.
  - `size` ({width, height}) -- initial window size in pixels.
  - `width` (number) -- window width in pixels (alternative to `size`).
  - `height` (number) -- window height in pixels (alternative to `size`).
  - `position` ({x, y}) -- initial window position.
  - `min_size` ({width, height}) -- minimum window dimensions.
  - `max_size` ({width, height}) -- maximum window dimensions.
  - `maximized` (boolean) -- start maximized.
  - `fullscreen` (boolean) -- start in fullscreen mode.
  - `visible` (boolean) -- whether the window is visible.
  - `resizable` (boolean) -- whether the window can be resized.
  - `closeable` (boolean) -- whether the window close button is shown.
  - `minimizable` (boolean) -- whether the window can be minimized.
  - `decorations` (boolean) -- whether to show window decorations (title bar, borders).
  - `transparent` (boolean) -- whether the window background is transparent.
  - `blur` (boolean) -- whether to blur the window background.
  - `level` (atom) -- window stacking level (`:normal`, `:always_on_top`, `:always_on_bottom`).
  - `exit_on_close_request` (boolean) -- whether closing the window exits the app.
  - `scale_factor` (number) -- window scale factor override.
  """

  alias Plushie.Widget.Build

  @type option ::
          {:title, String.t()}
          | {:size, {number(), number()}}
          | {:width, number()}
          | {:height, number()}
          | {:position, {number(), number()}}
          | {:min_size, {number(), number()}}
          | {:max_size, {number(), number()}}
          | {:maximized, boolean()}
          | {:fullscreen, boolean()}
          | {:visible, boolean()}
          | {:resizable, boolean()}
          | {:closeable, boolean()}
          | {:minimizable, boolean()}
          | {:decorations, boolean()}
          | {:transparent, boolean()}
          | {:blur, boolean()}
          | {:level, atom()}
          | {:exit_on_close_request, boolean()}
          | {:scale_factor, number()}

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t() | nil,
          size: {number(), number()} | nil,
          width: number() | nil,
          height: number() | nil,
          position: {number(), number()} | nil,
          min_size: {number(), number()} | nil,
          max_size: {number(), number()} | nil,
          maximized: boolean() | nil,
          fullscreen: boolean() | nil,
          visible: boolean() | nil,
          resizable: boolean() | nil,
          closeable: boolean() | nil,
          minimizable: boolean() | nil,
          decorations: boolean() | nil,
          transparent: boolean() | nil,
          blur: boolean() | nil,
          level: atom() | nil,
          exit_on_close_request: boolean() | nil,
          scale_factor: number() | nil,
          children: [Plushie.Widget.child()]
        }

  defstruct [
    :id,
    :title,
    :size,
    :width,
    :height,
    :position,
    :min_size,
    :max_size,
    :maximized,
    :fullscreen,
    :visible,
    :resizable,
    :closeable,
    :minimizable,
    :decorations,
    :transparent,
    :blur,
    :level,
    :exit_on_close_request,
    :scale_factor,
    children: []
  ]

  @valid_option_keys ~w(title size width height position min_size max_size maximized fullscreen visible resizable closeable minimizable decorations transparent blur level exit_on_close_request scale_factor)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__, do: %{}

  @doc "Creates a new window struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing window struct."
  @spec with_options(window :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = w, []), do: w

  def with_options(%__MODULE__{} = w, opts) do
    Enum.reduce(opts, w, fn
      {:title, v}, acc -> title(acc, v)
      {:size, v}, acc -> size(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:position, v}, acc -> position(acc, v)
      {:min_size, v}, acc -> min_size(acc, v)
      {:max_size, v}, acc -> max_size(acc, v)
      {:maximized, v}, acc -> maximized(acc, v)
      {:fullscreen, v}, acc -> fullscreen(acc, v)
      {:visible, v}, acc -> visible(acc, v)
      {:resizable, v}, acc -> resizable(acc, v)
      {:closeable, v}, acc -> closeable(acc, v)
      {:minimizable, v}, acc -> minimizable(acc, v)
      {:decorations, v}, acc -> decorations(acc, v)
      {:transparent, v}, acc -> transparent(acc, v)
      {:blur, v}, acc -> blur(acc, v)
      {:level, v}, acc -> level(acc, v)
      {:exit_on_close_request, v}, acc -> exit_on_close_request(acc, v)
      {:scale_factor, v}, acc -> scale_factor(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the window title."
  @spec title(window :: t(), title :: String.t()) :: t()
  def title(%__MODULE__{} = w, title) when is_binary(title), do: %{w | title: title}

  @doc "Sets the window size as a `{width, height}` tuple."
  @spec size(window :: t(), size :: {number(), number()}) :: t()
  def size(%__MODULE__{} = w, {_w, _h} = size), do: %{w | size: size}

  @doc "Sets the window width."
  @spec width(window :: t(), width :: number()) :: t()
  def width(%__MODULE__{} = w, width) when is_number(width), do: %{w | width: width}

  @doc "Sets the window height."
  @spec height(window :: t(), height :: number()) :: t()
  def height(%__MODULE__{} = w, height) when is_number(height), do: %{w | height: height}

  @doc "Sets the initial window position."
  @spec position(window :: t(), position :: {number(), number()}) :: t()
  def position(%__MODULE__{} = w, {_x, _y} = pos), do: %{w | position: pos}

  @doc "Sets the minimum window size."
  @spec min_size(window :: t(), min_size :: {number(), number()}) :: t()
  def min_size(%__MODULE__{} = w, {_w, _h} = min), do: %{w | min_size: min}

  @doc "Sets the maximum window size."
  @spec max_size(window :: t(), max_size :: {number(), number()}) :: t()
  def max_size(%__MODULE__{} = w, {_w, _h} = max), do: %{w | max_size: max}

  @doc "Sets whether the window starts maximized."
  @spec maximized(window :: t(), maximized :: boolean()) :: t()
  def maximized(%__MODULE__{} = w, maximized) when is_boolean(maximized),
    do: %{w | maximized: maximized}

  @doc "Sets whether the window starts in fullscreen."
  @spec fullscreen(window :: t(), fullscreen :: boolean()) :: t()
  def fullscreen(%__MODULE__{} = w, fullscreen) when is_boolean(fullscreen),
    do: %{w | fullscreen: fullscreen}

  @doc "Sets whether the window is visible."
  @spec visible(window :: t(), visible :: boolean()) :: t()
  def visible(%__MODULE__{} = w, visible) when is_boolean(visible),
    do: %{w | visible: visible}

  @doc "Sets whether the window is resizable."
  @spec resizable(window :: t(), resizable :: boolean()) :: t()
  def resizable(%__MODULE__{} = w, resizable) when is_boolean(resizable),
    do: %{w | resizable: resizable}

  @doc "Sets whether the window close button is shown."
  @spec closeable(window :: t(), closeable :: boolean()) :: t()
  def closeable(%__MODULE__{} = w, closeable) when is_boolean(closeable),
    do: %{w | closeable: closeable}

  @doc "Sets whether the window can be minimized."
  @spec minimizable(window :: t(), minimizable :: boolean()) :: t()
  def minimizable(%__MODULE__{} = w, minimizable) when is_boolean(minimizable),
    do: %{w | minimizable: minimizable}

  @doc "Sets whether to show window decorations."
  @spec decorations(window :: t(), decorations :: boolean()) :: t()
  def decorations(%__MODULE__{} = w, decorations) when is_boolean(decorations),
    do: %{w | decorations: decorations}

  @doc "Sets whether the window background is transparent."
  @spec transparent(window :: t(), transparent :: boolean()) :: t()
  def transparent(%__MODULE__{} = w, transparent) when is_boolean(transparent),
    do: %{w | transparent: transparent}

  @doc "Sets whether to blur the window background."
  @spec blur(window :: t(), blur :: boolean()) :: t()
  def blur(%__MODULE__{} = w, blur) when is_boolean(blur), do: %{w | blur: blur}

  @doc "Sets the window stacking level."
  @spec level(window :: t(), level :: atom()) :: t()
  def level(%__MODULE__{} = w, level) when is_atom(level), do: %{w | level: level}

  @doc "Sets whether closing the window exits the app."
  @spec exit_on_close_request(window :: t(), exit_on_close_request :: boolean()) :: t()
  def exit_on_close_request(%__MODULE__{} = w, v) when is_boolean(v),
    do: %{w | exit_on_close_request: v}

  @doc "Sets the window scale factor."
  @spec scale_factor(window :: t(), scale_factor :: number()) :: t()
  def scale_factor(%__MODULE__{} = w, scale_factor) when is_number(scale_factor),
    do: %{w | scale_factor: scale_factor}

  @doc "Appends a child to the window."
  @spec push(window :: t(), child :: Plushie.Widget.child()) :: t()
  def push(%__MODULE__{} = w, child), do: %{w | children: [child | w.children]}

  @doc "Appends multiple children to the window."
  @spec extend(window :: t(), children :: [Plushie.Widget.child()]) ::
          t()
  def extend(%__MODULE__{} = w, children),
    do: %{w | children: Enum.reverse(children) ++ w.children}

  @doc "Converts this window struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(window :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = w), do: Plushie.Widget.to_node(w)

  defimpl Plushie.Widget.WidgetProtocol do
    import Plushie.Widget.Build

    def to_node(w) do
      children = Enum.reverse(w.children)
      validate_single_child!(w.id, "window", children)

      props =
        %{}
        |> put_if(w.title, :title)
        |> put_if(w.size, :size)
        |> put_if(w.width, :width)
        |> put_if(w.height, :height)
        |> put_if(w.position, :position)
        |> put_if(w.min_size, :min_size)
        |> put_if(w.max_size, :max_size)
        |> put_if(w.maximized, :maximized)
        |> put_if(w.fullscreen, :fullscreen)
        |> put_if(w.visible, :visible)
        |> put_if(w.resizable, :resizable)
        |> put_if(w.closeable, :closeable)
        |> put_if(w.minimizable, :minimizable)
        |> put_if(w.decorations, :decorations)
        |> put_if(w.transparent, :transparent)
        |> put_if(w.blur, :blur)
        |> put_if(w.level, :level)
        |> put_if(w.exit_on_close_request, :exit_on_close_request)
        |> put_if(w.scale_factor, :scale_factor)

      %{
        id: w.id,
        type: "window",
        props: props,
        children: children_to_nodes(children)
      }
    end
  end
end
