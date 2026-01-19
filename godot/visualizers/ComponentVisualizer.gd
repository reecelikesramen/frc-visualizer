extends Node3D

var nt_instance = null
var topic_path: String = ""

# Store where we WANT to be
var target_pose: Transform3D = Transform3D()

# Tuning knob: Higher = Snappier (but jittery), Lower = Smoother (but laggy)
const SMOOTH_SPEED = 30.0

# 3D Model Management
var model_node: Node3D = null
var model_offset: Vector3 = Vector3.ZERO
var model_rotation: Vector3 = Vector3.ZERO
var current_model_path: String = ""

func setup(nt: Node, path: String, context: Dictionary = {}):
	nt_instance = nt
	topic_path = path
	
	_ensure_default_model()

func _ready():
	target_pose = global_transform

func _process(delta: float) -> void:
	if not nt_instance or topic_path == "":
		return

	valid_nt_update()
	transform = transform.interpolate_with(target_pose, SMOOTH_SPEED * delta)

func valid_nt_update():
	# Components might be Transform3d or Pose3d
	# Prioritize Transform3d for components usually? Or just use same logic.
	# The registry allows Pose3d, Transform3d.
	# NT4 lib usually distinguishes.
	# Try Pose3d first (most common for "Robot"-like things)
	# Or just generic get_pose3d which falls back?
	# Let's try to detect type if possible, or just ask implementation.
	# Just reuse the robust logic from RobotVisualizer for now given the types are same intersection
	var val = nt_instance.get_value(topic_path, null)
	
	if val is PackedByteArray and val.size() == 24:
		# Pose2d/Transform2d
		var p2d = nt_instance.get_pose2d(topic_path, Transform2D())
		var x = p2d.origin.y
		var z = - p2d.origin.x
		var yaw = - p2d.get_rotation()
		target_pose = Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0.0, z))
	else:
		# Pose3d/Transform3d
		target_pose = nt_instance.get_pose3d(topic_path, target_pose)

# --- Model Management API ---

func set_model_offset(offset: Vector3):
	model_offset = _convert_frc_offset(offset)
	if model_node:
		model_node.position = model_offset

func set_model_rotation(degrees: Vector3):
	model_rotation = _convert_frc_rotation(degrees)
	if model_node:
		model_node.rotation_degrees = model_rotation

func _convert_frc_offset(vec: Vector3) -> Vector3:
	return Vector3(-vec.y, vec.z, -vec.x)

func _convert_frc_rotation(euler_deg: Vector3) -> Vector3:
	var r = deg_to_rad(euler_deg.x)
	var p = deg_to_rad(euler_deg.y)
	var y = deg_to_rad(euler_deg.z)
	
	var b = Basis()
	b = b.rotated(Vector3(0, 1, 0), y) # Z_frc -> Y_godot
	b = b.rotated(Vector3(-1, 0, 0), p) # Y_frc -> -X_godot
	b = b.rotated(Vector3(0, 0, -1), r) # X_frc -> -Z_godot
	
	return b.get_euler() * (180.0 / PI)

func set_custom_model(path: String):
	if path == current_model_path and path != "":
		return
		
	var gltf = GLTFDocument.new()
	var state = GLTFState.new()
	var err = gltf.append_from_file(path, state)
	
	if err == OK:
		var scene = gltf.generate_scene(state)
		_replace_model_node(scene)
		current_model_path = path
	else:
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is PackedScene:
				_replace_model_node(res.instantiate())
				current_model_path = path
			elif res is Mesh:
				var mi = MeshInstance3D.new()
				mi.mesh = res
				_replace_model_node(mi)
				current_model_path = path
		else:
			push_warning("ComponentVisualizer: Failed to load model from " + path)

func _replace_model_node(new_node: Node3D):
	if model_node:
		model_node.queue_free()
		remove_child(model_node)
	
	model_node = new_node
	add_child(model_node)
	model_node.position = model_offset
	model_node.rotation_degrees = model_rotation
	model_node.visible = true
	
	# Force visibility update if parent or tree state was lagging
	if is_inside_tree():
		model_node.force_update_transform()

func _ensure_default_model():
	if not model_node:
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = BoxMesh.new()
		mesh_inst.mesh.size = Vector3(0.3, 0.3, 0.3) # Slightly smaller default for components
		_replace_model_node(mesh_inst)
