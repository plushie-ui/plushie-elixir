use serde_json::{json, Value};

use crate::protocol::EffectResponse;

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
    let text = payload
        .get("text")
        .and_then(|v| v.as_str())
        .unwrap_or("");

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
            match clipboard.get().clipboard(LinuxClipboardKind::Primary).text() {
                Ok(text) => EffectResponse::ok(id, json!({"text": text})),
                Err(e) => EffectResponse::error(id, format!("primary clipboard read failed: {e}")),
            }
        }
        Err(e) => EffectResponse::error(id, format!("clipboard init failed: {e}")),
    }
}

#[cfg(all(feature = "clipboard", target_os = "linux"))]
fn handle_clipboard_write_primary(id: String, payload: &Value) -> EffectResponse {
    use arboard::{SetExtLinux, LinuxClipboardKind};
    let text = payload
        .get("text")
        .and_then(|v| v.as_str())
        .unwrap_or("");

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

    let body = payload
        .get("body")
        .and_then(|v| v.as_str())
        .unwrap_or("");

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
