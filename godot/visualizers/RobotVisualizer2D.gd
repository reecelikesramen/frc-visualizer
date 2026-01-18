extends Node2D

var nt_instance = null
var topic_path: String = ""
var field_2d = null

# Visual properties
var robot_length = 0.8 # meters
var robot_width = 0.8 # meters
var bumper_color = Color.RED

const SMOOTH_SPEED = 30.0
var target_pose: Transform2D = Transform2D()
var current_pose: Transform2D = Transform2D()

func setup(nt: Node, path: String, context: Dictionary = {}):
	nt_instance = nt
	topic_path = path
	
	# Find Field2D parent
	var p = get_parent()
	while p and not p.has_method("field_to_pixel"):
		p = p.get_parent()
	field_2d = p
	
	if context.has("options"):
		var _opts = context["options"]
		# Handle options like color if needed
		pass

func _process(delta):
	if not nt_instance or topic_path == "" or not field_2d:
		return
		
	# Prioritize Pose3D which is more specific (56 bytes) than Pose2D (24 bytes).
	# get_pose2d will return garbage valid data if run on a Pose3D topic.
	var new_target_pose = Transform2D()
	var pose3d = nt_instance.get_pose3d(topic_path, Transform3D())
	
	if pose3d != Transform3D():
		# FRC Coordinate Recovery from Godot Transform3D
		# Rust GDExtension Mapping:
		# Godot X = -FRC Y (Width)
		# Godot Y = FRC Z (Height)
		# Godot Z = -FRC X (Length)
		var frc_x = - pose3d.origin.z
		var frc_y = - pose3d.origin.x
		
		# Rotation recovery
		# We need the Yaw (rotation around FRC Z / Godot Y)
		# Godot Y is FRC Z, so we can just grab Euler Y.
		var frc_rot = pose3d.basis.get_euler().y
		
		new_target_pose = Transform2D(frc_rot, Vector2(frc_x, frc_y))
	else:
		# Fallback to Pose2D
		var p2d = nt_instance.get_pose2d(topic_path, Transform2D())
		if p2d != Transform2D():
			new_target_pose = p2d
	
	if new_target_pose != Transform2D():
		target_pose = new_target_pose
		
	# Smoothly Interpolate
	current_pose = current_pose.interpolate_with(target_pose, SMOOTH_SPEED * delta)
	
	# Update Visuals
	if current_pose != Transform2D():
		# Map meter position to pixel position
		position = field_2d.field_to_pixel(current_pose.get_origin())
		
		# Rotation
		# FRC rotation is CCW positive, Godot 2D is CW positive?
		# Actually, it depends on the field projection.
		# If (+X, +Y) maps to (Right, Up) in pixel space, then rotation is CCW.
		# But Godot pixels are (Right, Down).
		# My field_to_pixel handles the flip if corner_00 and corner_max are set correctly.
		
		# Rotation Robust Mapping
		# This accounts for X/Y inversions in the field image mapping
		var rot = current_pose.get_rotation()
		var p0 = field_2d.field_to_pixel(Vector2.ZERO)
		var p_x = field_2d.field_to_pixel(Vector2(1, 0))
		var p_y = field_2d.field_to_pixel(Vector2(0, 1))
		
		var x_axis = p_x - p0
		var y_axis = p_y - p0
		
		var base_rot = x_axis.angle()
		# Determine parity: (Godot 2D is left-handed screen coords)
		var det = x_axis.x * y_axis.y - x_axis.y * y_axis.x
		if det > 0:
			# X -> Y is a CW turn in pixels (positive increment in Godot)
			rotation = base_rot + rot
		else:
			# X -> Y is a CCW turn in pixels (negative increment in Godot)
			rotation = base_rot - rot
			
		queue_redraw()

func _draw():
	if not field_2d: return
	
	# Calculate size in pixels
	var scale_factor = field_2d.get_m_to_px_scale()
	var size_px = Vector2(robot_length, robot_width) * scale_factor
	
	# Draw bumper rectangle
	var rect = Rect2(-size_px / 2.0, size_px)
	draw_rect(rect, bumper_color, false, 2.0)
	draw_rect(rect, Color(bumper_color, 0.3), true)
	
	# Draw "front" indicator (arrow or line)
	draw_line(Vector2(0, 0), Vector2(size_px.x / 2.0, 0), Color.WHITE, 2.0)
	draw_circle(Vector2(size_px.x / 2.0, 0), 3.0, Color.WHITE)
