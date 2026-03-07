use serde_json::{json, Value};

use crate::protocol::EffectResponse;

/// Returns true for effect kinds that should run asynchronously (file dialogs).
pub fn is_async_effect(kind: &str) -> bool {
    matches!(kind, "file_open" | "file_save" | "directory_select")
}

pub fn handle_effect(id: String, kind: &str, payload: &Value) -> EffectResponse {
    match kind {
        "file_open" => handle_file_open(id, payload),
        "file_save" => handle_file_save(id, payload),
        "directory_select" => handle_directory_select(id, payload),
        "clipboard_read" => handle_clipboard_read(id),
        "clipboard_write" => handle_clipboard_write(id, payload),
        "clipboard_read_primary" => handle_clipboard_read_primary(id),
        "clipboard_write_primary" => handle_clipboard_write_primary(id, payload),
        "notification" => handle_notification(id, payload),
        _ => EffectResponse::unsupported(id),
    }
}

// ---------------------------------------------------------------------------
// File dialogs (requires "dialogs" feature / rfd crate)
// ---------------------------------------------------------------------------

#[cfg(feature = "dialogs")]
fn handle_file_open(id: String, payload: &Value) -> EffectResponse {
    let title = payload
        .get("title")
        .and_then(|v| v.as_str())
        .unwrap_or("Open File");

    let mut dialog = rfd::FileDialog::new().set_title(title);

    if let Some(filters) = payload.get("filters").and_then(|v| v.as_array()) {
        for filter in filters {
            if let Some(arr) = filter.as_array() {
                if arr.len() >= 2 {
                    if let (Some(name), Some(ext)) = (arr[0].as_str(), arr[1].as_str()) {
                        let extensions: Vec<&str> = ext
                            .split(';')
                            .map(|e| e.trim().trim_start_matches("*."))
                            .collect();
                        dialog = dialog.add_filter(name, &extensions);
                    }
                }
            }
        }
    }

    if let Some(dir) = payload.get("directory").and_then(|v| v.as_str()) {
        dialog = dialog.set_directory(dir);
    }

    match dialog.pick_file() {
        Some(path) => EffectResponse::ok(id, json!({"path": path.to_string_lossy()})),
        None => EffectResponse::error(id, "cancelled".to_string()),
    }
}

#[cfg(not(feature = "dialogs"))]
fn handle_file_open(id: String, _payload: &Value) -> EffectResponse {
    EffectResponse::unsupported(id)
}

#[cfg(feature = "dialogs")]
fn handle_file_save(id: String, payload: &Value) -> EffectResponse {
    let title = payload
        .get("title")
        .and_then(|v| v.as_str())
        .unwrap_or("Save File");

    let mut dialog = rfd::FileDialog::new().set_title(title);

    if let Some(name) = payload.get("default_name").and_then(|v| v.as_str()) {
        dialog = dialog.set_file_name(name);
    }

    if let Some(filters) = payload.get("filters").and_then(|v| v.as_array()) {
        for filter in filters {
            if let Some(arr) = filter.as_array() {
                if arr.len() >= 2 {
                    if let (Some(name), Some(ext)) = (arr[0].as_str(), arr[1].as_str()) {
                        let extensions: Vec<&str> = ext
                            .split(';')
                            .map(|e| e.trim().trim_start_matches("*."))
                            .collect();
                        dialog = dialog.add_filter(name, &extensions);
                    }
                }
            }
        }
    }

    match dialog.save_file() {
        Some(path) => EffectResponse::ok(id, json!({"path": path.to_string_lossy()})),
        None => EffectResponse::error(id, "cancelled".to_string()),
    }
}

#[cfg(not(feature = "dialogs"))]
fn handle_file_save(id: String, _payload: &Value) -> EffectResponse {
    EffectResponse::unsupported(id)
}

#[cfg(feature = "dialogs")]
fn handle_directory_select(id: String, payload: &Value) -> EffectResponse {
    let title = payload
        .get("title")
        .and_then(|v| v.as_str())
        .unwrap_or("Select Directory");

    let dialog = rfd::FileDialog::new().set_title(title);

    match dialog.pick_folder() {
        Some(path) => EffectResponse::ok(id, json!({"path": path.to_string_lossy()})),
        None => EffectResponse::error(id, "cancelled".to_string()),
    }
}

#[cfg(not(feature = "dialogs"))]
fn handle_directory_select(id: String, _payload: &Value) -> EffectResponse {
    EffectResponse::unsupported(id)
}

// ---------------------------------------------------------------------------
// Clipboard (requires "clipboard" feature / arboard crate)
// ---------------------------------------------------------------------------

#[cfg(feature = "clipboard")]
fn handle_clipboard_read(id: String) -> EffectResponse {
    match arboard::Clipboard::new() {
        Ok(mut clipboard) => match clipboard.get_text() {
            Ok(text) => EffectResponse::ok(id, json!({"text": text})),
            Err(e) => EffectResponse::error(id, format!("clipboard read failed: {e}")),
        },
        Err(e) => EffectResponse::error(id, format!("clipboard init failed: {e}")),
    }
}

#[cfg(not(feature = "clipboard"))]
fn handle_clipboard_read(id: String) -> EffectResponse {
    EffectResponse::unsupported(id)
}

#[cfg(feature = "clipboard")]
fn handle_clipboard_write(id: String, payload: &Value) -> EffectResponse {
    let text = payload.get("text").and_then(|v| v.as_str()).unwrap_or("");

    match arboard::Clipboard::new() {
        Ok(mut clipboard) => match clipboard.set_text(text.to_string()) {
            Ok(()) => EffectResponse::ok(id, json!(null)),
            Err(e) => EffectResponse::error(id, format!("clipboard write failed: {e}")),
        },
        Err(e) => EffectResponse::error(id, format!("clipboard init failed: {e}")),
    }
}

#[cfg(not(feature = "clipboard"))]
fn handle_clipboard_write(id: String, _payload: &Value) -> EffectResponse {
    EffectResponse::unsupported(id)
}

// Primary clipboard: uses the X11/Wayland primary selection on Linux.
// On other platforms, falls back to the standard clipboard.

#[cfg(all(feature = "clipboard", target_os = "linux"))]
fn handle_clipboard_read_primary(id: String) -> EffectResponse {
    use arboard::{GetExtLinux, LinuxClipboardKind};
    match arboard::Clipboard::new() {
        Ok(mut clipboard) => {
            match clipboard
                .get()
                .clipboard(LinuxClipboardKind::Primary)
                .text()
            {
                Ok(text) => EffectResponse::ok(id, json!({"text": text})),
                Err(e) => EffectResponse::error(id, format!("primary clipboard read failed: {e}")),
            }
        }
        Err(e) => EffectResponse::error(id, format!("clipboard init failed: {e}")),
    }
}

#[cfg(all(feature = "clipboard", target_os = "linux"))]
fn handle_clipboard_write_primary(id: String, payload: &Value) -> EffectResponse {
    use arboard::{LinuxClipboardKind, SetExtLinux};
    let text = payload.get("text").and_then(|v| v.as_str()).unwrap_or("");

    match arboard::Clipboard::new() {
        Ok(mut clipboard) => {
            match clipboard
                .set()
                .clipboard(LinuxClipboardKind::Primary)
                .text(text.to_string())
            {
                Ok(()) => EffectResponse::ok(id, json!(null)),
                Err(e) => EffectResponse::error(id, format!("primary clipboard write failed: {e}")),
            }
        }
        Err(e) => EffectResponse::error(id, format!("clipboard init failed: {e}")),
    }
}

// On non-Linux platforms, primary clipboard falls back to the standard clipboard.
#[cfg(all(feature = "clipboard", not(target_os = "linux")))]
fn handle_clipboard_read_primary(id: String) -> EffectResponse {
    // Primary selection is a Linux/X11 concept; fall back to standard clipboard.
    handle_clipboard_read(id)
}

#[cfg(all(feature = "clipboard", not(target_os = "linux")))]
fn handle_clipboard_write_primary(id: String, payload: &Value) -> EffectResponse {
    // Primary selection is a Linux/X11 concept; fall back to standard clipboard.
    handle_clipboard_write(id, payload)
}

#[cfg(not(feature = "clipboard"))]
fn handle_clipboard_read_primary(id: String) -> EffectResponse {
    EffectResponse::unsupported(id)
}

#[cfg(not(feature = "clipboard"))]
fn handle_clipboard_write_primary(id: String, _payload: &Value) -> EffectResponse {
    EffectResponse::unsupported(id)
}

// ---------------------------------------------------------------------------
// Notifications (requires "notifications" feature / notify-rust crate)
// ---------------------------------------------------------------------------

#[cfg(feature = "notifications")]
fn handle_notification(id: String, payload: &Value) -> EffectResponse {
    let title = payload
        .get("title")
        .and_then(|v| v.as_str())
        .unwrap_or("Julep");

    let body = payload.get("body").and_then(|v| v.as_str()).unwrap_or("");

    match notify_rust::Notification::new()
        .summary(title)
        .body(body)
        .show()
    {
        Ok(_) => EffectResponse::ok(id, json!(null)),
        Err(e) => EffectResponse::error(id, format!("notification failed: {e}")),
    }
}

#[cfg(not(feature = "notifications"))]
fn handle_notification(id: String, _payload: &Value) -> EffectResponse {
    EffectResponse::unsupported(id)
}

// ---------------------------------------------------------------------------
// Async effect handlers (file dialogs via rfd::AsyncFileDialog)
// ---------------------------------------------------------------------------

/// Handle an async effect and return an EffectResponse. The response format
/// matches the sync handlers exactly so Elixir can deserialize uniformly.
#[cfg(feature = "dialogs")]
pub async fn handle_async_effect(id: String, effect_type: &str, params: &Value) -> EffectResponse {
    match effect_type {
        "file_open" => {
            let title = params
                .get("title")
                .and_then(|v| v.as_str())
                .unwrap_or("Open File");

            let mut dialog = rfd::AsyncFileDialog::new().set_title(title);

            if let Some(filters) = params.get("filters").and_then(|v| v.as_array()) {
                for filter in filters {
                    if let Some(arr) = filter.as_array() {
                        if arr.len() >= 2 {
                            if let (Some(name), Some(ext)) = (arr[0].as_str(), arr[1].as_str()) {
                                let extensions: Vec<&str> = ext
                                    .split(';')
                                    .map(|e| e.trim().trim_start_matches("*."))
                                    .collect();
                                dialog = dialog.add_filter(name, &extensions);
                            }
                        }
                    }
                }
            }

            if let Some(dir) = params.get("directory").and_then(|v| v.as_str()) {
                dialog = dialog.set_directory(dir);
            }

            match dialog.pick_file().await {
                Some(handle) => {
                    EffectResponse::ok(id, json!({"path": handle.path().to_string_lossy()}))
                }
                None => EffectResponse::error(id, "cancelled".to_string()),
            }
        }
        "file_save" => {
            let title = params
                .get("title")
                .and_then(|v| v.as_str())
                .unwrap_or("Save File");

            let mut dialog = rfd::AsyncFileDialog::new().set_title(title);

            if let Some(name) = params.get("default_name").and_then(|v| v.as_str()) {
                dialog = dialog.set_file_name(name);
            }

            if let Some(filters) = params.get("filters").and_then(|v| v.as_array()) {
                for filter in filters {
                    if let Some(arr) = filter.as_array() {
                        if arr.len() >= 2 {
                            if let (Some(name), Some(ext)) = (arr[0].as_str(), arr[1].as_str()) {
                                let extensions: Vec<&str> = ext
                                    .split(';')
                                    .map(|e| e.trim().trim_start_matches("*."))
                                    .collect();
                                dialog = dialog.add_filter(name, &extensions);
                            }
                        }
                    }
                }
            }

            match dialog.save_file().await {
                Some(handle) => {
                    EffectResponse::ok(id, json!({"path": handle.path().to_string_lossy()}))
                }
                None => EffectResponse::error(id, "cancelled".to_string()),
            }
        }
        "directory_select" => {
            let title = params
                .get("title")
                .and_then(|v| v.as_str())
                .unwrap_or("Select Directory");

            let dialog = rfd::AsyncFileDialog::new().set_title(title);

            match dialog.pick_folder().await {
                Some(handle) => {
                    EffectResponse::ok(id, json!({"path": handle.path().to_string_lossy()}))
                }
                None => EffectResponse::error(id, "cancelled".to_string()),
            }
        }
        _ => EffectResponse::unsupported(id),
    }
}

#[cfg(not(feature = "dialogs"))]
pub async fn handle_async_effect(
    id: String,
    _effect_type: &str,
    _params: &Value,
) -> EffectResponse {
    EffectResponse::unsupported(id)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn unknown_effect_returns_unsupported() {
        let resp = handle_effect("eff-1".to_string(), "teleport_sandwich", &json!({}));
        assert_eq!(resp.status, "error");
        assert_eq!(resp.error.as_deref(), Some("unsupported"));
        assert_eq!(resp.id, "eff-1");
    }

    /// Dispatch every known effect kind with a minimal payload and verify
    /// none of them panic. The handlers may return "unsupported" (when the
    /// corresponding feature is not compiled in) or "error" (when the OS
    /// resource -- clipboard, display server, notification daemon -- is
    /// unavailable in the test environment). That's fine: we're testing
    /// that the routing reaches the right handler and returns cleanly.
    #[test]
    fn dispatch_routes_all_known_kinds_without_panic() {
        let kinds_with_payloads: Vec<(&str, Value)> = vec![
            ("file_open", json!({"title": "Pick a file"})),
            (
                "file_save",
                json!({"title": "Save", "default_name": "out.txt"}),
            ),
            ("directory_select", json!({"title": "Choose dir"})),
            ("clipboard_read", json!({})),
            ("clipboard_write", json!({"text": "hello"})),
            ("clipboard_read_primary", json!({})),
            ("clipboard_write_primary", json!({"text": "primary"})),
            ("notification", json!({"title": "Test", "body": "body"})),
        ];

        for (kind, payload) in &kinds_with_payloads {
            let id = format!("test-{kind}");
            let resp = handle_effect(id.clone(), kind, payload);

            // Must get a well-formed response with matching id.
            assert_eq!(resp.id, id, "id mismatch for kind {kind}");
            assert_eq!(resp.message_type, "effect_response");
            assert!(
                resp.status == "ok" || resp.status == "error",
                "unexpected status '{}' for kind {kind}",
                resp.status
            );
        }
    }

    /// Verify that minimal/empty payloads don't cause panics -- handlers
    /// should defensively unwrap_or on missing fields, not panic.
    #[test]
    fn handlers_tolerate_empty_payloads() {
        let kinds: &[&str] = &[
            "file_open",
            "file_save",
            "directory_select",
            "clipboard_read",
            "clipboard_write",
            "clipboard_read_primary",
            "clipboard_write_primary",
            "notification",
        ];

        for kind in kinds {
            let resp = handle_effect(format!("empty-{kind}"), kind, &json!({}));
            assert_eq!(resp.message_type, "effect_response");
        }
    }

    /// Multiple unknown kinds all return unsupported with distinct ids.
    #[test]
    fn unknown_kinds_preserve_id() {
        for i in 0..5 {
            let id = format!("unk-{i}");
            let resp = handle_effect(id.clone(), &format!("bogus_{i}"), &json!(null));
            assert_eq!(resp.id, id);
            assert_eq!(resp.status, "error");
            assert_eq!(resp.error.as_deref(), Some("unsupported"));
        }
    }

    // NOTE: The feature-gated handler implementations (file dialogs via rfd,
    // clipboard via arboard, notifications via notify-rust) interact with real
    // OS resources -- display server, clipboard daemon, notification service.
    // They can't be meaningfully unit-tested without those services running.
    // Integration-level testing of those paths belongs in a CI environment
    // with Xvfb / a clipboard provider available, not in pure unit tests.
}
