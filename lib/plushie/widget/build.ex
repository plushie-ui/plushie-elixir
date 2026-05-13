defmodule Plushie.Widget.Build do
  @moduledoc "Internal helpers for widget `to_node/1` implementations."

  @doc "Adds `key => value` to props if value is not nil."
  @spec put_if(props :: map(), value :: term(), key :: atom()) :: map()
  def put_if(props, nil, _key), do: props
  def put_if(props, value, key), do: Map.put(props, key, value)

  @doc "Adds `key => transform.(value)` to props if value is not nil."
  @spec put_if(
          props :: map(),
          value :: term(),
          key :: atom(),
          transform :: (term() -> term())
        ) ::
          map()
  def put_if(props, nil, _key, _transform), do: props
  def put_if(props, value, key, transform), do: Map.put(props, key, transform.(value))

  @doc """
  Casts a color value, passing animation descriptors through unchanged.

  Used by generated `to_node/1` code for Color-typed fields where struct
  defaults bypass setters. Animation descriptors need to reach
  Tree.normalize intact for encoding via `encode_value/1`.
  """
  @spec cast_color_or_passthrough(term()) :: term()
  def cast_color_or_passthrough(val) do
    if animation_descriptor?(val) do
      val
    else
      case Plushie.Type.Color.cast(val) do
        {:ok, casted} ->
          casted

        :error ->
          raise ArgumentError, "invalid color value: #{inspect(val)}"
      end
    end
  end

  @doc "Converts a child element to a ui_node() map if it's a widget struct."
  @spec to_node(child :: Plushie.Widget.child()) :: Plushie.Widget.ui_node()
  def to_node(%{id: _, type: _, props: _, children: _} = node), do: node
  def to_node(%_module{} = widget), do: Plushie.Widget.to_node(widget)

  @doc "Converts a list of children (ui_node maps or widget structs) to ui_node() maps."
  @spec children_to_nodes(children :: [Plushie.Widget.child()]) :: [
          Plushie.Widget.ui_node()
        ]
  def children_to_nodes(children), do: Enum.map(children, &to_node/1)

  @doc """
  Returns true if the value is an animation descriptor (Transition,
  Spring, or Sequence).
  """
  @spec animation_descriptor?(term()) :: boolean()
  def animation_descriptor?(%Plushie.Animation.Transition{}), do: true
  def animation_descriptor?(%Plushie.Animation.Spring{}), do: true
  def animation_descriptor?(%Plushie.Animation.Sequence{}), do: true
  def animation_descriptor?(_), do: false

  @doc """
  Wraps a widget build pipeline with exit animation handling.

  Animation descriptors (Transition, Spring, Sequence) on regular fields
  go through widget setters which validate the target values. The `exit:`
  prop is special (not a per-field setter), so it is extracted here and
  merged onto the node's props after the build function runs.

      Build.build_node(opts, fn widget_opts ->
        Button.new(id, label, widget_opts) |> Button.build()
      end)
  """
  @spec build_node(opts :: keyword(), build_fn :: (keyword() -> Plushie.Widget.ui_node())) ::
          Plushie.Widget.ui_node()
  def build_node(opts, build_fn) when is_list(opts) and is_function(build_fn, 1) do
    {exit_opts, widget_opts} =
      Keyword.split_with(opts, fn
        {:exit, _} -> true
        _ -> false
      end)

    node = build_fn.(widget_opts)

    if exit_opts == [] do
      node
    else
      # Convert exit keyword list to map for correct wire encoding.
      # Without this, exit: [max_width: transition(...)] encodes as
      # nested arrays instead of a map.
      exit_map =
        case Keyword.get(exit_opts, :exit) do
          exits when is_list(exits) -> Map.new(exits)
          other -> other
        end

      %{node | props: Map.put(node.props, :exit, exit_map)}
    end
  end

  @doc """
  Validates that an animation descriptor's `to` and `from` values are
  valid for the given field type.

  Called by generated animation setter clauses. Raises `ArgumentError`
  if validation fails. Skips validation for `:any` typed fields.
  """
  @spec validate_animation_target!(
          descriptor :: term(),
          field_type :: term(),
          field_name :: atom()
        ) ::
          :ok
  def validate_animation_target!(descriptor, field_type, field_name) do
    resolved = Plushie.Type.resolve(field_type)

    # :any accepts everything, skip validation
    if resolved == Plushie.Type.Any do
      :ok
    else
      validate_animation_to!(descriptor, field_type, field_name)
      validate_animation_from!(descriptor, field_type, field_name)
    end
  end

  defp validate_animation_to!(descriptor, field_type, field_name) do
    to = animation_to(descriptor)

    if to != nil do
      case Plushie.Type.cast_value(field_type, to) do
        {:ok, _} ->
          :ok

        :error ->
          type_str = Plushie.Type.type_display_string(field_type)

          raise ArgumentError,
                "animation target for :#{field_name} must be a valid #{type_str}, got: #{inspect(to)}"
      end
    end
  end

  defp validate_animation_from!(descriptor, field_type, field_name) do
    from = animation_from(descriptor)

    if from != nil do
      case Plushie.Type.cast_value(field_type, from) do
        {:ok, _} ->
          :ok

        :error ->
          type_str = Plushie.Type.type_display_string(field_type)

          raise ArgumentError,
                "animation :from for :#{field_name} must be a valid #{type_str}, got: #{inspect(from)}"
      end
    end
  end

  defp animation_to(%Plushie.Animation.Transition{to: to}), do: to
  defp animation_to(%Plushie.Animation.Spring{to: to}), do: to

  defp animation_to(%Plushie.Animation.Sequence{steps: [first | _]}),
    do: animation_to(first)

  defp animation_to(%Plushie.Animation.Sequence{steps: []}), do: nil

  defp animation_from(%Plushie.Animation.Transition{from: from}), do: from
  defp animation_from(%Plushie.Animation.Spring{from: from}), do: from
  defp animation_from(%Plushie.Animation.Sequence{}), do: nil

  @doc "Raises ArgumentError for an unknown option key passed to a widget constructor."
  @spec unknown_option!(module :: module(), key :: term()) :: no_return()
  def unknown_option!(module, key) do
    name = module |> Module.split() |> List.last()
    raise ArgumentError, "unknown option #{inspect(key)} for #{name}.new"
  end

  @doc """
  Validates that a widget has at most one child.

  Raises `ArgumentError` if the children list has more than one element.
  The error message includes the widget type and ID for easy diagnosis:

      ** (ArgumentError) container "sidebar" accepts at most 1 child, got 3

  Called at the top of `to_node/1` for single-child wrappers (container,
  tooltip, pointer_area, scrollable, themer, floating, responsive, pin,
  sensor, window).
  """
  @spec validate_single_child!(
          id :: String.t(),
          type :: String.t(),
          children :: [Plushie.Widget.child()]
        ) :: :ok
  def validate_single_child!(_id, _type, []), do: :ok
  def validate_single_child!(_id, _type, [_]), do: :ok

  def validate_single_child!(id, type, children) do
    raise ArgumentError,
          "#{type} #{inspect(id)} accepts at most 1 child, got #{length(children)}"
  end

  @doc """
  Validates that a widget has exactly the expected number of children.

  Raises `ArgumentError` if the children count does not match `expected`.
  The error message includes the widget type, ID, and both the expected
  and actual counts:

      ** (ArgumentError) overlay "popup" requires exactly 2 children, got 1

  Called at the top of `to_node/1` for widgets with strict child count
  requirements (overlay).
  """
  @spec validate_children_count!(
          id :: String.t(),
          type :: String.t(),
          children :: [Plushie.Widget.child()],
          expected :: pos_integer()
        ) :: :ok
  def validate_children_count!(_id, _type, children, expected)
      when length(children) == expected,
      do: :ok

  def validate_children_count!(id, type, children, expected) do
    raise ArgumentError,
          "#{type} #{inspect(id)} requires exactly #{expected} children, got #{length(children)}"
  end

  @doc """
  Resolves a11y derived values from the widget's props.

  If the a11y prop has a `label_from` directive, the referenced prop's
  value is used as the accessible label. Called during to_node after
  all props are set.
  """
  @spec resolve_a11y(props :: map()) :: map()
  def resolve_a11y(%{a11y: %Plushie.Type.A11y{} = a11y} = props) do
    resolved = Plushie.Type.A11y.resolve(a11y, props)
    Map.put(props, :a11y, resolved)
  end

  def resolve_a11y(props), do: props
end
