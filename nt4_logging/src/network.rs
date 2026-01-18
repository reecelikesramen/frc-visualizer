use crate::log_store::LogStore;
use crate::schema::{Schema, decode_struct};
use godot::prelude::*;
use nt_client::{Client, NTAddr, NewClientOptions, subscribe::ReceivedMessage};
use parking_lot::RwLock;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::runtime::Runtime;

pub struct NetworkManager {
    runtime: Runtime,
}

impl NetworkManager {
    pub fn new(_store: Arc<RwLock<LogStore>>, server_ip: String, generation: u32) -> Self {
        godot_print!("nm: Initializing NetworkManager... (Gen: {})", generation);

        let store_clone = _store.clone();

        // Initialize Logger (only once)
        let _ = log::set_logger(&SIMPLE_LOGGER);
        let _ = log::set_max_level(log::LevelFilter::Debug);

        // Parse server IP to NTAddr or use Local if 127.0.0.1
        let addr = if server_ip == "127.0.0.1" || server_ip == "localhost" {
            NTAddr::Local
        } else {
            godot_print!("Using Local address for {}", server_ip);
            NTAddr::Local
        };

        // We use a dedicated thread to ensure the runtime and client live forever
        // and are not subject to Godot's memory management quirks or Tokio's drop behavior.
        std::thread::spawn(move || {
            log_to_file("nm: Thread Started. Creating Runtime...");
            let rt = Runtime::new().expect("Failed to create Tokio runtime");
            log_to_file("nm: Runtime created. Blocking on client connection...");

            rt.block_on(async move {
                log_to_file(&format!(
                    "nm: Async Block Started! Connecting to {:?}...",
                    addr
                ));

                let options = NewClientOptions {
                    addr,
                    ..Default::default()
                };

                let client = Client::new(options);
                log_to_file("nm: Client struct created.");

                let result = client
                    .connect_setup(|client| {
                        log_to_file("nm: Connection Setup Callback!");

                        // Construct a TopicPath that resolves to "/" (via segments=[])
                        // Standard "/" string parses to empty segments due to stripping.
                        let segments = std::collections::VecDeque::new();
                        // segments.push_back("".to_string()); // Removed: Empty segments = Root path
                        let path = nt_client::topic::TopicPath::new(segments);

                        // Subscribe to all topics (Root)
                        let topic = client.topic(path);

                        // Spawn the subscription handler
                        tokio::spawn(async move {
                            log_to_file("nm: Subscribing to '/'...");
                            let options = nt_client::data::SubscriptionOptions {
                                prefix: Some(true),
                                ..Default::default()
                            };
                            let mut sub = match topic.subscribe(options).await {
                                Ok(s) => s,
                                Err(e) => {
                                    log_to_file(&format!("nm: Failed to subscribe: {:?}", e));
                                    return;
                                }
                            };
                            log_to_file("nm: Subscribed! Waiting for messages...");

                            let mut schemas: HashMap<String, Schema> = HashMap::new();

                            loop {
                                match sub.recv().await {
                                    Ok(ReceivedMessage::Updated((topic_ref, value))) => {
                                        let topic_name = topic_ref.name();
                                        let mut timestamp = topic_ref
                                            .last_updated()
                                            .map(|d| d.as_micros() as u64)
                                            .unwrap_or(0);
                                        if timestamp == 0 {
                                            timestamp = 1;
                                        }

                                        let mut store = store_clone.write();
                                        if !store.check_generation(generation) {
                                            godot_print!("nm: Generation mismatch ({} vs {}). Stopping thread.", store.generation, generation);
                                            break;
                                        }

                                        // 1. Handle Schema Definitions
                                        if topic_name.starts_with("/.schema/") {
                                            if let rmpv::Value::String(s) = &value {
                                                if let Some(schema_str) = s.as_str() {
                                                    let schema_key = topic_name
                                                        .strip_prefix("/.schema/")
                                                        .unwrap_or(topic_name)
                                                        .to_string();
                                                    let schema =
                                                        Schema::new(schema_key.clone(), schema_str);
                                                    log_to_file(&format!(
                                                        "nm: Parsed Schema: {} -> {:?}",
                                                        schema_key, schema
                                                    ));
                                                    schemas.insert(schema_key, schema);
                                                }
                                            }
                                        }

                                        // 2. Handle Data
                                        match topic_ref.r#type() {
                                            nt_client::data::r#type::DataType::Struct(
                                                struct_name,
                                            ) => {
                                                if let rmpv::Value::Binary(data) = &value {
                                                    store.update_raw(
                                                        topic_name.to_string(),
                                                        timestamp,
                                                        data.clone(),
                                                    );
                                                    store.set_type(
                                                        topic_name.to_string(),
                                                        format!("struct:{}", struct_name),
                                                    );

                                                    let schema_lookup =
                                                        format!("struct:{}", struct_name);
                                                    if let Some(schema) =
                                                        schemas.get(&schema_lookup)
                                                    {
                                                        let decoded =
                                                            decode_struct(schema, data, &schemas);
                                                        for (field_path, val) in decoded {
                                                            let full_path = format!(
                                                                "{}/{}",
                                                                topic_name, field_path
                                                            );
                                                            match val {
                                                                rmpv::Value::F64(f) => store
                                                                    .update_double(
                                                                        full_path, timestamp, f,
                                                                    ),
                                                                rmpv::Value::F32(f) => store
                                                                    .update_double(
                                                                        full_path, timestamp,
                                                                        f as f64,
                                                                    ),
                                                                rmpv::Value::Boolean(b) => store
                                                                    .update_boolean(
                                                                        full_path, timestamp, b,
                                                                    ),
                                                                rmpv::Value::Integer(i) => {
                                                                    if let Some(f) = i.as_f64() {
                                                                        store.update_double(
                                                                            full_path, timestamp, f,
                                                                        );
                                                                    }
                                                                }
                                                                _ => {}
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            nt_client::data::r#type::DataType::StructArray(
                                                struct_name,
                                            ) => {
                                                if let rmpv::Value::Binary(data) = &value {
                                                    store.update_raw(
                                                        topic_name.to_string(),
                                                        timestamp,
                                                        data.clone(),
                                                    );
                                                    store.set_type(
                                                        topic_name.to_string(),
                                                        format!("struct:{}[]", struct_name),
                                                    );

                                                    let schema_lookup =
                                                        format!("struct:{}", struct_name);
                                                    if let Some(schema) =
                                                        schemas.get(&schema_lookup)
                                                    {
                                                        let mut cursor = 0;
                                                        let mut soa: HashMap<
                                                            String,
                                                            Vec<rmpv::Value>,
                                                        > = HashMap::new();
                                                        while cursor < data.len() {
                                                            let size =
                                                                crate::schema::calculate_size(
                                                                    schema, &schemas,
                                                                );
                                                            if size == 0
                                                                || cursor + size > data.len()
                                                            {
                                                                break;
                                                            }
                                                            let decoded = decode_struct(
                                                                schema,
                                                                &data[cursor..cursor + size],
                                                                &schemas,
                                                            );
                                                            for (field, val) in decoded {
                                                                soa.entry(field)
                                                                    .or_default()
                                                                    .push(val);
                                                            }
                                                            cursor += size;
                                                        }
                                                        for (field_path, values) in soa {
                                                            let full_path = format!(
                                                                "{}/{}",
                                                                topic_name, field_path
                                                            );
                                                            match values.first() {
                                                                Some(rmpv::Value::F64(_))
                                                                | Some(rmpv::Value::F32(_)) => {
                                                                    let floats: Vec<f64> = values
                                                                        .iter()
                                                                        .filter_map(|v| v.as_f64())
                                                                        .collect();
                                                                    store.update_double_array(
                                                                        full_path, timestamp,
                                                                        floats,
                                                                    );
                                                                }
                                                                Some(rmpv::Value::Boolean(_)) => {
                                                                    let bools: Vec<bool> = values
                                                                        .iter()
                                                                        .filter_map(|v| v.as_bool())
                                                                        .collect();
                                                                    store.update_boolean_array(
                                                                        full_path, timestamp, bools,
                                                                    );
                                                                }
                                                                _ => {}
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            _ => {
                                                match value {
                                                    rmpv::Value::Boolean(b) => store
                                                        .update_boolean(
                                                            topic_name.to_string(),
                                                            timestamp,
                                                            b,
                                                        ),
                                                    rmpv::Value::F32(f) => store.update_double(
                                                        topic_name.to_string(),
                                                        timestamp,
                                                        f as f64,
                                                    ),
                                                    rmpv::Value::F64(f) => store.update_double(
                                                        topic_name.to_string(),
                                                        timestamp,
                                                        f,
                                                    ),
                                                    rmpv::Value::Integer(i) => {
                                                        if let Some(f) = i.as_f64() {
                                                            store.update_double(
                                                                topic_name.to_string(),
                                                                timestamp,
                                                                f,
                                                            );
                                                        }
                                                    }
                                                    rmpv::Value::String(s) => {
                                                        if let Some(str_val) = s.as_str() {
                                                            store.update_string(
                                                                topic_name.to_string(),
                                                                timestamp,
                                                                str_val.to_string(),
                                                            );
                                                        }
                                                    }
                                                    rmpv::Value::Binary(vec) => store.update_raw(
                                                        topic_name.to_string(),
                                                        timestamp,
                                                        vec,
                                                    ),
                                                    rmpv::Value::Array(vec) => {
                                                        if vec.is_empty() {
                                                            // Can't infer type
                                                        } else {
                                                            match &vec[0] {
                                                                rmpv::Value::Boolean(_) => {
                                                                    let bools: Vec<bool> = vec
                                                                        .iter()
                                                                        .filter_map(|v| v.as_bool())
                                                                        .collect();
                                                                    store.update_boolean_array(
                                                                        topic_name.to_string(),
                                                                        timestamp,
                                                                        bools,
                                                                    );
                                                                }
                                                                rmpv::Value::F64(_)
                                                                | rmpv::Value::F32(_) => {
                                                                    let floats: Vec<f64> = vec
                                                                        .iter()
                                                                        .filter_map(|v| v.as_f64())
                                                                        .collect();
                                                                    store.update_double_array(
                                                                        topic_name.to_string(),
                                                                        timestamp,
                                                                        floats,
                                                                    );
                                                                }
                                                                rmpv::Value::String(_) => {
                                                                    let strings: Vec<String> = vec
                                                                        .iter()
                                                                        .filter_map(|v| {
                                                                            v.as_str().map(|s| {
                                                                                s.to_string()
                                                                            })
                                                                        })
                                                                        .collect();
                                                                    store.update_string_array(
                                                                        topic_name.to_string(),
                                                                        timestamp,
                                                                        strings,
                                                                    );
                                                                }
                                                                _ => {}
                                                            }
                                                        }
                                                    }
                                                    _ => {
                                                        log_to_file(&format!(
                                                            "nm: Unhandled Value for {}: {:?}",
                                                            topic_name, value
                                                        ));
                                                    } // Ignore Maps/Ext/Nil
                                                }
                                            }
                                        }
                                    }
                                    Ok(ReceivedMessage::Announced(announce)) => {
                                        log_to_file(&format!(
                                            "nm: New Topic: {} (Type: {:?}, Properties: {:?})",
                                            announce.name(),
                                            announce.r#type(),
                                            announce.properties()
                                        ));
                                    }
                                    Ok(ReceivedMessage::Unannounced { name, id }) => {
                                        log_to_file(&format!(
                                            "nm: Topic Unannounced: {} (ID: {})",
                                            name, id
                                        ));
                                    }
                                    Ok(_) => {}
                                    Err(e) => {
                                        log_to_file(&format!("nm: Subscription error: {:?}", e));
                                        break;
                                    }
                                }
                            }
                        });
                    })
                    .await;

                if let Err(e) = result {
                    log_to_file(&format!("nm: NT4 Client Disconnected: {:?}", e));
                }
            });
            log_to_file("nm: Runtime block ended (Thread dying).");
        });

        // We return a dummy runtime placeholder because we moved execution to a thread.
        // We can create a temporary runtime to satisfy the struct, or change struct.
        // Changing struct requires changing nt4_node.rs
        // We'll just create a new unused runtime or remove the field?
        // Changing struct is cleaner but requires more edits.
        // We will just put a new runtime in the struct.
        let runtime = Runtime::new().unwrap();

        Self { runtime }
    }
}

fn log_to_file(msg: &str) {
    use std::io::Write;
    if let Ok(mut file) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open("/tmp/nt4_debug.log")
    {
        let _ = writeln!(file, "{}", msg);
    }
}

pub struct SimpleLogger;

impl log::Log for SimpleLogger {
    fn enabled(&self, metadata: &log::Metadata) -> bool {
        metadata.level() <= log::Level::Debug
    }

    fn log(&self, record: &log::Record) {
        if self.enabled(record.metadata()) {
            log_to_file(&format!("[{}] {}", record.level(), record.args()));
        }
    }

    fn flush(&self) {}
}

static SIMPLE_LOGGER: SimpleLogger = SimpleLogger;
