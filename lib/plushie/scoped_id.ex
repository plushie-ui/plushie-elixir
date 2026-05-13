defmodule Plushie.ScopedId do
  @moduledoc """
  Structured representation of a scoped widget ID.

  Wire IDs use the canonical format `window#scope/path/id`:

      "main#form/email"     widget in window
      "main#users/u1"       table row
      "main"                the window itself

  `ScopedId` parses this format into its components for
  programmatic manipulation. Event structs use flat fields
  (`id`, `scope`, `window`) for ergonomic pattern matching;
  use `from_event/1` to convert when the structured form
  is needed.

  ## Examples

      iex> Plushie.ScopedId.parse("main#sidebar/form/email")
      %Plushie.ScopedId{
        id: "email",
        scope: ["form", "sidebar"],
        window_id: "main",
        full: "main#sidebar/form/email"
      }

      iex> Plushie.ScopedId.parse("main")
      %Plushie.ScopedId{
        id: "main",
        scope: [],
        window_id: nil,
        full: "main"
      }

      iex> Plushie.ScopedId.parse("main#email")
      %Plushie.ScopedId{
        id: "email",
        scope: [],
        window_id: "main",
        full: "main#email"
      }
  """

  @enforce_keys [:id, :full]
  defstruct [:id, :window_id, full: "", scope: []]

  @type t :: %__MODULE__{
          id: String.t(),
          scope: [String.t()],
          window_id: String.t() | nil,
          full: String.t()
        }

  @doc """
  Parse a canonical wire ID into its components.

  The `#` separates the window from the widget path. The `/`
  separates scope segments within the path. The last segment
  is the local `id`.

      parse("main#sidebar/form/email")
      #=> %ScopedId{id: "email", scope: ["form", "sidebar"], window_id: "main", ...}

      parse("form/email")
      #=> %ScopedId{id: "email", scope: ["form"], window_id: nil, ...}

      parse("email")
      #=> %ScopedId{id: "email", scope: [], window_id: nil, ...}

  Edge cases: `"main#"` produces `id: ""` (the window itself with
  no widget path). `"#foo"` is treated as bare id `"#foo"` (empty
  window part is ignored). Empty string produces `id: ""`.

  This parser reflects wire ID structure. It does not validate whether a
  parsed local ID is legal as a user-authored widget ID.
  """
  @spec parse(canonical :: String.t()) :: t()
  def parse(canonical) when is_binary(canonical) do
    {window, path} =
      case String.split(canonical, "#", parts: 2) do
        [win, rest] when win != "" -> {win, rest}
        _ -> {nil, canonical}
      end

    {id, scope} =
      case String.split(path, "/") do
        [] ->
          {"", []}

        [single] ->
          {single, []}

        parts ->
          {fwd, [local]} = Enum.split(parts, -1)
          {local, Enum.reverse(fwd)}
      end

    %__MODULE__{
      id: id,
      scope: scope,
      window_id: window,
      full: canonical
    }
  end

  @doc """
  Build a ScopedId from event fields.

      from_event(%WidgetEvent{id: "email", scope: ["form"], window_id: "main"})
  """
  @type event_fields :: %{
          required(:id) => String.t(),
          required(:scope) => [String.t()] | nil,
          optional(:window_id) => String.t() | nil,
          optional(atom()) => term()
        }

  @spec from_event(event :: event_fields()) :: t()
  def from_event(%{id: id, scope: scope} = event) do
    win = Map.get(event, :window_id)
    scope_list = scope |> List.wrap() |> strip_window_scope(win)

    full = build_full(win, scope_list, id)

    %__MODULE__{
      id: id,
      scope: scope_list,
      window_id: win,
      full: full
    }
  end

  @doc "True if the local ID matches the given name."
  @spec matches_local?(sid :: t(), name :: String.t()) :: boolean()
  def matches_local?(%__MODULE__{id: id}, name), do: id == name

  @doc "True if the ancestor appears anywhere in the scope chain."
  @spec matches_scope?(sid :: t(), ancestor :: String.t()) :: boolean()
  def matches_scope?(%__MODULE__{scope: scope}, ancestor), do: ancestor in scope

  @doc "True if the ID is in the given window."
  @spec in_window?(sid :: t(), window :: String.t()) :: boolean()
  def in_window?(%__MODULE__{window_id: w}, window_id), do: w == window_id

  @doc "Returns the immediate parent (nearest ancestor), or nil."
  @spec parent(sid :: t()) :: String.t() | nil
  def parent(%__MODULE__{scope: [p | _]}), do: p
  def parent(%__MODULE__{scope: []}), do: nil

  # Build the canonical full ID from components.
  # Scope is in reversed order (nearest first), so reverse for path.
  defp strip_window_scope(scope, nil), do: scope

  defp strip_window_scope(scope, window),
    do: strip_window_scope(scope, window, Enum.reverse(scope))

  defp strip_window_scope(_scope, window, [candidate | rest]) when candidate == window,
    do: Enum.reverse(rest)

  defp strip_window_scope(scope, _window, _reversed_scope), do: scope

  defp build_full(nil, [], id), do: id

  defp build_full(nil, scope, id) do
    path = scope |> Enum.reverse() |> Enum.join("/")
    "#{path}/#{id}"
  end

  defp build_full(window, [], id), do: "#{window}##{id}"

  defp build_full(window, scope, id) do
    path = scope |> Enum.reverse() |> Enum.join("/")
    "#{window}##{path}/#{id}"
  end
end
