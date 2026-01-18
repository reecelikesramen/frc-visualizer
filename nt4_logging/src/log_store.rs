use godot::prelude::*;
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub enum TopicData {
    Double(Vec<u64>, Vec<f64>),
    Boolean(Vec<u64>, Vec<bool>),
    String(Vec<u64>, Vec<String>),
    DoubleArray(Vec<u64>, Vec<Vec<f64>>),
    BooleanArray(Vec<u64>, Vec<Vec<bool>>),
    StringArray(Vec<u64>, Vec<Vec<String>>),
    Raw(Vec<u64>, Vec<Vec<u8>>),
}

impl TopicData {
    pub fn new_double() -> Self {
        TopicData::Double(Vec::new(), Vec::new())
    }
    pub fn new_boolean() -> Self {
        TopicData::Boolean(Vec::new(), Vec::new())
    }
    pub fn new_string() -> Self {
        TopicData::String(Vec::new(), Vec::new())
    }
    pub fn new_double_array() -> Self {
        TopicData::DoubleArray(Vec::new(), Vec::new())
    }
    pub fn new_boolean_array() -> Self {
        TopicData::BooleanArray(Vec::new(), Vec::new())
    }
    pub fn new_string_array() -> Self {
        TopicData::StringArray(Vec::new(), Vec::new())
    }
    pub fn new_raw() -> Self {
        TopicData::Raw(Vec::new(), Vec::new())
    }

    pub fn last_timestamp(&self) -> u64 {
        match self {
            TopicData::Double(ts, _) => ts.last().copied().unwrap_or(0),
            TopicData::Boolean(ts, _) => ts.last().copied().unwrap_or(0),
            TopicData::String(ts, _) => ts.last().copied().unwrap_or(0),
            TopicData::DoubleArray(ts, _) => ts.last().copied().unwrap_or(0),
            TopicData::BooleanArray(ts, _) => ts.last().copied().unwrap_or(0),
            TopicData::StringArray(ts, _) => ts.last().copied().unwrap_or(0),
            TopicData::Raw(ts, _) => ts.last().copied().unwrap_or(0),
        }
    }
}

pub struct LogStore {
    pub data: HashMap<String, TopicData>,
    pub topic_types: HashMap<String, String>,
    pub generation: u32,
}

impl LogStore {
    pub fn new() -> Self {
        Self {
            data: HashMap::new(),
            topic_types: HashMap::new(),
            generation: 0,
        }
    }

    pub fn set_type(&mut self, topic: String, type_str: String) {
        self.topic_types.insert(topic, type_str);
    }

    pub fn clear(&mut self) {
        self.data.clear();
        self.topic_types.clear();
        self.generation += 1;
    }

    pub fn check_generation(&self, generation: u32) -> bool {
        self.generation == generation
    }

    pub fn has_topic(&self, topic: &str) -> bool {
        self.data.contains_key(topic)
    }

    pub fn update_double(&mut self, topic: String, timestamp: u64, value: f64) {
        let entry = self.data.entry(topic).or_insert_with(TopicData::new_double);
        if let TopicData::Double(ts, original_vals) = entry {
            if let Some(last_val) = original_vals.last() {
                if (last_val - value).abs() < f64::EPSILON {
                    return;
                }
            }
            ts.push(timestamp);
            original_vals.push(value);
        }
    }

    pub fn update_boolean(&mut self, topic: String, timestamp: u64, value: bool) {
        let entry = self
            .data
            .entry(topic)
            .or_insert_with(TopicData::new_boolean);
        if let TopicData::Boolean(ts, original_vals) = entry {
            if let Some(last_val) = original_vals.last() {
                if *last_val == value {
                    return;
                }
            }
            ts.push(timestamp);
            original_vals.push(value);
        }
    }

    pub fn update_string(&mut self, topic: String, timestamp: u64, value: String) {
        let entry = self.data.entry(topic).or_insert_with(TopicData::new_string);
        if let TopicData::String(ts, original_vals) = entry {
            if let Some(last_val) = original_vals.last() {
                if *last_val == value {
                    return;
                }
            }
            ts.push(timestamp);
            original_vals.push(value);
        }
    }

    pub fn update_double_array(&mut self, topic: String, timestamp: u64, value: Vec<f64>) {
        let entry = self
            .data
            .entry(topic)
            .or_insert_with(TopicData::new_double_array);
        if let TopicData::DoubleArray(ts, original_vals) = entry {
            if let Some(last_val) = original_vals.last() {
                if *last_val == value {
                    return;
                }
            }
            ts.push(timestamp);
            original_vals.push(value);
        }
    }

    pub fn update_boolean_array(&mut self, topic: String, timestamp: u64, value: Vec<bool>) {
        let entry = self
            .data
            .entry(topic)
            .or_insert_with(TopicData::new_boolean_array);
        if let TopicData::BooleanArray(ts, original_vals) = entry {
            if let Some(last_val) = original_vals.last() {
                if *last_val == value {
                    return;
                }
            }
            ts.push(timestamp);
            original_vals.push(value);
        }
    }

    pub fn update_string_array(&mut self, topic: String, timestamp: u64, value: Vec<String>) {
        let entry = self
            .data
            .entry(topic)
            .or_insert_with(TopicData::new_string_array);
        if let TopicData::StringArray(ts, original_vals) = entry {
            if let Some(last_val) = original_vals.last() {
                if *last_val == value {
                    return;
                }
            }
            ts.push(timestamp);
            original_vals.push(value);
        }
    }

    pub fn update_raw(&mut self, topic: String, timestamp: u64, value: Vec<u8>) {
        let entry = self.data.entry(topic).or_insert_with(TopicData::new_raw);
        if let TopicData::Raw(ts, original_vals) = entry {
            if let Some(last_val) = original_vals.last() {
                if *last_val == value {
                    return;
                }
            }
            ts.push(timestamp);
            original_vals.push(value);
        }
    }

    fn get_index(timestamps: &[u64], query_time: u64) -> usize {
        let idx = timestamps.partition_point(|&t| t <= query_time);
        if idx == 0 { 0 } else { idx - 1 }
    }

    pub fn get_double(&self, topic: &str, query_time: u64, default: f64) -> f64 {
        if let Some(TopicData::Double(ts, vals)) = self.data.get(topic) {
            if ts.is_empty() {
                return default;
            }
            let idx = Self::get_index(ts, query_time);
            vals.get(idx).copied().unwrap_or(default)
        } else {
            default
        }
    }

    pub fn get_boolean(&self, topic: &str, query_time: u64, default: bool) -> bool {
        if let Some(TopicData::Boolean(ts, vals)) = self.data.get(topic) {
            if ts.is_empty() {
                return default;
            }
            let idx = Self::get_index(ts, query_time);
            vals.get(idx).copied().unwrap_or(default)
        } else {
            default
        }
    }

    pub fn get_boolean_series(&self, topic: &str) -> Option<(Vec<u64>, Vec<bool>)> {
        if let Some(TopicData::Boolean(ts, vals)) = self.data.get(topic) {
            Some((ts.clone(), vals.clone()))
        } else {
            None
        }
    }

    pub fn get_string(&self, topic: &str, query_time: u64, default: String) -> String {
        if let Some(TopicData::String(ts, vals)) = self.data.get(topic) {
            if ts.is_empty() {
                return default;
            }
            let idx = Self::get_index(ts, query_time);
            vals.get(idx).cloned().unwrap_or(default)
        } else {
            default
        }
    }

    pub fn get_double_array(&self, topic: &str, query_time: u64, default: Vec<f64>) -> Vec<f64> {
        if let Some(TopicData::DoubleArray(ts, vals)) = self.data.get(topic) {
            if ts.is_empty() {
                return default;
            }
            let idx = Self::get_index(ts, query_time);
            vals.get(idx).cloned().unwrap_or(default)
        } else {
            default
        }
    }

    pub fn get_boolean_array(&self, topic: &str, query_time: u64, default: Vec<bool>) -> Vec<bool> {
        if let Some(TopicData::BooleanArray(ts, vals)) = self.data.get(topic) {
            if ts.is_empty() {
                return default;
            }
            let idx = Self::get_index(ts, query_time);
            vals.get(idx).cloned().unwrap_or(default)
        } else {
            default
        }
    }

    pub fn get_string_array(
        &self,
        topic: &str,
        query_time: u64,
        default: Vec<String>,
    ) -> Vec<String> {
        if let Some(TopicData::StringArray(ts, vals)) = self.data.get(topic) {
            if ts.is_empty() {
                return default;
            }
            let idx = Self::get_index(ts, query_time);
            vals.get(idx).cloned().unwrap_or(default)
        } else {
            default
        }
    }

    pub fn get_raw(&self, topic: &str, query_time: u64) -> Option<Vec<u8>> {
        if let Some(TopicData::Raw(ts, vals)) = self.data.get(topic) {
            if ts.is_empty() {
                return None;
            }
            let idx = Self::get_index(ts, query_time);
            vals.get(idx).cloned()
        } else {
            None
        }
    }

    pub fn get_topics_info(&self) -> Vec<(String, String)> {
        self.data
            .iter()
            .map(|(k, v)| {
                let type_str = if let Some(t) = self.topic_types.get(k) {
                    t.as_str()
                } else {
                    match v {
                        TopicData::Double(_, _) => "double",
                        TopicData::Boolean(_, _) => "boolean",
                        TopicData::String(_, _) => "string",
                        TopicData::DoubleArray(_, _) => "double[]",
                        TopicData::BooleanArray(_, _) => "boolean[]",
                        TopicData::StringArray(_, _) => "string[]",
                        TopicData::Raw(_, _) => "raw",
                    }
                };
                (k.clone(), type_str.to_string())
            })
            .collect()
    }

    pub fn get_start_timestamp(&self) -> u64 {
        let mut min_ts = u64::MAX;
        for data in self.data.values() {
            let first = match data {
                TopicData::Double(ts, _) => ts.first(),
                TopicData::Boolean(ts, _) => ts.first(),
                TopicData::String(ts, _) => ts.first(),
                TopicData::DoubleArray(ts, _) => ts.first(),
                TopicData::BooleanArray(ts, _) => ts.first(),
                TopicData::StringArray(ts, _) => ts.first(),
                TopicData::Raw(ts, _) => ts.first(),
            };
            if let Some(&t) = first {
                if t < min_ts {
                    min_ts = t;
                }
            }
        }
        if min_ts == u64::MAX { 0 } else { min_ts }
    }

    pub fn get_last_timestamp(&self) -> u64 {
        let mut max_ts = 0;
        for data in self.data.values() {
            let last = data.last_timestamp();
            if last > max_ts {
                max_ts = last;
            }
        }
        max_ts
    }
}
