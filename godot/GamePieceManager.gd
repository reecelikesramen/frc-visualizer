extends MultiMeshInstance3D

# Configure the path to the fuel mesh
# The user specified: godot/fields/rebuilt/assets/fuel.tres
# We expect this to be assigned in the inspector or loaded dynamically
const FUEL_MESH_PATH = "res://fields/rebuilt/assets/fuel.tres"
const NT_TOPIC_PATH = "/AdvantageKit/RealOutputs/FieldSimulation/FuelPositions"

# NT4 Instance
var nt = null

func _ready():
	# 1. Setup Mesh
	if not multimesh:
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		# Optimized for many objects
		multimesh.use_colors = false
		multimesh.use_custom_data = false
	
	var mesh_res = load(FUEL_MESH_PATH)
	if mesh_res:
		multimesh.mesh = mesh_res
	else:
		push_error("Could not load fuel mesh from: " + FUEL_MESH_PATH)

	# 2. Setup NT4
	# We create a new clieant to ensure we have access. 
	# Ideally this should be a singleton or passed in, but this is robust for now.
	nt = NT4.new()
	add_child(nt)
	nt.start_client("127.0.0.1") # Connects to localhost (Simulation)

func _process(delta):
	if not nt: return
	
	# Fetch the array of Transform3D from NT (using our new C++ helper)
	var poses = nt.get_pose3d_array(NT_TOPIC_PATH, [])
	var count = poses.size()
	
	# Update visible instance count
	if multimesh.instance_count < count:
		multimesh.instance_count = count + 100 # Add some buffer
		
	multimesh.visible_instance_count = count
	
	# Update instances
	for i in range(count):
		# The C++ method already handles coordinate conversion!
		multimesh.set_instance_transform(i, poses[i])
