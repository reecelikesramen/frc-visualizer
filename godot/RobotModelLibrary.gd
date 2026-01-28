extends Node

# RobotModelLibrary - Singleton for managing custom robot models
# Registered as autoload "RobotModelLibrary" in project settings

const SAVE_PATH = "user://robot_models.json"

# Structure:
# {
#   "custom_robots": {
#     "Robot Name": {
#       "chassis_model": "user://models/xxx.glb",
#       "chassis_offset": [0.0, 0.0, 0.0],
#       "chassis_rotation": [0.0, 0.0, 0.0],
#       "components": {
#         "Component Name": {
#           "model": "user://models/yyy.glb",
#           "offset": [0.0, 0.0, 0.0],
#           "rotation": [0.0, 0.0, 0.0]
#         }
#       }
#     }
#   }
# }

var _library: Dictionary = {"custom_robots": {}}

func _ready():
	load_library()

# --- Persistence ---

func load_library():
	if FileAccess.file_exists(SAVE_PATH):
		var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var json = JSON.new()
			var err = json.parse(f.get_as_text())
			if err == OK:
				_library = json.data
			else:
				push_warning("RobotModelLibrary: Failed to parse JSON: " + json.get_error_message())
			f.close()

func save_library():
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_library, "\t"))
		f.close()

# --- Custom Robot CRUD ---

func get_custom_robot_names() -> Array[String]:
	var names: Array[String] = []
	for name in _library.get("custom_robots", {}).keys():
		names.append(name)
	return names

func get_custom_robot(robot_name: String) -> Dictionary:
	return _library.get("custom_robots", {}).get(robot_name, {})

func add_custom_robot(robot_name: String, config: Dictionary):
	if not _library.has("custom_robots"):
		_library["custom_robots"] = {}
	_library["custom_robots"][robot_name] = config
	save_library()

func update_custom_robot(robot_name: String, config: Dictionary):
	add_custom_robot(robot_name, config)

func delete_custom_robot(robot_name: String):
	if _library.has("custom_robots") and _library["custom_robots"].has(robot_name):
		_library["custom_robots"].erase(robot_name)
		save_library()

func rename_custom_robot(old_name: String, new_name: String):
	if old_name == new_name:
		return
	var config = get_custom_robot(old_name)
	if config.is_empty():
		return
	delete_custom_robot(old_name)
	add_custom_robot(new_name, config)

# --- Component Helpers ---

func get_component_names(robot_name: String) -> Array[String]:
	var robot = get_custom_robot(robot_name)
	var names: Array[String] = []
	for name in robot.get("components", {}).keys():
		names.append(name)
	return names

func get_component(robot_name: String, component_name: String) -> Dictionary:
	var robot = get_custom_robot(robot_name)
	return robot.get("components", {}).get(component_name, {})

func add_component(robot_name: String, component_name: String, config: Dictionary):
	var robot = get_custom_robot(robot_name)
	if robot.is_empty():
		return
	if not robot.has("components"):
		robot["components"] = {}
	robot["components"][component_name] = config
	update_custom_robot(robot_name, robot)

func delete_component(robot_name: String, component_name: String):
	var robot = get_custom_robot(robot_name)
	if robot.is_empty():
		return
	if robot.has("components") and robot["components"].has(component_name):
		robot["components"].erase(component_name)
		update_custom_robot(robot_name, robot)

# --- Utility: Build config from vectors ---

static func make_robot_config(chassis_model: String, chassis_offset: Vector3, chassis_rotation: Vector3) -> Dictionary:
	return {
		"chassis_model": chassis_model,
		"chassis_offset": [chassis_offset.x, chassis_offset.y, chassis_offset.z],
		"chassis_rotation": [chassis_rotation.x, chassis_rotation.y, chassis_rotation.z],
		"components": {}
	}

static func make_component_config(model: String, offset: Vector3, rotation: Vector3) -> Dictionary:
	return {
		"model": model,
		"offset": [offset.x, offset.y, offset.z],
		"rotation": [rotation.x, rotation.y, rotation.z]
	}

# --- Utility: Parse vectors from config ---

static func parse_vector3(arr: Array) -> Vector3:
	if arr.size() >= 3:
		return Vector3(arr[0], arr[1], arr[2])
	return Vector3.ZERO
