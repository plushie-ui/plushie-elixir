defmodule Toddy.UI do
  @moduledoc """
  Ergonomic builder layer for Toddy UI trees.

  Import this module in your `view/1` function to get concise widget builder
  syntax with optional `do` block sugar for children.

  ## Usage

      def view(model) do
        import Toddy.UI

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

  Props use atom keys internally; string keys are used only at the wire encoding
  boundary. Reserved opts keys (`:children`, `:id`, `:do`) are not treated as props.

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

  **WARNING: Auto-generated IDs are unstable.** Layout and display widgets
  that do not receive an explicit `:id` option generate one from the call
  site line number: `"auto:ModuleName:42"`. These IDs change whenever you
  refactor code, add/remove lines above the call, or use conditional
  rendering (`if`/`case`) that moves the call to a different branch.

  When an ID changes between renders, the renderer treats it as a
  removal + insertion, **losing all widget-local state** (scroll position,
  text cursor, focus, editor content).

  **Always supply explicit `:id` opts for stateful widgets:**
  `text_editor`, `combo_box`, `pane_grid`, `scrollable`, `text_input`.

  Auto-IDs are fine for purely visual widgets like `text`, `row`, `column`
  where state loss is invisible.

  ## Formatter

  Toddy exports formatter settings that keep layout blocks paren-free so
  they read like declarative markup. Add `:toddy` to `import_deps` in
  your `.formatter.exs`:

      # .formatter.exs
      [
        inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
        import_deps: [:toddy]
      ]

  Layout blocks stay paren-free; leaf widgets keep parens for clarity:

      column padding: 8 do
        text("count", "Count: \#{model.count}", size: 24)
        button("inc", "+1")
      end

  ## Container inline props

  Container widgets (`column`, `row`, `container`, etc.) support option
  declarations directly inside their do-blocks, mixed with children:

      column do
        spacing 8
        padding do
          top 16
          bottom 16
        end
        width :fill

        text("Hello")
        button("save", "Save")
      end

  Options and children can be freely mixed. Options are validated at
  compile time -- using an option that doesn't belong to the container
  produces a helpful error.

  Struct-typed options support nested do-blocks:

      container "hero" do
        border do
          width 1
          color "#ddd"
          rounded 4
        end
        shadow do
          color "#00000022"
          offset_y 2
          blur_radius 4
        end
        padding 20

        text("Welcome")
      end

  All three forms are equivalent and can be mixed:

      column spacing: 8, padding: 16 do ... end    # keyword on call line
      column do spacing 8; padding 16; ... end      # inline in block
      column do padding do top 16 end; ... end      # nested do-block

  ## Block-form options

  Leaf widgets accept an optional `do` block for setting props when the
  keyword list gets long:

      button "save", "Save" do
        style(:primary)
      end

  The keyword form is still valid and preferred for short option lists.

  ## Canvas shapes

  Canvas shape functions (`rect`, `circle`, `line`, `path`, `stroke`,
  `linear_gradient`, `move_to`, `line_to`, etc.) and canvas structure
  macros (`group`, `layer`) are available directly via `import Toddy.UI`.
  No separate `import Toddy.Canvas.Shape` is needed inside canvas blocks.

  Inside `canvas`, `layer`, and `group` blocks, `text`, `image`, and
  `svg` calls resolve automatically to their canvas shape variants.

  The `interactive` directive inside a `group` block attaches hit-test
  and accessibility metadata:

      canvas "toggle", width: 52, height: 28 do
        layer "bg" do
          group do
            interactive "switch", on_click: true, cursor: :pointer
            rect(0, 0, 52, 28, fill: "#4CAF50", radius: 14)
            circle(36, 14, 10, fill: "#fff")
          end
        end
      end

  Import `Toddy.Canvas.Shape` directly only when building shapes in
  helper functions outside canvas blocks.

  ## Prop override semantics

  When both the keyword argument on the call line and a block
  declaration specify the same option, the block value wins:

      column spacing: 8 do
        spacing 16         # overrides -- spacing is 16
        text("hello")
      end

  This applies to all container and leaf widget do-blocks.

  ## Control flow preservation

  All DSL blocks preserve every expression from control flow forms.
  Multi-expression `if`/`for`/`case`/`cond`/`with` bodies contribute
  all their expressions to the parent's children list, not just the
  last one.

  ## Tree query

  `find/2` is re-exported from `Toddy.Tree` for convenience:

      Toddy.UI.find(tree, "my_button")

  ## Internals

  For maintainer and extension author details on the macro architecture,
  see `docs/dsl-internals.md`.
  """

  # Container widget modules and their display names, used to build the
  # reverse map from option key -> owning containers for compile-time
  # validation in container_scope.
  @container_modules [
    {Toddy.Widget.Column, "column"},
    {Toddy.Widget.Row, "row"},
    {Toddy.Widget.Container, "container"},
    {Toddy.Widget.Overlay, "overlay"},
    {Toddy.Widget.Scrollable, "scrollable"},
    {Toddy.Widget.Stack, "stack"},
    {Toddy.Widget.Grid, "grid"},
    {Toddy.Widget.KeyedColumn, "keyed_column"},
    {Toddy.Widget.Responsive, "responsive"},
    {Toddy.Widget.Pin, "pin"},
    {Toddy.Widget.Floating, "floating"},
    {Toddy.Widget.MouseArea, "mouse_area"},
    {Toddy.Widget.Sensor, "sensor"},
    {Toddy.Widget.Themer, "themer"},
    {Toddy.Widget.PaneGrid, "pane_grid"},
    {Toddy.Widget.Table, "table"},
    {Toddy.Widget.Tooltip, "tooltip"},
    {Toddy.Widget.Space, "space"},
    {Toddy.Widget.Rule, "rule"},
    {Toddy.Widget.Window, "window"}
  ]

  @all_container_option_owners (for {mod, name} <- @container_modules,
                                    Code.ensure_loaded?(mod) and
                                      function_exported?(mod, :__option_keys__, 0),
                                    key <- mod.__option_keys__(),
                                    reduce: %{} do
                                  acc -> Map.update(acc, key, [name], &[name | &1])
                                end)

  @all_container_option_names Map.keys(@all_container_option_owners)

  # ---------------------------------------------------------------------------
  # Core build helpers (public -- macro-generated code calls these at runtime)
  # ---------------------------------------------------------------------------

  @doc false
  @spec __build_container__(
          widget_mod :: module(),
          id :: String.t() | nil,
          opts :: keyword(),
          items :: [Toddy.Widget.ui_node() | {:__widget_prop__, atom(), term()}],
          auto_id :: String.t() | nil
        ) :: Toddy.Widget.ui_node()
  def __build_container__(widget_mod, id, opts, items, auto_id) do
    resolved_id = id || Keyword.get(opts, :id) || auto_id

    # Partition block items into props and children
    {prop_tuples, children} =
      Enum.split_with(items, &match?({:__widget_prop__, _, _}, &1))

    block_opts = Enum.map(prop_tuples, fn {:__widget_prop__, k, v} -> {k, v} end)

    # Merge: keyword opts from call line + block opts (block wins on conflict)
    merged_opts = Keyword.merge(clean_opts(opts), block_opts)

    resolved_children =
      if children != [] do
        children
      else
        Keyword.get(opts, :children, [])
      end

    widget = widget_mod.new(resolved_id, merged_opts)

    widget =
      if resolved_children != [] do
        widget_mod.extend(widget, resolved_children)
      else
        widget
      end

    widget_mod.build(widget)
  end

  # Kept for external callers. Internal macros use compile_auto_id/2 to
  # compute the string at compile time and inject a literal, avoiding
  # runtime Module.split + Enum.join on every render.
  @doc false
  @spec __auto_id__(mod :: module() | nil, line :: non_neg_integer()) :: String.t()
  def __auto_id__(nil, line), do: "auto:nomodule:#{line}"

  def __auto_id__(mod, line) do
    mod_str = mod |> Module.split() |> Enum.join(".")
    "auto:#{mod_str}:#{line}"
  end

  # Compile-time auto ID computation. Called inside defmacro bodies where
  # __CALLER__.module and __CALLER__.line are known at compile time.
  # The result is injected as a string literal in the generated code.
  @doc false
  defp compile_auto_id(nil, line), do: "auto:nomodule:#{line}"

  defp compile_auto_id(mod, line) do
    mod_str = mod |> Module.split() |> Enum.join(".")
    "auto:#{mod_str}:#{line}"
  end

  # ---------------------------------------------------------------------------
  # Positional argument validation
  # ---------------------------------------------------------------------------

  # Several widget functions accept required values as positional args followed
  # by an optional keyword list.  It is easy to accidentally pass the value as
  # a keyword (e.g. `text_input("id", value: v)` instead of
  # `text_input("id", v)`).  Elixir merges the keyword into the preceding
  # argument silently, so we guard against it here.  A FunctionClauseError
  # showing the keyword list in the args is far clearer than a cryptic
  # Msgpax.Packer error three layers deep.

  @doc false
  defguard is_keyword(v)
           when is_list(v) and v != [] and is_tuple(hd(v)) and tuple_size(hd(v)) == 2 and
                  is_atom(elem(hd(v), 0))

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
        option_keys = Toddy.Widget.Window.__option_keys__()
        option_types = Toddy.Widget.Window.__option_types__()
        block = container_scope(block, option_keys, option_types, "window")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Toddy.UI.__build_container__(
            Toddy.Widget.Window,
            unquote(id),
            [],
            items,
            nil
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Window,
            unquote(id),
            unquote(opts),
            [],
            nil
          )
        end
    end
  end

  @doc false
  defmacro window(id, opts, do: block) do
    option_keys = Toddy.Widget.Window.__option_keys__()
    option_types = Toddy.Widget.Window.__option_types__()
    block = container_scope(block, option_keys, option_types, "window")
    exprs = block_to_exprs(block)

    quote do
      items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Window,
        unquote(id),
        unquote(opts),
        items,
        nil
      )
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
        option_keys = Toddy.Widget.Column.__option_keys__()
        option_types = Toddy.Widget.Column.__option_types__()
        block = container_scope(block, option_keys, option_types, "column")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Toddy.UI.__build_container__(
            Toddy.Widget.Column,
            nil,
            [],
            items,
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Column,
            nil,
            unquote(opts),
            [],
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end
    end
  end

  @doc false
  defmacro column(opts, do: block) do
    option_keys = Toddy.Widget.Column.__option_keys__()
    option_types = Toddy.Widget.Column.__option_types__()
    block = container_scope(block, option_keys, option_types, "column")
    exprs = block_to_exprs(block)
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Column,
        nil,
        unquote(opts),
        items,
        unquote(compile_auto_id(caller_mod, caller_line))
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
        option_keys = Toddy.Widget.Row.__option_keys__()
        option_types = Toddy.Widget.Row.__option_types__()
        block = container_scope(block, option_keys, option_types, "row")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Toddy.UI.__build_container__(
            Toddy.Widget.Row,
            nil,
            [],
            items,
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Row,
            nil,
            unquote(opts),
            [],
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end
    end
  end

  @doc false
  defmacro row(opts, do: block) do
    option_keys = Toddy.Widget.Row.__option_keys__()
    option_types = Toddy.Widget.Row.__option_types__()
    block = container_scope(block, option_keys, option_types, "row")
    exprs = block_to_exprs(block)
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Row,
        nil,
        unquote(opts),
        items,
        unquote(compile_auto_id(caller_mod, caller_line))
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
        option_keys = Toddy.Widget.Container.__option_keys__()
        option_types = Toddy.Widget.Container.__option_types__()
        block = container_scope(block, option_keys, option_types, "container")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.Container, unquote(id), [], items, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Container,
            unquote(id),
            unquote(opts),
            [],
            nil
          )
        end
    end
  end

  @doc false
  defmacro container(id, opts, do: block) do
    option_keys = Toddy.Widget.Container.__option_keys__()
    option_types = Toddy.Widget.Container.__option_types__()
    block = container_scope(block, option_keys, option_types, "container")
    exprs = block_to_exprs(block)

    quote do
      items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Container,
        unquote(id),
        unquote(opts),
        items,
        nil
      )
    end
  end

  # -- overlay(id, opts) ------------------------------------------------------

  @doc """
  Overlay container. First child is the anchor, second is the overlay content.

  ## Options

  - `:position` -- `:below`, `:above`, `:left`, `:right`
  - `:gap` -- space between anchor and overlay in pixels
  - `:offset_x` -- horizontal offset in pixels
  - `:offset_y` -- vertical offset in pixels

  ## Example

      overlay "popup", position: :below, gap: 4 do
        button("anchor", "Click me")
        container "dropdown" do
          text("dropdown_text", "Dropdown content")
        end
      end
  """
  defmacro overlay(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        option_keys = Toddy.Widget.Overlay.__option_keys__()
        option_types = Toddy.Widget.Overlay.__option_types__()
        block = container_scope(block, option_keys, option_types, "overlay")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.Overlay, unquote(id), [], items, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(Toddy.Widget.Overlay, unquote(id), unquote(opts), [], nil)
        end
    end
  end

  @doc false
  defmacro overlay(id, opts, do: block) do
    option_keys = Toddy.Widget.Overlay.__option_keys__()
    option_types = Toddy.Widget.Overlay.__option_types__()
    block = container_scope(block, option_keys, option_types, "overlay")
    exprs = block_to_exprs(block)

    quote do
      items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Overlay,
        unquote(id),
        unquote(opts),
        items,
        nil
      )
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
        option_keys = Toddy.Widget.Scrollable.__option_keys__()
        option_types = Toddy.Widget.Scrollable.__option_types__()
        block = container_scope(block, option_keys, option_types, "scrollable")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.Scrollable, unquote(id), [], items, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Scrollable,
            unquote(id),
            unquote(opts),
            [],
            nil
          )
        end
    end
  end

  @doc false
  defmacro scrollable(id, opts, do: block) do
    option_keys = Toddy.Widget.Scrollable.__option_keys__()
    option_types = Toddy.Widget.Scrollable.__option_types__()
    block = container_scope(block, option_keys, option_types, "scrollable")
    exprs = block_to_exprs(block)

    quote do
      items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Scrollable,
        unquote(id),
        unquote(opts),
        items,
        nil
      )
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
        option_keys = Toddy.Widget.Stack.__option_keys__()
        option_types = Toddy.Widget.Stack.__option_types__()
        block = container_scope(block, option_keys, option_types, "stack")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Toddy.UI.__build_container__(
            Toddy.Widget.Stack,
            nil,
            [],
            items,
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Stack,
            nil,
            unquote(opts),
            [],
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end
    end
  end

  @doc false
  defmacro stack(opts, do: block) do
    option_keys = Toddy.Widget.Stack.__option_keys__()
    option_types = Toddy.Widget.Stack.__option_types__()
    block = container_scope(block, option_keys, option_types, "stack")
    exprs = block_to_exprs(block)
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Stack,
        nil,
        unquote(opts),
        items,
        unquote(compile_auto_id(caller_mod, caller_line))
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
        option_keys = Toddy.Widget.Grid.__option_keys__()
        option_types = Toddy.Widget.Grid.__option_types__()
        block = container_scope(block, option_keys, option_types, "grid")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Toddy.UI.__build_container__(
            Toddy.Widget.Grid,
            nil,
            [],
            items,
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Grid,
            nil,
            unquote(opts),
            [],
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end
    end
  end

  @doc false
  defmacro grid(opts, do: block) do
    option_keys = Toddy.Widget.Grid.__option_keys__()
    option_types = Toddy.Widget.Grid.__option_types__()
    block = container_scope(block, option_keys, option_types, "grid")
    exprs = block_to_exprs(block)
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Grid,
        nil,
        unquote(opts),
        items,
        unquote(compile_auto_id(caller_mod, caller_line))
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
          text(item.id, item.name)
        end
      end
  """
  defmacro keyed_column(opts_or_block \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    case opts_or_block do
      [do: block] ->
        option_keys = Toddy.Widget.KeyedColumn.__option_keys__()
        option_types = Toddy.Widget.KeyedColumn.__option_types__()
        block = container_scope(block, option_keys, option_types, "keyed_column")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Toddy.UI.__build_container__(
            Toddy.Widget.KeyedColumn,
            nil,
            [],
            items,
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.KeyedColumn,
            nil,
            unquote(opts),
            [],
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end
    end
  end

  @doc false
  defmacro keyed_column(opts, do: block) do
    option_keys = Toddy.Widget.KeyedColumn.__option_keys__()
    option_types = Toddy.Widget.KeyedColumn.__option_types__()
    block = container_scope(block, option_keys, option_types, "keyed_column")
    exprs = block_to_exprs(block)
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.KeyedColumn,
        nil,
        unquote(opts),
        items,
        unquote(compile_auto_id(caller_mod, caller_line))
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
        option_keys = Toddy.Widget.Responsive.__option_keys__()
        option_types = Toddy.Widget.Responsive.__option_types__()
        block = container_scope(block, option_keys, option_types, "responsive")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Toddy.UI.__build_container__(
            Toddy.Widget.Responsive,
            nil,
            [],
            items,
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Responsive,
            nil,
            unquote(opts),
            [],
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end
    end
  end

  @doc false
  defmacro responsive(opts, do: block) do
    option_keys = Toddy.Widget.Responsive.__option_keys__()
    option_types = Toddy.Widget.Responsive.__option_types__()
    block = container_scope(block, option_keys, option_types, "responsive")
    exprs = block_to_exprs(block)
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Responsive,
        nil,
        unquote(opts),
        items,
        unquote(compile_auto_id(caller_mod, caller_line))
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
        option_keys = Toddy.Widget.Pin.__option_keys__()
        option_types = Toddy.Widget.Pin.__option_types__()
        block = container_scope(block, option_keys, option_types, "pin")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.Pin, unquote(id), [], items, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(Toddy.Widget.Pin, unquote(id), unquote(opts), [], nil)
        end
    end
  end

  @doc false
  defmacro pin(id, opts, do: block) do
    option_keys = Toddy.Widget.Pin.__option_keys__()
    option_types = Toddy.Widget.Pin.__option_types__()
    block = container_scope(block, option_keys, option_types, "pin")
    exprs = block_to_exprs(block)

    quote do
      items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Toddy.UI.__build_container__(Toddy.Widget.Pin, unquote(id), unquote(opts), items, nil)
    end
  end

  # -- floating(id, opts) -----------------------------------------------------

  @doc """
  Floating overlay layout.

  ## Example

      floating "popup" do
        text("Floating content")
      end
  """
  defmacro floating(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        option_keys = Toddy.Widget.Floating.__option_keys__()
        option_types = Toddy.Widget.Floating.__option_types__()
        block = container_scope(block, option_keys, option_types, "floating")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.Floating, unquote(id), [], items, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(Toddy.Widget.Floating, unquote(id), unquote(opts), [], nil)
        end
    end
  end

  @doc false
  defmacro floating(id, opts, do: block) do
    option_keys = Toddy.Widget.Floating.__option_keys__()
    option_types = Toddy.Widget.Floating.__option_types__()
    block = container_scope(block, option_keys, option_types, "floating")
    exprs = block_to_exprs(block)

    quote do
      items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Floating,
        unquote(id),
        unquote(opts),
        items,
        nil
      )
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
        option_keys = Toddy.Widget.MouseArea.__option_keys__()
        option_types = Toddy.Widget.MouseArea.__option_types__()
        block = container_scope(block, option_keys, option_types, "mouse_area")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.MouseArea, unquote(id), [], items, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.MouseArea,
            unquote(id),
            unquote(opts),
            [],
            nil
          )
        end
    end
  end

  @doc false
  defmacro mouse_area(id, opts, do: block) do
    option_keys = Toddy.Widget.MouseArea.__option_keys__()
    option_types = Toddy.Widget.MouseArea.__option_types__()
    block = container_scope(block, option_keys, option_types, "mouse_area")
    exprs = block_to_exprs(block)

    quote do
      items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.MouseArea,
        unquote(id),
        unquote(opts),
        items,
        nil
      )
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
        option_keys = Toddy.Widget.Sensor.__option_keys__()
        option_types = Toddy.Widget.Sensor.__option_types__()
        block = container_scope(block, option_keys, option_types, "sensor")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.Sensor, unquote(id), [], items, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(Toddy.Widget.Sensor, unquote(id), unquote(opts), [], nil)
        end
    end
  end

  @doc false
  defmacro sensor(id, opts, do: block) do
    option_keys = Toddy.Widget.Sensor.__option_keys__()
    option_types = Toddy.Widget.Sensor.__option_types__()
    block = container_scope(block, option_keys, option_types, "sensor")
    exprs = block_to_exprs(block)

    quote do
      items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Toddy.UI.__build_container__(Toddy.Widget.Sensor, unquote(id), unquote(opts), items, nil)
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
        option_keys = Toddy.Widget.Themer.__option_keys__()
        option_types = Toddy.Widget.Themer.__option_types__()
        block = container_scope(block, option_keys, option_types, "themer")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.Themer, unquote(id), [], items, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(Toddy.Widget.Themer, unquote(id), unquote(opts), [], nil)
        end
    end
  end

  @doc false
  defmacro themer(id, opts, do: block) do
    option_keys = Toddy.Widget.Themer.__option_keys__()
    option_types = Toddy.Widget.Themer.__option_types__()
    block = container_scope(block, option_keys, option_types, "themer")
    exprs = block_to_exprs(block)

    quote do
      items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Toddy.UI.__build_container__(Toddy.Widget.Themer, unquote(id), unquote(opts), items, nil)
    end
  end

  # -- space(opts) ------------------------------------------------------------

  @doc """
  Flexible spacer. No children.

  ## Options

  - `:width` -- `:fill`, `:shrink`, or number
  - `:height` -- `:fill`, `:shrink`, or number

  ## Example

      space(width: :fill)

      space do
        width :fill
      end
  """
  defmacro space(opts_or_do \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line
    option_keys = Toddy.Widget.Space.__option_keys__()
    option_types = Toddy.Widget.Space.__option_types__()

    case opts_or_do do
      [do: block] ->
        block = container_scope(block, option_keys, option_types, "space")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Toddy.UI.__build_container__(
            Toddy.Widget.Space,
            nil,
            [],
            items,
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Space,
            nil,
            unquote(opts),
            [],
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Input widgets (require explicit id; support keyword and do-block opts)
  # ---------------------------------------------------------------------------

  @doc """
  Clickable button.

  Emits `%Widget{type: :click, id: id}` when clicked.

  ## Example

      button("save", "Save", style: :primary)

      button "save", "Save" do
        style :primary
      end
  """
  defmacro button(id, label, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        option_keys = Toddy.Widget.Button.__option_keys__()
        option_types = Toddy.Widget.Button.__option_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "button", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)
        quote do: Toddy.UI.__build_button__(unquote(id), unquote(label), unquote(opts_ast))

      opts ->
        quote do: Toddy.UI.__build_button__(unquote(id), unquote(label), unquote(opts))
    end
  end

  @doc false
  @spec __build_button__(String.t(), String.t(), keyword()) :: Toddy.Widget.ui_node()
  def __build_button__(id, label, opts) do
    Toddy.Widget.Button.new(id, label, clean_opts(opts)) |> Toddy.Widget.Button.build()
  end

  @doc """
  Single-line text input.

  Emits `%Widget{type: :input, id: id, value: value}` on change and `%Widget{type: :submit, id: id, value: value}` on Enter.

  ## Example

      text_input("name", model.name, placeholder: "Your name")

      text_input "name", model.name do
        placeholder "Your name"
      end
  """
  defmacro text_input(id, value, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        option_keys = Toddy.Widget.TextInput.__option_keys__()
        option_types = Toddy.Widget.TextInput.__option_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "text_input", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)
        quote do: Toddy.UI.__build_text_input__(unquote(id), unquote(value), unquote(opts_ast))

      opts ->
        quote do: Toddy.UI.__build_text_input__(unquote(id), unquote(value), unquote(opts))
    end
  end

  @doc false
  @spec __build_text_input__(String.t(), String.t(), keyword()) :: Toddy.Widget.ui_node()
  def __build_text_input__(id, value, opts) when not is_keyword(value) do
    Toddy.Widget.TextInput.new(id, value, clean_opts(opts)) |> Toddy.Widget.TextInput.build()
  end

  @doc """
  Boolean checkbox toggle.

  Emits `%Widget{type: :toggle, id: id, value: boolean}` when toggled.

  ## Example

      checkbox("agree", model.agreed, label: "I agree")

      checkbox "agree", model.agreed do
        label "I agree"
      end
  """
  defmacro checkbox(id, checked, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        option_keys = Toddy.Widget.Checkbox.__option_keys__()
        option_types = Toddy.Widget.Checkbox.__option_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "checkbox", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)
        quote do: Toddy.UI.__build_checkbox__(unquote(id), unquote(checked), unquote(opts_ast))

      opts ->
        quote do: Toddy.UI.__build_checkbox__(unquote(id), unquote(checked), unquote(opts))
    end
  end

  @doc false
  @spec __build_checkbox__(String.t(), boolean(), keyword()) :: Toddy.Widget.ui_node()
  def __build_checkbox__(id, checked, opts) when not is_keyword(checked) do
    clean = clean_opts(opts)
    {label, remaining} = Keyword.pop(clean, :label, "")
    Toddy.Widget.Checkbox.new(id, label, checked, remaining) |> Toddy.Widget.Checkbox.build()
  end

  # ---------------------------------------------------------------------------
  # Display widgets
  # ---------------------------------------------------------------------------

  @doc """
  Text label.

  ## Forms

  - `text(content)` -- auto-generated ID (sugar for quick labels)
  - `text(id, content)` -- explicit ID
  - `text(id, content, opts)` -- explicit ID with options

  ## Example

      text("Hello, world!")
      text("greeting", "Hello, world!", size: 18)
  """
  defmacro text(content) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      Toddy.Widget.Text.new(unquote(compile_auto_id(caller_mod, caller_line)), unquote(content))
      |> Toddy.Widget.Text.build()
    end
  end

  @doc false
  defmacro text(id, content) do
    quote do
      Toddy.Widget.Text.new(unquote(id), unquote(content)) |> Toddy.Widget.Text.build()
    end
  end

  @doc false
  defmacro text(id, content, opts_or_do) do
    if numeric_literal?(id) and numeric_literal?(content) do
      raise CompileError,
        line: __CALLER__.line,
        description: """
        text/3 is not valid here. Expected:

            text("content")
            text("id", "content")
            text("id", "content", size: 18)
        """
    end

    case opts_or_do do
      [do: block] ->
        option_keys = Toddy.Widget.Text.__option_keys__()
        option_types = Toddy.Widget.Text.__option_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "text", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do
          Toddy.Widget.Text.new(unquote(id), unquote(content), unquote(opts_ast))
          |> Toddy.Widget.Text.build()
        end

      opts ->
        quote do
          Toddy.Widget.Text.new(unquote(id), unquote(content), unquote(opts))
          |> Toddy.Widget.Text.build()
        end
    end
  end

  @doc """
  Horizontal or vertical divider.

  ## Example

      rule(width: :fill)

      rule do
        direction :vertical
        style :weak
      end
  """
  defmacro rule(opts_or_do \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line
    option_keys = Toddy.Widget.Rule.__option_keys__()
    option_types = Toddy.Widget.Rule.__option_types__()

    case opts_or_do do
      [do: block] ->
        block = container_scope(block, option_keys, option_types, "rule")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Toddy.UI.__build_container__(
            Toddy.Widget.Rule,
            nil,
            [],
            items,
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Rule,
            nil,
            unquote(opts),
            [],
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end
    end
  end

  @doc """
  Progress indicator.

  ## Forms

  - `progress_bar(range, value)` -- auto-generated ID (sugar)
  - `progress_bar(id, range, value)` -- explicit ID
  - `progress_bar(id, range, value, opts)` -- explicit ID with options

  ## Arguments

  - `range` -- `{min, max}` tuple defining the full range
  - `value` -- current value within the range

  ## Example

      progress_bar({0, 100}, model.progress)
      progress_bar("dl_progress", {0, 100}, model.progress, height: 8)
  """
  defmacro progress_bar(range, value) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      Toddy.Widget.ProgressBar.new(
        unquote(compile_auto_id(caller_mod, caller_line)),
        unquote(range),
        unquote(value)
      )
      |> Toddy.Widget.ProgressBar.build()
    end
  end

  @doc false
  defmacro progress_bar(id, range, value) do
    quote do
      Toddy.Widget.ProgressBar.new(unquote(id), unquote(range), unquote(value))
      |> Toddy.Widget.ProgressBar.build()
    end
  end

  @doc false
  defmacro progress_bar(id, range, value, opts_or_do) do
    case opts_or_do do
      [do: block] ->
        option_keys = Toddy.Widget.ProgressBar.__option_keys__()
        option_types = Toddy.Widget.ProgressBar.__option_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "progress_bar", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do
          Toddy.Widget.ProgressBar.new(
            unquote(id),
            unquote(range),
            unquote(value),
            unquote(opts_ast)
          )
          |> Toddy.Widget.ProgressBar.build()
        end

      opts ->
        quote do
          Toddy.Widget.ProgressBar.new(unquote(id), unquote(range), unquote(value), unquote(opts))
          |> Toddy.Widget.ProgressBar.build()
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Additional input widgets
  # ---------------------------------------------------------------------------

  @doc """
  Toggle switch.

  Emits `%Widget{type: :toggle, id: id, value: boolean}` when toggled.

  ## Example

      toggler("dark_mode", model.dark_mode, label: "Dark mode")

      toggler "dark_mode", model.dark_mode do
        label "Dark mode"
      end
  """
  defmacro toggler(id, is_toggled, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        option_keys = Toddy.Widget.Toggler.__option_keys__()
        option_types = Toddy.Widget.Toggler.__option_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "toggler", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)
        quote do: Toddy.UI.__build_toggler__(unquote(id), unquote(is_toggled), unquote(opts_ast))

      opts ->
        quote do: Toddy.UI.__build_toggler__(unquote(id), unquote(is_toggled), unquote(opts))
    end
  end

  @doc false
  @spec __build_toggler__(String.t(), boolean(), keyword()) :: Toddy.Widget.ui_node()
  def __build_toggler__(id, is_toggled, opts) when not is_keyword(is_toggled) do
    Toddy.Widget.Toggler.new(id, is_toggled, clean_opts(opts)) |> Toddy.Widget.Toggler.build()
  end

  @doc """
  Radio button for single-value selection from a group.

  Use the `group` option so all radios in the same group emit select events
  with the group name as the ID instead of each radio's individual ID.

  ## Example

      radio("size_sm", "small", model.size, label: "Small", group: "size")
      radio("size_lg", "large", model.size, label: "Large", group: "size")

      radio "size_sm", "small", model.size do
        label "Small"
        group "size"
      end
  """
  defmacro radio(id, value, selected, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        option_keys = Toddy.Widget.Radio.__option_keys__()
        option_types = Toddy.Widget.Radio.__option_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "radio", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do
          Toddy.UI.__build_radio__(
            unquote(id),
            unquote(value),
            unquote(selected),
            unquote(opts_ast)
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_radio__(
            unquote(id),
            unquote(value),
            unquote(selected),
            unquote(opts)
          )
        end
    end
  end

  @doc false
  @spec __build_radio__(String.t(), term(), term(), keyword()) :: Toddy.Widget.ui_node()
  def __build_radio__(id, value, selected, opts)
      when not is_keyword(value) and not is_keyword(selected) do
    Toddy.Widget.Radio.new(id, value, selected, clean_opts(opts)) |> Toddy.Widget.Radio.build()
  end

  @doc """
  Horizontal slider for numeric range input.

  ## Arguments

  - `range` -- `{min, max}` tuple or `min..max` Range
  - `value` -- current value

  ## Example

      slider("volume", {0, 100}, model.volume, step: 5)
      slider("volume", 0..100, model.volume, step: 5)

      slider "volume", {0, 100}, model.volume do
        step 5
      end
  """
  defmacro slider(id, range, value, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        option_keys = Toddy.Widget.Slider.__option_keys__()
        option_types = Toddy.Widget.Slider.__option_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "slider", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do
          Toddy.UI.__build_slider__(
            unquote(id),
            unquote(range),
            unquote(value),
            unquote(opts_ast)
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_slider__(
            unquote(id),
            unquote(range),
            unquote(value),
            unquote(opts)
          )
        end
    end
  end

  @doc false
  @spec __build_slider__(String.t(), {number(), number()}, number(), keyword()) ::
          Toddy.Widget.ui_node()
  def __build_slider__(id, range, value, opts)
      when not is_keyword(range) and not is_keyword(value) do
    Toddy.Widget.Slider.new(id, normalize_range(range), value, clean_opts(opts))
    |> Toddy.Widget.Slider.build()
  end

  @doc """
  Vertical slider for numeric range input.

  Same as `slider/4` but oriented vertically. Accepts `{min, max}` or `min..max`.

  ## Example

      vertical_slider("brightness", {0, 100}, model.brightness)
      vertical_slider("brightness", 0..100, model.brightness)

      vertical_slider "brightness", {0, 100}, model.brightness do
        step 1
      end
  """
  defmacro vertical_slider(id, range, value, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        option_keys = Toddy.Widget.VerticalSlider.__option_keys__()
        option_types = Toddy.Widget.VerticalSlider.__option_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "vertical_slider", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do
          Toddy.UI.__build_vertical_slider__(
            unquote(id),
            unquote(range),
            unquote(value),
            unquote(opts_ast)
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_vertical_slider__(
            unquote(id),
            unquote(range),
            unquote(value),
            unquote(opts)
          )
        end
    end
  end

  @doc false
  @spec __build_vertical_slider__(String.t(), {number(), number()}, number(), keyword()) ::
          Toddy.Widget.ui_node()
  def __build_vertical_slider__(id, range, value, opts)
      when not is_keyword(range) and not is_keyword(value) do
    Toddy.Widget.VerticalSlider.new(id, normalize_range(range), value, clean_opts(opts))
    |> Toddy.Widget.VerticalSlider.build()
  end

  @doc """
  Dropdown pick list for selecting from a list of options.

  ## Example

      pick_list("country", ["UK", "US", "DE"], model.country, placeholder: "Choose...")

      pick_list "country", ["UK", "US", "DE"], model.country do
        placeholder "Choose..."
      end
  """
  defmacro pick_list(id, options, selected, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        option_keys = Toddy.Widget.PickList.__option_keys__()
        option_types = Toddy.Widget.PickList.__option_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "pick_list", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do
          Toddy.UI.__build_pick_list__(
            unquote(id),
            unquote(options),
            unquote(selected),
            unquote(opts_ast)
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_pick_list__(
            unquote(id),
            unquote(options),
            unquote(selected),
            unquote(opts)
          )
        end
    end
  end

  @doc false
  @spec __build_pick_list__(String.t(), [String.t()], String.t() | nil, keyword()) ::
          Toddy.Widget.ui_node()
  def __build_pick_list__(id, options, selected, opts)
      when not is_keyword(options) and not is_keyword(selected) do
    Toddy.Widget.PickList.new(id, options, [{:selected, selected} | clean_opts(opts)])
    |> Toddy.Widget.PickList.build()
  end

  @doc """
  Combo box with free-text input and dropdown suggestions.

  ## Example

      combo_box("lang", ["Elixir", "Rust", "Go"], model.lang, placeholder: "Type...")

      combo_box "lang", ["Elixir", "Rust", "Go"], model.lang do
        placeholder "Type..."
      end
  """
  defmacro combo_box(id, options, value, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        option_keys = Toddy.Widget.ComboBox.__option_keys__()
        option_types = Toddy.Widget.ComboBox.__option_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "combo_box", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do
          Toddy.UI.__build_combo_box__(
            unquote(id),
            unquote(options),
            unquote(value),
            unquote(opts_ast)
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_combo_box__(
            unquote(id),
            unquote(options),
            unquote(value),
            unquote(opts)
          )
        end
    end
  end

  @doc false
  @spec __build_combo_box__(String.t(), [String.t()], String.t(), keyword()) ::
          Toddy.Widget.ui_node()
  def __build_combo_box__(id, options, value, opts)
      when not is_keyword(options) and not is_keyword(value) do
    Toddy.Widget.ComboBox.new(id, options, [{:value, value} | clean_opts(opts)])
    |> Toddy.Widget.ComboBox.build()
  end

  @doc """
  Multi-line text editor.

  ## Example

      text_editor("notes", model.notes, width: :fill, height: 200)

      text_editor "notes", model.notes do
        width :fill
        height 200
      end
  """
  defmacro text_editor(id, content, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        option_keys = Toddy.Widget.TextEditor.__option_keys__()
        option_types = Toddy.Widget.TextEditor.__option_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "text_editor", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)
        quote do: Toddy.UI.__build_text_editor__(unquote(id), unquote(content), unquote(opts_ast))

      opts ->
        quote do: Toddy.UI.__build_text_editor__(unquote(id), unquote(content), unquote(opts))
    end
  end

  @doc false
  @spec __build_text_editor__(String.t(), String.t(), keyword()) :: Toddy.Widget.ui_node()
  def __build_text_editor__(id, content, opts) when not is_keyword(content) do
    Toddy.Widget.TextEditor.new(id, [{:content, content} | clean_opts(opts)])
    |> Toddy.Widget.TextEditor.build()
  end

  # ---------------------------------------------------------------------------
  # Additional display widgets
  # ---------------------------------------------------------------------------

  @doc """
  Raster image display.

  ## Example

      image("logo", "/assets/logo.png", width: 200, content_fit: :cover)

      image "logo", "/assets/logo.png" do
        width 200
        content_fit :cover
      end
  """
  defmacro image(id, source, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        option_keys = Toddy.Widget.Image.__option_keys__()
        option_types = Toddy.Widget.Image.__option_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "image", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)
        quote do: Toddy.UI.__build_image__(unquote(id), unquote(source), unquote(opts_ast))

      opts ->
        quote do: Toddy.UI.__build_image__(unquote(id), unquote(source), unquote(opts))
    end
  end

  @doc false
  @spec __build_image__(String.t(), String.t(), keyword()) :: Toddy.Widget.ui_node()
  def __build_image__(id, source, opts) when not is_keyword(source) do
    Toddy.Widget.Image.new(id, source, clean_opts(opts)) |> Toddy.Widget.Image.build()
  end

  @doc """
  SVG image display.

  ## Example

      svg("icon", "/assets/icon.svg", width: 24, height: 24)

      svg "icon", "/assets/icon.svg" do
        width 24
        height 24
      end
  """
  defmacro svg(id, source, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        option_keys = Toddy.Widget.Svg.__option_keys__()
        option_types = Toddy.Widget.Svg.__option_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "svg", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)
        quote do: Toddy.UI.__build_svg__(unquote(id), unquote(source), unquote(opts_ast))

      opts ->
        quote do: Toddy.UI.__build_svg__(unquote(id), unquote(source), unquote(opts))
    end
  end

  @doc false
  @spec __build_svg__(String.t(), String.t(), keyword()) :: Toddy.Widget.ui_node()
  def __build_svg__(id, source, opts) when not is_keyword(source) do
    Toddy.Widget.Svg.new(id, source, clean_opts(opts)) |> Toddy.Widget.Svg.build()
  end

  @doc """
  Markdown content renderer.

  ## Forms

  - `markdown(content)` -- auto-generated ID
  - `markdown(id, content)` -- explicit ID
  - `markdown(id, content, opts)` -- explicit ID with options

  ## Example

      markdown("# Hello\\n\\nSome **bold** text")
      markdown("my_md", "# Hello", code_theme: "dracula")
  """
  defmacro markdown(content) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      Toddy.Widget.Markdown.new(
        unquote(compile_auto_id(caller_mod, caller_line)),
        unquote(content)
      )
      |> Toddy.Widget.Markdown.build()
    end
  end

  @doc false
  defmacro markdown(id, content) do
    quote do
      Toddy.Widget.Markdown.new(unquote(id), unquote(content)) |> Toddy.Widget.Markdown.build()
    end
  end

  @doc false
  defmacro markdown(id, content, opts_or_do) do
    case opts_or_do do
      [do: block] ->
        option_keys = Toddy.Widget.Markdown.__option_keys__()
        option_types = Toddy.Widget.Markdown.__option_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "markdown", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do
          Toddy.Widget.Markdown.new(unquote(id), unquote(content), unquote(opts_ast))
          |> Toddy.Widget.Markdown.build()
        end

      opts ->
        quote do
          Toddy.Widget.Markdown.new(unquote(id), unquote(content), unquote(opts))
          |> Toddy.Widget.Markdown.build()
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Additional layout widgets (macros with do block support)
  # ---------------------------------------------------------------------------

  # -- tooltip(id, tip, opts) --------------------------------------------------

  @doc """
  Tooltip wrapper. Children are the content being tooltipped.

  ## Forms

  - `tooltip(id, tip, do: block)` -- with children
  - `tooltip(id, tip, opts, do: block)` -- with children and options

  ## Example

      tooltip "save_tip", "Save your work", position: :top do
        button("save", "Save")
      end
  """
  defmacro tooltip(id, tip_or_do) do
    option_keys = Toddy.Widget.Tooltip.__option_keys__()
    option_types = Toddy.Widget.Tooltip.__option_types__()

    case tip_or_do do
      [do: block] ->
        block = container_scope(block, option_keys, option_types, "tooltip")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.Tooltip, unquote(id), [], items, nil)
        end

      tip when is_binary(tip) ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Tooltip,
            unquote(id),
            [tip: unquote(tip)],
            [],
            nil
          )
        end
    end
  end

  @doc false
  defmacro tooltip(id, tip, opts_or_do) do
    option_keys = Toddy.Widget.Tooltip.__option_keys__()
    option_types = Toddy.Widget.Tooltip.__option_types__()

    case opts_or_do do
      [do: block] ->
        block = container_scope(block, option_keys, option_types, "tooltip")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Toddy.UI.__build_container__(
            Toddy.Widget.Tooltip,
            unquote(id),
            [tip: unquote(tip)],
            items,
            nil
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Tooltip,
            unquote(id),
            [tip: unquote(tip)] ++ unquote(opts),
            [],
            nil
          )
        end
    end
  end

  @doc false
  defmacro tooltip(id, tip, opts, do: block) do
    option_keys = Toddy.Widget.Tooltip.__option_keys__()
    option_types = Toddy.Widget.Tooltip.__option_types__()
    block = container_scope(block, option_keys, option_types, "tooltip")
    exprs = block_to_exprs(block)

    quote do
      items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Tooltip,
        unquote(id),
        [tip: unquote(tip)] ++ unquote(opts),
        items,
        nil
      )
    end
  end

  # ---------------------------------------------------------------------------
  # Canvas (macro -- supports do-block with layers)
  # ---------------------------------------------------------------------------

  @doc """
  Canvas for drawing shapes organized into named layers.

  ## Keyword form

      canvas("drawing",
        layers: %{"main" => [%{type: "circle", x: 50, y: 50, r: 20}]},
        width: 400,
        height: 300
      )

  ## Do-block form

  Use `layer/2` to collect layers declaratively:

      canvas "chart", width: 400, height: 300 do
        layer "grid" do
          rect(0, 0, 400, 300, stroke: "#eee")
        end
        layer "data" do
          for bar <- bars do
            rect(bar.x, bar.y, bar.w, bar.h, fill: bar.color)
          end
        end
      end

  ## Options

  - `:layers` -- map of layer names to shape descriptor lists
  - `:width` / `:height` -- dimensions
  - `:background` -- background color
  """
  defmacro canvas(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        block = canvas_scope(block, :canvas)
        exprs = block_to_exprs(block)

        quote do
          layers =
            [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1) |> Map.new()

          Toddy.UI.__build_canvas__(unquote(id), layers: layers)
        end

      opts ->
        quote do
          Toddy.UI.__build_canvas__(unquote(id), unquote(opts))
        end
    end
  end

  @doc false
  defmacro canvas(id, opts, do: block) do
    block = canvas_scope(block, :canvas)
    exprs = block_to_exprs(block)

    quote do
      layers =
        [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1) |> Map.new()

      opts = [{:layers, layers} | Keyword.delete(unquote(opts), :layers)]
      Toddy.UI.__build_canvas__(unquote(id), opts)
    end
  end

  @doc false
  @spec __build_canvas__(String.t(), keyword()) :: Toddy.Widget.ui_node()
  def __build_canvas__(id, opts) do
    Toddy.Widget.Canvas.new(id, clean_opts(opts)) |> Toddy.Widget.Canvas.build()
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
        option_keys = Toddy.Widget.PaneGrid.__option_keys__()
        option_types = Toddy.Widget.PaneGrid.__option_types__()
        block = container_scope(block, option_keys, option_types, "pane_grid")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.PaneGrid, unquote(id), [], items, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(Toddy.Widget.PaneGrid, unquote(id), unquote(opts), [], nil)
        end
    end
  end

  @doc false
  defmacro pane_grid(id, opts, do: block) do
    option_keys = Toddy.Widget.PaneGrid.__option_keys__()
    option_types = Toddy.Widget.PaneGrid.__option_types__()
    block = container_scope(block, option_keys, option_types, "pane_grid")
    exprs = block_to_exprs(block)

    quote do
      items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.PaneGrid,
        unquote(id),
        unquote(opts),
        items,
        nil
      )
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

      rich_text "styled" do
        spans [%{text: "bold", weight: :bold}, %{text: " normal"}]
      end
  """
  defmacro rich_text(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        option_keys = Toddy.Widget.RichText.__option_keys__()
        option_types = Toddy.Widget.RichText.__option_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "rich_text", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)
        quote do: Toddy.UI.__build_rich_text__(unquote(id), unquote(opts_ast))

      opts ->
        quote do: Toddy.UI.__build_rich_text__(unquote(id), unquote(opts))
    end
  end

  @doc false
  @spec __build_rich_text__(String.t(), keyword()) :: Toddy.Widget.ui_node()
  def __build_rich_text__(id, opts) do
    Toddy.Widget.RichText.new(id, clean_opts(opts)) |> Toddy.Widget.RichText.build()
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
        option_keys = Toddy.Widget.Table.__option_keys__()
        option_types = Toddy.Widget.Table.__option_types__()
        block = container_scope(block, option_keys, option_types, "table")
        exprs = block_to_exprs(block)

        quote do
          items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.Table, unquote(id), [], items, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(Toddy.Widget.Table, unquote(id), unquote(opts), [], nil)
        end
    end
  end

  @doc false
  defmacro table(id, opts, do: block) do
    option_keys = Toddy.Widget.Table.__option_keys__()
    option_types = Toddy.Widget.Table.__option_types__()
    block = container_scope(block, option_keys, option_types, "table")
    exprs = block_to_exprs(block)

    quote do
      items = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Toddy.UI.__build_container__(Toddy.Widget.Table, unquote(id), unquote(opts), items, nil)
    end
  end

  # __build_fixed_node__ removed -- use __build_container__

  # ---------------------------------------------------------------------------
  # Canvas group, layer, and interactive macros
  # ---------------------------------------------------------------------------

  @doc """
  Groups child shapes with optional positioning and interaction.

  ## Do-block form

      group x: 4, y: 4 do
        interactive "btn" do
          on_click
        end
        rect(0, 0, 32, 32, radius: 4)
      end

  ## List form

      group([rect(0, 0, 100, 40)], x: 10, y: 50)
  """
  defmacro group(opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        block = canvas_scope(block, :group)
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.Canvas.Shape.__build_group__(children, [])
        end

      other ->
        quote do
          Toddy.Canvas.Shape.__build_group__(unquote(other), [])
        end
    end
  end

  @doc false
  defmacro group(first, second) do
    case second do
      [do: block] ->
        block = canvas_scope(block, :group)
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.Canvas.Shape.__build_group__(children, unquote(first))
        end

      opts ->
        quote do
          Toddy.Canvas.Shape.__build_group__(unquote(first), unquote(opts))
        end
    end
  end

  @doc """
  Collects shapes into a named layer for use inside canvas blocks.

      canvas "chart", width: 400 do
        layer "grid" do
          rect(0, 0, 400, 300, stroke: "#eee")
        end
      end
  """
  defmacro layer(name, do: block) do
    block = canvas_scope(block, :layer)
    exprs = block_to_exprs(block)

    quote do
      {unquote(name), [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)}
    end
  end

  @doc """
  Marks a shape or group as interactive.

  ## Block form (inside group)

      group do
        interactive "bold" do
          on_click
          hover_style %{fill: "#ddd"}
          cursor "pointer"
        end
        rect(0, 0, 32, 32, radius: 4)
      end

  ## Keyword form (inside group)

      group do
        interactive "bold", on_click: true
        rect(0, 0, 32, 32)
      end

  ## Pipe form (on any shape)

      rect(0, 0, 100, 40) |> interactive(id: "btn", on_click: true)
  """

  # Form 1: Block directive with id
  defmacro interactive(id, do: block) do
    field_types = Toddy.Canvas.Shape.Interactive.__field_types__()
    pairs = interpret_block(block, field_types)
    validate_interactive_keys!(pairs, __CALLER__)
    opts_ast = pairs_to_keyword_ast(pairs)

    quote do
      {:__canvas_meta__, :interactive,
       Toddy.Canvas.Shape.Interactive.new([{:id, unquote(id)} | unquote(opts_ast)])}
    end
  end

  # Form 2/3: Keyword directive (id first) or pipe modifier (shape first)
  @doc false
  defmacro interactive(first, opts) do
    quote do
      Toddy.UI.__build_interactive__(unquote(first), unquote(opts))
    end
  end

  # Form 4: Arity 1 -- keyword without id positional, or error on bare do-block
  @doc false
  defmacro interactive(opts_or_do) do
    case opts_or_do do
      [do: _block] ->
        raise CompileError,
          line: __CALLER__.line,
          description: """
          interactive requires an id as the first argument. Expected:

              interactive "my_id" do
                on_click
                hover_style %{fill: "#ddd"}
              end
          """

      opts ->
        quote do
          {:__canvas_meta__, :interactive, Toddy.Canvas.Shape.Interactive.new(unquote(opts))}
        end
    end
  end

  @doc false
  @spec __build_interactive__(String.t() | map(), keyword()) ::
          {:__canvas_meta__, :interactive, Toddy.Canvas.Shape.Interactive.t()} | map()
  def __build_interactive__(id, opts) when is_binary(id) do
    {:__canvas_meta__, :interactive, Toddy.Canvas.Shape.Interactive.new([{:id, id} | opts])}
  end

  def __build_interactive__(shape, opts) when is_map(shape) do
    Toddy.Canvas.Shape.interactive(shape, opts)
  end

  # ---------------------------------------------------------------------------
  # Canvas shape macros (block-form support)
  # ---------------------------------------------------------------------------

  @doc "Builds a rectangle shape. See `Toddy.Canvas.Shape.rect/5`."
  defmacro rect(x, y, w, h, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        pairs = interpret_block(block)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do:
                Toddy.Canvas.Shape.rect(
                  unquote(x),
                  unquote(y),
                  unquote(w),
                  unquote(h),
                  unquote(opts_ast)
                )

      opts ->
        quote do:
                Toddy.Canvas.Shape.rect(
                  unquote(x),
                  unquote(y),
                  unquote(w),
                  unquote(h),
                  unquote(opts)
                )
    end
  end

  @doc "Builds a circle shape. See `Toddy.Canvas.Shape.circle/4`."
  defmacro circle(x, y, r, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        pairs = interpret_block(block)
        opts_ast = pairs_to_keyword_ast(pairs)
        quote do: Toddy.Canvas.Shape.circle(unquote(x), unquote(y), unquote(r), unquote(opts_ast))

      opts ->
        quote do: Toddy.Canvas.Shape.circle(unquote(x), unquote(y), unquote(r), unquote(opts))
    end
  end

  @doc "Builds a line shape. See `Toddy.Canvas.Shape.line/5`."
  defmacro line(x1, y1, x2, y2, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        pairs = interpret_block(block)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do:
                Toddy.Canvas.Shape.line(
                  unquote(x1),
                  unquote(y1),
                  unquote(x2),
                  unquote(y2),
                  unquote(opts_ast)
                )

      opts ->
        quote do:
                Toddy.Canvas.Shape.line(
                  unquote(x1),
                  unquote(y1),
                  unquote(x2),
                  unquote(y2),
                  unquote(opts)
                )
    end
  end

  @doc "Builds a path shape. See `Toddy.Canvas.Shape.path/2`."
  defmacro path(commands, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        pairs = interpret_block(block)
        opts_ast = pairs_to_keyword_ast(pairs)
        quote do: Toddy.Canvas.Shape.path(unquote(commands), unquote(opts_ast))

      opts ->
        quote do: Toddy.Canvas.Shape.path(unquote(commands), unquote(opts))
    end
  end

  @doc "Builds a stroke descriptor. See `Toddy.Canvas.Shape.stroke/3`."
  defmacro stroke(color, width, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        pairs = interpret_block(block)
        opts_ast = pairs_to_keyword_ast(pairs)
        quote do: Toddy.Canvas.Shape.stroke(unquote(color), unquote(width), unquote(opts_ast))

      opts ->
        quote do: Toddy.Canvas.Shape.stroke(unquote(color), unquote(width), unquote(opts))
    end
  end

  # ---------------------------------------------------------------------------
  # Canvas shape re-exports (no block form needed)
  # ---------------------------------------------------------------------------

  # Path commands
  defdelegate move_to(x, y), to: Toddy.Canvas.Shape
  defdelegate line_to(x, y), to: Toddy.Canvas.Shape
  defdelegate bezier_to(cp1x, cp1y, cp2x, cp2y, x, y), to: Toddy.Canvas.Shape
  defdelegate quadratic_to(cpx, cpy, x, y), to: Toddy.Canvas.Shape
  defdelegate arc(cx, cy, r, start_angle, end_angle), to: Toddy.Canvas.Shape
  defdelegate arc_to(x1, y1, x2, y2, radius), to: Toddy.Canvas.Shape
  defdelegate ellipse(cx, cy, rx, ry, rotation, start_angle, end_angle), to: Toddy.Canvas.Shape
  defdelegate rounded_rect(x, y, w, h, radius), to: Toddy.Canvas.Shape
  defdelegate close(), to: Toddy.Canvas.Shape

  # Transforms
  defdelegate push_transform(), to: Toddy.Canvas.Shape
  defdelegate pop_transform(), to: Toddy.Canvas.Shape
  defdelegate translate(x, y), to: Toddy.Canvas.Shape
  defdelegate rotate(angle), to: Toddy.Canvas.Shape
  defdelegate scale(x, y), to: Toddy.Canvas.Shape

  # Clips
  defdelegate push_clip(x, y, w, h), to: Toddy.Canvas.Shape
  defdelegate pop_clip(), to: Toddy.Canvas.Shape

  # Gradients
  defdelegate linear_gradient(from, to, stops), to: Toddy.Canvas.Shape

  # ---------------------------------------------------------------------------
  # Tree query
  # ---------------------------------------------------------------------------

  @doc """
  Finds the first node in a tree whose `:id` matches `id`.

  Delegates to `Toddy.Tree.find/2`. Returns the node map or `nil`.

  ## Example

      tree = MyApp.view(model)
      Toddy.UI.find(tree, "save_button")
  """
  @spec find(tree :: Toddy.Widget.ui_node(), id :: String.t()) :: Toddy.Widget.ui_node() | nil
  defdelegate find(tree, id), to: Toddy.Tree

  @doc "Returns true if a node with `id` exists in the tree."
  @spec exists?(tree :: Toddy.Widget.ui_node() | nil, id :: String.t()) :: boolean()
  defdelegate exists?(tree, id), to: Toddy.Tree

  @doc "Returns all node IDs in the tree."
  @spec ids(tree :: Toddy.Widget.ui_node() | nil) :: [String.t()]
  defdelegate ids(tree), to: Toddy.Tree

  @doc "Finds all nodes matching a predicate."
  @spec find_all(
          tree :: Toddy.Widget.ui_node() | nil,
          id_or_pred :: String.t() | (Toddy.Widget.ui_node() -> boolean())
        ) ::
          [Toddy.Widget.ui_node()]
  defdelegate find_all(tree, id_or_pred), to: Toddy.Tree

  # ---------------------------------------------------------------------------
  # QR Code (function -- no children)
  # ---------------------------------------------------------------------------

  @doc """
  QR code display. No children.

  ## Arguments

  - `id` -- unique identifier
  - `data` -- the string to encode

  ## Options

  - `:cell_size` -- size of each QR module in pixels (default 4.0)
  - `:cell_color` -- color of dark modules
  - `:background_color` -- color of light modules
  - `:error_correction` -- `:low`, `:medium` (default), `:quartile`, `:high`

  ## Example

      qr_code("my_qr", "https://example.com", cell_size: 6)

      qr_code "my_qr", "https://example.com" do
        cell_size 6
      end
  """
  defmacro qr_code(id, data, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        option_keys = Toddy.Widget.QrCode.__option_keys__()
        option_types = Toddy.Widget.QrCode.__option_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "qr_code", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)
        quote do: Toddy.UI.__build_qr_code__(unquote(id), unquote(data), unquote(opts_ast))

      opts ->
        quote do: Toddy.UI.__build_qr_code__(unquote(id), unquote(data), unquote(opts))
    end
  end

  @doc false
  @spec __build_qr_code__(String.t(), String.t(), keyword()) :: Toddy.Widget.ui_node()
  def __build_qr_code__(id, data, opts) do
    Toddy.Widget.QrCode.new(id, data, clean_opts(opts)) |> Toddy.Widget.QrCode.build()
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @reserved_keys [:children, :id, :do]

  @interactive_keys ~w(on_click on_hover draggable drag_axis drag_bounds cursor hover_style pressed_style tooltip a11y hit_rect)a

  @leaf_widget_names ~w(button text_input checkbox toggler radio slider
    vertical_slider pick_list combo_box text_editor image svg rich_text
    qr_code)a

  @display_widget_names ~w(text markdown progress_bar)a

  @container_widget_names Enum.map(@container_modules, fn {_mod, name} -> String.to_atom(name) end)

  @widget_calls @leaf_widget_names ++
                  @display_widget_names ++ @container_widget_names ++ [:canvas]

  for key <- @all_container_option_names, key in @widget_calls do
    raise CompileError,
      description: "option key #{inspect(key)} collides with widget macro name"
  end

  @canvas_shape_calls ~w(rect circle line path group)a

  @canvas_transform_calls ~w(push_transform pop_transform translate rotate scale push_clip pop_clip)a

  defp clean_opts(opts), do: Keyword.drop(opts, @reserved_keys)

  defp normalize_range({min, max}), do: {min, max}
  defp normalize_range(first..last//_), do: {first, last}

  # ---------------------------------------------------------------------------
  # Private macro helpers
  # ---------------------------------------------------------------------------

  defp block_to_exprs({:__block__, _, exprs}), do: exprs
  defp block_to_exprs(single_expr), do: [single_expr]

  # ---------------------------------------------------------------------------
  # Block-form option interpretation
  # ---------------------------------------------------------------------------

  # Interprets a do-block AST as keyword pairs.
  # When type_mapping is provided, fields with do-block values get recursive
  # struct construction via Module.from_opts(pairs).
  defp interpret_block(block, type_mapping \\ %{})

  defp interpret_block({:__block__, _, exprs}, type_mapping) do
    Enum.map(exprs, &interpret_block_expr(&1, type_mapping))
  end

  defp interpret_block(single_expr, type_mapping) do
    [interpret_block_expr(single_expr, type_mapping)]
  end

  defp interpret_block_expr({name, _meta, [value]}, type_mapping) when is_atom(name) do
    case {Map.get(type_mapping, name), value} do
      {nil, _} ->
        {name, value}

      {struct_mod, [{:do, inner_block}]} ->
        nested_types = struct_mod.__field_types__()
        nested_pairs = interpret_block(inner_block, nested_types)
        nested_ast = pairs_to_keyword_ast(nested_pairs)
        value_ast = quote do: unquote(struct_mod).from_opts(unquote(nested_ast))
        {name, value_ast}

      {_struct_mod, _} ->
        {name, value}
    end
  end

  defp interpret_block_expr({name, _meta, nil}, _type_mapping) when is_atom(name) do
    {name, true}
  end

  defp interpret_block_expr({name, _meta, context}, _type_mapping)
       when is_atom(name) and is_atom(context) do
    {name, true}
  end

  defp interpret_block_expr(other, _type_mapping) do
    raise ArgumentError,
          "not valid here, expected `key value` declaration, got: #{Macro.to_string(other)}"
  end

  defp pairs_to_keyword_ast(pairs) do
    for {key, val} <- pairs do
      {:{}, [], [key, val]}
    end
  end

  # ---------------------------------------------------------------------------
  # AST guards
  # ---------------------------------------------------------------------------

  defp numeric_literal?(n) when is_integer(n) or is_float(n), do: true
  defp numeric_literal?({:-, _, [n]}) when is_number(n), do: true
  defp numeric_literal?(_), do: false

  # ---------------------------------------------------------------------------
  # Interactive key validation (used by Step 4: interactive directive)
  # ---------------------------------------------------------------------------

  defp validate_interactive_keys!(pairs, caller) do
    for {key, _val} <- pairs do
      unless key in @interactive_keys do
        raise CompileError,
          line: caller.line,
          file: caller.file,
          description:
            "unknown interactive option: #{inspect(key)}. " <>
              "Valid options: #{inspect(@interactive_keys)}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Control flow block wrapping
  # ---------------------------------------------------------------------------

  # Wraps multi-expression blocks in a list so all values contribute
  # to the parent's items list (instead of just the last expression).
  defp wrap_block_in_list({:__block__, _meta, exprs}) when length(exprs) > 1 do
    exprs
  end

  defp wrap_block_in_list(single), do: single

  # ---------------------------------------------------------------------------
  # Context-aware container AST walker
  # ---------------------------------------------------------------------------
  #
  # Walks container do-block ASTs, rewriting bare option calls to
  # {:__widget_prop__, name, value} tuples that __build_container__/5
  # partitions from children at runtime. Compile-time errors for options
  # that belong to a different container.

  defp container_scope({:__block__, meta, exprs}, option_keys, option_types, widget_name) do
    {:__block__, meta,
     Enum.map(exprs, &container_scope(&1, option_keys, option_types, widget_name))}
  end

  defp container_scope(expr, _ok, _ot, _wn) when not is_tuple(expr), do: expr
  defp container_scope(expr, _ok, _ot, _wn) when tuple_size(expr) != 3, do: expr

  # Fully qualified calls -- skip
  defp container_scope({{:., _, _}, _, _} = node, _ok, _ot, _wn), do: node

  # Bare name (no args) -- could be a boolean option or wrong-container error
  defp container_scope({name, meta, context} = node, option_keys, _option_types, widget_name)
       when is_atom(name) and (context == nil or is_atom(context)) do
    cond do
      name in option_keys ->
        quote_prop_tuple(name, true, meta)

      name in @all_container_option_names ->
        owners = Map.get(@all_container_option_owners, name, [])
        container_scope_error!(meta, name, widget_name, owners)

      true ->
        node
    end
  end

  # Control flow -- recurse (must be before the general {name, meta, args} clause)

  defp container_scope({:for, meta, args}, ok, ot, wn) do
    {:for, meta,
     Enum.map(args, fn
       {:do, body} -> {:do, wrap_block_in_list(container_scope(body, ok, ot, wn))}
       {:else, body} -> {:else, wrap_block_in_list(container_scope(body, ok, ot, wn))}
       other -> other
     end)}
  end

  defp container_scope({:if, meta, [condition, clauses]}, ok, ot, wn) do
    {:if, meta,
     [
       condition,
       Enum.map(clauses, fn
         {:do, body} -> {:do, wrap_block_in_list(container_scope(body, ok, ot, wn))}
         {:else, body} -> {:else, wrap_block_in_list(container_scope(body, ok, ot, wn))}
         other -> other
       end)
     ]}
  end

  defp container_scope({:unless, meta, [condition, clauses]}, ok, ot, wn) do
    {:unless, meta,
     [
       condition,
       Enum.map(clauses, fn
         {:do, body} -> {:do, wrap_block_in_list(container_scope(body, ok, ot, wn))}
         {:else, body} -> {:else, wrap_block_in_list(container_scope(body, ok, ot, wn))}
         other -> other
       end)
     ]}
  end

  defp container_scope({:case, meta, [subject, [do: clauses]]}, ok, ot, wn) do
    {:case, meta,
     [
       subject,
       [
         do:
           Enum.map(clauses, fn
             {:->, m, [pattern, body]} ->
               {:->, m, [pattern, wrap_block_in_list(container_scope(body, ok, ot, wn))]}

             other ->
               other
           end)
       ]
     ]}
  end

  defp container_scope({:cond, meta, [[do: clauses]]}, ok, ot, wn) do
    {:cond, meta,
     [
       [
         do:
           Enum.map(clauses, fn
             {:->, m, [pattern, body]} ->
               {:->, m, [pattern, wrap_block_in_list(container_scope(body, ok, ot, wn))]}

             other ->
               other
           end)
       ]
     ]}
  end

  defp container_scope({:with, meta, args}, ok, ot, wn) do
    {:with, meta,
     Enum.map(args, fn
       {:do, body} ->
         {:do, wrap_block_in_list(container_scope(body, ok, ot, wn))}

       {:else, clauses} ->
         {:else,
          Enum.map(clauses, fn
            {:->, m, [pattern, body]} ->
              {:->, m, [pattern, wrap_block_in_list(container_scope(body, ok, ot, wn))]}

            other ->
              other
          end)}

       other ->
         other
     end)}
  end

  defp container_scope({:fn, meta, clauses}, ok, ot, wn) do
    {:fn, meta,
     Enum.map(clauses, fn
       {:->, m, [pattern, body]} ->
         {:->, m, [pattern, wrap_block_in_list(container_scope(body, ok, ot, wn))]}

       other ->
         other
     end)}
  end

  # Name with args -- could be an option key, wrong-container, or child
  defp container_scope({name, meta, args} = node, option_keys, option_types, widget_name)
       when is_atom(name) and is_list(args) do
    cond do
      name in option_keys ->
        case args do
          [[{:do, block}]] ->
            struct_mod = Map.get(option_types, name)
            type_mapping = if struct_mod, do: struct_mod.__field_types__(), else: %{}
            nested_pairs = interpret_block(block, type_mapping)

            value_ast =
              if struct_mod do
                nested_ast = pairs_to_keyword_ast(nested_pairs)
                quote do: unquote(struct_mod).from_opts(unquote(nested_ast))
              else
                {:%{}, [], nested_pairs}
              end

            quote_prop_tuple(name, value_ast, meta)

          [value] ->
            # Single arg: name(value)
            quote_prop_tuple(name, value, meta)

          _ ->
            # Multiple args -- likely not an option, pass through as child
            node
        end

      length(args) == 1 and name in @all_container_option_names ->
        owners = Map.get(@all_container_option_owners, name, [])
        container_scope_error!(meta, name, widget_name, owners)

      true ->
        node
    end
  end

  # Default -- pass through
  defp container_scope(other, _ok, _ot, _wn), do: other

  # Helper to build {:__widget_prop__, name, value} AST
  defp quote_prop_tuple(name, value, _meta) do
    {:{}, [], [:__widget_prop__, name, value]}
  end

  # Compile-time validation: check that all do-block keys belong to the widget.
  defp validate_option_keys!(pairs, option_keys, widget_name, caller) do
    for {key, _} <- pairs, key not in option_keys do
      raise CompileError,
        line: caller.line,
        file: caller.file,
        description:
          "#{key} is not a valid option for #{widget_name}. " <>
            "Valid options: #{inspect(option_keys)}"
    end
  end

  # Error helper for wrong-container options
  defp container_scope_error!(meta, option_name, widget_name, owners) do
    owners_str = Enum.sort(owners) |> Enum.join(", ")

    raise CompileError,
      line: Keyword.get(meta, :line, 0),
      description:
        "#{option_name} is not a valid option for #{widget_name}.\n" <>
          "Supported by: #{owners_str}"
  end

  # ---------------------------------------------------------------------------
  # Context-aware canvas AST walker
  # ---------------------------------------------------------------------------

  # Entry point: walk a block AST with context
  defp canvas_scope({:__block__, meta, exprs}, context) do
    {:__block__, meta, Enum.map(exprs, &canvas_scope(&1, context))}
  end

  defp canvas_scope(expr, _context) when not is_tuple(expr), do: expr
  defp canvas_scope(expr, _context) when tuple_size(expr) != 3, do: expr

  # Fully qualified calls -- skip
  defp canvas_scope({{:., _, _}, _, _} = node, _context), do: node

  # --- Canvas container calls (don't recurse into their blocks) ---

  # layer: valid in :canvas only
  defp canvas_scope({:layer, _, _} = node, :canvas), do: node

  defp canvas_scope({:layer, meta, _}, _ctx) do
    canvas_scope_error!(meta, "layer is not valid here. Layers belong inside a canvas block.")
  end

  # group: valid in :layer and :group
  defp canvas_scope({:group, _, _} = node, ctx) when ctx in [:layer, :group], do: node

  defp canvas_scope({:group, meta, _}, :canvas) do
    canvas_scope_error!(meta, """
    group is not valid here. Put groups inside a layer:

        layer "main" do
          group do
            ...
          end
        end
    """)
  end

  # interactive: valid in :group only
  defp canvas_scope({:interactive, _, _} = node, :group), do: node

  defp canvas_scope({:interactive, meta, _}, _ctx) do
    canvas_scope_error!(meta, """
    interactive is not valid here. Use it inside a group:

        group do
          interactive "btn" do
            on_click
          end
          rect(0, 0, 100, 40)
        end
    """)
  end

  # --- Ambiguous name rewrites (text, image, svg) ---

  # text/1,2: always error in canvas context
  defp canvas_scope({:text, meta, args}, _ctx) when is_list(args) and length(args) in [1, 2] do
    canvas_scope_error!(meta, """
    text/#{length(args)} is not valid here. Expected:

        text(x, y, "content")
        text(x, y, "content", fill: "#000")
    """)
  end

  # text/3+: rewrite to Shape.__build_text__ in :layer/:group, error in :canvas
  defp canvas_scope({:text, meta, args}, ctx) when is_list(args) and length(args) >= 3 do
    if ctx == :canvas do
      canvas_scope_error!(meta, """
      text is not valid here. Shapes go inside layers:

          layer "main" do
            text(10, 20, "Hello", fill: "#000")
          end
      """)
    else
      args = canvas_scope_rewrite_do_block(args)
      {{:., meta, [Toddy.Canvas.Shape, :__build_text__]}, meta, args}
    end
  end

  # image/1,2,3: always error in canvas context
  defp canvas_scope({:image, meta, args}, _ctx)
       when is_list(args) and length(args) in [1, 2, 3] do
    canvas_scope_error!(meta, """
    image/#{length(args)} is not valid here. Expected:

        image("source", x, y, w, h)
        image("source", x, y, w, h, rotation: 0.5)
    """)
  end

  # image/5+: rewrite in :layer/:group, error in :canvas
  defp canvas_scope({:image, meta, args}, ctx) when is_list(args) and length(args) >= 5 do
    if ctx == :canvas do
      canvas_scope_error!(meta, """
      image is not valid here. Shapes go inside layers:

          layer "main" do
            image("source", x, y, w, h)
          end
      """)
    else
      args = canvas_scope_rewrite_do_block(args)
      {{:., meta, [Toddy.Canvas.Shape, :__build_image__]}, meta, args}
    end
  end

  # svg/1,2,3: always error in canvas context
  defp canvas_scope({:svg, meta, args}, _ctx)
       when is_list(args) and length(args) in [1, 2, 3] do
    canvas_scope_error!(meta, """
    svg/#{length(args)} is not valid here. Expected:

        svg("source", x, y, w, h)
    """)
  end

  # svg/5+: rewrite in :layer/:group, error in :canvas
  defp canvas_scope({:svg, meta, args}, ctx) when is_list(args) and length(args) >= 5 do
    if ctx == :canvas do
      canvas_scope_error!(meta, """
      svg is not valid here. Shapes go inside layers:

          layer "main" do
            svg("source", x, y, w, h)
          end
      """)
    else
      args = canvas_scope_rewrite_do_block(args)
      {{:., meta, [Toddy.Canvas.Shape, :__build_svg__]}, meta, args}
    end
  end

  # --- Shape calls (rect, circle, line, path) ---

  defp canvas_scope({name, _, _} = node, ctx)
       when is_atom(name) and name in @canvas_shape_calls do
    case ctx do
      :canvas ->
        {_, meta, _} = node

        canvas_scope_error!(meta, """
        #{name} is not valid here. Shapes go inside layers:

            layer "main" do
              #{name}(...)
            end
        """)

      _other ->
        node
    end
  end

  # --- Transform/clip calls ---

  defp canvas_scope({name, _, _} = node, ctx)
       when is_atom(name) and name in @canvas_transform_calls do
    case ctx do
      :canvas ->
        {_, meta, _} = node

        canvas_scope_error!(meta, """
        #{name} is not valid here. Transforms go inside layers:

            layer "main" do
              #{name}(...)
            end
        """)

      _other ->
        node
    end
  end

  # --- Widget calls (always error in canvas context) ---

  defp canvas_scope({name, meta, args}, _ctx)
       when is_atom(name) and is_list(args) and name in @widget_calls do
    canvas_scope_error!(meta, """
    #{name} is not valid here. Expected canvas shapes:
    rect, circle, line, text, path, image, svg, group
    """)
  end

  # --- Control flow: recurse into bodies ---

  defp canvas_scope({:for, meta, args}, ctx) do
    {:for, meta, canvas_scope_for_args(args, ctx)}
  end

  defp canvas_scope({:if, meta, [condition, clauses]}, ctx) do
    {:if, meta, [condition, canvas_scope_clauses(clauses, ctx)]}
  end

  defp canvas_scope({:unless, meta, [condition, clauses]}, ctx) do
    {:unless, meta, [condition, canvas_scope_clauses(clauses, ctx)]}
  end

  defp canvas_scope({:case, meta, [subject, [do: clauses]]}, ctx) do
    {:case, meta, [subject, [do: canvas_scope_match_clauses(clauses, ctx)]]}
  end

  defp canvas_scope({:cond, meta, [[do: clauses]]}, ctx) do
    {:cond, meta, [[do: canvas_scope_match_clauses(clauses, ctx)]]}
  end

  defp canvas_scope({:with, meta, args}, ctx) do
    {:with, meta, canvas_scope_with_args(args, ctx)}
  end

  defp canvas_scope({:fn, meta, clauses}, ctx) do
    {:fn, meta, canvas_scope_match_clauses(clauses, ctx)}
  end

  # --- Default: pass through ---
  defp canvas_scope(other, _ctx), do: other

  # --- Helper functions ---

  defp canvas_scope_error!(meta, message) do
    raise CompileError,
      line: Keyword.get(meta, :line, 0),
      description: String.trim(message)
  end

  # Rewrite [do: block] in the last arg to interpreted opts
  defp canvas_scope_rewrite_do_block(args) do
    case List.last(args) do
      [{:do, block}] ->
        pairs = interpret_block(block)
        opts_ast = pairs_to_keyword_ast(pairs)
        List.replace_at(args, -1, opts_ast)

      _ ->
        args
    end
  end

  # For comprehension: recurse into the do/else bodies
  defp canvas_scope_for_args(args, ctx) do
    Enum.map(args, fn
      {:do, body} -> {:do, wrap_block_in_list(canvas_scope(body, ctx))}
      {:else, body} -> {:else, wrap_block_in_list(canvas_scope(body, ctx))}
      other -> other
    end)
  end

  # if/unless clauses
  defp canvas_scope_clauses(clauses, ctx) do
    Enum.map(clauses, fn
      {:do, body} -> {:do, wrap_block_in_list(canvas_scope(body, ctx))}
      {:else, body} -> {:else, wrap_block_in_list(canvas_scope(body, ctx))}
      other -> other
    end)
  end

  # case/cond/fn clauses (list of {:->, meta, [pattern, body]})
  defp canvas_scope_match_clauses(clauses, ctx) do
    Enum.map(clauses, fn
      {:->, meta, [pattern, body]} ->
        {:->, meta, [pattern, wrap_block_in_list(canvas_scope(body, ctx))]}

      other ->
        other
    end)
  end

  # with args: generators + do/else
  defp canvas_scope_with_args(args, ctx) do
    Enum.map(args, fn
      {:do, body} -> {:do, wrap_block_in_list(canvas_scope(body, ctx))}
      {:else, clauses} -> {:else, canvas_scope_match_clauses(clauses, ctx)}
      other -> other
    end)
  end
end
