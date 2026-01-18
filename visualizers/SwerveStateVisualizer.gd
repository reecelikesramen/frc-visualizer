extends Node3D

var nt_instance = null
var topic_path: String = ""

# Visual Elements
var arrows: Array[Node3D] = []
var arrow_length_scale = 1.0 # Scale factor for speed -> length

# Structure Configuration
var arrangement_map: Array[int] = [0, 1, 2, 3] # visual_idx -> data_idx
var arrow_color: Color = Color(1, 0, 0) # Default Red

# Standard Visual Quadrants: FL, FR, BL, BR
# Godot Coordinates: Forward(-Z), Left(-X) -> Right(+X)
# FL: Forward, Left -> -Z, -X
# FR: Forward, Right -> -Z, +X
# BL: Back, Left -> +Z, -X
# BR: Back, Right -> +Z, +X
const MODULE_OFFSET = 0.3 # Meters from center
const MODULE_POSITIONS = [
	Vector3(-MODULE_OFFSET, 0, -MODULE_OFFSET), # FL (Godot: -X, -Z)
	Vector3(MODULE_OFFSET, 0, -MODULE_OFFSET), # FR (Godot: +X, -Z)
	Vector3(-MODULE_OFFSET, 0, MODULE_OFFSET), # BL (Godot: -X, +Z)
	Vector3(MODULE_OFFSET, 0, MODULE_OFFSET) # BR (Godot: +X, +Z)
]

const SMOOTH_SPEED = 30.0
# State tracking for smoothing
var current_angles: Array[float] = [0.0, 0.0, 0.0, 0.0]
var current_speeds: Array[float] = [0.0, 0.0, 0.0, 0.0]


# Map strings to Standard Position Indices
const QUADRANT_NAMES = ["FL", "FR", "BL", "BR"]

func setup(nt: Node, path: String, context: Dictionary = {}):
	nt_instance = nt
	topic_path = path

	# Parse Context Options
	# 1. Arrangement
	# Default: "FL/FR/BL/BR"
	var arr_str = "FL/FR/BL/BR"
	# User options might be nested? The registry says options struct.
	# But typically options are passed flattened or we look them up?
	# In the `add_visualizer` of `TopicDock`, we didn't extract user selections from a UI yet.
	# We just passed defaults/User selection from future UI. 
	# For now, let's assume if context has "options", we use it, else default.
	# Wait, relying on the user to *select* options in a menu hasn't been implemented in TopicDock yet.
	# But we need to support it IF passed.
	if context.has("Arrangement"):
		arr_str = context["Arrangement"]
	
	_parse_arrangement(arr_str)
	
	# 2. Color
	var color_name = "Red"
	if context.has("Color"):
		color_name = context["Color"]
	
	_set_color(color_name)
	
	_create_arrows()

func _parse_arrangement(arr_str: String):
	var tokens = arr_str.split("/")
	if tokens.size() != 4:
		push_warning("SwerveStateVisualizer: Invalid arrangement string '" + arr_str + "', utilizing default.")
		arrangement_map = [0, 1, 2, 3]
		return
		
	# visual_idx 0 is ALWAYS FL spatial position
	# We find where "FL" is in the tokens. That index is the data index.
	for i in range(4):
		var key = QUADRANT_NAMES[i]
		var data_idx = tokens.find(key)
		if data_idx == -1:
			push_warning("SwerveStateVisualizer: Missing key " + key + " in arrangement.")
			data_idx = i # Fallback
		
		# Ensure map is sized
		if arrangement_map.size() <= i:
			arrangement_map.resize(i + 1)
			
		arrangement_map[i] = data_idx

func _set_color(color_name: String):
	match color_name:
		"Red": arrow_color = Color.RED
		"Blue": arrow_color = Color.BLUE
		"Green": arrow_color = Color.GREEN
		"Orange": arrow_color = Color.ORANGE
		"Cyan": arrow_color = Color.CYAN
		"Yellow": arrow_color = Color.YELLOW
		"Magenta": arrow_color = Color.MAGENTA
		_: arrow_color = Color.RED

func _create_arrows():
	# Clear existing
	for c in get_children():
		c.queue_free()
	arrows.clear()
	
	# Create 4 arrows fixed to the 4 Quadrants
	for i in range(4):
		var arrow_root = Node3D.new()
		
		# Material
		var mat = StandardMaterial3D.new()
		mat.albedo_color = arrow_color
		
		# Arrow Shaft
		var shaft = MeshInstance3D.new()
		var shaft_mesh = BoxMesh.new()
		shaft_mesh.size = Vector3(0.05, 0.05, 1.0) # Length 1 initially
		shaft.mesh = shaft_mesh
		shaft.position.z = -0.5 # Grow forward from origin
		shaft.mesh.surface_set_material(0, mat)
		arrow_root.add_child(shaft)
		
		# Arrow Head
		var head = MeshInstance3D.new()
		var head_mesh = PrismMesh.new()
		head_mesh.size = Vector3(0.15, 0.2, 0.15)
		head.mesh = head_mesh
		head.rotation.x = - PI / 2
		head.position.z = -1.0
		head.mesh.surface_set_material(0, mat)
		arrow_root.add_child(head)
		
		add_child(arrow_root)
		arrows.append(arrow_root)
		
		# Position relative to robot center
		arrow_root.position = MODULE_POSITIONS[i]

func _process(_delta: float) -> void:
	if not nt_instance or topic_path == "":
		return

	# Parse Struct Array
	var raw = nt_instance.get_value(topic_path, PackedByteArray())
	if typeof(raw) == TYPE_PACKED_BYTE_ARRAY and raw.size() > 0:
		var data = StructParser.parse_packet(raw, "struct:SwerveModuleState[]")
		if typeof(data) == TYPE_ARRAY and data.size() >= 4:
			_process_smoothing(data, _delta)
			_update_visuals()

func _process_smoothing(target_states: Array, delta: float):
	for viz_idx in range(4):
		var data_idx = arrangement_map[viz_idx]
		if data_idx >= target_states.size(): continue
		
		var state = target_states[data_idx]
		var target_angle = state.get("angle", 0.0)
		var target_speed = state.get("speed", 0.0)
		
		# Interpolate
		current_angles[viz_idx] = lerp_angle(current_angles[viz_idx], target_angle, SMOOTH_SPEED * delta)
		current_speeds[viz_idx] = lerp(current_speeds[viz_idx], target_speed, SMOOTH_SPEED * delta)

func _update_visuals():
	for viz_idx in range(4):
		var angle = current_angles[viz_idx]
		var speed = current_speeds[viz_idx]
		
		var arrow = arrows[viz_idx]
		
		# Logic:
		# Angle=0 -> Forward (-Z).
		# Rotation Y is CCW around Up (+Y).
		# FRC Angle 0 is Forward +X. +90 is Left +Y.
		# Godot -Z is Forward. -X is Left. 
		# Rotation Y +90 turns -Z to -X.
		# So FRC Angle -> Godot Y Rotation is 1:1.
		
		# Direction Reversal for negative speed
		var effective_angle = angle
		if speed < 0:
			effective_angle += PI
			
		arrow.rotation.y = effective_angle
		
		# Length
		var length = abs(speed) * 0.5
		if length < 0.1: length = 0.1
		
		arrow.scale.z = length
		arrow.visible = true
