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
          type :: String.t(),
          id :: String.t() | nil,
          opts :: keyword(),
          children :: [Julep.Iced.ui_node()],
          caller :: {module(), non_neg_integer()}
        ) :: Julep.Iced.ui_node()
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
  @spec __auto_id__(mod :: module() | nil, line :: non_neg_integer()) :: String.t()
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

          Julep.UI.__build_node__(
            "column",
            nil,
            [],
            children,
            {unquote(caller_mod), unquote(caller_line)}
          )
        end

      opts ->
        quote do
          Julep.UI.__build_node__(
            "column",
            nil,
            unquote(opts),
            [],
            {unquote(caller_mod), unquote(caller_line)}
          )
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

      Julep.UI.__build_node__(
        "column",
        nil,
        unquote(opts),
        children,
        {unquote(caller_mod), unquote(caller_line)}
      )
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

          Julep.UI.__build_node__(
            "row",
            nil,
            [],
            children,
            {unquote(caller_mod), unquote(caller_line)}
          )
        end

      opts ->
        quote do
          Julep.UI.__build_node__(
            "row",
            nil,
            unquote(opts),
            [],
            {unquote(caller_mod), unquote(caller_line)}
          )
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

      Julep.UI.__build_node__(
        "row",
        nil,
        unquote(opts),
        children,
        {unquote(caller_mod), unquote(caller_line)}
      )
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

          Julep.UI.__build_node__(
            "stack",
            nil,
            [],
            children,
            {unquote(caller_mod), unquote(caller_line)}
          )
        end

      opts ->
        quote do
          Julep.UI.__build_node__(
            "stack",
            nil,
            unquote(opts),
            [],
            {unquote(caller_mod), unquote(caller_line)}
          )
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

      Julep.UI.__build_node__(
        "stack",
        nil,
        unquote(opts),
        children,
        {unquote(caller_mod), unquote(caller_line)}
      )
    end
  end

  # -- grid(opts) -------------------------------------------------------------

  @doc """
  Grid layout.

  ## Options

  - `:column_count` -- number of columns
  - `:column_width` -- width of each column
  - `:row_height` -- height of each row
  - `:spacing` -- gap between cells
  - `:padding` -- padding around grid
  - `:width` / `:height` -- dimensions
  - `:id` -- explicit ID (otherwise auto-generated from call site)

  ## Example

      grid column_count: 3, spacing: 8 do
        for item <- items do
          text(item.name)
        end
      end
  """
  defmacro grid(opts_or_block \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    case opts_or_block do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Julep.UI.__build_node__(
            "grid",
            nil,
            [],
            children,
            {unquote(caller_mod), unquote(caller_line)}
          )
        end

      opts ->
        quote do
          Julep.UI.__build_node__(
            "grid",
            nil,
            unquote(opts),
            [],
            {unquote(caller_mod), unquote(caller_line)}
          )
        end
    end
  end

  @doc false
  defmacro grid(opts, do: block) do
    exprs = block_to_exprs(block)
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Julep.UI.__build_node__(
        "grid",
        nil,
        unquote(opts),
        children,
        {unquote(caller_mod), unquote(caller_line)}
      )
    end
  end

  # -- keyed_column(opts) -----------------------------------------------------

  @doc """
  Keyed column for efficient list diffing.

  ## Options

  Same as `column/1`.

  ## Example

      keyed_column spacing: 8 do
        for item <- items do
          text(item.name, id: item.id)
        end
      end
  """
  defmacro keyed_column(opts_or_block \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    case opts_or_block do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Julep.UI.__build_node__(
            "keyed_column",
            nil,
            [],
            children,
            {unquote(caller_mod), unquote(caller_line)}
          )
        end

      opts ->
        quote do
          Julep.UI.__build_node__(
            "keyed_column",
            nil,
            unquote(opts),
            [],
            {unquote(caller_mod), unquote(caller_line)}
          )
        end
    end
  end

  @doc false
  defmacro keyed_column(opts, do: block) do
    exprs = block_to_exprs(block)
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Julep.UI.__build_node__(
        "keyed_column",
        nil,
        unquote(opts),
        children,
        {unquote(caller_mod), unquote(caller_line)}
      )
    end
  end

  # -- responsive(opts) -------------------------------------------------------

  @doc """
  Responsive layout that adapts to available size.

  ## Options

  - `:width` / `:height` -- dimensions
  - `:id` -- explicit ID (otherwise auto-generated from call site)

  ## Example

      responsive do
        column do
          text("Adapts to size")
        end
      end
  """
  defmacro responsive(opts_or_block \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    case opts_or_block do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Julep.UI.__build_node__(
            "responsive",
            nil,
            [],
            children,
            {unquote(caller_mod), unquote(caller_line)}
          )
        end

      opts ->
        quote do
          Julep.UI.__build_node__(
            "responsive",
            nil,
            unquote(opts),
            [],
            {unquote(caller_mod), unquote(caller_line)}
          )
        end
    end
  end

  @doc false
  defmacro responsive(opts, do: block) do
    exprs = block_to_exprs(block)
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Julep.UI.__build_node__(
        "responsive",
        nil,
        unquote(opts),
        children,
        {unquote(caller_mod), unquote(caller_line)}
      )
    end
  end

  # -- pin(id, opts) ----------------------------------------------------------

  @doc """
  Pin layout for absolute positioning.

  ## Example

      pin "overlay" do
        text("Pinned content")
      end
  """
  defmacro pin(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_fixed_node__("pin", unquote(id), [], children)
        end

      opts ->
        quote do
          Julep.UI.__build_fixed_node__("pin", unquote(id), unquote(opts), [])
        end
    end
  end

  @doc false
  defmacro pin(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_fixed_node__("pin", unquote(id), unquote(opts), children)
    end
  end

  # -- float_widget(id, opts) -------------------------------------------------

  @doc """
  Floating overlay layout.

  ## Example

      float_widget "popup" do
        text("Floating content")
      end
  """
  defmacro float_widget(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_fixed_node__("float", unquote(id), [], children)
        end

      opts ->
        quote do
          Julep.UI.__build_fixed_node__("float", unquote(id), unquote(opts), [])
        end
    end
  end

  @doc false
  defmacro float_widget(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_fixed_node__("float", unquote(id), unquote(opts), children)
    end
  end

  # -- mouse_area(id, opts) ---------------------------------------------------

  @doc """
  Mouse area for capturing mouse events on children.

  ## Options

  - `:on_press`, `:on_release`, `:on_right_press`, `:on_middle_press`
  - `:on_enter`, `:on_exit`

  ## Example

      mouse_area "clickable" do
        text("Click me")
      end
  """
  defmacro mouse_area(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_fixed_node__("mouse_area", unquote(id), [], children)
        end

      opts ->
        quote do
          Julep.UI.__build_fixed_node__("mouse_area", unquote(id), unquote(opts), [])
        end
    end
  end

  @doc false
  defmacro mouse_area(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_fixed_node__("mouse_area", unquote(id), unquote(opts), children)
    end
  end

  # -- sensor(id, opts) -------------------------------------------------------

  @doc """
  Sensor for detecting layout changes on children.

  ## Options

  - `:on_resize`, `:on_appear`

  ## Example

      sensor "tracked" do
        text("Monitored content")
      end
  """
  defmacro sensor(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_fixed_node__("sensor", unquote(id), [], children)
        end

      opts ->
        quote do
          Julep.UI.__build_fixed_node__("sensor", unquote(id), unquote(opts), [])
        end
    end
  end

  @doc false
  defmacro sensor(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_fixed_node__("sensor", unquote(id), unquote(opts), children)
    end
  end

  # -- themer(id, opts) -------------------------------------------------------

  @doc """
  Per-subtree theme override.

  ## Options

  - `:theme` -- theme name string or custom palette map

  ## Example

      themer "dark_section", theme: "Dark" do
        column do
          text("This subtree uses the dark theme")
        end
      end
  """
  defmacro themer(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_fixed_node__("themer", unquote(id), [], children)
        end

      opts ->
        quote do
          Julep.UI.__build_fixed_node__("themer", unquote(id), unquote(opts), [])
        end
    end
  end

  @doc false
  defmacro themer(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_fixed_node__("themer", unquote(id), unquote(opts), children)
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
      Julep.UI.__build_node__(
        "space",
        nil,
        unquote(opts),
        [],
        {unquote(caller_mod), unquote(caller_line)}
      )
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
  @spec button(id :: String.t(), label :: String.t(), opts :: keyword()) :: Julep.Iced.ui_node()
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
  @spec text_input(id :: String.t(), value :: String.t(), opts :: keyword()) ::
          Julep.Iced.ui_node()
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
  @spec checkbox(id :: String.t(), checked :: boolean(), opts :: keyword()) ::
          Julep.Iced.ui_node()
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

      id =
        Keyword.get(opts, :id) || Julep.UI.__auto_id__(unquote(caller_mod), unquote(caller_line))

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

      id =
        Keyword.get(opts, :id) || Julep.UI.__auto_id__(unquote(caller_mod), unquote(caller_line))

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

      id =
        Keyword.get(opts, :id) || Julep.UI.__auto_id__(unquote(caller_mod), unquote(caller_line))

      %{id: id, type: "progress_bar", props: Map.merge(base_props, extra_props), children: []}
    end
  end

  # ---------------------------------------------------------------------------
  # Additional input widgets
  # ---------------------------------------------------------------------------

  @doc """
  Toggle switch.

  Emits `{:toggle, id, boolean}` when toggled.

  ## Example

      toggler("dark_mode", model.dark_mode, label: "Dark mode")
  """
  @spec toggler(id :: String.t(), is_toggled :: boolean(), opts :: keyword()) ::
          Julep.Iced.ui_node()
  def toggler(id, is_toggled, opts \\ []) do
    base_props = %{"is_toggled" => is_toggled}

    extra_props =
      opts
      |> Keyword.drop([:children, :id, :do])
      |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

    %{id: id, type: "toggler", props: Map.merge(base_props, extra_props), children: []}
  end

  @doc """
  Radio button for single-value selection from a group.

  Use the `group` option so all radios in the same group emit select events
  with the group name as the ID instead of each radio's individual ID.

  ## Example

      radio("size_sm", "small", model.size, label: "Small", group: "size")
      radio("size_lg", "large", model.size, label: "Large", group: "size")
  """
  @spec radio(
          id :: String.t(),
          value :: String.t(),
          selected :: String.t() | nil,
          opts :: keyword()
        ) ::
          Julep.Iced.ui_node()
  def radio(id, value, selected, opts \\ []) do
    base_props = %{"value" => value, "selected" => selected}

    extra_props =
      opts
      |> Keyword.drop([:children, :id, :do])
      |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

    %{id: id, type: "radio", props: Map.merge(base_props, extra_props), children: []}
  end

  @doc """
  Horizontal slider for numeric range input.

  ## Arguments

  - `range` -- `{min, max}` tuple
  - `value` -- current value

  ## Example

      slider("volume", {0, 100}, model.volume, step: 5)
  """
  @spec slider(
          id :: String.t(),
          range :: {number(), number()},
          value :: number(),
          opts :: keyword()
        ) ::
          Julep.Iced.ui_node()
  def slider(id, range, value, opts \\ []) do
    base_props = %{"range" => Tuple.to_list(range), "value" => value}

    extra_props =
      opts
      |> Keyword.drop([:children, :id, :do])
      |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

    %{id: id, type: "slider", props: Map.merge(base_props, extra_props), children: []}
  end

  @doc """
  Vertical slider for numeric range input.

  Same as `slider/4` but oriented vertically.

  ## Example

      vertical_slider("brightness", {0, 100}, model.brightness)
  """
  @spec vertical_slider(
          id :: String.t(),
          range :: {number(), number()},
          value :: number(),
          opts :: keyword()
        ) ::
          Julep.Iced.ui_node()
  def vertical_slider(id, range, value, opts \\ []) do
    base_props = %{"range" => Tuple.to_list(range), "value" => value}

    extra_props =
      opts
      |> Keyword.drop([:children, :id, :do])
      |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

    %{id: id, type: "vertical_slider", props: Map.merge(base_props, extra_props), children: []}
  end

  @doc """
  Dropdown pick list for selecting from a list of options.

  ## Example

      pick_list("country", ["UK", "US", "DE"], model.country, placeholder: "Choose...")
  """
  @spec pick_list(
          id :: String.t(),
          options :: [String.t()],
          selected :: String.t() | nil,
          opts :: keyword()
        ) :: Julep.Iced.ui_node()
  def pick_list(id, options, selected, opts \\ []) do
    base_props = %{"options" => options, "selected" => selected}

    extra_props =
      opts
      |> Keyword.drop([:children, :id, :do])
      |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

    %{id: id, type: "pick_list", props: Map.merge(base_props, extra_props), children: []}
  end

  @doc """
  Combo box with free-text input and dropdown suggestions.

  ## Example

      combo_box("lang", ["Elixir", "Rust", "Go"], model.lang, placeholder: "Type...")
  """
  @spec combo_box(
          id :: String.t(),
          options :: [String.t()],
          value :: String.t(),
          opts :: keyword()
        ) ::
          Julep.Iced.ui_node()
  def combo_box(id, options, value, opts \\ []) do
    base_props = %{"options" => options, "value" => value}

    extra_props =
      opts
      |> Keyword.drop([:children, :id, :do])
      |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

    %{id: id, type: "combo_box", props: Map.merge(base_props, extra_props), children: []}
  end

  @doc """
  Multi-line text editor.

  ## Example

      text_editor("notes", model.notes, width: :fill, height: 200)
  """
  @spec text_editor(id :: String.t(), content :: String.t(), opts :: keyword()) ::
          Julep.Iced.ui_node()
  def text_editor(id, content, opts \\ []) do
    base_props = %{"content" => content}

    extra_props =
      opts
      |> Keyword.drop([:children, :id, :do])
      |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

    %{id: id, type: "text_editor", props: Map.merge(base_props, extra_props), children: []}
  end

  # ---------------------------------------------------------------------------
  # Additional display widgets
  # ---------------------------------------------------------------------------

  @doc """
  Raster image display.

  ## Example

      image("logo", "/assets/logo.png", width: 200, content_fit: :cover)
  """
  @spec image(id :: String.t(), source :: String.t(), opts :: keyword()) :: Julep.Iced.ui_node()
  def image(id, source, opts \\ []) do
    base_props = %{"source" => source}

    extra_props =
      opts
      |> Keyword.drop([:children, :id, :do])
      |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

    %{id: id, type: "image", props: Map.merge(base_props, extra_props), children: []}
  end

  @doc """
  SVG image display.

  ## Example

      svg("icon", "/assets/icon.svg", width: 24, height: 24)
  """
  @spec svg(id :: String.t(), source :: String.t(), opts :: keyword()) :: Julep.Iced.ui_node()
  def svg(id, source, opts \\ []) do
    base_props = %{"source" => source}

    extra_props =
      opts
      |> Keyword.drop([:children, :id, :do])
      |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

    %{id: id, type: "svg", props: Map.merge(base_props, extra_props), children: []}
  end

  @doc """
  Markdown content renderer.

  Auto-generates an ID from the call site unless `:id` is given in opts.

  ## Example

      markdown("# Hello\\n\\nSome **bold** text")
  """
  defmacro markdown(content, opts \\ []) do
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

      id =
        Keyword.get(opts, :id) || Julep.UI.__auto_id__(unquote(caller_mod), unquote(caller_line))

      %{id: id, type: "markdown", props: Map.merge(base_props, extra_props), children: []}
    end
  end

  # ---------------------------------------------------------------------------
  # Additional layout/composite widgets (macros with do block support)
  # ---------------------------------------------------------------------------

  # -- tooltip(id, opts) ------------------------------------------------------

  @doc """
  Tooltip wrapper. Children are the content being tooltipped.

  ## Options

  - `:tip` -- tooltip text
  - `:position` -- `:top`, `:bottom`, `:left`, `:right`

  ## Example

      tooltip "save_tip", tip: "Save your work", position: :top do
        button("save", "Save")
      end
  """
  defmacro tooltip(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_fixed_node__("tooltip", unquote(id), [], children)
        end

      opts ->
        quote do
          Julep.UI.__build_fixed_node__("tooltip", unquote(id), unquote(opts), [])
        end
    end
  end

  @doc false
  defmacro tooltip(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_fixed_node__("tooltip", unquote(id), unquote(opts), children)
    end
  end

  # -- tabs(id, opts) ---------------------------------------------------------

  @doc """
  Tabbed container. Children are the tab content panels.

  ## Options

  - `:active` -- id of the active tab

  ## Example

      tabs "settings_tabs", active: "general" do
        container "general" do
          text("General settings")
        end
      end
  """
  defmacro tabs(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_fixed_node__("tabs", unquote(id), [], children)
        end

      opts ->
        quote do
          Julep.UI.__build_fixed_node__("tabs", unquote(id), unquote(opts), [])
        end
    end
  end

  @doc false
  defmacro tabs(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_fixed_node__("tabs", unquote(id), unquote(opts), children)
    end
  end

  # -- nav(id, opts) ----------------------------------------------------------

  @doc """
  Navigation container.

  ## Options

  - `:active` -- id of the active nav item

  ## Example

      nav "main_nav", active: "home" do
        button("home", "Home")
        button("settings", "Settings")
      end
  """
  defmacro nav(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_fixed_node__("nav", unquote(id), [], children)
        end

      opts ->
        quote do
          Julep.UI.__build_fixed_node__("nav", unquote(id), unquote(opts), [])
        end
    end
  end

  @doc false
  defmacro nav(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_fixed_node__("nav", unquote(id), unquote(opts), children)
    end
  end

  # -- modal(id, opts) --------------------------------------------------------

  @doc """
  Modal dialog overlay.

  ## Options

  - `:visible` -- boolean controlling visibility

  ## Example

      modal "confirm_dialog", visible: model.show_confirm do
        text("Are you sure?")
        button("yes", "Yes")
      end
  """
  defmacro modal(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_fixed_node__("modal", unquote(id), [], children)
        end

      opts ->
        quote do
          Julep.UI.__build_fixed_node__("modal", unquote(id), unquote(opts), [])
        end
    end
  end

  @doc false
  defmacro modal(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_fixed_node__("modal", unquote(id), unquote(opts), children)
    end
  end

  # -- card(id, opts) ---------------------------------------------------------

  @doc """
  Card container with optional title.

  ## Options

  - `:title` -- card heading text
  - `:padding` -- inner padding

  ## Example

      card "user_card", title: "Profile", padding: 16 do
        text("Alice")
      end
  """
  defmacro card(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_fixed_node__("card", unquote(id), [], children)
        end

      opts ->
        quote do
          Julep.UI.__build_fixed_node__("card", unquote(id), unquote(opts), [])
        end
    end
  end

  @doc false
  defmacro card(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_fixed_node__("card", unquote(id), unquote(opts), children)
    end
  end

  # -- panel(id, opts) --------------------------------------------------------

  @doc """
  Collapsible panel.

  ## Options

  - `:title` -- panel heading
  - `:collapsed` -- boolean

  ## Example

      panel "details", title: "Details", collapsed: false do
        text("Some details here")
      end
  """
  defmacro panel(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_fixed_node__("panel", unquote(id), [], children)
        end

      opts ->
        quote do
          Julep.UI.__build_fixed_node__("panel", unquote(id), unquote(opts), [])
        end
    end
  end

  @doc false
  defmacro panel(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_fixed_node__("panel", unquote(id), unquote(opts), children)
    end
  end

  # -- form(id, opts) ---------------------------------------------------------

  @doc """
  Form container for grouping input widgets.

  ## Options

  - `:spacing` -- gap between form fields

  ## Example

      form "login_form", spacing: 8 do
        text_input("user", "", placeholder: "Username")
        text_input("pass", "", placeholder: "Password")
        button("submit", "Log in")
      end
  """
  defmacro form(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_fixed_node__("form", unquote(id), [], children)
        end

      opts ->
        quote do
          Julep.UI.__build_fixed_node__("form", unquote(id), unquote(opts), [])
        end
    end
  end

  @doc false
  defmacro form(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_fixed_node__("form", unquote(id), unquote(opts), children)
    end
  end

  # -- split_pane(id, opts) ---------------------------------------------------

  @doc """
  Split pane layout dividing space between two sections.

  ## Options

  - `:ratio` -- float 0.0-1.0 controlling split position
  - `:direction` -- `:horizontal` or `:vertical`

  ## Example

      split_pane "editor_split", ratio: 0.3, direction: :horizontal do
        container "sidebar" do
          text("Sidebar")
        end
        container "main" do
          text("Main content")
        end
      end
  """
  defmacro split_pane(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_fixed_node__("split_pane", unquote(id), [], children)
        end

      opts ->
        quote do
          Julep.UI.__build_fixed_node__("split_pane", unquote(id), unquote(opts), [])
        end
    end
  end

  @doc false
  defmacro split_pane(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_fixed_node__("split_pane", unquote(id), unquote(opts), children)
    end
  end

  # ---------------------------------------------------------------------------
  # Canvas (function -- no children)
  # ---------------------------------------------------------------------------

  @doc """
  Canvas for drawing shapes. No children.

  ## Options

  - `:shapes` -- list of shape descriptors
  - `:width` / `:height` -- dimensions
  - `:background` -- background color

  ## Example

      canvas("drawing", shapes: [%{type: "circle", x: 50, y: 50, r: 20}], width: 400, height: 300)
  """
  @spec canvas(id :: String.t(), opts :: keyword()) :: Julep.Iced.ui_node()
  def canvas(id, opts \\ []) do
    props =
      opts
      |> Keyword.drop([:children, :id, :do])
      |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

    %{id: id, type: "canvas", props: props, children: []}
  end

  # -- pane_grid(id, opts) ----------------------------------------------------

  @doc """
  Pane grid for resizable tiled panes.

  ## Options

  - `:spacing` -- gap between panes
  - `:min_size` -- minimum pane size
  - `:on_resize` -- resize event tag
  - `:on_drag` -- drag event tag
  - `:on_click` -- click event tag

  Children are pane content keyed by ID.

  ## Example

      pane_grid "editor_panes", spacing: 2 do
        column id: "left" do
          text("Left pane")
        end
        column id: "right" do
          text("Right pane")
        end
      end
  """
  defmacro pane_grid(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_fixed_node__("pane_grid", unquote(id), [], children)
        end

      opts ->
        quote do
          Julep.UI.__build_fixed_node__("pane_grid", unquote(id), unquote(opts), [])
        end
    end
  end

  @doc false
  defmacro pane_grid(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_fixed_node__("pane_grid", unquote(id), unquote(opts), children)
    end
  end

  # -- rich_text(id, opts) ----------------------------------------------------

  @doc """
  Rich text display with styled spans.

  ## Options

  - `:spans` -- list of span descriptors
  - `:width` -- width

  ## Example

      rich_text("styled", spans: [%{text: "bold", weight: :bold}, %{text: " normal"}])
  """
  @spec rich_text(id :: String.t(), opts :: keyword()) :: Julep.Iced.ui_node()
  def rich_text(id, opts \\ []) do
    props =
      opts
      |> Keyword.drop([:children, :id, :do])
      |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)

    %{id: id, type: "rich_text", props: props, children: []}
  end

  # -- table(id, opts) --------------------------------------------------------

  @doc """
  Data table widget.

  ## Options

  - `:columns` -- list of column descriptors (`%{key, label, width}`)
  - `:rows` -- list of row data maps

  The `do` block can contain row content templates (e.g. for custom cell
  rendering). Children from the block are stored in `:children`.

  ## Examples

      table("users", columns: cols, rows: data)

      table "users", columns: cols, rows: data do
        text("custom footer")
      end
  """
  defmacro table(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Julep.UI.__build_fixed_node__("table", unquote(id), [], children)
        end

      opts ->
        quote do
          Julep.UI.__build_fixed_node__("table", unquote(id), unquote(opts), [])
        end
    end
  end

  @doc false
  defmacro table(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Julep.UI.__build_fixed_node__("table", unquote(id), unquote(opts), children)
    end
  end

  # ---------------------------------------------------------------------------
  # Public runtime helpers called from macro-generated code
  # ---------------------------------------------------------------------------

  @doc false
  @spec __build_fixed_node__(
          type :: String.t(),
          id :: String.t(),
          opts :: keyword(),
          children :: [Julep.Iced.ui_node()]
        ) ::
          Julep.Iced.ui_node()
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
  @spec find(tree :: Julep.Iced.ui_node(), id :: String.t()) :: Julep.Iced.ui_node() | nil
  defdelegate find(tree, id), to: Julep.Tree

  @doc "Returns true if a node with `id` exists in the tree."
  @spec exists?(tree :: Julep.Iced.ui_node() | nil, id :: String.t()) :: boolean()
  defdelegate exists?(tree, id), to: Julep.Tree

  @doc "Returns all node IDs in the tree."
  @spec ids(tree :: Julep.Iced.ui_node() | nil) :: [String.t()]
  defdelegate ids(tree), to: Julep.Tree

  @doc "Finds all nodes matching a predicate."
  @spec find_all(
          tree :: Julep.Iced.ui_node() | nil,
          id_or_pred :: String.t() | (Julep.Iced.ui_node() -> boolean())
        ) ::
          [Julep.Iced.ui_node()]
  defdelegate find_all(tree, id_or_pred), to: Julep.Tree

  # ---------------------------------------------------------------------------
  # Private macro helpers
  # ---------------------------------------------------------------------------

  defp block_to_exprs({:__block__, _, exprs}), do: exprs
  defp block_to_exprs(single_expr), do: [single_expr]
end
