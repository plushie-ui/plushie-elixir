# Effects

Effects are native platform operations that require the renderer to interact
with the OS on behalf of the Elixir app. File dialogs, clipboard access,
notifications, and similar features are effects.

## Design principle

Effects are simple request/response pairs over the same stdio transport.
Elixir asks, the renderer does, the renderer replies. No capability model,
no policy engine, no permission framework. If an effect is requested, the
renderer executes it.

If granular permission control is needed later, it can be layered in the
Elixir runtime (decide whether to send the request) rather than in the
renderer (decide whether to execute it). Keep the renderer dumb.

## How effects work

### Elixir side

```elixir
def update(model, %Widget{type: :click, id: "open_file"}) do
  cmd = Julep.Effects.file_open(
    title: "Choose a file",
    filters: [{"Text files", "*.txt"}, {"All files", "*"}]
  )
  {model, cmd}
end

def update(model, %Effect{result: {:ok, %{"path" => path}}}) do
  %{model | file_path: path}
end

def update(model, %Effect{result: {:error, "cancelled"}}) do
  model
end
```

Every effect function returns a `Julep.Command` struct. The command must be
returned from `update` as part of a `{model, command}` tuple -- discarding
it silently does nothing. The effect ID is auto-generated (e.g. `"ef_1"`)
and embedded in the command payload. You can extract it via
`cmd.payload.id` if you need to correlate a specific response.

Result keys come from the renderer as string keys, not atoms (e.g.
`%{"path" => path}`, not `%{path: path}`).

The result arrives as an `%Effect{request_id: id, result: result}` event in a
subsequent `update` call. Effects are asynchronous -- the model is not
blocked waiting for the result.

### Transport

MessagePack is the default wire format. JSON shown here for readability
(use `--json` flag for JSONL mode).

```json
-> {"type": "effect", "id": "ef_1", "kind": "file_open", "payload": {"title": "Choose a file", "filters": [["Text files", "*.txt"], ["All files", "*"]]}}
<- {"type": "effect_response", "id": "ef_1", "status": "ok", "result": {"path": "/home/user/notes.txt"}}
```

The `id` correlates request to response. The runtime generates unique IDs
automatically.

## Available effects (v1)

| Kind | Description | Payload | Result |
|---|---|---|---|
| `file_open` | Open file dialog | `title`, `filters`, `directory` | `{path}` or error |
| `file_open_multiple` | Multi-file open dialog | `title`, `filters`, `directory` | `{paths}` or error |
| `file_save` | Save file dialog | `title`, `filters`, `default_name` | `{path}` or error |
| `directory_select` | Directory picker | `title` | `{path}` or error |
| `directory_select_multiple` | Multi-directory picker | `title` | `{paths}` or error |
| `clipboard_read` | Read clipboard | -- | `{text}` or error |
| `clipboard_write` | Write to clipboard | `text` | ok or error |
| `clipboard_read_html` | Read HTML from clipboard | -- | `{html}` or error |
| `clipboard_write_html` | Write HTML to clipboard | `html`, `alt_text` | ok or error |
| `clipboard_clear` | Clear the clipboard | -- | ok or error |
| `clipboard_read_primary` | Read primary selection (Linux) | -- | `{text}` or error |
| `clipboard_write_primary` | Write to primary selection (Linux) | `text` | ok or error |
| `notification` | Show OS notification | `title`, `body`, `icon`, `timeout`, `urgency`, `sound` | ok |

All effects can return `{"status": "error", "error": "unsupported"}` if the
renderer is running on a platform that does not support the operation.

## Adding new effects

Adding an effect requires changes in two places:

1. **Renderer:** handle the new `kind` in the effect dispatch, execute the
   platform operation, return the result.
2. **Elixir:** add a convenience function in `Julep.Effects` (optional, apps
   can always send raw requests).

The transport does not need to change. Unknown effect kinds return
`unsupported`.

## Effects are not commands

Some frameworks conflate effects (I/O operations) with commands (internal
state mutations). In julep, `update` handles state mutations synchronously.
Effects handle I/O asynchronously. They are separate concerns with separate
code paths.

If your app needs something that is purely internal (start a timer, schedule
a follow-up event, batch multiple updates), that is handled in the Elixir
runtime, not as an effect. Effects always involve the renderer or the OS.
