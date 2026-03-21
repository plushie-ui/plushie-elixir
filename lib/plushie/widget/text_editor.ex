defmodule Plushie.Widget.TextEditor do
  @moduledoc """
  Text editor -- multi-line editable text area.

  The renderer manages an internal `text_editor::Content` cache keyed by
  node ID. The `content` prop seeds the initial content.

  ## Props

  - `content` (string) -- initial text content (used to seed the editor cache).
  - `placeholder` (string) -- placeholder text shown when editor is empty.
  - `width` (length) -- editor width. Default: shrink. See `Plushie.Type.Length`.
  - `height` (length) -- editor height. Default: shrink. See `Plushie.Type.Length`.
  - `min_height` (number) -- minimum height in pixels.
  - `max_height` (number) -- maximum height in pixels.
  - `font` (string | map) -- font specification. See `Plushie.Type.Font`.
  - `size` (number) -- font size in pixels.
  - `line_height` (number | map) -- line height.
  - `padding` (number) -- uniform padding in pixels.
  - `wrapping` -- text wrapping mode. See `Plushie.Type.Wrapping`.
  - `ime_purpose` (string) -- IME input purpose hint: `"normal"`, `"secure"`, `"terminal"`.
    Default: `"normal"`.
  - `highlight_syntax` (string) -- language extension for syntax highlighting (e.g. "rs", "py", "ex").
  - `highlight_theme` (string) -- highlighter theme. One of `"solarized_dark"`, `"base16_mocha"`,
    `"base16_ocean"`, `"base16_eighties"`, `"inspired_github"`. Defaults to `"solarized_dark"`.
  - `style` -- `:default` or `StyleMap.t()` for custom styling. See `Plushie.Type.StyleMap`.
  - `key_bindings` (list of maps) -- declarative key binding rules for the editor.
    Each rule is a map with optional `key` (character), `named` (named key string),
    `modifiers` (list of modifier strings), and `binding` (the action to take).
    See `key_bindings/2` for details.
  - `placeholder_color` (color) -- placeholder text color. See `Plushie.Type.Color`.
  - `selection_color` (color) -- text selection highlight color. See `Plushie.Type.Color`.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.

  ## Events

  The editor emits text action events handled internally by the renderer.
  Content changes are reported back to Elixir via the protocol.
  """

  alias Plushie.Type.A11y
  alias Plushie.Type.Color
  alias Plushie.Type.StyleMap
  alias Plushie.Widget.Build

  @type style :: :default | StyleMap.t()

  @type option ::
          {:content, String.t()}
          | {:placeholder, String.t()}
          | {:width, Plushie.Type.Length.t()}
          | {:height, Plushie.Type.Length.t()}
          | {:min_height, number()}
          | {:max_height, number()}
          | {:font, Plushie.Type.Font.t()}
          | {:size, number()}
          | {:line_height, number() | map()}
          | {:padding, number()}
          | {:wrapping, Plushie.Type.Wrapping.t()}
          | {:ime_purpose, String.t()}
          | {:highlight_syntax, String.t()}
          | {:highlight_theme, String.t()}
          | {:style, style()}
          | {:key_bindings, [map()]}
          | {:placeholder_color, Plushie.Type.Color.input()}
          | {:selection_color, Plushie.Type.Color.input()}
          | {:a11y, Plushie.Type.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          content: String.t() | nil,
          placeholder: String.t() | nil,
          width: Plushie.Type.Length.t() | nil,
          height: Plushie.Type.Length.t() | nil,
          min_height: number() | nil,
          max_height: number() | nil,
          font: Plushie.Type.Font.t() | nil,
          size: number() | nil,
          line_height: number() | map() | nil,
          padding: number() | nil,
          wrapping: Plushie.Type.Wrapping.t() | nil,
          ime_purpose: String.t() | nil,
          highlight_syntax: String.t() | nil,
          highlight_theme: String.t() | nil,
          style: style() | nil,
          key_bindings: [map()] | nil,
          placeholder_color: Plushie.Type.Color.t() | nil,
          selection_color: Plushie.Type.Color.t() | nil,
          a11y: Plushie.Type.A11y.t() | nil
        }

  defstruct [
    :id,
    :content,
    :placeholder,
    :width,
    :height,
    :min_height,
    :max_height,
    :font,
    :size,
    :line_height,
    :padding,
    :wrapping,
    :ime_purpose,
    :highlight_syntax,
    :highlight_theme,
    :style,
    :key_bindings,
    :placeholder_color,
    :selection_color,
    :a11y
  ]

  @valid_option_keys ~w(content placeholder width height min_height max_height font size line_height padding wrapping ime_purpose highlight_syntax highlight_theme style key_bindings placeholder_color selection_color a11y)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__ do
    %{font: Plushie.Type.Font, a11y: Plushie.Type.A11y}
  end

  @doc "Creates a new text editor struct with the given id and optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing text editor struct."
  @spec with_options(text_editor :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = ed, []), do: ed

  def with_options(%__MODULE__{} = ed, opts) do
    Enum.reduce(opts, ed, fn
      {:content, v}, acc -> content(acc, v)
      {:placeholder, v}, acc -> placeholder(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:min_height, v}, acc -> min_height(acc, v)
      {:max_height, v}, acc -> max_height(acc, v)
      {:font, v}, acc -> font(acc, v)
      {:size, v}, acc -> size(acc, v)
      {:line_height, v}, acc -> line_height(acc, v)
      {:padding, v}, acc -> padding(acc, v)
      {:wrapping, v}, acc -> wrapping(acc, v)
      {:ime_purpose, v}, acc -> ime_purpose(acc, v)
      {:highlight_syntax, v}, acc -> highlight_syntax(acc, v)
      {:highlight_theme, v}, acc -> highlight_theme(acc, v)
      {:style, v}, acc -> style(acc, v)
      {:key_bindings, v}, acc -> key_bindings(acc, v)
      {:placeholder_color, v}, acc -> placeholder_color(acc, v)
      {:selection_color, v}, acc -> selection_color(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the initial text content."
  @spec content(text_editor :: t(), content :: String.t()) :: t()
  def content(%__MODULE__{} = ed, content) when is_binary(content), do: %{ed | content: content}

  @doc "Sets the placeholder text."
  @spec placeholder(text_editor :: t(), placeholder :: String.t()) :: t()
  def placeholder(%__MODULE__{} = ed, placeholder) when is_binary(placeholder),
    do: %{ed | placeholder: placeholder}

  @doc "Sets the editor width."
  @spec width(text_editor :: t(), width :: Plushie.Type.Length.t()) :: t()
  def width(%__MODULE__{} = ed, width), do: %{ed | width: width}

  @doc "Sets the editor height."
  @spec height(text_editor :: t(), height :: Plushie.Type.Length.t()) :: t()
  def height(%__MODULE__{} = ed, height), do: %{ed | height: height}

  @doc "Sets the minimum height in pixels."
  @spec min_height(text_editor :: t(), min_height :: number()) :: t()
  def min_height(%__MODULE__{} = ed, min_height) when is_number(min_height),
    do: %{ed | min_height: min_height}

  @doc "Sets the maximum height in pixels."
  @spec max_height(text_editor :: t(), max_height :: number()) :: t()
  def max_height(%__MODULE__{} = ed, max_height) when is_number(max_height),
    do: %{ed | max_height: max_height}

  @doc "Sets the font."
  @spec font(text_editor :: t(), font :: Plushie.Type.Font.t()) :: t()
  def font(%__MODULE__{} = ed, font), do: %{ed | font: font}

  @doc "Sets the font size in pixels."
  @spec size(text_editor :: t(), size :: number()) :: t()
  def size(%__MODULE__{} = ed, size) when is_number(size), do: %{ed | size: size}

  @doc "Sets the line height."
  @spec line_height(text_editor :: t(), line_height :: number() | map()) :: t()
  def line_height(%__MODULE__{} = ed, line_height), do: %{ed | line_height: line_height}

  @doc "Sets the uniform padding in pixels."
  @spec padding(text_editor :: t(), padding :: number()) :: t()
  def padding(%__MODULE__{} = ed, padding) when is_number(padding), do: %{ed | padding: padding}

  @doc "Sets the text wrapping mode."
  @spec wrapping(text_editor :: t(), wrapping :: Plushie.Type.Wrapping.t()) :: t()
  def wrapping(%__MODULE__{} = ed, wrapping), do: %{ed | wrapping: wrapping}

  @doc "Sets the IME input purpose hint."
  @spec ime_purpose(text_editor :: t(), ime_purpose :: String.t()) :: t()
  def ime_purpose(%__MODULE__{} = ed, ime_purpose) when ime_purpose in ~w(normal secure terminal),
    do: %{ed | ime_purpose: ime_purpose}

  @doc ~S[Sets the syntax language for highlighting (e.g. "rs", "py", "ex").]
  @spec highlight_syntax(text_editor :: t(), highlight_syntax :: String.t()) :: t()
  def highlight_syntax(%__MODULE__{} = ed, highlight_syntax) when is_binary(highlight_syntax),
    do: %{ed | highlight_syntax: highlight_syntax}

  @doc "Sets the highlighter color theme."
  @spec highlight_theme(text_editor :: t(), highlight_theme :: String.t()) :: t()
  def highlight_theme(%__MODULE__{} = ed, highlight_theme) when is_binary(highlight_theme),
    do: %{ed | highlight_theme: highlight_theme}

  @doc "Sets the text editor style."
  @spec style(text_editor :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = ed, %StyleMap{} = style), do: %{ed | style: style}
  def style(%__MODULE__{} = ed, :default), do: %{ed | style: :default}

  @doc """
  Sets declarative key binding rules for the editor.

  Each rule is a map with:

  - `"key"` (string) -- a character to match (layout-independent via `to_latin`).
  - `"named"` (string) -- a named key like `"Enter"`, `"Escape"`, `"Tab"`, etc.
  - `"modifiers"` (list of strings) -- required modifiers: `"shift"`, `"ctrl"`,
    `"alt"`, `"logo"`, `"command"`, `"jump"`.
  - `"binding"` -- the action: a string like `"copy"`, `"cut"`, `"paste"`,
    `"enter"`, `"backspace"`, `"delete"`, `"unfocus"`, `"select_all"`,
    `"select_word"`, `"select_line"`, `"default"`, or a map for complex
    actions like `%{"move" => "left"}`, `%{"select" => "word_right"}`,
    `%{"insert" => "x"}`, `%{"custom" => "my_tag"}`,
    `%{"sequence" => [binding1, binding2, ...]}`.

  Rules are matched in order. The first matching rule wins. If no rule matches,
  the key press is ignored (no binding). Use `"default"` as the binding to
  delegate to iced's built-in key handler.
  """
  @spec key_bindings(text_editor :: t(), key_bindings :: [map()]) :: t()
  def key_bindings(%__MODULE__{} = ed, key_bindings), do: %{ed | key_bindings: key_bindings}

  @doc "Sets the placeholder text color. Accepts any form `Color.cast/1` supports."
  @spec placeholder_color(text_editor :: t(), color :: Plushie.Type.Color.input()) :: t()
  def placeholder_color(%__MODULE__{} = ed, color),
    do: %{ed | placeholder_color: Color.cast(color)}

  @doc "Sets the text selection highlight color. Accepts any form `Color.cast/1` supports."
  @spec selection_color(text_editor :: t(), color :: Plushie.Type.Color.input()) :: t()
  def selection_color(%__MODULE__{} = ed, color),
    do: %{ed | selection_color: Color.cast(color)}

  @doc "Sets accessibility annotations."
  @spec a11y(text_editor :: t(), a11y :: Plushie.Type.A11y.t()) :: t()
  def a11y(%__MODULE__{} = ed, a11y), do: %{ed | a11y: A11y.cast(a11y)}

  @doc "Converts this text editor struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(text_editor :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = ed), do: Plushie.Widget.to_node(ed)

  defimpl Plushie.Widget do
    import Plushie.Widget.Build

    def to_node(ed) do
      props =
        %{}
        |> put_if(ed.content, :content)
        |> put_if(ed.placeholder, :placeholder)
        |> put_if(ed.width, :width)
        |> put_if(ed.height, :height)
        |> put_if(ed.min_height, :min_height)
        |> put_if(ed.max_height, :max_height)
        |> put_if(ed.font, :font)
        |> put_if(ed.size, :size)
        |> put_if(ed.line_height, :line_height)
        |> put_if(ed.padding, :padding)
        |> put_if(ed.wrapping, :wrapping)
        |> put_if(ed.ime_purpose, :ime_purpose)
        |> put_if(ed.highlight_syntax, :highlight_syntax)
        |> put_if(ed.highlight_theme, :highlight_theme)
        |> put_if(ed.style, :style)
        |> put_if(ed.key_bindings, :key_bindings)
        |> put_if(ed.placeholder_color, :placeholder_color)
        |> put_if(ed.selection_color, :selection_color)
        |> put_if(ed.a11y, :a11y)

      %{id: ed.id, type: "text_editor", props: props, children: []}
    end
  end
end
