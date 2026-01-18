use byteorder::{ByteOrder, LittleEndian};
use rmpv::Value;
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct SchemaField {
    pub name: String,
    pub type_str: String,
    pub array_size: Option<usize>, // None if scalar, Some(size) if fixed array (e.g. double[3])
}

#[derive(Debug, Clone)]
pub struct Schema {
    pub name: String,
    pub fields: Vec<SchemaField>,
    pub size: usize, // Total size in bytes (calculated)
}

impl Schema {
    pub fn new(name: String, schema_str: &str) -> Self {
        let mut fields = Vec::new();
        let mut current_offset = 0;

        // Simple parser for "type name; type name;" format
        // Ignoring complicated nested structs for now, assuming primitives or we'll add support later.
        // Actually, the schema string might contain nested struct types.
        // Example: "double x; double y; rotation r;"

        let parts: Vec<&str> = schema_str
            .split(';')
            .map(|s| s.trim())
            .filter(|s| !s.is_empty())
            .collect();

        for part in parts {
            let tokens: Vec<&str> = part.split_whitespace().collect();
            if tokens.len() >= 2 {
                let type_str = tokens[0].to_string();
                let name = tokens[1].to_string();

                // TODO: Handle array syntax if needed (e.g. double[3] x) - NT4 schemas usually use fixed types or specific syntax.
                // For now assuming "type name"

                let size = Self::get_type_size(&type_str);
                current_offset += size;

                fields.push(SchemaField {
                    name,
                    type_str,
                    array_size: None,
                });
            }
        }

        Schema {
            name,
            fields,
            size: current_offset,
        }
    }

    fn get_type_size(type_str: &str) -> usize {
        match type_str {
            "double" | "float64" => 8,
            "float" | "float32" => 4,
            "bool" | "boolean" => 1,
            "int8" | "uint8" => 1,
            "int16" | "uint16" => 2,
            "int32" | "uint32" | "int" => 4,
            "int64" | "uint64" | "long" => 8,
            // Struct types (like "Transform3d") have variable sizes depending on their definition.
            // We can't determine their size without looking up their schema.
            // But for parsing THIS schema, we might need it.
            // However, the recursive decoding will happen at runtime using the schema map.
            // For now, return 0 for unknown types and handle dynamic size during decoding.
            _ => 0,
        }
    }
}

pub fn decode_struct(
    schema: &Schema,
    data: &[u8],
    schemas: &HashMap<String, Schema>, // Need access to other schemas for nested types
) -> Vec<(String, Value)> {
    let mut results = Vec::new();
    let mut cursor = 0;

    for field in &schema.fields {
        if cursor >= data.len() {
            break;
        }

        match field.type_str.as_str() {
            "double" | "float64" => {
                if cursor + 8 <= data.len() {
                    let val = LittleEndian::read_f64(&data[cursor..cursor + 8]);
                    results.push((field.name.clone(), Value::F64(val)));
                    cursor += 8;
                }
            }
            "float" | "float32" => {
                if cursor + 4 <= data.len() {
                    let val = LittleEndian::read_f32(&data[cursor..cursor + 4]);
                    results.push((field.name.clone(), Value::F32(val)));
                    cursor += 4;
                }
            }
            "bool" | "boolean" => {
                if cursor + 1 <= data.len() {
                    let val = data[cursor] != 0;
                    results.push((field.name.clone(), Value::Boolean(val)));
                    cursor += 1;
                }
            }
            "int32" | "int" => {
                if cursor + 4 <= data.len() {
                    let val = LittleEndian::read_i32(&data[cursor..cursor + 4]);
                    results.push((field.name.clone(), Value::Integer(val.into())));
                    cursor += 4;
                }
            }
            // Handle other primitives...

            // Nested structs
            other_type => {
                // Check if it's a known schema type
                // Schema names in map usually match the type name (e.g. "Pose3d")
                // Or "struct:Pose3d" -> we strip "struct:" when storing?
                // Let's assume schemas are stored by their short name "Pose3d".
                if let Some(nested_schema) = schemas.get(other_type) {
                    // Recurse
                    // We need to know how many bytes the nested struct takes.
                    // The schema.size might be 0 if it contains nested types.
                    // We should compute the actual size consumed by decoding.

                    // Wait, decode_struct returns values. We need to construct a sub-list.
                    // Actually, we want to flatten: "pose.translation.x"
                    // The `decode_struct` can return nested values, and the caller flattens?
                    // Or we flatten here: `field.name` + "." + `sub_field.name`

                    // Let's implement recursive flattening here.
                    // But we need to pass a slice of the remaining data.
                    let nested_values = decode_struct(nested_schema, &data[cursor..], schemas);

                    // How much data did we consume? We need `decode_struct` to return bytes consumed or we rely on computed size.
                    // If nested types are fixed size, `nested_schema.size` works.
                    // If `nested_schema.size` was 0 because it depended on others, we have a problem.
                    // Correct approach: Calculate full size of schema after all schemas are loaded?
                    // Or just make decode return consumed bytes.

                    // Let's make `decode_struct_internal` that returns (values, consumed).
                    // For now, let's assume we can calculate size if we have all schemas.

                    let consumed = calculate_size(nested_schema, schemas);

                    for (sub_key, sub_val) in nested_values {
                        results.push((format!("{}/{}", field.name, sub_key), sub_val));
                    }
                    cursor += consumed;
                } else {
                    // Unknown type, skip? Or panic?
                    // Ideally log error.
                    // For now, can't proceed if we don't know size.
                    break;
                }
            }
        }
    }

    results
}

pub fn calculate_size(schema: &Schema, schemas: &HashMap<String, Schema>) -> usize {
    let mut size = 0;
    for field in &schema.fields {
        let s = Schema::get_type_size(&field.type_str);
        if s > 0 {
            size += s;
        } else {
            // Nested
            if let Some(nested) = schemas.get(&field.type_str) {
                size += calculate_size(nested, schemas);
            }
        }
    }
    size
}
