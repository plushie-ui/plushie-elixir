defmodule Julep.Test.Backend.RendererBase do
  @moduledoc """
  Shared implementation for renderer-backed test backends (headless, full).

  Provides the `__using__` macro that injects all 20 backend callbacks,
  GenServer plumbing, response handling, event dispatching, and wire helpers.
  Backends configure themselves via opts and override `init/1`, `port_args/1`,
  `resolve_renderer_path/0`, and `screenshot_payload/2`.
  """

  # The entire module is one macro -- the long quote block is intentional.
  # credo:disable-for-this-file Credo.Check.Refactor.LongQuoteBlocks

  defmacro __using__(opts) do
    quote do
      @behaviour Julep.Test.Backend

      use GenServer

      require Logger

      # Event decoding is handled by Julep.Test.Backend.EventDecoder.
      alias Julep.Test.Backend.CommandProcessor
      alias Julep.Test.Element
      alias Julep.Test.Screenshot
      alias Julep.Test.Snapshot

      @call_timeout unquote(opts[:call_timeout] || 10_000)

      # -- Backend callbacks --

      @impl Julep.Test.Backend
      def start(app, opts \\ []) do
        GenServer.start(__MODULE__, {app, opts})
      end

      @impl Julep.Test.Backend
      def stop(pid), do: GenServer.stop(pid)

      @impl Julep.Test.Backend
      def find(pid, selector), do: GenServer.call(pid, {:find, selector}, @call_timeout)

      @impl Julep.Test.Backend
      def find!(pid, selector) do
        case find(pid, selector) do
          nil -> raise "Element not found: #{inspect(selector)}"
          element -> element
        end
      end

      @impl Julep.Test.Backend
      def click(pid, selector) do
        GenServer.call(pid, {:interact, "click", selector, %{}}, @call_timeout)
      end

      @impl Julep.Test.Backend
      def type_text(pid, selector, text) do
        GenServer.call(pid, {:interact, "type_text", selector, %{"text" => text}}, @call_timeout)
      end

      @impl Julep.Test.Backend
      def submit(pid, selector) do
        GenServer.call(pid, {:interact, "submit", selector, %{}}, @call_timeout)
      end

      @impl Julep.Test.Backend
      def toggle(pid, selector) do
        GenServer.call(pid, {:interact, "toggle", selector, %{}}, @call_timeout)
      end

      @impl Julep.Test.Backend
      def select(pid, selector, value) do
        GenServer.call(pid, {:interact, "select", selector, %{"value" => value}}, @call_timeout)
      end

      @impl Julep.Test.Backend
      def slide(pid, selector, value) do
        GenServer.call(pid, {:interact, "slide", selector, %{"value" => value}}, @call_timeout)
      end

      @impl Julep.Test.Backend
      def model(pid), do: GenServer.call(pid, :model)

      @impl Julep.Test.Backend
      def tree(pid), do: GenServer.call(pid, :tree, @call_timeout)

      @impl Julep.Test.Backend
      def snapshot(pid, name), do: GenServer.call(pid, {:snapshot, name}, 30_000)

      @impl Julep.Test.Backend
      def screenshot(pid, name), do: GenServer.call(pid, {:screenshot, name}, 30_000)

      @impl Julep.Test.Backend
      def reset(pid), do: GenServer.call(pid, :reset, @call_timeout)

      @impl Julep.Test.Backend
      def await_async(_pid, _tag, _timeout \\ 5000), do: :ok

      @impl Julep.Test.Backend
      def press(pid, key) do
        GenServer.call(pid, {:interact, "press", nil, %{"key" => key}}, @call_timeout)
      end

      @impl Julep.Test.Backend
      def release(pid, key) do
        GenServer.call(pid, {:interact, "release", nil, %{"key" => key}}, @call_timeout)
      end

      @impl Julep.Test.Backend
      def move_to(pid, x, y) do
        GenServer.call(pid, {:interact, "move_to", nil, %{"x" => x, "y" => y}}, @call_timeout)
      end

      @impl Julep.Test.Backend
      def type_key(pid, key) do
        GenServer.call(pid, {:interact, "type_key", nil, %{"key" => key}}, @call_timeout)
      end

      # -- GenServer callbacks --

      @impl GenServer
      def terminate(_reason, state) do
        if state.port && Port.info(state.port) != nil, do: Port.close(state.port)
        :ok
      end

      @impl GenServer
      def handle_call(msg, from, state), do: do_handle_call(msg, from, state)

      @impl GenServer
      # JSON mode: line-buffered data
      def handle_info({port, {:data, {:eol, line}}}, %{port: port, format: :json} = state) do
        full_line = state.buffer <> line
        state = %{state | buffer: ""}

        case Julep.Protocol.decode(full_line, :json) do
          {:ok, response} ->
            {:noreply, handle_response(response, state)}

          {:error, _} ->
            {:noreply, state}
        end
      end

      def handle_info({port, {:data, {:noeol, chunk}}}, %{port: port, format: :json} = state) do
        {:noreply, %{state | buffer: state.buffer <> chunk}}
      end

      # MsgPack mode: complete framed messages from {:packet, 4}
      def handle_info({port, {:data, binary}}, %{port: port, format: :msgpack} = state)
          when is_binary(binary) do
        case Julep.Protocol.decode(binary, :msgpack) do
          {:ok, response} ->
            {:noreply, handle_response(response, state)}

          {:error, _} ->
            {:noreply, state}
        end
      end

      def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
        for {_id, pending} <- state.pending do
          case pending do
            {_type, from} -> GenServer.reply(from, {:error, {:renderer_exited, code}})
            {_type, from, _extra} -> GenServer.reply(from, {:error, {:renderer_exited, code}})
          end
        end

        {:stop, {:renderer_exited, code}, state}
      end

      def handle_info(_msg, state), do: {:noreply, state}

      # -- Call handlers --

      defp do_handle_call({:find, selector}, from, state) do
        {id, state} = next_id(state)
        sel = encode_selector(selector)

        send_message(state.port, state.format, %{
          type: "query",
          id: id,
          target: "find",
          selector: sel
        })

        {:noreply, put_in(state, [:pending, id], {:find, from})}
      end

      defp do_handle_call(:tree, from, state) do
        {id, state} = next_id(state)

        send_message(state.port, state.format, %{
          type: "query",
          id: id,
          target: "tree",
          selector: %{}
        })

        {:noreply, put_in(state, [:pending, id], {:tree, from})}
      end

      defp do_handle_call({:interact, action, selector, payload}, from, state) do
        {id, state} = next_id(state)
        sel = encode_selector(selector)

        send_message(state.port, state.format, %{
          type: "interact",
          id: id,
          action: action,
          selector: sel,
          payload: payload
        })

        {:noreply, put_in(state, [:pending, id], {:interact, from, action})}
      end

      defp do_handle_call({:snapshot, name}, from, state) do
        {id, state} = next_id(state)

        send_message(state.port, state.format, %{
          type: "snapshot_capture",
          id: id,
          name: name,
          theme: %{},
          viewport: %{}
        })

        {:noreply, put_in(state, [:pending, id], {:snapshot, from, name})}
      end

      defp do_handle_call({:screenshot, name}, from, state) do
        {id, state} = next_id(state)

        msg = Map.put(screenshot_payload(name), :id, id)
        send_message(state.port, state.format, msg)

        {:noreply, put_in(state, [:pending, id], {:screenshot, from, name})}
      end

      defp do_handle_call(:model, _from, state) do
        {:reply, state.model, state}
      end

      defp do_handle_call(:reset, from, state) do
        {id, state} = next_id(state)
        send_message(state.port, state.format, %{type: "reset", id: id})

        {model, commands} = init_app(state.app, state.opts)
        model = CommandProcessor.process(state.app, model, commands)
        tree = render_tree(state.app, model)
        send_message(state.port, state.format, %{type: "snapshot", tree: tree})

        {:noreply, put_in(%{state | model: model, tree: tree}, [:pending, id], {:reset, from})}
      end

      # -- Response handling --

      defp handle_response(%{"type" => "query_response", "id" => id} = resp, state) do
        case Map.pop(state.pending, id) do
          {nil, _} ->
            state

          {{:find, from}, pending} ->
            element =
              case resp["data"] do
                nil -> nil
                data when data == %{} -> nil
                data -> Element.from_node(data)
              end

            GenServer.reply(from, element)
            %{state | pending: pending}

          {{:tree, from}, pending} ->
            GenServer.reply(from, resp["data"])
            %{state | pending: pending}
        end
      end

      defp handle_response(%{"type" => "interact_response", "id" => id} = resp, state) do
        case Map.pop(state.pending, id) do
          {nil, _} ->
            state

          {{:interact, from, _action}, pending} ->
            state = dispatch_events(resp["events"] || [], state)
            GenServer.reply(from, :ok)
            %{state | pending: pending}
        end
      end

      defp handle_response(%{"type" => "snapshot_response", "id" => id} = resp, state) do
        case Map.pop(state.pending, id) do
          {nil, _} ->
            state

          {{:snapshot, from, _name}, pending} ->
            snapshot = %Snapshot{
              name: resp["name"],
              hash: resp["hash"],
              size: {resp["width"] || 0, resp["height"] || 0}
            }

            GenServer.reply(from, snapshot)
            %{state | pending: pending}
        end
      end

      defp handle_response(%{"type" => "screenshot_response", "id" => id} = resp, state) do
        case Map.pop(state.pending, id) do
          {nil, _} ->
            state

          {{:screenshot, from, _name}, pending} ->
            screenshot = %Screenshot{
              name: resp["name"],
              hash: resp["hash"] || "",
              size: {resp["width"] || 0, resp["height"] || 0},
              rgba_data: extract_rgba(resp)
            }

            GenServer.reply(from, screenshot)
            %{state | pending: pending}
        end
      end

      defp handle_response(%{"type" => "reset_response", "id" => id}, state) do
        case Map.pop(state.pending, id) do
          {nil, _} ->
            state

          {{:reset, from}, pending} ->
            GenServer.reply(from, :ok)
            %{state | pending: pending}
        end
      end

      defp handle_response(%{"type" => "event"} = event, state) do
        dispatch_event(event, state)
      end

      defp handle_response(_unknown, state), do: state

      # -- Event dispatching --

      defp dispatch_events(events, state) do
        Enum.reduce(events, state, fn event, acc -> dispatch_event(event, acc) end)
      end

      defp dispatch_event(%{"family" => type, "id" => id} = event, state) do
        elixir_event = Julep.Test.Backend.EventDecoder.decode(type, id, event)

        {model, commands} =
          CommandProcessor.dispatch_update(state.app, state.model, elixir_event)

        model = CommandProcessor.process(state.app, model, commands)

        tree = render_tree(state.app, model)
        send_message(state.port, state.format, %{type: "snapshot", tree: tree})

        %{state | model: model, tree: tree}
      end

      defp dispatch_event(_event, state), do: state

      # -- Helpers --

      defp init_app(app, opts) do
        case app.init(opts) do
          {model, commands} when is_list(commands) -> {model, commands}
          {model, %Julep.Command{} = cmd} -> {model, [cmd]}
          model -> {model, []}
        end
      end

      defp render_tree(app, model) do
        app.view(model) |> Julep.Tree.normalize()
      end

      defp next_id(state) do
        id = "req_#{state.next_id}"
        {id, %{state | next_id: state.next_id + 1}}
      end

      defp encode_selector(nil), do: %{}
      defp encode_selector("#" <> id), do: %{"by" => "id", "value" => id}

      defp encode_selector({:role, role}) when is_binary(role),
        do: %{"by" => "role", "value" => role}

      defp encode_selector({:label, label}) when is_binary(label),
        do: %{"by" => "label", "value" => label}

      defp encode_selector(:focused), do: %{"by" => "focused"}
      defp encode_selector(text) when is_binary(text), do: %{"by" => "text", "value" => text}

      defp send_message(port, format, msg) do
        data = Julep.Protocol.encode(msg, format)
        Port.command(port, data)
      end

      defp extract_rgba(%{"rgba" => rgba}) when is_binary(rgba), do: rgba
      defp extract_rgba(%{"rgba_base64" => b64}) when is_binary(b64), do: Base.decode64!(b64)
      defp extract_rgba(_), do: nil

      # Port options based on wire format
      defp port_opts(:json), do: [{:line, 65_536}]
      defp port_opts(:msgpack), do: [{:packet, 4}]

      # Build initial GenServer state after opening the port
      defp build_state(port, format, app, opts) do
        {model, commands} = init_app(app, opts)
        model = CommandProcessor.process(app, model, commands)
        tree = render_tree(app, model)

        state = %{
          port: port,
          format: format,
          app: app,
          opts: opts,
          model: model,
          tree: tree,
          buffer: "",
          pending: %{},
          next_id: 1
        }

        {state, tree}
      end

      # Backends must define: init/1, port_args/1, screenshot_payload/1
      # and optionally resolve_renderer_path/0
    end
  end
end
