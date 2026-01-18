use crate::log_store::LogStore;
use crate::network::NetworkManager;
use byteorder::{ByteOrder, LittleEndian};
use godot::prelude::*;
use parking_lot::RwLock;
use std::sync::Arc;

#[derive(GodotClass)]
#[class(base=Node)]
pub struct NT4 {
    #[base]
    base: Base<Node>,

    store: Arc<RwLock<LogStore>>,
    network: Option<NetworkManager>, // Option to allow late initialization

    server_ip: String,

    // Debug/Replay controls
    cursor_time: u64, // 0 means "live"
}

#[godot_api]
impl INode for NT4 {
    fn init(base: Base<Node>) -> Self {
        Self {
            base,
            store: Arc::new(RwLock::new(LogStore::new())),
            network: None,
            server_ip: "127.0.0.1".to_string(),
            cursor_time: 0,
        }
    }
}

#[godot_api]
impl NT4 {
    #[func]
    pub fn start_client(&mut self, server_ip: String) {
        godot_print!("NT4: start_client called with ip: {}", server_ip);
        self.server_ip = server_ip.clone();
        self.network = Some(NetworkManager::new(
            self.store.clone(),
            self.server_ip.clone(),
        ));
        godot_print!("NT4: NetworkManager initialized.");
    }

    #[func]
    pub fn subscribe_to_all(&self) {
        // In a real implementation using nt-network or equivalent,
        // we would send a subscribe message here.
        godot_print!("Subscribing to all topics...");
    }

    #[func]
    pub fn set_replay_cursor(&mut self, timestamp_micros: i64) {
        self.cursor_time = timestamp_micros as u64;
    }

    fn current_time(&self) -> u64 {
        if self.cursor_time > 0 {
            self.cursor_time
        } else {
            // Return max u64 effectively for "latest"
            u64::MAX
        }
    }

    #[func]
    pub fn get_log_start_time(&self) -> i64 {
        let store = self.store.read();
        store.get_start_timestamp() as i64
    }

    #[func]
    pub fn get_last_timestamp(&self) -> i64 {
        let store = self.store.read();
        store.get_last_timestamp() as i64
    }

    // --- Legacy API Getters ---

    #[func]
    pub fn get_number(&self, topic: String, default: f64) -> f64 {
        let store = self.store.read();
        store.get_double(&topic, self.current_time(), default)
    }

    #[func]
    pub fn get_boolean(&self, topic: String, default: bool) -> bool {
        let store = self.store.read();
        store.get_boolean(&topic, self.current_time(), default)
    }

    #[func]
    pub fn get_string(&self, topic: String, default: String) -> String {
        let store = self.store.read();
        store.get_string(&topic, self.current_time(), default)
    }

    #[func]
    pub fn get_value(&self, topic: String, default: Variant) -> Variant {
        let store = self.store.read();
        let time = self.current_time();

        if let Some(crate::log_store::TopicData::Double(..)) = store.data.get(&topic) {
            return store.get_double(&topic, time, 0.0).to_variant();
        }
        if let Some(crate::log_store::TopicData::Boolean(..)) = store.data.get(&topic) {
            return store.get_boolean(&topic, time, false).to_variant();
        }
        if let Some(crate::log_store::TopicData::String(..)) = store.data.get(&topic) {
            return store.get_string(&topic, time, "".to_string()).to_variant();
        }
        if let Some(crate::log_store::TopicData::DoubleArray(..)) = store.data.get(&topic) {
            let vec = store.get_double_array(&topic, time, Vec::new());
            return vec.into_iter().collect::<PackedFloat64Array>().to_variant();
        }
        if let Some(crate::log_store::TopicData::BooleanArray(..)) = store.data.get(&topic) {
            let vec = store.get_boolean_array(&topic, time, Vec::new());
            let mut arr = Array::new();
            for v in vec {
                arr.push(v);
            }
            return arr.to_variant();
        }
        if let Some(crate::log_store::TopicData::StringArray(..)) = store.data.get(&topic) {
            let vec = store.get_string_array(&topic, time, Vec::new());
            return vec
                .iter()
                .map(GString::from)
                .collect::<PackedStringArray>()
                .to_variant();
        }
        if let Some(crate::log_store::TopicData::Raw(..)) = store.data.get(&topic) {
            if let Some(vec) = store.get_raw(&topic, time) {
                return PackedByteArray::from(&vec[..]).to_variant();
            }
        }

        default
    }

    #[func]
    pub fn get_number_array(
        &self,
        topic: String,
        default: PackedFloat64Array,
    ) -> PackedFloat64Array {
        let store = self.store.read();
        let vec = store.get_double_array(&topic, self.current_time(), Vec::new());
        if vec.is_empty() {
            return default;
        }
        vec.into_iter().collect()
    }

    #[func]
    pub fn get_boolean_array(&self, topic: String, default: Array<bool>) -> Array<bool> {
        let store = self.store.read();
        let vec = store.get_boolean_array(&topic, self.current_time(), Vec::new());
        if vec.is_empty() {
            return default;
        }
        let mut arr = Array::new();
        for v in vec {
            arr.push(v);
        }
        arr
    }

    #[func]
    pub fn get_string_array(&self, topic: String, default: PackedStringArray) -> PackedStringArray {
        let store = self.store.read();
        let vec = store.get_string_array(&topic, self.current_time(), Vec::new());
        if vec.is_empty() {
            return default;
        }
        vec.iter().map(GString::from).collect()
    }

    #[func]
    pub fn get_boolean_series(&self, topic: String) -> Dictionary {
        let store = self.store.read();
        let mut dict = Dictionary::new();

        if let Some((ts, vals)) = store.get_boolean_series(&topic) {
            let mut ts_array = Array::new();
            for &t in &ts {
                ts_array.push(t as i64); // Godot uses i64 for integers usually
            }

            let mut val_array = Array::new();
            for &v in &vals {
                val_array.push(v);
            }

            dict.set("timestamps", ts_array);
            dict.set("values", val_array);
        }

        dict
    }

    // --- Geometry Helpers (Parsing Raw Bytes) ---

    // Helper to get raw bytes
    fn get_raw_bytes(&self, topic: &str) -> Option<Vec<u8>> {
        let store = self.store.read();
        store.get_raw(topic, self.current_time())
    }

    #[func]
    pub fn get_translation2d(&self, topic: String, default: Vector2) -> Vector2 {
        if let Some(bytes) = self.get_raw_bytes(&topic) {
            if bytes.len() >= 16 {
                let x = LittleEndian::read_f64(&bytes[0..8]);
                let y = LittleEndian::read_f64(&bytes[8..16]);
                return Vector2::new(x as f32, -y as f32); // Godot Y-Up
            }
        }
        default
    }

    #[func]
    pub fn get_rotation2d(&self, topic: String, default: f64) -> f64 {
        if let Some(bytes) = self.get_raw_bytes(&topic) {
            if bytes.len() >= 8 {
                let val = LittleEndian::read_f64(&bytes[0..8]);
                return -val; // Negated
            }
        }
        default
    }

    #[func]
    pub fn get_pose2d(&self, topic: String, default: Transform2D) -> Transform2D {
        if let Some(bytes) = self.get_raw_bytes(&topic) {
            if bytes.len() >= 24 {
                let x = LittleEndian::read_f64(&bytes[0..8]);
                let y = LittleEndian::read_f64(&bytes[8..16]);
                let rot = LittleEndian::read_f64(&bytes[16..24]);

                let params = Vector2::new(x as f32, -y as f32);
                let rotation = -rot as f32;
                return Transform2D::from_angle_origin(rotation, params);
            }
        }
        default
    }

    #[func]
    pub fn get_pose3d(&self, topic: String, default: Transform3D) -> Transform3D {
        if let Some(bytes) = self.get_raw_bytes(&topic) {
            if bytes.len() >= 56 {
                // Translation (24 bytes)
                let tx = LittleEndian::read_f64(&bytes[0..8]);
                let ty = LittleEndian::read_f64(&bytes[8..16]);
                let tz = LittleEndian::read_f64(&bytes[16..24]);

                // Rotation (32 bytes)
                let qw = LittleEndian::read_f64(&bytes[24..32]);
                let qx = LittleEndian::read_f64(&bytes[32..40]);
                let qy = LittleEndian::read_f64(&bytes[40..48]);
                let qz = LittleEndian::read_f64(&bytes[48..56]);

                // Mapping: Origin: Vector3(-y, z, -x)
                let origin = Vector3::new(-ty as f32, tz as f32, -tx as f32);

                // Mapping: Basis: Quaternion(-qy, qz, -qx, qw)
                let quat = Quaternion::new(-qy as f32, qz as f32, -qx as f32, qw as f32);

                return Transform3D::new(Basis::from_quaternion(quat), origin);
            }
        }
        default
    }

    #[func]
    pub fn get_pose3d_array(
        &self,
        topic: String,
        default: Array<Transform3D>,
    ) -> Array<Transform3D> {
        // Assuming raw bytes contain concatenated Pose3Ds [56 bytes * N]
        if let Some(bytes) = self.get_raw_bytes(&topic) {
            if bytes.len() % 56 == 0 {
                let count = bytes.len() / 56;
                let mut array = Array::new();
                for i in 0..count {
                    let offset = i * 56;
                    // Translation
                    let tx = LittleEndian::read_f64(&bytes[offset + 0..offset + 8]);
                    let ty = LittleEndian::read_f64(&bytes[offset + 8..offset + 16]);
                    let tz = LittleEndian::read_f64(&bytes[offset + 16..offset + 24]);

                    // Rotation
                    let qw = LittleEndian::read_f64(&bytes[offset + 24..offset + 32]);
                    let qx = LittleEndian::read_f64(&bytes[offset + 32..offset + 40]);
                    let qy = LittleEndian::read_f64(&bytes[offset + 40..offset + 48]);
                    let qz = LittleEndian::read_f64(&bytes[offset + 48..offset + 56]);

                    let origin = Vector3::new(-ty as f32, tz as f32, -tx as f32);
                    let quat = Quaternion::new(-qy as f32, qz as f32, -qx as f32, qw as f32);

                    array.push(Transform3D::new(Basis::from_quaternion(quat), origin));
                }
                return array;
            }
        }
        default
    }

    #[func]
    pub fn get_topic_info(&self) -> Array<Variant> {
        let store = self.store.read();
        let mut arr = Array::new();
        for (name, type_str) in store.get_topics_info() {
            let mut dict = VarDictionary::new();
            dict.set("name", name);
            dict.set("type", type_str);
            let var = dict.to_variant(); // Create variant
            arr.push(&var); // Push reference
        }
        arr
    }
}
