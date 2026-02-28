use std::collections::HashMap;

use iced::widget::image;

/// In-memory registry for image handles. Allows Elixir to send raw pixel
/// or encoded image data and reference them by name in the UI tree.
pub struct ImageRegistry {
    handles: HashMap<String, image::Handle>,
}

impl ImageRegistry {
    pub fn new() -> Self {
        Self {
            handles: HashMap::new(),
        }
    }

    /// Store an image from encoded bytes (PNG, JPEG, etc.).
    pub fn create_from_bytes(&mut self, name: String, data: Vec<u8>) {
        self.handles.insert(name, image::Handle::from_bytes(data));
    }

    /// Store an image from raw RGBA pixel data.
    pub fn create_from_rgba(&mut self, name: String, width: u32, height: u32, pixels: Vec<u8>) {
        self.handles
            .insert(name, image::Handle::from_rgba(width, height, pixels));
    }

    /// Remove a named image handle.
    pub fn delete(&mut self, name: &str) {
        self.handles.remove(name);
    }

    /// Look up a named image handle.
    pub fn get(&self, name: &str) -> Option<&image::Handle> {
        self.handles.get(name)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn new_registry_is_empty() {
        let reg = ImageRegistry::new();
        assert!(reg.get("nope").is_none());
    }

    #[test]
    fn create_from_bytes_and_get() {
        let mut reg = ImageRegistry::new();
        reg.create_from_bytes("test".to_string(), vec![0x89, 0x50, 0x4e, 0x47]);
        assert!(reg.get("test").is_some());
    }

    #[test]
    fn create_from_rgba_and_get() {
        let mut reg = ImageRegistry::new();
        // 1x1 RGBA pixel
        reg.create_from_rgba("pixel".to_string(), 1, 1, vec![255, 0, 0, 255]);
        assert!(reg.get("pixel").is_some());
    }

    #[test]
    fn delete_removes_handle() {
        let mut reg = ImageRegistry::new();
        reg.create_from_bytes("gone".to_string(), vec![1, 2, 3]);
        reg.delete("gone");
        assert!(reg.get("gone").is_none());
    }

    #[test]
    fn delete_nonexistent_is_noop() {
        let mut reg = ImageRegistry::new();
        reg.delete("never_existed");
        // no panic
    }

    #[test]
    fn overwrite_replaces_handle() {
        let mut reg = ImageRegistry::new();
        reg.create_from_bytes("img".to_string(), vec![1]);
        reg.create_from_bytes("img".to_string(), vec![2, 3]);
        assert!(reg.get("img").is_some());
    }
}
