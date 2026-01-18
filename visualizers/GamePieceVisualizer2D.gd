extends Node2D

var nt_instance = null
var topic_path: String = ""
var field_2d = null

const FUEL_DIAMETER_INCHES = 5.91
const FUEL_DIAMETER_METERS = FUEL_DIAMETER_INCHES * 0.0254
const FUEL_COLOR = Color("#D1BB3D")

const SMOOTH_SPEED = 30.0

# Store current smoothed positions (Vector2 in field meters)
var current_positions: Array[Vector2] = []
var target_positions: Array[Vector2] = []

func setup(nt: Node, path: String, _context: Dictionary = {}):
	nt_instance = nt
	topic_path = path

	# Find Field2D parent
	var p = get_parent()
	while p and not p.has_method("field_to_pixel"):
		p = p.get_parent()
	field_2d = p

func _process(delta: float) -> void:
	if not nt_instance or topic_path == "" or not field_2d:
		return

	# Fetch latest data
	var new_targets: Array[Vector2] = []
	var poses: Array[Transform3D] = []
	
	# Determine how to fetch based on topic type (could pass nt_type in setup, but we don't have it stored easily yet without modifying setup again)
	# Easier: Try array fetch. If empty and topic isn't array type, try single.
	
	# Fix: Use explicit typed default array
	var default_arr: Array[Transform3D] = []
	poses = nt_instance.get_pose3d_array(topic_path, default_arr)
	
	# If empty, it might be a single Pose3D topic or a Translation3D topic
	if poses.is_empty():
		# Try single Pose3D
		var p = nt_instance.get_pose3d(topic_path, Transform3D())
		if p != Transform3D():
			poses.append(p)
		else:
			# Try Translation3D[] (Vector3[])
			# NT4 backend might expose get_vector3_array for double[] or specialized Translation3d[]
			# If the backend maps Translation3d[] to Pose3d[] automatically (with identity rot), get_pose3d_array would have worked.
			# If it maps to Vector3[], we need that.
			# Let's assume for now the user mainly uses Pose3D/Transform3D derivatives effectively mapped to Pose3D by the backend or explicitly.
			# If we need Translation3D support specifically, we might need a get_translation3d_array or similar.
			pass

	# FRC 3D -> Godot 2D Mapping (same as RobotVisualizer2D)
	# Rust GDExtension Mapping:
	# Godot X = -FRC Y (Width)
	# Godot Z = -FRC X (Length)
	for pose in poses:
		var frc_x = - pose.origin.z
		var frc_y = - pose.origin.x
		new_targets.append(Vector2(frc_x, frc_y))
		
	# Handle flat number arrays if needed later (TODO)
	
	# Resize current array to match target
	if current_positions.size() != new_targets.size():
		current_positions.resize(new_targets.size())
		# Initialize new elements if size grew (or shrink)
		# For new elements, snap to target to avoid flying in from (0,0)
		for i in range(new_targets.size()):
			# If this index was present before, keep it? 
			# But array resize in Godot preserves data up to min size.
			# If we grew, new elements are zero. 
			# Let's simple check distance. 
			pass
			
	# Update positions with smoothing
	for i in range(new_targets.size()):
		var target = new_targets[i]
		if current_positions[i] == Vector2.ZERO and target != Vector2.ZERO:
			 # Initial snap
			current_positions[i] = target
		else:
			current_positions[i] = current_positions[i].lerp(target, SMOOTH_SPEED * delta)
			
	target_positions = new_targets
	queue_redraw()

func _draw():
	if not field_2d: return
	
	var scale_factor = field_2d.get_m_to_px_scale()
	var radius_px = (FUEL_DIAMETER_METERS / 2.0) * scale_factor
	
	for pos_m in current_positions:
		var pos_px = field_2d.field_to_pixel(pos_m)
		# Draw in local space? No, this node is child of Field2D?
		# Wait, Field2D is a Control. RobotVisualizer2D extends Node2D.
		# If Field2D is the parent, and it's a Control, Node2D children position works relative to global or what?
		# RobotVisualizer2D sets `position = field_2d.field_to_pixel(...)`.
		# So RobotVisualizer2D moves the whole node.
		# Here we are drawing multiple items.
		# If we leave `position` at (0,0), then drawing at `pos_px` works if `pos_px` is local to this node.
		# `field_to_pixel` returns local coordinates relative to Field2D (Top-Left 0,0).
		# Since this Node2D is a child of Field2D, its origin (0,0) aligns with Field2D (0,0).
		# So drawing at `pos_px` is correct.
		
		# Draw circle
		draw_circle(pos_px, radius_px, FUEL_COLOR)
		# Optional: Draw outline
		draw_arc(pos_px, radius_px, 0, TAU, 16, Color.BLACK, 1.0, true)
