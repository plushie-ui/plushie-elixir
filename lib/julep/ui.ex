defmodule Julep.UI do
  @moduledoc """
  Ergonomic builder layer for Julep UI trees.

  Import this module in your `view/1` function to get concise widget builder
  syntax with optional `do` block sugar for children.

  ## Usage

      def view(model) do
        import Julep.UI

        window "main", title: "Counter" do
          column do
            text("Count: \#{model.count}")
            row do
              button("increment", "+")
              button("decrement", "-")
            end
          end
        end
      end

  ## Node shape

  Every builder produces:

      %{id: string, type: string, props: %{}, children: []}

  Props use string keys. Reserved opts keys (`:children`, `:id`, `:do`) are
  not treated as props.

  ## Two equivalent forms

  The `do` block is sugar that compiles to the explicit `:children` form:

      column(padding: 8, children: [text("hello")])

      column padding: 8 do
        text("hello")
      end

  Inside a `do` block:
  - `for` comprehensions work (they return lists; one level is flattened)
  - `if` without `else` works (returns nil; nils are filtered out)

  ## Auto-IDs

  Layout and display widgets that do not receive an explicit `:id` option
  generate one from the call site: `"auto:ModuleName:42"`. This is stable
  within a render but will change if you move the call to a different line.
  For stable identity across re-renders (scroll position, focus), supply an
  explicit `:id` opt.

  ## Tree query

  `find/2` is re-exported from `Julep.Tree` for convenience:

      Julep.UI.find(tree, "my_button")
  """

  # ---------------------------------------------------------------------------
  # Core build function (public -- macro-generated code calls it at runtime)
  # ---------------------------------------------------------------------------

  @doc """
  Builds a UI node map. Public so macro-generated code can call it after
  the `do` block has been evaluated at runtime.

  - `type`     -- string widget type
  - `id`       -- explicit id string, or nil to auto-generate
  - `opts`     -- keyword list; may include `:children` and `:id`
  - `children` -- already-evaluated child list (wins over `:children` opt)
  - `caller`   -- `{module, line}` used for auto-ID generation

  All opts keys except `:children`, `:id`, and `:do` become string-keyed props.
  """
  @spec __build_node__(
          String.t(),
          String.t() | nil,
          keyword(),
          [map()],
          {module(), non_neg_integer()}
        ) :: map()
  def __build_node__(type, id, opts, children, {caller_mod, caller_line}) do
    resolved_id =
      id ||
        Keyword.get(opts, :id) ||
        __auto_id__(caller_mod, caller_line)

    resolved_children =
      if children != [] do
        children
      else
        Keyword.get(opts, :children, [])
      end

    props =
      opts
      |> Keyword.drop([:children, :id, :do])
      |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

    %{
      id: resolved_id,
      type: type,
      props: props,
      children: resolved_children
    }
  end

  @doc false
  @spec __auto_id__(module() | nil, non_neg_integer()) :: String.t()
  def __auto_id__(nil, line), do: "auto:nomodule:#{line}"

  def __auto_id__(mod, line) do
    mod_str = mod |> Module.split() |> Enum.join(".")
    "auto:#{mod_str}:#{line}"
  end

  # ---------------------------------------------------------------------------
  # Layout widgets
  # ---------------------------------------------------------------------------

  # -- window(id, opts) -------------------------------------------------------
  # All forms are macros so there is no def/defmacro arity conflict.
  #
  #   window("main")
  #   window("main", title: "App")
  #   window "main" do ... end
  #   window "main", title: "App" do ... end

  @doc """
  Top-level window container.

  ## Arguments

  - `id`   -- stable string identifier for this window
  - `opts` -- keyword list; common option: `:title`

  ## Example

      window "main", title: "My App" do
        column do
          text("Hello")
        end
      end
  """
  defmacro window(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_fixed_node__("window", unquote(id), [], children)
        end

      opts ->
        quote do
          Julep.UI.__build_fixed_node__("window", unquote(id), unquote(opts), [])
        end
    end
  end

  @doc false
  defmacro window(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_fixed_node__("window", unquote(id), unquote(opts), children)
    end
  end

  # -- column(opts) -----------------------------------------------------------
  # All forms are macros so we always have __CALLER__ for auto-ID.
  #
  #   column()
  #   column(padding: 8)
  #   column do ... end
  #   column padding: 8 do ... end

  @doc """
  Vertical flex layout.

  ## Options

  - `:spacing` -- gap between children
  - `:padding` -- padding around children
  - `:width` / `:height` -- `:fill`, `:shrink`, or number
  - `:align_x` -- `:start`, `:center`, `:end`
  - `:id` -- explicit ID (otherwise auto-generated from call site)
  - `:children` -- child nodes (function-form shorthand)

  ## Example

      column spacing: 8 do
        text("Hello")
        text("World")
      end
  """
  defmacro column(opts_or_block \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    case opts_or_block do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_node__("column", nil, [], children, {unquote(caller_mod), unquote(caller_line)})
        end

      opts ->
        quote do
          Julep.UI.__build_node__("column", nil, unquote(opts), [], {unquote(caller_mod), unquote(caller_line)})
        end
    end
  end

  @doc false
  defmacro column(opts, do: block) do
    exprs = block_to_exprs(block)
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_node__("column", nil, unquote(opts), children, {unquote(caller_mod), unquote(caller_line)})
    end
  end

  # -- row(opts) --------------------------------------------------------------

  @doc """
  Horizontal flex layout.

  ## Options

  Same as `column/1`.

  ## Example

      row spacing: 4 do
        button("yes", "Yes")
        button("no", "No")
      end
  """
  defmacro row(opts_or_block \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    case opts_or_block do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_node__("row", nil, [], children, {unquote(caller_mod), unquote(caller_line)})
        end

      opts ->
        quote do
          Julep.UI.__build_node__("row", nil, unquote(opts), [], {unquote(caller_mod), unquote(caller_line)})
        end
    end
  end

  @doc false
  defmacro row(opts, do: block) do
    exprs = block_to_exprs(block)
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_node__("row", nil, unquote(opts), children, {unquote(caller_mod), unquote(caller_line)})
    end
  end

  # -- container(id, opts) ----------------------------------------------------

  @doc """
  Generic box with alignment and padding.

  ## Example

      container "hero", padding: 16 do
        text("Welcome")
      end
  """
  defmacro container(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_fixed_node__("container", unquote(id), [], children)
        end

      opts ->
        quote do
          Julep.UI.__build_fixed_node__("container", unquote(id), unquote(opts), [])
        end
    end
  end

  @doc false
  defmacro container(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_fixed_node__("container", unquote(id), unquote(opts), children)
    end
  end

  # -- scrollable(id, opts) ---------------------------------------------------

  @doc """
  Scrollable region.

  ## Example

      scrollable "feed" do
        for item <- items do
          text(item.title)
        end
      end
  """
  defmacro scrollable(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_fixed_node__("scrollable", unquote(id), [], children)
        end

      opts ->
        quote do
          Julep.UI.__build_fixed_node__("scrollable", unquote(id), unquote(opts), [])
        end
    end
  end

  @doc false
  defmacro scrollable(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_fixed_node__("scrollable", unquote(id), unquote(opts), children)
    end
  end

  # -- stack(opts) ------------------------------------------------------------

  @doc """
  Z-axis stacking layout (overlays).

  ## Example

      stack do
        image("bg", "/path/to/bg.png")
        container "overlay", padding: 16 do
          text("Overlaid text")
        end
      end
  """
  defmacro stack(opts_or_block \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    case opts_or_block do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_node__("stack", nil, [], children, {unquote(caller_mod), unquote(caller_line)})
        end

      opts ->
        quote do
          Julep.UI.__build_node__("stack", nil, unquote(opts), [], {unquote(caller_mod), unquote(caller_line)})
        end
    end
  end

  @doc false
  defmacro stack(opts, do: block) do
    exprs = block_to_exprs(block)
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_node__("stack", nil, unquote(opts), children, {unquote(caller_mod), unquote(caller_line)})
    end
  end

  # -- space(opts) ------------------------------------------------------------

  @doc """
  Flexible spacer. No children.

  ## Options

  - `:width` -- `:fill`, `:shrink`, or number
  - `:height` -- `:fill`, `:shrink`, or number
  """
  defmacro space(opts \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      Julep.UI.__build_node__("space", nil, unquote(opts), [], {unquote(caller_mod), unquote(caller_line)})
    end
  end

  # ---------------------------------------------------------------------------
  # Input widgets (require explicit id; no do-block form needed)
  # ---------------------------------------------------------------------------

  @doc """
  Clickable button.

  Emits `{:click, id}` when clicked.

  ## Example

      button("save", "Save", style: :primary)
  """
  @spec button(String.t(), String.t(), keyword()) :: map()
  def button(id, label, opts \\ []) do
    base_props = %{"label" => label}
    extra_props =
      opts
      |> Keyword.drop([:children, :id, :do])
      |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

    %{id: id, type: "button", props: Map.merge(base_props, extra_props), children: []}
  end

  @doc """
  Single-line text input.

  Emits `{:input, id, value}` on change and `{:submit, id, value}` on Enter.

  ## Example

      text_input("name", model.name, placeholder: "Your name")
  """
  @spec text_input(String.t(), String.t(), keyword()) :: map()
  def text_input(id, value, opts \\ []) do
    base_props = %{"value" => value}
    extra_props =
      opts
      |> Keyword.drop([:children, :id, :do])
      |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

    %{id: id, type: "text_input", props: Map.merge(base_props, extra_props), children: []}
  end

  @doc """
  Boolean checkbox toggle.

  Emits `{:toggle, id, boolean}` when toggled.

  ## Example

      checkbox("agree", model.agreed, label: "I agree")
  """
  @spec checkbox(String.t(), boolean(), keyword()) :: map()
  def checkbox(id, checked, opts \\ []) do
    base_props = %{"checked" => checked}
    extra_props =
      opts
      |> Keyword.drop([:children, :id, :do])
      |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

    %{id: id, type: "checkbox", props: Map.merge(base_props, extra_props), children: []}
  end

  # ---------------------------------------------------------------------------
  # Display widgets
  # ---------------------------------------------------------------------------

  @doc """
  Text label.

  Auto-generates an ID from the call site unless `:id` is given in opts.

  ## Example

      text("Hello, world!", size: 18)
  """
  defmacro text(content, opts \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      content = unquote(content)
      opts = unquote(opts)
      base_props = %{"content" => content}
      extra_props =
        opts
        |> Keyword.drop([:children, :id, :do])
        |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

      id = Keyword.get(opts, :id) || Julep.UI.__auto_id__(unquote(caller_mod), unquote(caller_line))
      %{id: id, type: "text", props: Map.merge(base_props, extra_props), children: []}
    end
  end

  @doc """
  Horizontal or vertical divider.

  ## Example

      rule(width: :fill)
  """
  defmacro rule(opts \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      opts = unquote(opts)
      props =
        opts
        |> Keyword.drop([:children, :id, :do])
        |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

      id = Keyword.get(opts, :id) || Julep.UI.__auto_id__(unquote(caller_mod), unquote(caller_line))
      %{id: id, type: "rule", props: props, children: []}
    end
  end

  @doc """
  Progress indicator.

  ## Arguments

  - `range` -- `{min, max}` tuple defining the full range
  - `value` -- current value within the range

  ## Example

      progress_bar({0, 100}, model.progress)
  """
  defmacro progress_bar(range, value, opts \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      range = unquote(range)
      value = unquote(value)
      opts = unquote(opts)
      base_props = %{"range" => Tuple.to_list(range), "value" => value}
      extra_props =
        opts
        |> Keyword.drop([:children, :id, :do])
        |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

      id = Keyword.get(opts, :id) || Julep.UI.__auto_id__(unquote(caller_mod), unquote(caller_line))
      %{id: id, type: "progress_bar", props: Map.merge(base_props, extra_props), children: []}
    end
  end

  # ---------------------------------------------------------------------------
  # Public runtime helpers called from macro-generated code
  # ---------------------------------------------------------------------------

  @doc false
  @spec __build_fixed_node__(String.t(), String.t(), keyword(), [map()]) :: map()
  def __build_fixed_node__(type, id, opts, children) do
    resolved_children =
      if children != [] do
        children
      else
        Keyword.get(opts, :children, [])
      end

    props =
      opts
      |> Keyword.drop([:children, :id, :do])
      |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

    %{id: id, type: type, props: props, children: resolved_children}
  end

  # ---------------------------------------------------------------------------
  # Tree query
  # ---------------------------------------------------------------------------

  @doc """
  Finds the first node in a tree whose `:id` matches `id`.

  Delegates to `Julep.Tree.find/2`. Returns the node map or `nil`.

  ## Example

      tree = MyApp.view(model)
      Julep.UI.find(tree, "save_button")
  """
  @spec find(map(), String.t()) :: map() | nil
  defdelegate find(tree, id), to: Julep.Tree

  @doc "Returns true if a node with `id` exists in the tree."
  @spec exists?(map() | nil, String.t()) :: boolean()
  defdelegate exists?(tree, id), to: Julep.Tree

  @doc "Returns all node IDs in the tree."
  @spec ids(map() | nil) :: [String.t()]
  defdelegate ids(tree), to: Julep.Tree

  @doc "Finds all nodes matching a predicate."
  @spec find_all(map() | nil, String.t() | (map() -> boolean())) :: [map()]
  defdelegate find_all(tree, id_or_pred), to: Julep.Tree

  # ---------------------------------------------------------------------------
  # Private macro helpers
  # ---------------------------------------------------------------------------

  defp block_to_exprs({:__block__, _, exprs}), do: exprs
  defp block_to_exprs(single_expr), do: [single_expr]
end
