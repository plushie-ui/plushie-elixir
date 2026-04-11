defmodule Plushie.UI do
  @moduledoc """
  Ergonomic builder layer for Plushie UI trees.

  Import this module in your `view/1` function to get concise widget builder
  syntax with optional `do` block sugar for children.

  ## Usage

      def view(model) do
        import Plushie.UI

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

  Plushie exports formatter settings that keep layout blocks paren-free so
  they read like declarative markup. Add `:plushie` to `import_deps` in
  your `.formatter.exs`:

      # .formatter.exs
      [
        inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
        import_deps: [:plushie]
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

  ## Available widgets

  Layout containers (auto-ID, accept children in do-blocks):
  `column`, `row`, `container`, `stack`, `grid`, `floating`, `pin`,
  `responsive`, `sensor`, `scrollable`, `themer`, `overlay`

  Explicit-ID containers: `window`, `canvas`, `pane_grid`, `tooltip`

  Leaf widgets: `text`, `button`, `text_input`, `text_editor`,
  `checkbox`, `toggler`, `radio`, `slider`, `vertical_slider`,
  `pick_list`, `combo_box`, `progress_bar`, `image`, `svg`,
  `markdown`, `rich_text`, `rule`, `space`, `qr_code`

  Canvas shapes: `rect`, `circle`, `line`, `path`, `text` (canvas
  variant), `image` (canvas variant), `svg` (canvas variant)

  Canvas structure: `layer`, `group`, `interactive`

  Each widget's full prop reference is on its `Plushie.Widget.*`
  module. Canvas shapes are documented in `Plushie.Canvas.*`.

  ## Canvas shapes

  Canvas shape functions (`rect`, `circle`, `line`, `path`, `stroke`,
  `linear_gradient`, `move_to`, `line_to`, etc.) and canvas structure
  macros (`group`, `layer`) are available directly via `import Plushie.UI`.
  No separate `import Plushie.Canvas.Shape` is needed inside canvas blocks.

  Inside `canvas`, `layer`, and `group` blocks, `text`, `image`, and
  `svg` calls resolve automatically to their canvas shape variants.

  For interactive canvas elements, use `interactive` (requires an id):

      canvas "toggle", width: 52, height: 28 do
        layer "bg" do
          interactive "switch", on_click: true, cursor: :pointer do
            rect(0, 0, 52, 28, fill: "#4CAF50", radius: 14)
            circle(36, 14, 10, fill: "#fff")
          end
        end
      end

  Import `Plushie.Canvas.Shape` directly only when building shapes in
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

  Tree query functions live in `Plushie.Tree`:

      Plushie.Tree.find(tree, "form/save")
      Plushie.Tree.find(tree, "save", "settings")
      Plushie.Tree.find_local(tree, "save")

  ## Internals

  For maintainer and widget author details on the macro architecture,
  see `docs/reference/dsl.md`.
  """

  # Container widget modules and their display names, used to build the
  # reverse map from option key -> owning containers for compile-time
  # validation in container_scope.
  @container_modules [
    {Plushie.Widget.Column, "column"},
    {Plushie.Widget.Row, "row"},
    {Plushie.Widget.Container, "container"},
    {Plushie.Widget.Overlay, "overlay"},
    {Plushie.Widget.Scrollable, "scrollable"},
    {Plushie.Widget.Stack, "stack"},
    {Plushie.Widget.Grid, "grid"},
    {Plushie.Widget.KeyedColumn, "keyed_column"},
    {Plushie.Widget.Responsive, "responsive"},
    {Plushie.Widget.Pin, "pin"},
    {Plushie.Widget.Floating, "floating"},
    {Plushie.Widget.PointerArea, "pointer_area"},
    {Plushie.Widget.Sensor, "sensor"},
    {Plushie.Widget.Themer, "themer"},
    {Plushie.Widget.PaneGrid, "pane_grid"},
    {Plushie.Widget.Table, "table"},
    {Plushie.Widget.Tooltip, "tooltip"},
    {Plushie.Widget.Space, "space"},
    {Plushie.Widget.Rule, "rule"},
    {Plushie.Widget.Window, "window"}
  ]

  @all_container_option_owners (for {mod, name} <- @container_modules,
                                    Code.ensure_loaded?(mod) and
                                      function_exported?(mod, :__field_keys__, 0),
                                    key <- mod.__field_keys__(),
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
          items :: [Plushie.Widget.ui_node() | {:__widget_prop__, atom(), term()}],
          auto_id :: String.t() | nil
        ) :: Plushie.Widget.ui_node()
  def __build_container__(widget_mod, id, opts, items, auto_id) do
    resolved_id = id || Keyword.get(opts, :id) || auto_id

    # Partition block items into props and children
    {prop_tuples, children} =
      Enum.split_with(items, &match?({:__widget_prop__, _, _}, &1))

    block_opts = Enum.map(prop_tuples, fn {:__widget_prop__, k, v} -> {k, v} end)

    # Merge: keyword opts from call line + block opts (block wins on conflict)
    merged_opts = Keyword.merge(clean_opts(opts), block_opts)

    # Block children take precedence over keyword children when present.
    # An empty block does NOT suppress keyword children because blocks
    # can be used purely for prop declarations (padding, spacing, etc.)
    # while children come from the keyword:
    #
    #   column(children: dynamic_items) do
    #     padding 10
    #   end
    resolved_children =
      if children != [] do
        children
      else
        Keyword.get(opts, :children, [])
      end

    Plushie.Widget.Build.build_node(merged_opts, fn widget_opts ->
      widget = widget_mod.new(resolved_id, widget_opts)

      widget =
        if resolved_children != [] do
          widget_mod.extend(widget, resolved_children)
        else
          widget
        end

      widget_mod.build(widget)
    end)
  end

  # Kept for external callers. Internal macros use compile_auto_id/2 to
  # compute the string at compile time and inject a literal, avoiding
  # runtime Module.split + Enum.join on every render.
  @doc false
  @spec __auto_id__(mod :: module() | nil, line :: non_neg_integer()) :: String.t()
  def __auto_id__(nil, line), do: "auto:nomodule:#{line}"

  def __auto_id__(mod, line) do
    # Elixir module names can contain Unicode (e.g. Héllo.Wörld).
    # Normalize to printable ASCII so auto-IDs satisfy the wire protocol's
    # ID constraints. Line number ensures uniqueness even after normalization.
    mod_str =
      mod
      |> Module.split()
      |> Enum.join(".")
      |> String.replace(~r/[^\x21-\x7e]/, "_")

    "auto:#{mod_str}:#{line}"
  end

  # Compile-time auto ID computation. Called inside defmacro bodies where
  # __CALLER__.module and __CALLER__.line are known at compile time.
  # The result is injected as a string literal in the generated code.
  @doc false
  defp compile_auto_id(nil, line), do: "auto:nomodule:#{line}"

  defp compile_auto_id(mod, line) do
    mod_str =
      mod
      |> Module.split()
      |> Enum.join(".")
      |> String.replace(~r/[^\x21-\x7e]/, "_")

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
  # Memo (render path optimization)
  # ---------------------------------------------------------------------------

  @doc """
  Caches a subtree based on a dependency term.

  When `deps` is structurally equal (`===`) to the previous render's
  value for this memo site, the cached normalized subtree is reused
  directly. The tree differ short-circuits on reference equality, making
  the diff for unchanged subtrees O(1).

      window "main" do
        memo model.sidebar_version do
          sidebar(model.sidebar_data)
        end
      end

  The body is only evaluated when `deps` changes. For dynamic lists,
  include the item key in deps so each iteration gets a unique cache
  entry:

      for item <- model.items do
        memo {item.id, item.version} do
          item_card(item)
        end
      end
  """
  defmacro memo(deps, do: block) do
    auto_id = compile_auto_id(__CALLER__.module, __CALLER__.line)
    exprs = block_to_exprs(block)

    quote do
      %{
        type: "__memo__",
        id: unquote(auto_id),
        props: %{},
        children: [],
        meta: %{
          __memo_deps__: unquote(deps),
          __memo_fun__: fn ->
            unquote(build_list_accumulator(exprs))
            |> :lists.reverse()
            |> List.flatten()
            |> Enum.reject(&is_nil/1)
          end
        }
      }
    end
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
        option_keys = Plushie.Widget.Window.__field_keys__()
        option_types = Plushie.Widget.Window.__field_types__()
        block = container_scope(block, option_keys, option_types, "window")
        exprs = block_to_exprs(block)

        quote do
          items =
            unquote(build_list_accumulator(exprs))
            |> :lists.reverse()
            |> List.flatten()
            |> Enum.reject(&is_nil/1)

          Plushie.UI.__build_container__(
            Plushie.Widget.Window,
            unquote(id),
            [],
            items,
            nil
          )
        end

      opts ->
        quote do
          Plushie.UI.__build_container__(
            Plushie.Widget.Window,
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
    option_keys = Plushie.Widget.Window.__field_keys__()
    option_types = Plushie.Widget.Window.__field_types__()
    block = container_scope(block, option_keys, option_types, "window")
    exprs = block_to_exprs(block)

    quote do
      items =
        unquote(build_list_accumulator(exprs))
        |> :lists.reverse()
        |> List.flatten()
        |> Enum.reject(&is_nil/1)

      Plushie.UI.__build_container__(
        Plushie.Widget.Window,
        unquote(id),
        unquote(opts),
        items,
        nil
      )
    end
  end

  # ---------------------------------------------------------------------------
  # Generated container macros (explicit-ID and auto-ID)
  # ---------------------------------------------------------------------------
  #
  # Two categories of containers share identical macro structure:
  #
  # 1. Explicit-ID containers: macro(id, opts_or_do), macro(id, opts, do: block)
  # 2. Auto-ID containers: macro(opts_or_block), macro(opts, do: block)
  #
  # The only differences are the widget module and the display name string
  # used for compile-time validation messages. The helpers below generate
  # the AST shared by every container in each category.

  # Returns the macro body AST for explicit-ID container 2-arity form.
  defp id_container_2arity_body(widget_mod, name_str, id, opts_or_do) do
    case opts_or_do do
      [do: block] ->
        option_keys = widget_mod.__field_keys__()
        option_types = widget_mod.__field_types__()
        block = container_scope(block, option_keys, option_types, name_str)
        exprs = block_to_exprs(block)

        quote do
          items =
            unquote(build_list_accumulator(exprs))
            |> :lists.reverse()
            |> List.flatten()
            |> Enum.reject(&is_nil/1)

          Plushie.UI.__build_container__(unquote(widget_mod), unquote(id), [], items, nil)
        end

      opts ->
        quote do
          Plushie.UI.__build_container__(
            unquote(widget_mod),
            unquote(id),
            unquote(opts),
            [],
            nil
          )
        end
    end
  end

  # Returns the macro body AST for explicit-ID container 3-arity form.
  defp id_container_3arity_body(widget_mod, name_str, id, opts, block) do
    option_keys = widget_mod.__field_keys__()
    option_types = widget_mod.__field_types__()
    block = container_scope(block, option_keys, option_types, name_str)
    exprs = block_to_exprs(block)

    quote do
      items =
        unquote(build_list_accumulator(exprs))
        |> :lists.reverse()
        |> List.flatten()
        |> Enum.reject(&is_nil/1)

      Plushie.UI.__build_container__(
        unquote(widget_mod),
        unquote(id),
        unquote(opts),
        items,
        nil
      )
    end
  end

  # Returns the macro body AST for auto-ID container 1-arity form.
  defp auto_container_1arity_body(widget_mod, name_str, opts_or_block, auto_id) do
    case opts_or_block do
      [do: block] ->
        option_keys = widget_mod.__field_keys__()
        option_types = widget_mod.__field_types__()
        block = container_scope(block, option_keys, option_types, name_str)
        exprs = block_to_exprs(block)

        quote do
          items =
            unquote(build_list_accumulator(exprs))
            |> :lists.reverse()
            |> List.flatten()
            |> Enum.reject(&is_nil/1)

          Plushie.UI.__build_container__(
            unquote(widget_mod),
            nil,
            [],
            items,
            unquote(auto_id)
          )
        end

      opts ->
        quote do
          Plushie.UI.__build_container__(
            unquote(widget_mod),
            nil,
            unquote(opts),
            [],
            unquote(auto_id)
          )
        end
    end
  end

  # Returns the macro body AST for auto-ID container 2-arity form.
  defp auto_container_2arity_body(widget_mod, name_str, opts, block, auto_id) do
    option_keys = widget_mod.__field_keys__()
    option_types = widget_mod.__field_types__()
    block = container_scope(block, option_keys, option_types, name_str)
    exprs = block_to_exprs(block)

    quote do
      items =
        unquote(build_list_accumulator(exprs))
        |> :lists.reverse()
        |> List.flatten()
        |> Enum.reject(&is_nil/1)

      Plushie.UI.__build_container__(
        unquote(widget_mod),
        nil,
        unquote(opts),
        items,
        unquote(auto_id)
      )
    end
  end

  # -- Auto-ID containers (no explicit id argument) ---------------------------

  @auto_id_container_docs %{
    column: """
    Vertical flex layout.

    ## Options

    - `:spacing` -- gap between children
    - `:padding` -- padding around children
    - `:width` / `:height` -- `:fill`, `:shrink`, or number
    - `:align_x` -- `:left`, `:center`, `:right`
    - `:id` -- explicit ID (otherwise auto-generated from call site)
    - `:children` -- child nodes (function-form shorthand)

    ## Example

        column spacing: 8 do
          text("Hello")
          text("World")
        end
    """,
    row: """
    Horizontal flex layout.

    ## Options

    Same as `column/1`.

    ## Example

        row spacing: 4 do
          button("yes", "Yes")
          button("no", "No")
        end
    """,
    stack: """
    Z-axis stacking layout (overlays).

    ## Example

        stack do
          image("bg", "/path/to/bg.png")
          container "overlay", padding: 16 do
            text("Overlaid text")
          end
        end
    """,
    grid: """
    Grid layout.

    ## Options

    - `:columns` -- number of columns
    - `:column_width` -- width of each column
    - `:row_height` -- height of each row
    - `:spacing` -- gap between cells
    - `:padding` -- padding around grid
    - `:width` / `:height` -- dimensions
    - `:id` -- explicit ID (otherwise auto-generated from call site)

    ## Example

        grid columns: 3, spacing: 8 do
          for item <- items do
            text(item.id, item.name)
          end
        end
    """,
    keyed_column: """
    Keyed column for efficient list diffing.

    ## Options

    Same as `column/1`.

    ## Example

        keyed_column spacing: 8 do
          for item <- items do
            text(item.id, item.name)
          end
        end
    """,
    responsive: """
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
  }

  @auto_id_containers [
    {:column, Plushie.Widget.Column},
    {:row, Plushie.Widget.Row},
    {:stack, Plushie.Widget.Stack},
    {:grid, Plushie.Widget.Grid},
    {:keyed_column, Plushie.Widget.KeyedColumn},
    {:responsive, Plushie.Widget.Responsive}
  ]

  for {name, mod} <- @auto_id_containers do
    name_str = Atom.to_string(name)

    @doc @auto_id_container_docs[name]
    defmacro unquote(name)(opts_or_block \\ []) do
      auto_id = compile_auto_id(__CALLER__.module, __CALLER__.line)

      auto_container_1arity_body(
        unquote(mod),
        unquote(name_str),
        opts_or_block,
        auto_id
      )
    end

    @doc false
    defmacro unquote(name)(opts, do: block) do
      auto_id = compile_auto_id(__CALLER__.module, __CALLER__.line)

      auto_container_2arity_body(
        unquote(mod),
        unquote(name_str),
        opts,
        block,
        auto_id
      )
    end
  end

  # -- Explicit-ID containers -------------------------------------------------

  @id_container_docs %{
    container: """
    Generic box with alignment and padding.

    ## Example

        container "hero", padding: 16 do
          text("Welcome")
        end
    """,
    overlay: """
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
    """,
    scrollable: """
    Scrollable region.

    ## Example

        scrollable "feed" do
          for item <- items do
            text(item.id, item.title)
          end
        end
    """,
    pin: """
    Pin layout for absolute positioning.

    ## Example

        pin "overlay" do
          text("Pinned content")
        end
    """,
    floating: """
    Floating overlay layout.

    ## Example

        floating "popup" do
          text("Floating content")
        end
    """,
    pointer_area: """
    Pointer area for capturing mouse events on children.

    ## Options

    - `:on_press`, `:on_release`, `:on_right_press`, `:on_middle_press`
    - `:on_enter`, `:on_exit`

    ## Example

        pointer_area "clickable" do
          text("Click me")
        end
    """,
    sensor: """
    Sensor for detecting layout changes on children.

    ## Options

    - `:on_resize`, `:on_appear`

    ## Example

        sensor "tracked" do
          text("Monitored content")
        end
    """,
    themer: """
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
  }

  # Stateful containers that hold renderer-side state
  @stateful_id_containers ~w(scrollable pane_grid)a

  @id_containers [
    {:container, Plushie.Widget.Container},
    {:overlay, Plushie.Widget.Overlay},
    {:scrollable, Plushie.Widget.Scrollable},
    {:pin, Plushie.Widget.Pin},
    {:floating, Plushie.Widget.Floating},
    {:pointer_area, Plushie.Widget.PointerArea},
    {:sensor, Plushie.Widget.Sensor},
    {:themer, Plushie.Widget.Themer}
  ]

  for {name, mod} <- @id_containers do
    name_str = Atom.to_string(name)

    @doc @id_container_docs[name]
    defmacro unquote(name)(id, opts_or_do \\ []) do
      # Detect scrollable do...end without an ID (id arg receives the do-block)
      if unquote(name) in @stateful_id_containers and Keyword.keyword?(id) and
           Keyword.has_key?(id, :do) do
        raise CompileError,
          line: __CALLER__.line,
          file: __CALLER__.file,
          description:
            "#{unquote(name_str)} requires an explicit ID because it holds renderer-side state. " <>
              "Use #{unquote(name_str)}(\"my-id\") do ... end"
      end

      id_container_2arity_body(unquote(mod), unquote(name_str), id, opts_or_do)
    end

    @doc false
    defmacro unquote(name)(id, opts, do: block) do
      id_container_3arity_body(unquote(mod), unquote(name_str), id, opts, block)
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
    option_keys = Plushie.Widget.Space.__field_keys__()
    option_types = Plushie.Widget.Space.__field_types__()

    case opts_or_do do
      [do: block] ->
        block = container_scope(block, option_keys, option_types, "space")
        exprs = block_to_exprs(block)

        quote do
          items =
            unquote(build_list_accumulator(exprs))
            |> :lists.reverse()
            |> List.flatten()
            |> Enum.reject(&is_nil/1)

          Plushie.UI.__build_container__(
            Plushie.Widget.Space,
            nil,
            [],
            items,
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end

      opts ->
        quote do
          Plushie.UI.__build_container__(
            Plushie.Widget.Space,
            nil,
            unquote(opts),
            [],
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Generated leaf widget macros
  # ---------------------------------------------------------------------------
  #
  # Leaf widgets that take (id, positional_arg, opts_or_do) share identical
  # macro structure. Only the widget module, display name, and build function
  # differ. The macros are stamped out from @leaf_widgets; the build functions
  # remain hand-written below since each has its own constructor signature.

  # Returns the macro body AST for leaf widget 3-arity forms.
  defp leaf_macro_body(widget_mod, name_str, build_fn, id, positional, opts_or_do, caller) do
    case opts_or_do do
      [do: block] ->
        option_keys = widget_mod.__field_keys__()
        option_types = widget_mod.__field_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, name_str, caller)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do
          Plushie.Widget.Build.build_node(unquote(opts_ast), fn widget_opts ->
            Plushie.UI.unquote(build_fn)(unquote(id), unquote(positional), widget_opts)
          end)
        end

      opts ->
        quote do
          Plushie.Widget.Build.build_node(unquote(opts), fn widget_opts ->
            Plushie.UI.unquote(build_fn)(unquote(id), unquote(positional), widget_opts)
          end)
        end
    end
  end

  @leaf_widget_docs %{
    button: """
    Clickable button.

    Emits `%WidgetEvent{type: :click, id: id}` when clicked.

    ## Example

        button("save", "Save", style: :primary)

        button "save", "Save" do
          style :primary
        end
    """,
    text_input: """
    Single-line text input.

    Emits `%WidgetEvent{type: :input, id: id, value: value}` on change and `%WidgetEvent{type: :submit, id: id, value: value}` on Enter.

    ## Example

        text_input("name", model.name, placeholder: "Your name")

        text_input "name", model.name do
          placeholder "Your name"
        end
    """,
    checkbox: """
    Boolean checkbox toggle.

    Emits `%WidgetEvent{type: :toggle, id: id, value: boolean}` when toggled.

    ## Example

        checkbox("agree", model.agreed, label: "I agree")

        checkbox "agree", model.agreed do
          label "I agree"
        end
    """,
    toggler: """
    Toggle switch.

    Emits `%WidgetEvent{type: :toggle, id: id, value: boolean}` when toggled.

    ## Example

        toggler("dark_mode", model.dark_mode, label: "Dark mode")

        toggler "dark_mode", model.dark_mode do
          label "Dark mode"
        end
    """,
    text_editor: """
    Multi-line text editor.

    ## Example

        text_editor("notes", model.notes, width: :fill, height: 200)

        text_editor "notes", model.notes do
          width :fill
          height 200
        end
    """,
    image: """
    Raster image display.

    ## Example

        image("logo", "/assets/logo.png", width: 200, content_fit: :cover)

        image "logo", "/assets/logo.png" do
          width 200
          content_fit :cover
        end
    """,
    svg: """
    SVG image display.

    ## Example

        svg("icon", "/assets/icon.svg", width: 24, height: 24)

        svg "icon", "/assets/icon.svg" do
          width 24
          height 24
        end
    """,
    qr_code: """
    QR code display. No children.

    ## Arguments

    - `id` -- unique identifier
    - `data` -- the string to encode

    ## Options

    - `:cell_size` -- size of each QR module in pixels (default 4.0)
    - `:cell_color` -- color of dark modules
    - `:background` -- color of light modules
    - `:error_correction` -- `:low`, `:medium` (default), `:quartile`, `:high`

    ## Example

        qr_code("my_qr", "https://example.com", cell_size: 6)

        qr_code "my_qr", "https://example.com" do
          cell_size 6
        end
    """
  }

  @leaf_widgets [
    {:button, Plushie.Widget.Button},
    {:text_input, Plushie.Widget.TextInput},
    {:checkbox, Plushie.Widget.Checkbox},
    {:toggler, Plushie.Widget.Toggler},
    {:text_editor, Plushie.Widget.TextEditor},
    {:image, Plushie.Widget.Image},
    {:svg, Plushie.Widget.Svg},
    {:qr_code, Plushie.Widget.QrCode}
  ]

  for {name, mod} <- @leaf_widgets do
    name_str = Atom.to_string(name)
    build_fn = :"__build_#{name}__"

    @doc @leaf_widget_docs[name]
    defmacro unquote(name)(id, positional, opts_or_do \\ []) do
      leaf_macro_body(
        unquote(mod),
        unquote(name_str),
        unquote(build_fn),
        id,
        positional,
        opts_or_do,
        __CALLER__
      )
    end
  end

  # -- Leaf widget build functions (hand-written, each has unique logic) ------

  @doc false
  @spec __build_button__(String.t(), String.t(), keyword()) ::
          Plushie.Widget.ui_node()
  def __build_button__(id, label, opts) do
    Plushie.Widget.Button.new(id, label, clean_opts(opts)) |> Plushie.Widget.Button.build()
  end

  @doc false
  @spec __build_text_input__(String.t(), String.t(), keyword()) ::
          Plushie.Widget.ui_node()
  def __build_text_input__(id, value, opts) when not is_keyword(value) do
    Plushie.Widget.TextInput.new(id, value, clean_opts(opts)) |> Plushie.Widget.TextInput.build()
  end

  @doc false
  @spec __build_checkbox__(String.t(), boolean(), keyword()) ::
          Plushie.Widget.ui_node()
  def __build_checkbox__(id, checked, opts) when not is_keyword(checked) do
    clean = clean_opts(opts)
    {label, remaining} = Keyword.pop(clean, :label, "")
    Plushie.Widget.Checkbox.new(id, label, checked, remaining) |> Plushie.Widget.Checkbox.build()
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
      Plushie.Widget.Text.new(unquote(compile_auto_id(caller_mod, caller_line)), unquote(content))
      |> Plushie.Widget.Text.build()
    end
  end

  @doc false
  defmacro text(id, content) do
    quote do
      Plushie.Widget.Text.new(unquote(id), unquote(content)) |> Plushie.Widget.Text.build()
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
        option_keys = Plushie.Widget.Text.__field_keys__()
        option_types = Plushie.Widget.Text.__field_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "text", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do
          Plushie.Widget.Build.build_node(unquote(opts_ast), fn widget_opts ->
            Plushie.Widget.Text.new(unquote(id), unquote(content), widget_opts)
            |> Plushie.Widget.Text.build()
          end)
        end

      opts ->
        quote do
          Plushie.Widget.Build.build_node(unquote(opts), fn widget_opts ->
            Plushie.Widget.Text.new(unquote(id), unquote(content), widget_opts)
            |> Plushie.Widget.Text.build()
          end)
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
    option_keys = Plushie.Widget.Rule.__field_keys__()
    option_types = Plushie.Widget.Rule.__field_types__()

    case opts_or_do do
      [do: block] ->
        block = container_scope(block, option_keys, option_types, "rule")
        exprs = block_to_exprs(block)

        quote do
          items =
            unquote(build_list_accumulator(exprs))
            |> :lists.reverse()
            |> List.flatten()
            |> Enum.reject(&is_nil/1)

          Plushie.UI.__build_container__(
            Plushie.Widget.Rule,
            nil,
            [],
            items,
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end

      opts ->
        quote do
          Plushie.UI.__build_container__(
            Plushie.Widget.Rule,
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
      Plushie.Widget.ProgressBar.new(
        unquote(compile_auto_id(caller_mod, caller_line)),
        unquote(range),
        unquote(value)
      )
      |> Plushie.Widget.ProgressBar.build()
    end
  end

  @doc false
  defmacro progress_bar(id, range, value) do
    quote do
      Plushie.Widget.ProgressBar.new(unquote(id), unquote(range), unquote(value))
      |> Plushie.Widget.ProgressBar.build()
    end
  end

  @doc false
  defmacro progress_bar(id, range, value, opts_or_do) do
    case opts_or_do do
      [do: block] ->
        option_keys = Plushie.Widget.ProgressBar.__field_keys__()
        option_types = Plushie.Widget.ProgressBar.__field_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "progress_bar", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do
          Plushie.Widget.Build.build_node(unquote(opts_ast), fn widget_opts ->
            Plushie.Widget.ProgressBar.new(
              unquote(id),
              unquote(range),
              unquote(value),
              widget_opts
            )
            |> Plushie.Widget.ProgressBar.build()
          end)
        end

      opts ->
        quote do
          Plushie.Widget.Build.build_node(unquote(opts), fn widget_opts ->
            Plushie.Widget.ProgressBar.new(
              unquote(id),
              unquote(range),
              unquote(value),
              widget_opts
            )
            |> Plushie.Widget.ProgressBar.build()
          end)
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Additional input widgets
  # ---------------------------------------------------------------------------

  @doc false
  @spec __build_toggler__(String.t(), boolean(), keyword()) ::
          Plushie.Widget.ui_node()
  def __build_toggler__(id, is_toggled, opts) when not is_keyword(is_toggled) do
    Plushie.Widget.Toggler.new(id, is_toggled, clean_opts(opts)) |> Plushie.Widget.Toggler.build()
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
        option_keys = Plushie.Widget.Radio.__field_keys__()
        option_types = Plushie.Widget.Radio.__field_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "radio", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do
          Plushie.Widget.Build.build_node(unquote(opts_ast), fn widget_opts ->
            Plushie.UI.__build_radio__(
              unquote(id),
              unquote(value),
              unquote(selected),
              widget_opts
            )
          end)
        end

      opts ->
        quote do
          Plushie.Widget.Build.build_node(unquote(opts), fn widget_opts ->
            Plushie.UI.__build_radio__(
              unquote(id),
              unquote(value),
              unquote(selected),
              widget_opts
            )
          end)
        end
    end
  end

  @doc false
  @spec __build_radio__(String.t(), term(), term(), keyword()) ::
          Plushie.Widget.ui_node()
  def __build_radio__(id, value, selected, opts)
      when not is_keyword(value) and not is_keyword(selected) do
    Plushie.Widget.Radio.new(id, value, selected, clean_opts(opts))
    |> Plushie.Widget.Radio.build()
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
        option_keys = Plushie.Widget.Slider.__field_keys__()
        option_types = Plushie.Widget.Slider.__field_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "slider", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do
          Plushie.Widget.Build.build_node(unquote(opts_ast), fn widget_opts ->
            Plushie.UI.__build_slider__(
              unquote(id),
              unquote(range),
              unquote(value),
              widget_opts
            )
          end)
        end

      opts ->
        quote do
          Plushie.Widget.Build.build_node(unquote(opts), fn widget_opts ->
            Plushie.UI.__build_slider__(
              unquote(id),
              unquote(range),
              unquote(value),
              widget_opts
            )
          end)
        end
    end
  end

  @doc false
  @spec __build_slider__(String.t(), {number(), number()}, number(), keyword()) ::
          Plushie.Widget.ui_node()
  def __build_slider__(id, range, value, opts)
      when not is_keyword(range) and not is_keyword(value) do
    Plushie.Widget.Slider.new(id, normalize_range(range), value, clean_opts(opts))
    |> Plushie.Widget.Slider.build()
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
        option_keys = Plushie.Widget.VerticalSlider.__field_keys__()
        option_types = Plushie.Widget.VerticalSlider.__field_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "vertical_slider", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do
          Plushie.Widget.Build.build_node(unquote(opts_ast), fn widget_opts ->
            Plushie.UI.__build_vertical_slider__(
              unquote(id),
              unquote(range),
              unquote(value),
              widget_opts
            )
          end)
        end

      opts ->
        quote do
          Plushie.Widget.Build.build_node(unquote(opts), fn widget_opts ->
            Plushie.UI.__build_vertical_slider__(
              unquote(id),
              unquote(range),
              unquote(value),
              widget_opts
            )
          end)
        end
    end
  end

  @doc false
  @spec __build_vertical_slider__(String.t(), {number(), number()}, number(), keyword()) ::
          Plushie.Widget.ui_node()
  def __build_vertical_slider__(id, range, value, opts)
      when not is_keyword(range) and not is_keyword(value) do
    Plushie.Widget.VerticalSlider.new(id, normalize_range(range), value, clean_opts(opts))
    |> Plushie.Widget.VerticalSlider.build()
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
        option_keys = Plushie.Widget.PickList.__field_keys__()
        option_types = Plushie.Widget.PickList.__field_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "pick_list", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do
          Plushie.Widget.Build.build_node(unquote(opts_ast), fn widget_opts ->
            Plushie.UI.__build_pick_list__(
              unquote(id),
              unquote(options),
              unquote(selected),
              widget_opts
            )
          end)
        end

      opts ->
        quote do
          Plushie.Widget.Build.build_node(unquote(opts), fn widget_opts ->
            Plushie.UI.__build_pick_list__(
              unquote(id),
              unquote(options),
              unquote(selected),
              widget_opts
            )
          end)
        end
    end
  end

  @doc false
  @spec __build_pick_list__(String.t(), [String.t()], String.t() | nil, keyword()) ::
          Plushie.Widget.ui_node()
  def __build_pick_list__(id, options, selected, opts)
      when not is_keyword(options) and not is_keyword(selected) do
    Plushie.Widget.PickList.new(id, options, [{:selected, selected} | clean_opts(opts)])
    |> Plushie.Widget.PickList.build()
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
        option_keys = Plushie.Widget.ComboBox.__field_keys__()
        option_types = Plushie.Widget.ComboBox.__field_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "combo_box", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do
          Plushie.Widget.Build.build_node(unquote(opts_ast), fn widget_opts ->
            Plushie.UI.__build_combo_box__(
              unquote(id),
              unquote(options),
              unquote(value),
              widget_opts
            )
          end)
        end

      opts ->
        quote do
          Plushie.Widget.Build.build_node(unquote(opts), fn widget_opts ->
            Plushie.UI.__build_combo_box__(
              unquote(id),
              unquote(options),
              unquote(value),
              widget_opts
            )
          end)
        end
    end
  end

  @doc false
  @spec __build_combo_box__(String.t(), [String.t()], String.t(), keyword()) ::
          Plushie.Widget.ui_node()
  def __build_combo_box__(id, options, value, opts)
      when not is_keyword(options) and not is_keyword(value) do
    Plushie.Widget.ComboBox.new(id, options, [{:value, value} | clean_opts(opts)])
    |> Plushie.Widget.ComboBox.build()
  end

  @doc false
  @spec __build_text_editor__(String.t(), String.t(), keyword()) ::
          Plushie.Widget.ui_node()
  def __build_text_editor__(id, content, opts) when not is_keyword(content) do
    Plushie.Widget.TextEditor.new(id, [{:content, content} | clean_opts(opts)])
    |> Plushie.Widget.TextEditor.build()
  end

  # ---------------------------------------------------------------------------
  # Additional display widgets
  # ---------------------------------------------------------------------------

  @doc false
  @spec __build_image__(String.t(), String.t(), keyword()) ::
          Plushie.Widget.ui_node()
  def __build_image__(id, source, opts) when not is_keyword(source) do
    Plushie.Widget.Image.new(id, source, clean_opts(opts)) |> Plushie.Widget.Image.build()
  end

  @doc false
  @spec __build_svg__(String.t(), String.t(), keyword()) ::
          Plushie.Widget.ui_node()
  def __build_svg__(id, source, opts) when not is_keyword(source) do
    Plushie.Widget.Svg.new(id, source, clean_opts(opts)) |> Plushie.Widget.Svg.build()
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
      Plushie.Widget.Markdown.new(
        unquote(compile_auto_id(caller_mod, caller_line)),
        unquote(content)
      )
      |> Plushie.Widget.Markdown.build()
    end
  end

  @doc false
  defmacro markdown(id, content) do
    quote do
      Plushie.Widget.Markdown.new(unquote(id), unquote(content))
      |> Plushie.Widget.Markdown.build()
    end
  end

  @doc false
  defmacro markdown(id, content, opts_or_do) do
    case opts_or_do do
      [do: block] ->
        option_keys = Plushie.Widget.Markdown.__field_keys__()
        option_types = Plushie.Widget.Markdown.__field_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "markdown", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do
          Plushie.Widget.Build.build_node(unquote(opts_ast), fn widget_opts ->
            Plushie.Widget.Markdown.new(unquote(id), unquote(content), widget_opts)
            |> Plushie.Widget.Markdown.build()
          end)
        end

      opts ->
        quote do
          Plushie.Widget.Build.build_node(unquote(opts), fn widget_opts ->
            Plushie.Widget.Markdown.new(unquote(id), unquote(content), widget_opts)
            |> Plushie.Widget.Markdown.build()
          end)
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
    option_keys = Plushie.Widget.Tooltip.__field_keys__()
    option_types = Plushie.Widget.Tooltip.__field_types__()

    case tip_or_do do
      [do: block] ->
        block = container_scope(block, option_keys, option_types, "tooltip")
        exprs = block_to_exprs(block)

        quote do
          items =
            unquote(build_list_accumulator(exprs))
            |> :lists.reverse()
            |> List.flatten()
            |> Enum.reject(&is_nil/1)

          Plushie.UI.__build_container__(Plushie.Widget.Tooltip, unquote(id), [], items, nil)
        end

      tip when is_binary(tip) ->
        quote do
          Plushie.UI.__build_container__(
            Plushie.Widget.Tooltip,
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
    option_keys = Plushie.Widget.Tooltip.__field_keys__()
    option_types = Plushie.Widget.Tooltip.__field_types__()

    case opts_or_do do
      [do: block] ->
        block = container_scope(block, option_keys, option_types, "tooltip")
        exprs = block_to_exprs(block)

        quote do
          items =
            unquote(build_list_accumulator(exprs))
            |> :lists.reverse()
            |> List.flatten()
            |> Enum.reject(&is_nil/1)

          Plushie.UI.__build_container__(
            Plushie.Widget.Tooltip,
            unquote(id),
            [tip: unquote(tip)],
            items,
            nil
          )
        end

      opts ->
        quote do
          Plushie.UI.__build_container__(
            Plushie.Widget.Tooltip,
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
    option_keys = Plushie.Widget.Tooltip.__field_keys__()
    option_types = Plushie.Widget.Tooltip.__field_types__()
    block = container_scope(block, option_keys, option_types, "tooltip")
    exprs = block_to_exprs(block)

    quote do
      items =
        unquote(build_list_accumulator(exprs))
        |> :lists.reverse()
        |> List.flatten()
        |> Enum.reject(&is_nil/1)

      Plushie.UI.__build_container__(
        Plushie.Widget.Tooltip,
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

  Canvas is a container widget. Its children are Layer elements,
  each holding shape children.

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

  Common options: `:width`, `:height`, `:background`, `:interactive`,
  `:a11y`. See `Plushie.Widget.Canvas` for all props.
  """
  defmacro canvas(id, opts_or_do \\ []) do
    caller_mod = __CALLER__.module

    case opts_or_do do
      [do: block] ->
        block = canvas_scope(block, :canvas, caller_mod)
        exprs = block_to_exprs(block)

        quote do
          items =
            unquote(build_list_accumulator(exprs))
            |> :lists.reverse()
            |> List.flatten()
            |> Enum.reject(&is_nil/1)

          Plushie.UI.__build_container__(
            Plushie.Widget.Canvas,
            unquote(id),
            [],
            items,
            nil
          )
        end

      opts ->
        quote do
          Plushie.UI.__build_container__(
            Plushie.Widget.Canvas,
            unquote(id),
            unquote(opts),
            [],
            nil
          )
        end
    end
  end

  @doc false
  defmacro canvas(id, opts, do: block) do
    block = canvas_scope(block, :canvas, __CALLER__.module)
    exprs = block_to_exprs(block)

    quote do
      items =
        unquote(build_list_accumulator(exprs))
        |> :lists.reverse()
        |> List.flatten()
        |> Enum.reject(&is_nil/1)

      Plushie.UI.__build_container__(
        Plushie.Widget.Canvas,
        unquote(id),
        unquote(opts),
        items,
        nil
      )
    end
  end

  @doc false
  @spec __build_layer__(String.t(), [term()]) :: Plushie.Canvas.Layer.t()
  def __build_layer__(name, children) do
    layer = Plushie.Canvas.Layer.new(name, name: name)

    if children != [] do
      Plushie.Canvas.Layer.extend(layer, children)
    else
      layer
    end
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
        option_keys = Plushie.Widget.PaneGrid.__field_keys__()
        option_types = Plushie.Widget.PaneGrid.__field_types__()
        block = container_scope(block, option_keys, option_types, "pane_grid")
        exprs = block_to_exprs(block)

        quote do
          items =
            unquote(build_list_accumulator(exprs))
            |> :lists.reverse()
            |> List.flatten()
            |> Enum.reject(&is_nil/1)

          Plushie.UI.__build_container__(Plushie.Widget.PaneGrid, unquote(id), [], items, nil)
        end

      opts ->
        quote do
          Plushie.UI.__build_container__(
            Plushie.Widget.PaneGrid,
            unquote(id),
            unquote(opts),
            [],
            nil
          )
        end
    end
  end

  @doc false
  defmacro pane_grid(id, opts, do: block) do
    option_keys = Plushie.Widget.PaneGrid.__field_keys__()
    option_types = Plushie.Widget.PaneGrid.__field_types__()
    block = container_scope(block, option_keys, option_types, "pane_grid")
    exprs = block_to_exprs(block)

    quote do
      items =
        unquote(build_list_accumulator(exprs))
        |> :lists.reverse()
        |> List.flatten()
        |> Enum.reject(&is_nil/1)

      Plushie.UI.__build_container__(
        Plushie.Widget.PaneGrid,
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
        option_keys = Plushie.Widget.RichText.__field_keys__()
        option_types = Plushie.Widget.RichText.__field_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "rich_text", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do
          Plushie.Widget.Build.build_node(unquote(opts_ast), fn widget_opts ->
            Plushie.UI.__build_rich_text__(unquote(id), widget_opts)
          end)
        end

      opts ->
        quote do
          Plushie.Widget.Build.build_node(unquote(opts), fn widget_opts ->
            Plushie.UI.__build_rich_text__(unquote(id), widget_opts)
          end)
        end
    end
  end

  @doc false
  @spec __build_rich_text__(String.t(), keyword()) :: Plushie.Widget.ui_node()
  def __build_rich_text__(id, opts) do
    Plushie.Widget.RichText.new(id, clean_opts(opts))
    |> Plushie.Widget.RichText.build()
  end

  # -- table(id, opts) --------------------------------------------------------

  @doc """
  Data table widget.

  ## Options

  - `:columns` -- list of column descriptors (`%{key, label, width}`)
  - `:rows` -- list of row data maps

  ## Examples

      table("users", columns: cols, rows: data)

      table "users", columns: cols, rows: data do
        header_text_size 14
        row_text_size 12
      end
  """
  defmacro table(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        option_keys = Plushie.Widget.Table.__field_keys__()
        option_types = Plushie.Widget.Table.__field_types__()
        pairs = interpret_block(block, option_types)
        validate_option_keys!(pairs, option_keys, "table", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do
          Plushie.Widget.Build.build_node(unquote(opts_ast), fn widget_opts ->
            Plushie.Widget.Table.new(unquote(id), widget_opts)
            |> Plushie.Widget.Table.build()
          end)
        end

      opts ->
        quote do
          Plushie.Widget.Build.build_node(unquote(opts), fn widget_opts ->
            Plushie.Widget.Table.new(unquote(id), widget_opts)
            |> Plushie.Widget.Table.build()
          end)
        end
    end
  end

  @doc false
  defmacro table(id, opts, do: block) do
    option_keys = Plushie.Widget.Table.__field_keys__()
    option_types = Plushie.Widget.Table.__field_types__()
    pairs = interpret_block(block, option_types)
    validate_option_keys!(pairs, option_keys, "table", __CALLER__)
    opts_ast = pairs_to_keyword_ast(pairs)

    quote do
      Plushie.Widget.Build.build_node(
        Keyword.merge(unquote(opts), unquote(opts_ast)),
        fn widget_opts ->
          Plushie.Widget.Table.new(unquote(id), widget_opts)
          |> Plushie.Widget.Table.build()
        end
      )
    end
  end

  # __build_fixed_node__ removed -- use __build_container__

  # ---------------------------------------------------------------------------
  # Canvas group and layer macros
  # ---------------------------------------------------------------------------

  @doc """
  Groups child shapes as a structural container (transforms, clips).

  For interactive elements (click, hover, drag, focus), use the
  `interactive` macro instead.

  ## Do-block form

      group x: 4, y: 4 do
        rect(0, 0, 32, 32, radius: 4)
      end

  ## List form

      group([rect(0, 0, 100, 40)], x: 10, y: 50)
  """
  defmacro group(opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children =
            unquote(build_list_accumulator(exprs))
            |> :lists.reverse()
            |> List.flatten()
            |> Enum.reject(&is_nil/1)

          Plushie.Canvas.Shape.__build_group__(children, [])
        end

      other ->
        quote do
          Plushie.Canvas.Shape.__build_group__(unquote(other), [])
        end
    end
  end

  @doc false
  defmacro group(first, second) do
    case second do
      [do: block] ->
        exprs = block_to_exprs(block)

        # At compile time, check if `first` is a string literal (id).
        opts_ast =
          if is_binary(first) do
            # group "some-id" do ... end
            [id: first]
          else
            # group opts do ... end (keyword list or runtime expression)
            first
          end

        quote do
          children =
            unquote(build_list_accumulator(exprs))
            |> :lists.reverse()
            |> List.flatten()
            |> Enum.reject(&is_nil/1)

          Plushie.Canvas.Shape.__build_group__(children, unquote(opts_ast))
        end

      opts ->
        quote do
          Plushie.Canvas.Shape.__build_group__(unquote(first), unquote(opts))
        end
    end
  end

  @doc false
  defmacro group(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children =
        unquote(build_list_accumulator(exprs))
        |> :lists.reverse()
        |> List.flatten()
        |> Enum.reject(&is_nil/1)

      Plushie.Canvas.Shape.__build_group__(children, [{:id, unquote(id)} | unquote(opts)])
    end
  end

  @doc """
  Creates an interactive canvas element with a required id.

  Use `interactive` for canvas elements that respond to user input
  (click, hover, drag, focus). For structural grouping (transforms,
  clips), use `group`.

      interactive "btn", on_click: true, cursor: "pointer" do
        rect(0, 0, 100, 40, fill: "#3498db")
      end
  """
  defmacro interactive(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children =
            unquote(build_list_accumulator(exprs))
            |> :lists.reverse()
            |> List.flatten()
            |> Enum.reject(&is_nil/1)

          Plushie.Canvas.Shape.__build_interactive__(unquote(id), children, [])
        end

      opts ->
        quote do
          Plushie.Canvas.Shape.__build_interactive__(unquote(id), [], unquote(opts))
        end
    end
  end

  @doc false
  defmacro interactive(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children =
        unquote(build_list_accumulator(exprs))
        |> :lists.reverse()
        |> List.flatten()
        |> Enum.reject(&is_nil/1)

      Plushie.Canvas.Shape.__build_interactive__(unquote(id), children, unquote(opts))
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
    block = canvas_scope(block, :layer, __CALLER__.module)
    exprs = block_to_exprs(block)

    acc_ast = build_list_accumulator(exprs)

    quote do
      children =
        unquote(acc_ast) |> :lists.reverse() |> List.flatten() |> Enum.reject(&is_nil/1)

      Plushie.UI.__build_layer__(unquote(name), children)
    end
  end

  # ---------------------------------------------------------------------------
  # Canvas shape macros (block-form support)
  # ---------------------------------------------------------------------------

  @doc "Builds a rectangle shape. See `Plushie.Canvas.Shape.rect/5`."
  @canvas_shape_type_mapping %{stroke: Plushie.Canvas.Stroke}
  @canvas_option_keys ~w(width height background interactive on_press on_release on_move on_scroll alt description role arrow_mode event_rate a11y)a

  defmacro rect(x, y, w, h, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        pairs = interpret_block(block, @canvas_shape_type_mapping)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do:
                Plushie.Canvas.Shape.rect(
                  unquote(x),
                  unquote(y),
                  unquote(w),
                  unquote(h),
                  unquote(opts_ast)
                )

      opts ->
        quote do:
                Plushie.Canvas.Shape.rect(
                  unquote(x),
                  unquote(y),
                  unquote(w),
                  unquote(h),
                  unquote(opts)
                )
    end
  end

  @doc "Builds a circle shape. See `Plushie.Canvas.Shape.circle/4`."
  defmacro circle(x, y, r, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        pairs = interpret_block(block, @canvas_shape_type_mapping)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do:
                Plushie.Canvas.Shape.circle(unquote(x), unquote(y), unquote(r), unquote(opts_ast))

      opts ->
        quote do: Plushie.Canvas.Shape.circle(unquote(x), unquote(y), unquote(r), unquote(opts))
    end
  end

  @doc "Builds a line shape. See `Plushie.Canvas.Shape.line/5`."
  defmacro line(x1, y1, x2, y2, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        pairs = interpret_block(block, @canvas_shape_type_mapping)
        opts_ast = pairs_to_keyword_ast(pairs)

        quote do:
                Plushie.Canvas.Shape.line(
                  unquote(x1),
                  unquote(y1),
                  unquote(x2),
                  unquote(y2),
                  unquote(opts_ast)
                )

      opts ->
        quote do:
                Plushie.Canvas.Shape.line(
                  unquote(x1),
                  unquote(y1),
                  unquote(x2),
                  unquote(y2),
                  unquote(opts)
                )
    end
  end

  @doc "Builds a path shape. See `Plushie.Canvas.Shape.path/2`."
  defmacro path(commands, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        pairs = interpret_block(block, @canvas_shape_type_mapping)
        opts_ast = pairs_to_keyword_ast(pairs)
        quote do: Plushie.Canvas.Shape.path(unquote(commands), unquote(opts_ast))

      opts ->
        quote do: Plushie.Canvas.Shape.path(unquote(commands), unquote(opts))
    end
  end

  @doc "Builds a stroke descriptor. See `Plushie.Canvas.Shape.stroke/3`."
  defmacro stroke(color, width, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        pairs = interpret_block(block, %{dash: Plushie.Canvas.Dash})
        opts_ast = pairs_to_keyword_ast(pairs)
        quote do: Plushie.Canvas.Shape.stroke(unquote(color), unquote(width), unquote(opts_ast))

      opts ->
        quote do: Plushie.Canvas.Shape.stroke(unquote(color), unquote(width), unquote(opts))
    end
  end

  # ---------------------------------------------------------------------------
  # Canvas shape re-exports (no block form needed)
  # ---------------------------------------------------------------------------

  # Path commands
  defdelegate move_to(x, y), to: Plushie.Canvas.Shape
  defdelegate line_to(x, y), to: Plushie.Canvas.Shape
  defdelegate bezier_to(cp1x, cp1y, cp2x, cp2y, x, y), to: Plushie.Canvas.Shape
  defdelegate quadratic_to(cpx, cpy, x, y), to: Plushie.Canvas.Shape
  defdelegate arc(cx, cy, r, start_angle, end_angle), to: Plushie.Canvas.Shape
  defdelegate arc_to(x1, y1, x2, y2, radius), to: Plushie.Canvas.Shape
  defdelegate ellipse(cx, cy, rx, ry, rotation, start_angle, end_angle), to: Plushie.Canvas.Shape
  defdelegate rounded_rect(x, y, w, h, radius), to: Plushie.Canvas.Shape
  defdelegate close(), to: Plushie.Canvas.Shape

  # Transforms (used as directives inside group blocks)
  defdelegate translate(x, y), to: Plushie.Canvas.Shape
  defdelegate rotate(angle), to: Plushie.Canvas.Shape
  defdelegate scale(x, y), to: Plushie.Canvas.Shape
  defdelegate scale(factor), to: Plushie.Canvas.Shape

  # Clips (used as directive inside group blocks)
  defdelegate clip(x, y, w, h), to: Plushie.Canvas.Shape

  # Gradients
  defdelegate linear_gradient(from, to, stops), to: Plushie.Canvas.Shape

  # ---------------------------------------------------------------------------
  # Animation descriptors
  # ---------------------------------------------------------------------------

  @doc """
  Creates a timed transition descriptor for animated prop values.

  The renderer handles interpolation locally -- zero wire traffic
  during animation. Duration can be a positional argument or a
  keyword.

  ## Examples

      opacity: transition(300, to: 0.0)
      opacity: transition(300, to: 0.0, easing: :ease_out)
      opacity: transition(to: 0.0, duration: 300)

      # Enter animation
      opacity: transition(200, to: 1.0, from: 0.0)

      # Do-block
      opacity: transition 300 do
        to 0.0
        easing :ease_out
      end
  """
  defmacro transition(opts_or_do) do
    case opts_or_do do
      [do: block] ->
        option_keys = Plushie.Animation.Transition.__field_keys__()
        pairs = interpret_block(block)
        validate_option_keys!(pairs, option_keys, "transition", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)
        quote do: Plushie.UI.__build_transition__(unquote(opts_ast))

      opts ->
        quote do: Plushie.UI.__build_transition__(unquote(opts))
    end
  end

  defmacro transition(duration, opts_or_do) do
    case opts_or_do do
      [do: block] ->
        option_keys = Plushie.Animation.Transition.__field_keys__()
        pairs = interpret_block(block)
        validate_option_keys!(pairs, option_keys, "transition", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)
        quote do: Plushie.UI.__build_transition__(unquote(duration), unquote(opts_ast))

      opts ->
        quote do: Plushie.UI.__build_transition__(unquote(duration), unquote(opts))
    end
  end

  @doc """
  Creates a looping transition descriptor.

  Sets `repeat: :forever` and `auto_reverse: true` by default.
  Requires `from:` and `to:`.

  ## Examples

      opacity: loop(800, to: 0.4, from: 1.0)
      rotation: loop(1000, to: 360, from: 0, auto_reverse: false)
      opacity: loop(to: 0.4, from: 1.0, duration: 800, cycles: 3)
  """
  defmacro loop(opts_or_do) do
    case opts_or_do do
      [do: block] ->
        option_keys = Plushie.Animation.Transition.__field_keys__()
        pairs = interpret_block(block)
        validate_option_keys!(pairs, option_keys, "loop", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)
        quote do: Plushie.UI.__build_loop__(unquote(opts_ast))

      opts ->
        quote do: Plushie.UI.__build_loop__(unquote(opts))
    end
  end

  defmacro loop(duration, opts_or_do) do
    case opts_or_do do
      [do: block] ->
        option_keys = Plushie.Animation.Transition.__field_keys__()
        pairs = interpret_block(block)
        validate_option_keys!(pairs, option_keys, "loop", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)
        quote do: Plushie.UI.__build_loop__(unquote(duration), unquote(opts_ast))

      opts ->
        quote do: Plushie.UI.__build_loop__(unquote(duration), unquote(opts))
    end
  end

  @doc """
  Creates a physics-based spring descriptor.

  Springs have no fixed duration -- they settle naturally based
  on stiffness and damping.

  ## Examples

      scale: spring(to: 1.05, preset: :bouncy)
      scale: spring(to: 1.05, stiffness: 200, damping: 20)

      scale: spring do
        to 1.05
        preset :bouncy
      end
  """
  defmacro spring(opts_or_do) do
    case opts_or_do do
      [do: block] ->
        option_keys = Plushie.Animation.Spring.__field_keys__()
        pairs = interpret_block(block)
        validate_option_keys!(pairs, option_keys, "spring", __CALLER__)
        opts_ast = pairs_to_keyword_ast(pairs)
        quote do: Plushie.UI.__build_spring__(unquote(opts_ast))

      opts ->
        quote do: Plushie.UI.__build_spring__(unquote(opts))
    end
  end

  @doc """
  Creates a sequential animation chain.

  Steps execute one after another on the same prop. Accepts a
  list of transition/spring descriptors.

  ## Examples

      opacity: sequence([
        transition(200, to: 1.0, from: 0.0),
        loop(800, to: 0.7, from: 1.0, cycles: 3),
        transition(300, to: 0.0)
      ])

      opacity: sequence do
        transition(200, to: 1.0, from: 0.0)
        transition(300, to: 0.0)
      end
  """
  defmacro sequence(list_or_do) do
    case list_or_do do
      [do: {:__block__, _, exprs}] ->
        quote do: Plushie.UI.__build_sequence__(unquote(exprs))

      [do: single_expr] ->
        quote do: Plushie.UI.__build_sequence__([unquote(single_expr)])

      list ->
        quote do: Plushie.UI.__build_sequence__(unquote(list))
    end
  end

  @doc false
  def __build_transition__(opts), do: Plushie.Animation.Transition.new(opts)

  @doc false
  def __build_transition__(duration, opts),
    do: Plushie.Animation.Transition.new(duration, opts)

  @doc false
  def __build_loop__(opts), do: Plushie.Animation.Transition.loop(opts)

  @doc false
  def __build_loop__(duration, opts), do: Plushie.Animation.Transition.loop(duration, opts)

  @doc false
  def __build_spring__(opts), do: Plushie.Animation.Spring.new(opts)

  @doc false
  def __build_sequence__(steps), do: Plushie.Animation.Sequence.new(steps)

  # ---------------------------------------------------------------------------
  # QR Code (function -- no children)
  # ---------------------------------------------------------------------------

  @doc false
  @spec __build_qr_code__(String.t(), String.t(), keyword()) ::
          Plushie.Widget.ui_node()
  def __build_qr_code__(id, data, opts) do
    Plushie.Widget.QrCode.new(id, data, clean_opts(opts))
    |> Plushie.Widget.QrCode.build()
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @reserved_keys [:children, :id, :do]

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

  @canvas_transform_calls ~w(translate rotate scale clip)a

  defp clean_opts(opts), do: Keyword.drop(opts, @reserved_keys)

  defp normalize_range({min, max}), do: {min, max}
  defp normalize_range(first..last//_), do: {first, last}

  # ---------------------------------------------------------------------------
  # Private macro helpers
  # ---------------------------------------------------------------------------

  defp block_to_exprs({:__block__, _, exprs}), do: exprs
  defp block_to_exprs(single_expr), do: [single_expr]

  # Builds an AST that evaluates expressions sequentially (preserving
  # variable scope between them) and collects results into a list.
  # This replaces [unquote_splicing(exprs)] which breaks variable bindings
  # because list literal elements don't share scope in Elixir macros.
  defp build_list_accumulator(exprs) do
    var = Macro.var(:__canvas_acc__, __MODULE__)

    init = quote do: unquote(var) = []

    steps =
      Enum.map(exprs, fn expr ->
        quote do: unquote(var) = [unquote(expr) | unquote(var)]
      end)

    {:__block__, [], [init | steps] ++ [var]}
  end

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
    if name in option_keys do
      quote_prop_tuple(name, true, meta)
    else
      if Map.has_key?(@all_container_option_owners, name) do
        owners = Map.get(@all_container_option_owners, name, [])
        container_scope_error!(meta, name, widget_name, owners)
      else
        node
      end
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
    if name in option_keys do
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
          quote_prop_tuple(name, value, meta)

        _ ->
          node
      end
    else
      if length(args) == 1 and Map.has_key?(@all_container_option_owners, name) do
        owners = Map.get(@all_container_option_owners, name, [])
        container_scope_error!(meta, name, widget_name, owners)
      else
        node
      end
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

  # Entry point: walk a block AST with context and caller module
  defp canvas_scope({:__block__, meta, exprs}, context, caller_mod) do
    {:__block__, meta, Enum.map(exprs, &canvas_scope(&1, context, caller_mod))}
  end

  defp canvas_scope(expr, _context, _caller_mod) when not is_tuple(expr), do: expr
  defp canvas_scope(expr, _context, _caller_mod) when tuple_size(expr) != 3, do: expr

  # Fully qualified calls -- skip
  defp canvas_scope({{:., _, _}, _, _} = node, _context, _caller_mod), do: node

  # --- Canvas container calls (don't recurse into their blocks) ---

  # layer: valid in :canvas only
  defp canvas_scope({:layer, _, _} = node, :canvas, _caller_mod), do: node

  defp canvas_scope({:layer, meta, _}, _ctx, _caller_mod) do
    canvas_scope_error!(meta, "layer is not valid here. Layers belong inside a canvas block.")
  end

  # group: valid in :layer and :group. Recurse into do-block so
  # the dynamic/static context is properly threaded. Inject auto-ID
  # for the group itself when no explicit string ID is provided.
  defp canvas_scope({:group, meta, args} = node, ctx, caller_mod)
       when ctx in [:layer, :group] do
    # Recurse into the group's do-block (if present) so the
    # dynamic context from an outer for/fn propagates into the
    # group's children.
    processed = canvas_scope_recurse_into_container(node, meta, args, :group, caller_mod)

    if canvas_scope_group_has_explicit_id?(processed) do
      processed
    else
      canvas_scope_inject_auto_id(processed, meta, caller_mod)
    end
  end

  defp canvas_scope({:group, meta, _}, :canvas, _caller_mod) do
    canvas_scope_error!(meta, """
    group is not valid here. Put groups inside a layer:

        layer "main" do
          group do
            ...
          end
        end
    """)
  end

  # interactive: valid in :layer and :group. Recurse into do-block.
  defp canvas_scope({:interactive, meta, args} = node, ctx, caller_mod)
       when ctx in [:layer, :group] do
    canvas_scope_recurse_into_container(node, meta, args, :group, caller_mod)
  end

  defp canvas_scope({:interactive, meta, _}, :canvas, _caller_mod) do
    canvas_scope_error!(meta, """
    interactive is not valid here. Put interactive elements inside a layer:

        layer "main" do
          interactive "btn", on_click: true do
            ...
          end
        end
    """)
  end

  # --- Ambiguous name rewrites (text, image, svg) ---

  # text/1,2: always error in canvas context
  defp canvas_scope({:text, meta, args}, _ctx, _caller_mod)
       when is_list(args) and length(args) in [1, 2] do
    canvas_scope_error!(meta, """
    text/#{length(args)} is not valid here. Expected:

        text(x, y, "content")
        text(x, y, "content", fill: "#000")
    """)
  end

  # text/3+: rewrite to Shape.__build_text__ in :layer/:group, error in :canvas
  defp canvas_scope({:text, meta, args}, ctx, caller_mod)
       when is_list(args) and length(args) >= 3 do
    if ctx == :canvas do
      canvas_scope_error!(meta, """
      text is not valid here. Shapes go inside layers:

          layer "main" do
            text(10, 20, "Hello", fill: "#000")
          end
      """)
    else
      args = canvas_scope_rewrite_do_block(args)
      rewritten = {{:., meta, [Plushie.Canvas.Shape, :__build_text__]}, meta, args}
      canvas_scope_inject_auto_id(rewritten, meta, caller_mod)
    end
  end

  # image/1,2,3: always error in canvas context
  defp canvas_scope({:image, meta, args}, _ctx, _caller_mod)
       when is_list(args) and length(args) in [1, 2, 3] do
    canvas_scope_error!(meta, """
    image/#{length(args)} is not valid here. Expected:

        image("source", x, y, w, h)
        image("source", x, y, w, h, rotation: 0.5)
    """)
  end

  # image/5+: rewrite in :layer/:group, error in :canvas
  defp canvas_scope({:image, meta, args}, ctx, caller_mod)
       when is_list(args) and length(args) >= 5 do
    if ctx == :canvas do
      canvas_scope_error!(meta, """
      image is not valid here. Shapes go inside layers:

          layer "main" do
            image("source", x, y, w, h)
          end
      """)
    else
      args = canvas_scope_rewrite_do_block(args)
      rewritten = {{:., meta, [Plushie.Canvas.Shape, :__build_image__]}, meta, args}
      canvas_scope_inject_auto_id(rewritten, meta, caller_mod)
    end
  end

  # svg/1,2,3: always error in canvas context
  defp canvas_scope({:svg, meta, args}, _ctx, _caller_mod)
       when is_list(args) and length(args) in [1, 2, 3] do
    canvas_scope_error!(meta, """
    svg/#{length(args)} is not valid here. Expected:

        svg("source", x, y, w, h)
    """)
  end

  # svg/5+: rewrite in :layer/:group, error in :canvas
  defp canvas_scope({:svg, meta, args}, ctx, caller_mod)
       when is_list(args) and length(args) >= 5 do
    if ctx == :canvas do
      canvas_scope_error!(meta, """
      svg is not valid here. Shapes go inside layers:

          layer "main" do
            svg("source", x, y, w, h)
          end
      """)
    else
      args = canvas_scope_rewrite_do_block(args)
      rewritten = {{:., meta, [Plushie.Canvas.Shape, :__build_svg__]}, meta, args}
      canvas_scope_inject_auto_id(rewritten, meta, caller_mod)
    end
  end

  # --- Shape calls (rect, circle, line, path) ---

  defp canvas_scope({name, meta, _} = node, ctx, caller_mod)
       when is_atom(name) and name in @canvas_shape_calls do
    case ctx do
      :canvas ->
        canvas_scope_error!(meta, """
        #{name} is not valid here. Shapes go inside layers:

            layer "main" do
              #{name}(...)
            end
        """)

      _other ->
        canvas_scope_inject_auto_id(node, meta, caller_mod)
    end
  end

  # --- Transform/clip calls ---

  defp canvas_scope({name, meta, _} = node, ctx, _caller_mod)
       when is_atom(name) and name in @canvas_transform_calls do
    case ctx do
      :canvas ->
        canvas_scope_error!(meta, """
        #{name} is not valid here. Transforms go inside layers:

            layer "main" do
              #{name}(...)
            end
        """)

      :group ->
        # In group context, wrap transform/clip calls as canvas metadata
        # tuples so __build_group__ can collect them into the transforms
        # list or clip field (instead of treating them as child shapes).
        tag = if name == :clip, do: :clip, else: :transform

        quote do
          {:__canvas_meta__, unquote(tag), unquote(node)}
        end

      _other ->
        canvas_scope_error!(meta, """
        #{name} must be inside a group block, not directly in a layer. \
        Wrap your shapes in a group to apply transforms.
        """)
    end
  end

  # --- Widget calls (always error in canvas context) ---

  defp canvas_scope({name, meta, args}, _ctx, _caller_mod)
       when is_atom(name) and is_list(args) and name in @widget_calls do
    canvas_scope_error!(meta, """
    #{name} is not valid here. Expected canvas shapes:
    rect, circle, line, text, path, image, svg, group, interactive
    """)
  end

  # --- Control flow: recurse into bodies ---

  defp canvas_scope({:for, meta, args}, ctx, _caller_mod) do
    # for comprehension bodies are dynamic: the same line-based
    # auto-ID would repeat on each iteration. Use :dynamic to
    # suppress auto-ID injection and let the runtime fallback
    # assign unique positional IDs.
    {:for, meta, canvas_scope_for_args(args, ctx, :dynamic)}
  end

  defp canvas_scope({:if, meta, [condition, clauses]}, ctx, caller_mod) do
    {:if, meta, [condition, canvas_scope_clauses(clauses, ctx, caller_mod)]}
  end

  defp canvas_scope({:unless, meta, [condition, clauses]}, ctx, caller_mod) do
    {:unless, meta, [condition, canvas_scope_clauses(clauses, ctx, caller_mod)]}
  end

  defp canvas_scope({:case, meta, [subject, [do: clauses]]}, ctx, caller_mod) do
    {:case, meta, [subject, [do: canvas_scope_match_clauses(clauses, ctx, caller_mod)]]}
  end

  defp canvas_scope({:cond, meta, [[do: clauses]]}, ctx, caller_mod) do
    {:cond, meta, [[do: canvas_scope_match_clauses(clauses, ctx, caller_mod)]]}
  end

  defp canvas_scope({:with, meta, args}, ctx, caller_mod) do
    {:with, meta, canvas_scope_with_args(args, ctx, caller_mod)}
  end

  defp canvas_scope({:fn, meta, clauses}, ctx, _caller_mod) do
    # fn closures are dynamic: same line-based auto-ID would repeat
    # on each invocation. Suppress auto-ID injection.
    {:fn, meta, canvas_scope_match_clauses(clauses, ctx, :dynamic)}
  end

  # --- Canvas inline option declarations (width, height, background, etc.) ---
  defp canvas_scope({name, _meta, [_value]} = node, :canvas, _caller_mod)
       when is_atom(name) and name in @canvas_option_keys do
    quote_prop_tuple(name, elem(node, 2) |> hd(), elem(node, 1))
  end

  defp canvas_scope({name, _meta, nil} = node, :canvas, _caller_mod)
       when is_atom(name) and name in @canvas_option_keys do
    quote_prop_tuple(name, true, elem(node, 1))
  end

  # --- Default: pass through ---
  defp canvas_scope(other, _ctx, _caller_mod), do: other

  # --- Helper functions ---

  # Recurse into the do-block of a group/interactive call so the
  # caller_mod (including :dynamic) propagates through nested shapes.
  # Returns the node with the do-block processed.
  defp canvas_scope_recurse_into_container(
         {name, meta, args},
         _meta,
         _args,
         scope_ctx,
         caller_mod
       )
       when is_list(args) do
    processed_args = canvas_scope_process_do_in_args(args, scope_ctx, caller_mod)
    {name, meta, processed_args}
  end

  # Walk the args list, find the keyword entry with :do, and
  # recursively process the block inside it.
  defp canvas_scope_process_do_in_args(args, scope_ctx, caller_mod) do
    Enum.map(args, fn
      [{:do, block}] ->
        [{:do, canvas_scope(block, scope_ctx, caller_mod)}]

      kw when is_list(kw) ->
        Enum.map(kw, fn
          {:do, block} -> {:do, canvas_scope(block, scope_ctx, caller_mod)}
          other -> other
        end)

      other ->
        other
    end)
  end

  # Checks whether a group AST node has an explicit string ID.
  # group "my-id" do ... end  -> true
  # group do ... end          -> false
  # group x: 10 do ... end    -> false
  defp canvas_scope_group_has_explicit_id?({:group, _, args}) when is_list(args) do
    case args do
      # group("id", ...) or group("id", opts, do: ...)
      [first | _] when is_binary(first) -> true
      _ -> false
    end
  end

  defp canvas_scope_group_has_explicit_id?(_), do: false

  # Wraps a shape call AST node to inject a compile-time auto-ID.
  # Produces: %{shape_expr | id: "auto:Module:42"}
  #
  # Inside dynamic contexts (for loops, fn closures), caller_mod is
  # :dynamic and auto-IDs are skipped. The runtime fallback in
  # children_to_nodes assigns positional IDs for shapes without
  # compile-time IDs.
  defp canvas_scope_inject_auto_id(node, _meta, :dynamic), do: node

  defp canvas_scope_inject_auto_id(node, meta, caller_mod) do
    line = Keyword.get(meta, :line, 0)
    auto_id = compile_auto_id(caller_mod, line)
    {:%{}, meta, [{:|, [], [node, [id: auto_id]]}]}
  end

  defp canvas_scope_error!(meta, message) do
    raise CompileError,
      line: Keyword.get(meta, :line, 0),
      description: String.trim(message)
  end

  # Rewrite [do: block] in the last arg to interpreted opts
  defp canvas_scope_rewrite_do_block(args) do
    case List.last(args) do
      [{:do, block}] ->
        pairs = interpret_block(block, @canvas_shape_type_mapping)
        opts_ast = pairs_to_keyword_ast(pairs)
        List.replace_at(args, -1, opts_ast)

      _ ->
        args
    end
  end

  # For comprehension: recurse into the do/else bodies
  defp canvas_scope_for_args(args, ctx, caller_mod) do
    Enum.map(args, fn
      {:do, body} -> {:do, wrap_block_in_list(canvas_scope(body, ctx, caller_mod))}
      {:else, body} -> {:else, wrap_block_in_list(canvas_scope(body, ctx, caller_mod))}
      other -> other
    end)
  end

  # if/unless clauses
  defp canvas_scope_clauses(clauses, ctx, caller_mod) do
    Enum.map(clauses, fn
      {:do, body} -> {:do, wrap_block_in_list(canvas_scope(body, ctx, caller_mod))}
      {:else, body} -> {:else, wrap_block_in_list(canvas_scope(body, ctx, caller_mod))}
      other -> other
    end)
  end

  # case/cond/fn clauses (list of {:->, meta, [pattern, body]})
  defp canvas_scope_match_clauses(clauses, ctx, caller_mod) do
    Enum.map(clauses, fn
      {:->, meta, [pattern, body]} ->
        {:->, meta, [pattern, wrap_block_in_list(canvas_scope(body, ctx, caller_mod))]}

      other ->
        other
    end)
  end

  # with args: generators + do/else
  defp canvas_scope_with_args(args, ctx, caller_mod) do
    Enum.map(args, fn
      {:do, body} -> {:do, wrap_block_in_list(canvas_scope(body, ctx, caller_mod))}
      {:else, clauses} -> {:else, canvas_scope_match_clauses(clauses, ctx, caller_mod)}
      other -> other
    end)
  end
end
