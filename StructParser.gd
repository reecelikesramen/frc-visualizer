class_name StructParser
extends RefCounted

# Helper to decode bytes.

static func parse_packet(data: PackedByteArray, schema_type: String) -> Variant:
	if data.size() == 0:
		return null
		
	# Handle Arrays
	if schema_type.ends_with("[]"):
		var base_type = schema_type.substr(0, schema_type.length() - 2)
		return parse_struct_array(data, base_type)
		
	if schema_type == "struct:SwerveModuleState":
		return parse_swerve_module_state(data)
	elif schema_type == "struct:Pose3d":
		return parse_pose3d(data)
	elif schema_type == "struct:Pose2d":
		return parse_pose2d(data)
	elif schema_type == "struct:Translation3d":
		return parse_translation3d(data)
	elif schema_type == "struct:Translation2d":
		return parse_translation2d(data)
	elif schema_type == "struct:Rotation3d":
		return parse_rotation3d(data)
	elif schema_type == "struct:Rotation2d":
		return parse_rotation2d(data)
	elif schema_type == "struct:ChassisSpeeds":
		return parse_chassis_speeds(data)
		
	return "Raw Data (" + str(data.size()) + " bytes)"

# --- Parsers ---

static func parse_struct_array(data: PackedByteArray, base_type: String) -> Array:
	var result = []
	var stride = get_struct_size(base_type)
	if stride <= 0: return []
	
	var count = data.size() / stride
	for i in range(count):
		var slice = data.slice(i * stride, (i + 1) * stride)
		var val = parse_packet(slice, base_type)
		result.append(val)
	return result

static func get_struct_size(type: String) -> int:
	match type:
		"struct:Pose3d": return 56
		"struct:Pose2d": return 24
		"struct:Translation3d": return 24
		"struct:Translation2d": return 16
		"struct:Rotation3d": return 32
		"struct:Rotation2d": return 8
		"struct:SwerveModuleState": return 16
		"struct:ChassisSpeeds": return 24
	return 0

static func parse_pose3d(data: PackedByteArray) -> Variant:
	if data.size() < 56: return null
	var arr = data.to_float64_array() 
	var tx = arr[0]; var ty = arr[1]; var tz = arr[2]
	var qw = arr[3]; var qx = arr[4]; var qy = arr[5]; var qz = arr[6]
	var origin = Vector3(-ty, tz, -tx)
	var q = Quaternion(-qy, qz, -qx, qw)
	return Transform3D(Basis(q), origin)

static func parse_pose2d(data: PackedByteArray) -> Variant:
	if data.size() < 24: return null
	var tx = data.decode_double(0)
	var ty = data.decode_double(8)
	var rot = data.decode_double(16)
	var pos = Vector2(tx, -ty)
	var godot_rot = -rot
	return Transform2D(godot_rot, pos)

static func parse_translation3d(data: PackedByteArray) -> Variant:
	if data.size() < 24: return null
	var arr = data.to_float64_array()
	return Vector3(-arr[1], arr[2], -arr[0])

static func parse_translation2d(data: PackedByteArray) -> Variant:
	if data.size() < 16: return null
	var tx = data.decode_double(0)
	var ty = data.decode_double(8)
	return Vector2(tx, -ty)

static func parse_rotation3d(data: PackedByteArray) -> Variant:
	if data.size() < 32: return null
	var arr = data.to_float64_array()
	var qw = arr[0]; var qx = arr[1]; var qy = arr[2]; var qz = arr[3]
	return Quaternion(-qy, qz, -qx, qw)

static func parse_rotation2d(data: PackedByteArray) -> Variant:
	if data.size() < 8: return null
	var rot = data.decode_double(0)
	return -rot

static func parse_swerve_module_state(data: PackedByteArray) -> Dictionary:
	if data.size() < 16: return {}
	var speed = data.decode_double(0)
	var angle = data.decode_double(8)
	return {
		"speed": speed,
		"angle": angle,
		"_type": "SwerveModuleState"
	}

static func parse_chassis_speeds(data: PackedByteArray) -> Dictionary:
	if data.size() < 24: return {}
	var vx = data.decode_double(0)
	var vy = data.decode_double(8)
	var omega = data.decode_double(16)
	return {
		"vx": vx,
		"vy": vy,
		"omega": omega,
		"_type": "ChassisSpeeds"
	}

# --- Formatting ---

static func format_value(val: Variant, short: bool = false) -> String:
	if typeof(val) == TYPE_DICTIONARY:
		if val.has("_type"):
			var type = val["_type"]
			if short:
				return type
			
			if type == "SwerveModuleState":
				return "Spd: %.2f m/s, Ang: %.2f rad" % [val.get("speed", 0), val.get("angle", 0)]
			if type == "ChassisSpeeds":
				return "vx: %.2f, vy: %.2f, ohm: %.2f" % [val.get("vx", 0), val.get("vy", 0), val.get("omega", 0)]
			if type == "Quaternion":
				# Convert Godot -> FRC Mapping for display: (-y, z, -x, w)
				# But wait, raw Quaternion from struct parse is ALREADY in Godot coords.
				# FRC(x, y, z, w) -> Godot(-y, z, -x, w)
				# So Inverse: 
				# FRC_x = -Godot_z
				# FRC_y = -Godot_x
				# FRC_z = Godot_y
				# FRC_w = Godot_w
				return "Quat(%.2f, %.2f, %.2f, %.2f)" % [-val["z"], -val["x"], val["y"], val["w"]]
			if type == "Euler":
				return "RPY(%.1f, %.1f, %.1f)" % [val["roll"], val["pitch"], val["yaw"]]
				
		return str(val)
		
	elif typeof(val) == TYPE_ARRAY:
		if val.size() > 0:
			var first = val[0]
			if short:
				if typeof(first) == TYPE_TRANSFORM3D: return "Pose3d[%d]" % val.size()
				if typeof(first) == TYPE_TRANSFORM2D: return "Pose2d[%d]" % val.size()
				if typeof(first) == TYPE_DICTIONARY and first.get("_type") == "SwerveModuleState":
					return "SwerveState[%d]" % val.size()
				if typeof(first) == TYPE_DICTIONARY and first.get("_type") == "ChassisSpeeds":
					return "ChassisSpeeds[%d]" % val.size()
				return "Array[%d]" % val.size()
			else:
				if typeof(first) == TYPE_TRANSFORM3D: return "Pose3d[%d]" % val.size()
				if typeof(first) == TYPE_TRANSFORM2D: return "Pose2d[%d]" % val.size()
				if typeof(first) == TYPE_DICTIONARY and first.get("_type") == "SwerveModuleState":
					return "SwerveState[%d]" % val.size()
				if typeof(first) == TYPE_DICTIONARY and first.get("_type") == "ChassisSpeeds":
					return "ChassisSpeeds[%d]" % val.size()

		return "Array[%d]" % val.size()

	elif typeof(val) == TYPE_PACKED_BYTE_ARRAY:
		return "Raw[%d]" % val.size()
		
	elif typeof(val) == TYPE_TRANSFORM3D:
		if short: return "Pose3d"
		# Convert to FRC
		var o = val.origin
		var frc_x = -o.z
		var frc_y = -o.x
		var frc_z = o.y
		
		# For Rotation, we convert the basis to Quaternion then map, or just Euler 
		# But usually people want Translation + Rotation
		var r = val.basis.get_euler()
		return "Pose(%.2f, %.2f, %.2f) YPR: %.2f, %.2f, %.2f" % [frc_x, frc_y, frc_z, rad_to_deg(r.y), rad_to_deg(r.x), rad_to_deg(r.z)]
		
	elif typeof(val) == TYPE_TRANSFORM2D:
		if short: return "Pose2d"
		var o = val.origin
		var r = val.get_rotation()
		return "Pose(%.2f, %.2f) Deg: %.2f" % [o.x, o.y, rad_to_deg(r)]
		
	elif typeof(val) == TYPE_VECTOR3:
		if short: return "Translation3d"
		# Godot -> FRC
		var frc_x = -val.z
		var frc_y = -val.x
		var frc_z = val.y
		var fmt = "%.4f" if short else "%.2f"
		return ("(" + fmt + ", " + fmt + ", " + fmt + ")") % [frc_x, frc_y, frc_z]
		
	elif typeof(val) == TYPE_VECTOR2:
		if short: return "Translation2d"
		return "(%.2f, %.2f)" % [val.x, val.y]
		
	elif typeof(val) == TYPE_QUATERNION:
		if short: return "Rotation3d"
		# Godot -> FRC
		var frc_x = -val.z
		var frc_y = -val.x
		var frc_z = val.y
		var frc_w = val.w
		return "Quat(%.2f, %.2f, %.2f, %.2f)" % [frc_x, frc_y, frc_z, frc_w]
	
	return str(val)

# --- Tree Expansion Helper ---

static func to_dictionary(val: Variant) -> Variant:
	if typeof(val) == TYPE_TRANSFORM3D:
		var o = val.origin
		# Godot -> FRC Logic in Dictionary?
		# The dictionary is used for the Tree View expansion. 
		# If the user wants to see FRC coords IN THE EXPANDED ITEMS, we should convert here.
		
		var frc_x = -o.z
		var frc_y = -o.x
		var frc_z = o.y
		
		var trans = { "x": frc_x, "y": frc_y, "z": frc_z, "_type": "Translation3d" }
		
		# Rotation breakdown
		var r = val.basis.get_euler()
		var q = val.basis.get_rotation_quaternion()
		
		# Convert Quat
		var frc_qx = -q.z
		var frc_qy = -q.x
		var frc_qz = q.y 
		var frc_qw = q.w
		
		var rot = {
			"Quaternion": { "x": frc_qx, "y": frc_qy, "z": frc_qz, "w": frc_qw, "_type": "Quaternion" },
			"Euler": { "roll": rad_to_deg(r.x), "pitch": rad_to_deg(r.y), "yaw": rad_to_deg(r.z), "_type": "Euler" },
			"_type": "Rotation3d"
		}
		
		return {
			"Translation": trans,
			"Rotation": rot,
			"_type": "Pose3d"
		}
	elif typeof(val) == TYPE_TRANSFORM2D:
		var o = val.origin
		var r = val.get_rotation()
		return {
			"Translation": { "x": o.x, "y": o.y, "_type": "Translation2d" },
			"Rotation": { "deg": rad_to_deg(r), "rad": r, "_type": "Rotation2d" },
			"_type": "Pose2d"
		}
	elif typeof(val) == TYPE_VECTOR3:
		# Godot -> FRC
		var frc_x = -val.z
		var frc_y = -val.x
		var frc_z = val.y
		return { "x": frc_x, "y": frc_y, "z": frc_z, "_type": "Translation3d" }
	elif typeof(val) == TYPE_VECTOR2:
		return { "x": val.x, "y": val.y, "_type": "Translation2d" }
	elif typeof(val) == TYPE_QUATERNION:
		var r = val.get_euler()
		
		var frc_qx = -val.z
		var frc_qy = -val.x
		var frc_qz = val.y 
		var frc_qw = val.w
		
		return {
			"Quaternion": { "x": frc_qx, "y": frc_qy, "z": frc_qz, "w": frc_qw, "_type": "Quaternion" },
			"Euler": { "roll": rad_to_deg(r.x), "pitch": rad_to_deg(r.y), "yaw": rad_to_deg(r.z), "_type": "Euler" },
			"_type": "Rotation3d"
		}
	elif typeof(val) == TYPE_ARRAY or \
		 typeof(val) == TYPE_PACKED_BYTE_ARRAY or \
		 typeof(val) == TYPE_PACKED_FLOAT32_ARRAY or \
		 typeof(val) == TYPE_PACKED_FLOAT64_ARRAY or \
		 typeof(val) == TYPE_PACKED_INT32_ARRAY or \
		 typeof(val) == TYPE_PACKED_INT64_ARRAY or \
		 typeof(val) == TYPE_PACKED_STRING_ARRAY:
		var ret = []
		for item in val:
			ret.append(to_dictionary(item))
		return ret
	elif typeof(val) == TYPE_DICTIONARY:
		return val
		
	return val

# --- Editing Helper ---
# Updates a specific field in a struct and returns the new full byte array
static func update_struct(original_bytes: PackedByteArray, type_str: String, path_to_field: String, new_value_str: String) -> PackedByteArray:
	# 1. Parse full struct
	var current_val = parse_packet(original_bytes, type_str)
	var dict = to_dictionary(current_val) # Nested dict
	
	# 2. Navigate and Update
	# path_to_field e.g. "Translation/x" or "Rotation/Euler/yaw"
	var parts = path_to_field.split("/")
	var target = dict
	for i in range(parts.size() - 1):
		target = target[parts[i]]
	
	var field = parts[parts.size() - 1]
	
	# Try to parse new value
	var val: Variant = new_value_str
	if new_value_str.is_valid_float():
		val = new_value_str.to_float()
	
	target[field] = val
	
	# 3. Re-Encode
	# We need access to the modified dict to rebuild the struct.
	# But `to_dictionary` is lossy (e.g. Euler vs Quat).
	# For "Tuning", we assume simpler edits.
	# We better rebuild the Godot Type (Transform3D etc) from the Dict, then Encode.
	
	var new_object = from_dictionary(dict, type_str)
	return encode_struct(new_object, type_str)

static func from_dictionary(dict: Dictionary, type: String) -> Variant:
	match type:
		"struct:Pose3d":
			var t = dict["Translation"]
			var origin = Vector3(t["x"], t["y"], t["z"])
			
			var r = dict["Rotation"]
			# Prefer Quaternion if available, else Euler?
			# Actually logic should track which one changed?
			# But for now let's use Quaternion as ground truth if exists.
			var q_dict = r["Quaternion"]
			var q = Quaternion(q_dict["x"], q_dict["y"], q_dict["z"], q_dict["w"])
			return Transform3D(Basis(q), origin)
			
	return null

static func encode_struct(val: Variant, type: String) -> PackedByteArray:
	var bytes = PackedByteArray()
	
	match type:
		"struct:Pose3d":
			# FRC: Translation(x, y, z), Rotation(w, x, y, z)
			# Godot: origin.x = -y_frc, origin.y = z_frc, origin.z = -x_frc
			# => y_frc = -origin.x, z_frc = origin.y, x_frc = -origin.z
			var t = val.origin
			var fx = -t.z
			var fy = -t.x
			var fz = t.y
			
			bytes.resize(56)
			bytes.encode_double(0, fx)
			bytes.encode_double(8, fy)
			bytes.encode_double(16, fz)
			
			var q = val.basis.get_rotation_quaternion()
			# FRC: w, x, y, z. Godot: x, y, z, w
			# Mapping: FRC(x, y, z, w) -> Godot(-y, z, -x, w)
			# => x_frc = -z_godot, y_frc = -x_godot, z_frc = y_godot
			var fqw = q.w
			var fqx = -q.z
			var fqy = -q.x
			var fqz = q.y 
			
			bytes.encode_double(24, fqw)
			bytes.encode_double(32, fqx)
			bytes.encode_double(40, fqy)
			bytes.encode_double(48, fqz)
			
	return bytes
