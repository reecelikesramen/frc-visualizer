extends Node3D

var nt_instance = null
var topic_path: String = ""

# Visual Elements
var arrows: Array[Node3D] = []
var arrow_length_scale = 1.0 # Scale factor for speed -> length

# Swerve Layout (Standard Square Frame)
# Godot: Forward is -Z, Left is +X? No, standard 3D in Godot is Right(+X), Up(+Y), Forward(-Z)?
# Wait, FRC Coordinate System: Forward +X, Left +Y.
# We map FRC +X -> Godot -Z.
# We map FRC +Y -> Godot -X.
# So FL (FRC +X, +Y) -> Godot (-Z, -X).
#     FR (FRC +X, -Y) -> Godot (-Z, +X).
#     BL (FRC -X, +Y) -> Godot (+Z, -X).
#     BR (FRC -X, -Y) -> Godot (+Z, +X).

const MODULE_OFFSET = 0.3 # Meters from center
const MODULE_POSITIONS = [
	Vector3(-MODULE_OFFSET, 0, -MODULE_OFFSET), # FL (Godot: -X, -Z)
	Vector3(MODULE_OFFSET, 0, -MODULE_OFFSET), # FR (Godot: +X, -Z)
	Vector3(-MODULE_OFFSET, 0, MODULE_OFFSET), # BL (Godot: -X, +Z)
	Vector3(MODULE_OFFSET, 0, MODULE_OFFSET) # BR (Godot: +X, +Z)
]

func setup(nt: Node, path: String, context: Dictionary = {}):
	nt_instance = nt
	topic_path = path
	
	_create_arrows()

func _create_arrows():
	# Create 4 arrows
	for i in range(4):
		var arrow_root = Node3D.new()
		
		# Arrow Shaft
		var shaft = MeshInstance3D.new()
		var shaft_mesh = BoxMesh.new()
		shaft_mesh.size = Vector3(0.05, 0.05, 1.0) # Length 1 initially
		shaft.mesh = shaft_mesh
		shaft.position.z = -0.5 # Center the shaft so it grows from origin forward
		# Material (Red)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0, 0)
		shaft.mesh.surface_set_material(0, mat)
		
		arrow_root.add_child(shaft)
		
		# Arrow Head
		var head = MeshInstance3D.new()
		var head_mesh = PrismMesh.new()
		head_mesh.size = Vector3(0.15, 0.2, 0.15)
		head.mesh = head_mesh
		head.rotation.x = - PI / 2 # Point forward
		head.position.z = -1.0 # Tip of shaft
		head.mesh.surface_set_material(0, mat)
		
		arrow_root.add_child(head)
		
		# Store references for updates (we might scale the root or shaft)
		# Actually, scaling the root is easiest.
		arrows.append(arrow_root)
		add_child(arrow_root)
		
		# Set initial base positions (relative to this node)
		# If this node is parented to the robot, these are relative to robot center.
		# But wait, standard SwerveModuleState order is usually FL, FR, BL, BR or similar.
		# Let's assume standard order: 0: FL, 1: FR, 2: BL, 3: BR
		# Adjust positions if needed.
		if i < MODULE_POSITIONS.size():
			arrow_root.position = MODULE_POSITIONS[i]

func _process(_delta: float) -> void:
	if not nt_instance or topic_path == "":
		return

	# Fetch data
	# We expect struct:SwerveModuleState[]
	# The raw data is a PackedByteArray if using generic get_value, 
	# OR we might have a helper for module states if we added one. 
	# TopicRow used `StructParser.gd` to parse. We should probably use that too.
	
	var raw = nt_instance.get_value(topic_path, PackedByteArray())
	if typeof(raw) == TYPE_PACKED_BYTE_ARRAY and raw.size() > 0:
		# Assume StructParser is globally available or we load it
		# We need to know the type string exactly to parse.
		# But wait, `get_value` returns raw bytes.
		# Use `StructParser.parse_packet`.
		# We assume the topic is compatible.
		var data = StructParser.parse_packet(raw, "struct:SwerveModuleState[]")
		if typeof(data) == TYPE_ARRAY and data.size() >= 4:
			_update_visuals(data)

func _update_visuals(states: Array):
	for i in range(4):
		if i >= arrows.size(): break
		
		var state = states[i] # specific struct dictionary
		# Expected keys: "angle" (double, radians), "speed" (double, m/s)
		
		var angle = state.get("angle", 0.0)
		var speed = state.get("speed", 0.0)
		
		var arrow = arrows[i]
		
		# Rotation
		# Swerve angles are usually standard CCW from +X or +Y?
		# WPILib Rotation2d is CCW+, 0 is +X (forward).
		# Godot 3D: -Z is forward. +X is right. +Y is up.
		# So 0 degrees (forward) should be -Z.
		# If WPILib 0 is +X (Field Forward?), and usually robot forward.
		# Let's assume 0 radians = Robot Forward (-Z in Godot).
		# If 0 is +X in WPILib, and Field X is Forward...
		# Let's start with: Godot Y rotation = WPILib Angle.
		# But checking coordinate systems:
		# WPILib: X forward, Y left, Z up.
		# Godot: -Z forward, +X right, +Y up.
		# So WPILib +X -> Godot -Z.
		# WPILib +Y -> Godot -X (Left vs Right).
		# Rotation around Z (WPILib) -> Rotation around Y (Godot).
		# CCW in WPILib (X to Y) -> (-Z to -X).
		# Godot Top View: -Z is Up on screen, -X is Left. 
		# So CCW is correct.
		arrow.rotation.y = angle
		
		# Length/Scale
		# Scale the arrow length by speed.
		# Scale z axis.
		var length = abs(speed) * 0.5 # Scale factor
		if length < 0.1: length = 0.1 # Minimum visibility
		
		arrow.scale.z = length
		arrow.visible = true
