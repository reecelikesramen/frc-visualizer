extends MultiMeshInstance3D

# Default configuration from GamePieceManager
const DEFAULT_MESH_PATH = "res://fields/rebuilt/assets/fuel.tres"

var nt_instance = null
var topic_path: String = ""

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
		# Try to load default if no mesh set
		var mesh_res = load(DEFAULT_MESH_PATH)
		if mesh_res:
			multimesh.mesh = mesh_res
		else:
			push_warning("RobotVisualizer: Could not load default mesh and none provided.")

func _process(delta):
	if not nt_instance or topic_path == "":
		return
	
	# Fetch the array of Transform3D from NT
	var poses = nt_instance.get_pose3d_array(topic_path, [])
	var count = poses.size()
	
	# Update visible instance count
	if multimesh.instance_count < count:
		multimesh.instance_count = count + 100 # Add buffer
		
	multimesh.visible_instance_count = count
	
	# Update instances
	for i in range(count):
		# The C++ method handles coordinate conversion
		multimesh.set_instance_transform(i, poses[i])
