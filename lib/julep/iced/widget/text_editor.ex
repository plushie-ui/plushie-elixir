defmodule Julep.Iced.Widget.TextEditor do
  @moduledoc """
  Text editor -- multi-line editable text area.

  The renderer manages an internal `text_editor::Content` cache keyed by
  node ID. The `content` prop seeds the initial content.

  ## Props

  - `content` (string) -- initial text content (used to seed the editor cache).
  - `placeholder` (string) -- placeholder text shown when editor is empty.
  - `width` (number) -- editor width in pixels (note: takes pixels, not length).
  - `height` (length) -- editor height. Default: shrink. See `Julep.Iced.Length`.
  - `min_height` (number) -- minimum height in pixels.
  - `max_height` (number) -- maximum height in pixels.
  - `font` (string | map) -- font specification. See `Julep.Iced.Font`.
  - `size` (number) -- font size in pixels.
  - `line_height` (number | map) -- line height.
  - `padding` (number) -- uniform padding in pixels.
  - `wrapping` (string) -- text wrapping: `"none"`, `"word"`, `"glyph"`, `"word_or_glyph"`.
  - `style` (string) -- named style. Currently only `"default"`.

  ## Events

  The editor emits text action events handled internally by the renderer.
  Content changes are reported back to Elixir via the protocol.
  """

  alias Julep.Iced.Widget.Build

  @type option ::
          {:content, String.t()}
          | {:placeholder, String.t()}
          | {:width, number()}
          | {:height, Julep.Iced.Length.t()}
          | {:min_height, number()}
          | {:max_height, number()}
          | {:font, Julep.Iced.Font.t()}
          | {:size, number()}
          | {:line_height, number() | map()}
          | {:padding, number()}
          | {:wrapping, atom()}
          | {:style, atom()}

  @type t :: %__MODULE__{
          id: String.t(),
          content: String.t() | nil,
          placeholder: String.t() | nil,
          width: number() | nil,
          height: Julep.Iced.Length.t() | nil,
          min_height: number() | nil,
          max_height: number() | nil,
          font: Julep.Iced.Font.t() | nil,
          size: number() | nil,
          line_height: number() | map() | nil,
          padding: number() | nil,
          wrapping: atom() | nil,
          style: atom() | nil
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
    :style
  ]

  @doc "Creates a new text editor struct with the given id and optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) do
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
      {:style, v}, acc -> style(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the initial text content."
  @spec content(text_editor :: t(), content :: String.t()) :: t()
  def content(%__MODULE__{} = ed, content), do: %{ed | content: content}

  @doc "Sets the placeholder text."
  @spec placeholder(text_editor :: t(), placeholder :: String.t()) :: t()
  def placeholder(%__MODULE__{} = ed, placeholder), do: %{ed | placeholder: placeholder}

  @doc "Sets the editor width in pixels."
  @spec width(text_editor :: t(), width :: number()) :: t()
  def width(%__MODULE__{} = ed, width), do: %{ed | width: width}

  @doc "Sets the editor height."
  @spec height(text_editor :: t(), height :: Julep.Iced.Length.t()) :: t()
  def height(%__MODULE__{} = ed, height), do: %{ed | height: height}

  @doc "Sets the minimum height in pixels."
  @spec min_height(text_editor :: t(), min_height :: number()) :: t()
  def min_height(%__MODULE__{} = ed, min_height), do: %{ed | min_height: min_height}

  @doc "Sets the maximum height in pixels."
  @spec max_height(text_editor :: t(), max_height :: number()) :: t()
  def max_height(%__MODULE__{} = ed, max_height), do: %{ed | max_height: max_height}

  @doc "Sets the font."
  @spec font(text_editor :: t(), font :: Julep.Iced.Font.t()) :: t()
  def font(%__MODULE__{} = ed, font), do: %{ed | font: font}

  @doc "Sets the font size in pixels."
  @spec size(text_editor :: t(), size :: number()) :: t()
  def size(%__MODULE__{} = ed, size), do: %{ed | size: size}

  @doc "Sets the line height."
  @spec line_height(text_editor :: t(), line_height :: number() | map()) :: t()
  def line_height(%__MODULE__{} = ed, line_height), do: %{ed | line_height: line_height}

  @doc "Sets the uniform padding in pixels."
  @spec padding(text_editor :: t(), padding :: number()) :: t()
  def padding(%__MODULE__{} = ed, padding), do: %{ed | padding: padding}

  @doc "Sets the text wrapping mode."
  @spec wrapping(text_editor :: t(), wrapping :: atom()) :: t()
  def wrapping(%__MODULE__{} = ed, wrapping), do: %{ed | wrapping: wrapping}

  @doc "Sets the text editor style."
  @spec style(text_editor :: t(), style :: atom()) :: t()
  def style(%__MODULE__{} = ed, style), do: %{ed | style: style}

  @doc "Converts this text editor struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(text_editor :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = ed), do: Julep.Iced.Widget.to_node(ed)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(ed) do
      props =
        %{}
        |> put_if(ed.content, "content")
        |> put_if(ed.placeholder, "placeholder")
        |> put_if(ed.width, "width")
        |> put_if(ed.height, "height")
        |> put_if(ed.min_height, "min_height")
        |> put_if(ed.max_height, "max_height")
        |> put_if(ed.font, "font")
        |> put_if(ed.size, "size")
        |> put_if(ed.line_height, "line_height")
        |> put_if(ed.padding, "padding")
        |> put_if(ed.wrapping, "wrapping", &to_string/1)
        |> put_if(ed.style, "style", &to_string/1)

      %{id: ed.id, type: "text_editor", props: props, children: []}
    end
  end
end
