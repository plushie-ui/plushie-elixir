use crate::extensions::{ExtensionDispatcher, WidgetExtension};

pub struct JulepAppBuilder {
    pub extensions: Vec<Box<dyn WidgetExtension>>,
}

impl JulepAppBuilder {
    pub fn new() -> Self {
        Self { extensions: vec![] }
    }

    pub fn extension(mut self, ext: Box<dyn WidgetExtension>) -> Self {
        self.extensions.push(ext);
        self
    }

    pub fn build_dispatcher(self) -> ExtensionDispatcher {
        ExtensionDispatcher::new(self.extensions)
    }
}

impl Default for JulepAppBuilder {
    fn default() -> Self {
        Self::new()
    }
}
