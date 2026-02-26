# Effects

Effects are native platform operations that require the renderer to interact
with the OS on behalf of the Elixir app. File dialogs, clipboard access,
notifications, and similar features are effects.

## Design principle

Effects are simple request/response pairs over the same JSONL transport.
Elixir asks, the renderer does, the renderer replies. No capability model,
no policy engine, no permission framework. If an effect is requested, the
renderer executes it.

If granular permission control is needed later, it can be layered in the
Elixir runtime (decide whether to send the request) rather than in the
renderer (decide whether to execute it). Keep the renderer dumb.

## How effects work

### Elixir side

```elixir
def update(model, {:click, "open_file"}) do
  Julep.Effects.request(:file_open,
    title: "Choose a file",
    filters: [{"Text files", "*.txt"}, {"All files", "*"}]
  )
  model
end

def update(model, {:effect_result, "file_open", {:ok, %{path: path}}}) do
  %{model | file_path: path}
end

def update(model, {:effect_result, "file_open", {:error, "cancelled"}}) do
  model
end
```

The `Julep.Effects.request/2` call sends an `effect_request` message to the
renderer. The result arrives as an event in a subsequent `update` call.
Effects are asynchronous -- the model is not blocked waiting for the result.

### Transport

```json
-> {"type": "effect_request", "id": "ef_1", "kind": "file_open", "payload": {"title": "Choose a file", "filters": [["Text files", "*.txt"], ["All files", "*"]]}}
<- {"type": "effect_response", "id": "ef_1", "status": "ok", "result": {"path": "/home/user/notes.txt"}}
```

The `id` correlates request to response. The runtime generates unique IDs
automatically.

## Available effects (v1)

| Kind | Description | Payload | Result |
|---|---|---|---|
| `file_open` | Open file dialog | `title`, `filters`, `directory` | `{path}` or error |
| `file_save` | Save file dialog | `title`, `filters`, `default_name` | `{path}` or error |
| `directory_select` | Directory picker | `title` | `{path}` or error |
| `clipboard_read` | Read clipboard | -- | `{text}` or error |
| `clipboard_write` | Write to clipboard | `text` | ok or error |
| `notification` | Show OS notification | `title`, `body` | ok |

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
