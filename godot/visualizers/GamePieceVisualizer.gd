extends MultiMeshInstance3D

# Default configuration from GamePieceManager
const DEFAULT_MESH_PATH = "res://fields/rebuilt/assets/fuel.tres"

# Tuning knob: Higher = Snappier (but jittery), Lower = Smoother (but laggy)
const SMOOTH_SPEED = 30.0

var nt_instance = null
var topic_path: String = ""

# Keep track of current and target transforms for each instance to allow smoothing
var target_poses: Array[Transform3D] = []
var current_poses: Array[Transform3D] = []

func setup(nt: Node, path: String, context: Dictionary = {}, mesh_resource: Mesh = null):
	nt_instance = nt
	topic_path = path
	
	if not multimesh:
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = false
		multimesh.use_custom_data = false
	
	if mesh_resource:
		multimesh.mesh = mesh_resource
	elif multimesh.mesh == null:
		# Procedural Sphere Mesh for Fuel
		var sphere = SphereMesh.new()
		# 5.91 inches diameter -> 0.150114 meters -> radius ~ 0.075
		sphere.radius = (5.91 * 0.0254) / 2.0
		sphere.height = sphere.radius * 2.0
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color("#D1BB3D") # Yellow
		sphere.surface_set_material(0, mat)
		
		multimesh.mesh = sphere

func _process(delta: float) -> void:
	if not nt_instance or topic_path == "":
		return
	
	# 1. Fetch the latest data from NT
	valid_nt_update()
	
	# 2. Smoothly Interpolate All Instances
	var count = target_poses.size()
	
	# Update visible instance count
	if multimesh.instance_count < count:
		multimesh.instance_count = count + 100 # Add buffer
	
	multimesh.visible_instance_count = count
	
	# Resize current poses if needed
	if current_poses.size() < count:
		var old_size = current_poses.size()
		current_poses.resize(count)
		for i in range(old_size, count):
			current_poses[i] = target_poses[i] # Snap new pieces to target initially

	# Update instances
	for i in range(count):
		# Interpolate
		current_poses[i] = current_poses[i].interpolate_with(target_poses[i], SMOOTH_SPEED * delta)
		multimesh.set_instance_transform(i, current_poses[i])

func valid_nt_update():
	# Fetch the array of Transform3D from NT
	var default_arr: Array[Transform3D] = []
	var data = nt_instance.get_pose3d_array(topic_path, default_arr)
	
	if data.is_empty():
		# Try single Pose3D
		var p = nt_instance.get_pose3d(topic_path, Transform3D())
		if p != Transform3D():
			data.append(p)
			
	target_poses = data
