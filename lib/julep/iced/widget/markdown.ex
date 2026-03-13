defmodule Julep.Iced.Widget.Markdown do
  @moduledoc """
  Markdown display -- renders parsed markdown content.

  The renderer manages an internal `markdown::Items` cache keyed by node ID.

  ## Props

  - `content` (string) -- raw markdown text (used to seed the parser cache).
  - `width` (length) -- container width. See `Julep.Iced.Length`.
  - `text_size` (number) -- base text size in pixels.
  - `h1_size` (number) -- heading 1 size in pixels.
  - `h2_size` (number) -- heading 2 size in pixels.
  - `h3_size` (number) -- heading 3 size in pixels.
  - `code_size` (number) -- code block text size in pixels.
  - `spacing` (number) -- spacing between markdown elements in pixels.

  ## Events

  - Link clicks are forwarded as `MarkdownUrl` messages by the renderer.
  """

  alias Julep.Iced.A11y
  alias Julep.Iced.Widget.Build

  @type option ::
          {:width, Julep.Iced.Length.t()}
          | {:text_size, number()}
          | {:h1_size, number()}
          | {:h2_size, number()}
          | {:h3_size, number()}
          | {:code_size, number()}
          | {:spacing, number()}
          | {:a11y, Julep.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          content: String.t(),
          width: Julep.Iced.Length.t() | nil,
          text_size: number() | nil,
          h1_size: number() | nil,
          h2_size: number() | nil,
          h3_size: number() | nil,
          code_size: number() | nil,
          spacing: number() | nil,
          a11y: Julep.Iced.A11y.t() | nil
        }

  defstruct [
    :id,
    :content,
    :width,
    :text_size,
    :h1_size,
    :h2_size,
    :h3_size,
    :code_size,
    :spacing,
    :a11y
  ]

  @doc "Creates a new markdown struct with the given content and optional keyword opts."
  @spec new(id :: String.t(), content :: String.t(), opts :: [option()]) :: t()
  def new(id, content, opts \\ []) when is_binary(id) and is_binary(content) do
    %__MODULE__{id: id, content: content} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing markdown struct."
  @spec with_options(markdown :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = md, []), do: md

  def with_options(%__MODULE__{} = md, opts) do
    Enum.reduce(opts, md, fn
      {:width, v}, acc -> width(acc, v)
      {:text_size, v}, acc -> text_size(acc, v)
      {:h1_size, v}, acc -> h1_size(acc, v)
      {:h2_size, v}, acc -> h2_size(acc, v)
      {:h3_size, v}, acc -> h3_size(acc, v)
      {:code_size, v}, acc -> code_size(acc, v)
      {:spacing, v}, acc -> spacing(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the container width."
  @spec width(markdown :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = md, width), do: %{md | width: width}

  @doc "Sets the base text size."
  @spec text_size(markdown :: t(), text_size :: number()) :: t()
  def text_size(%__MODULE__{} = md, text_size), do: %{md | text_size: text_size}

  @doc "Sets the heading 1 size."
  @spec h1_size(markdown :: t(), h1_size :: number()) :: t()
  def h1_size(%__MODULE__{} = md, h1_size), do: %{md | h1_size: h1_size}

  @doc "Sets the heading 2 size."
  @spec h2_size(markdown :: t(), h2_size :: number()) :: t()
  def h2_size(%__MODULE__{} = md, h2_size), do: %{md | h2_size: h2_size}

  @doc "Sets the heading 3 size."
  @spec h3_size(markdown :: t(), h3_size :: number()) :: t()
  def h3_size(%__MODULE__{} = md, h3_size), do: %{md | h3_size: h3_size}

  @doc "Sets the code block text size."
  @spec code_size(markdown :: t(), code_size :: number()) :: t()
  def code_size(%__MODULE__{} = md, code_size), do: %{md | code_size: code_size}

  @doc "Sets the spacing between markdown elements."
  @spec spacing(markdown :: t(), spacing :: number()) :: t()
  def spacing(%__MODULE__{} = md, spacing), do: %{md | spacing: spacing}

  @doc "Sets accessibility annotations."
  @spec a11y(markdown :: t(), a11y :: Julep.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = md, a11y), do: %{md | a11y: A11y.cast(a11y)}

  @doc "Converts this markdown struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(markdown :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = md), do: Julep.Iced.Widget.to_node(md)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(md) do
      props =
        %{}
        |> put_if(md.content, "content")
        |> put_if(md.width, "width")
        |> put_if(md.text_size, "text_size")
        |> put_if(md.h1_size, "h1_size")
        |> put_if(md.h2_size, "h2_size")
        |> put_if(md.h3_size, "h3_size")
        |> put_if(md.code_size, "code_size")
        |> put_if(md.spacing, "spacing")
        |> put_if(md.a11y, "a11y")

      %{id: md.id, type: "markdown", props: props, children: []}
    end
  end
end
