use godot::prelude::*;

mod log_store;
mod network;
mod nt4_node;
pub mod schema;

struct Nt4Logging;

#[gdextension]
unsafe impl ExtensionLibrary for Nt4Logging {}
