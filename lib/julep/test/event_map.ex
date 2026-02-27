defmodule Julep.Test.EventMap do
  @moduledoc """
  Maps widget types to the events they produce when interacted with.

  Used by the simulated backend to infer what event dispatching `click`,
  `type_text`, `toggle`, etc. should produce for a given widget type,
  without needing a real renderer.

  ## Event inference table

  | Widget       | click              | input                  | submit              | toggle                    | select                    | slide              |
  |--------------|--------------------|-----------------------|---------------------|---------------------------|---------------------------|--------------------|
  | button       | `{:click, id}`     | -                     | -                   | -                         | -                         | -                  |
  | checkbox     | -                  | -                     | -                   | `{:toggle, id, !checked}` | -                         | -                  |
  | toggler      | -                  | -                     | -                   | `{:toggle, id, !toggled}` | -                         | -                  |
  | radio        | -                  | -                     | -                   | -                         | `{:select, group, value}` | -                  |
  | text_input   | -                  | `{:input, id, text}`  | `{:submit, id, val}`| -                         | -                         | -                  |
  | text_editor  | -                  | `{:input, id, text}`  | -                   | -                         | -                         | -                  |
  | slider       | -                  | -                     | -                   | -                         | -                         | `{:slide, id, val}`|
  | pick_list    | -                  | -                     | -                   | -                         | `{:select, id, val}`      | -                  |
  | combo_box    | -                  | -                     | -                   | -                         | `{:select, id, val}`      | -                  |
  """

  alias Julep.Test.Element

  @doc "Infers the event produced by clicking a widget."
  @spec click(element :: Element.t()) :: {:ok, tuple()} | {:error, String.t()}
  def click(%Element{type: "button", id: id}), do: {:ok, {:click, id}}

  def click(%Element{type: type}) when type in ~w(checkbox toggler),
    do: {:error, "cannot click a #{type} widget -- use toggle/1 instead"}

  def click(%Element{type: type}), do: {:error, "cannot click a #{type} widget"}

  @doc "Infers the event produced by typing text into a widget."
  @spec input(element :: Element.t(), text :: String.t()) :: {:ok, tuple()} | {:error, String.t()}
  def input(%Element{type: "text_input", id: id}, text), do: {:ok, {:input, id, text}}
  def input(%Element{type: "text_editor", id: id}, text), do: {:ok, {:input, id, text}}
  def input(%Element{type: type}, _text), do: {:error, "cannot type into a #{type} widget"}

  @doc "Infers the event produced by submitting a widget."
  @spec submit(element :: Element.t()) :: {:ok, tuple()} | {:error, String.t()}
  def submit(%Element{type: "text_input", id: id, props: props}) do
    {:ok, {:submit, id, props["value"] || ""}}
  end

  def submit(%Element{type: type}), do: {:error, "cannot submit a #{type} widget"}

  @doc "Infers the event produced by toggling a widget."
  @spec toggle(element :: Element.t()) :: {:ok, tuple()} | {:error, String.t()}
  def toggle(%Element{type: "checkbox", id: id, props: props}) do
    current = props["is_checked"] || false
    {:ok, {:toggle, id, !current}}
  end

  def toggle(%Element{type: "toggler", id: id, props: props}) do
    current = props["is_toggled"] || false
    {:ok, {:toggle, id, !current}}
  end

  def toggle(%Element{type: type}) when type in ~w(button),
    do: {:error, "cannot toggle a #{type} widget -- use click/1 instead"}

  def toggle(%Element{type: type}), do: {:error, "cannot toggle a #{type} widget"}

  @doc "Infers the event produced by selecting a value from a widget."
  @spec select(element :: Element.t(), value :: term()) :: {:ok, tuple()} | {:error, String.t()}
  def select(%Element{type: "radio", props: props}, value) do
    group = props["group"] || props["name"]
    {:ok, {:select, group, value}}
  end

  def select(%Element{type: "pick_list", id: id}, value), do: {:ok, {:select, id, value}}
  def select(%Element{type: "combo_box", id: id}, value), do: {:ok, {:select, id, value}}
  def select(%Element{type: type}, _value), do: {:error, "cannot select from a #{type} widget"}

  @doc "Infers the event produced by sliding a widget to a value."
  @spec slide(element :: Element.t(), value :: number()) :: {:ok, tuple()} | {:error, String.t()}
  def slide(%Element{type: "slider", id: id}, value), do: {:ok, {:slide, id, value}}
  def slide(%Element{type: "vertical_slider", id: id}, value), do: {:ok, {:slide, id, value}}
  def slide(%Element{type: type}, _value), do: {:error, "cannot slide a #{type} widget"}
end
