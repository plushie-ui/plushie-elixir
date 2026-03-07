#[cfg(feature = "widget-image")]
use std::collections::HashMap;

#[cfg(feature = "widget-image")]
use iced::widget::image;

/// In-memory registry for image handles. Allows Elixir to send raw pixel
/// or encoded image data and reference them by name in the UI tree.
pub struct ImageRegistry {
    #[cfg(feature = "widget-image")]
    handles: HashMap<String, image::Handle>,
}

impl Default for ImageRegistry {
    fn default() -> Self {
        Self::new()
    }
}

impl ImageRegistry {
    pub fn new() -> Self {
        Self {
            #[cfg(feature = "widget-image")]
            handles: HashMap::new(),
        }
    }

    /// Maximum dimension (width or height) for a single image.
    const MAX_DIMENSION: u32 = 16384;

    /// Maximum pixel data size in bytes (256 MB).
    const MAX_PIXEL_BYTES: usize = 256 * 1024 * 1024;

    /// Store an image from encoded bytes (PNG, JPEG, etc.).
    #[cfg(feature = "widget-image")]
    pub fn create_from_bytes(&mut self, name: String, data: Vec<u8>) {
        if data.len() > Self::MAX_PIXEL_BYTES {
            log::error!(
                "image registry: encoded data for '{}' exceeds 256 MB limit ({} bytes)",
                name,
                data.len()
            );
            return;
        }
        self.handles.insert(name, image::Handle::from_bytes(data));
    }

    #[cfg(not(feature = "widget-image"))]
    pub fn create_from_bytes(&mut self, _name: String, _data: Vec<u8>) {
        log::warn!("image registry: widget-image feature not enabled");
    }

    /// Store an image from raw RGBA pixel data.
    #[cfg(feature = "widget-image")]
    pub fn create_from_rgba(&mut self, name: String, width: u32, height: u32, pixels: Vec<u8>) {
        if width > Self::MAX_DIMENSION || height > Self::MAX_DIMENSION {
            log::error!(
                "image registry: dimensions {}x{} for '{}' exceed max {}",
                width,
                height,
                name,
                Self::MAX_DIMENSION
            );
            return;
        }

        let expected = (width as usize) * (height as usize) * 4;
        if pixels.len() != expected {
            log::error!(
                "image registry: RGBA data size mismatch for '{}': expected {} bytes ({}x{}x4), got {}",
                name,
                expected,
                width,
                height,
                pixels.len()
            );
            return;
        }

        if pixels.len() > Self::MAX_PIXEL_BYTES {
            log::error!(
                "image registry: pixel data for '{}' exceeds 256 MB limit ({} bytes)",
                name,
                pixels.len()
            );
            return;
        }

        self.handles
            .insert(name, image::Handle::from_rgba(width, height, pixels));
    }

    #[cfg(not(feature = "widget-image"))]
    pub fn create_from_rgba(&mut self, _name: String, _width: u32, _height: u32, _pixels: Vec<u8>) {
        log::warn!("image registry: widget-image feature not enabled");
    }

    /// Remove a named image handle.
    #[cfg(feature = "widget-image")]
    pub fn delete(&mut self, name: &str) {
        self.handles.remove(name);
    }

    #[cfg(not(feature = "widget-image"))]
    pub fn delete(&mut self, _name: &str) {}

    /// Look up a named image handle.
    #[cfg(feature = "widget-image")]
    pub fn get(&self, name: &str) -> Option<&image::Handle> {
        self.handles.get(name)
    }

    #[cfg(not(feature = "widget-image"))]
    #[allow(dead_code)]
    pub fn get(&self, _name: &str) -> Option<&()> {
        None
    }
}

#[cfg(test)]
#[cfg(feature = "widget-image")]
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

    #[test]
    fn rgba_size_mismatch_rejected() {
        let mut reg = ImageRegistry::new();
        // 2x2 RGBA should be 16 bytes, providing only 4
        reg.create_from_rgba("bad".to_string(), 2, 2, vec![255, 0, 0, 255]);
        assert!(reg.get("bad").is_none());
    }

    #[test]
    fn rgba_dimension_too_large_rejected() {
        let mut reg = ImageRegistry::new();
        reg.create_from_rgba("huge".to_string(), 16385, 1, vec![0; 16385 * 4]);
        assert!(reg.get("huge").is_none());
    }

    #[test]
    fn rgba_valid_dimensions_accepted() {
        let mut reg = ImageRegistry::new();
        // 2x2 RGBA = 16 bytes
        reg.create_from_rgba("ok".to_string(), 2, 2, vec![0; 16]);
        assert!(reg.get("ok").is_some());
    }
}
