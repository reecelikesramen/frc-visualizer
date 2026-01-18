extends Node2D

var nt_instance = null
var topic_path: String = ""

# Visual Preferences
var arrow_color: Color = Color(1, 0, 0) # Default Red
var arrow_length_scale = 100.0 # Pixels per speed unit (if speed is m/s, 1m/s = 100px? Need to check field scale)

# Standard Visual Quadrants: FL, FR, BL, BR
# Godot 2D Robot Local Space: +X Forward, +Y Right (Standard FRC 2D if we adhere to it?)
# Wait, RobotVisualizer2D uses field_to_pixel.
# If this is nested under RobotVisualizer2D, it inherits the Robot's transform (position and rotation).
# So we are in "Robot Local Frame".
# In Godot 2D: +X is Right, +Y is Down (Screen coords).
# But RobotVisualizer2D sets rotation. 
# Let's assume the parent (RobotVisualizer2D) is rotated such that its +X axis aligns with Robot Forward.
# If RobotVisualizer2D draws a line from (0,0) to (Length/2, 0) as "Front", then +X is Forward in local space.

const MODULE_OFFSET = 0.3 # Meters from center
# 4 Corners in Standard FRC Order: FL, FR, BL, BR
# Local Coords (Forward X, Left Y):
# FL: +X, +Y (Forward, Left)
# FR: +X, -Y (Forward, Right)
# BL: -X, +Y (Back, Left)
# BR: -X, -Y (Back, Right)
# BUT wait, standard FRC 2d cordinate system usually is +X Forward, +Y Left.
# Let's double check RobotVisualizer2D _draw method:
# draw_line(Vector2(0, 0), Vector2(size_px.x / 2.0, 0), Color.WHITE, 2.0) checks out as +X being forward visualization.
# "Rect" is drawn centered.
# So we need to map our Modules to this Local +X Forward frame.

const MODULE_POSITIONS_METERS = [
	Vector2(MODULE_OFFSET, MODULE_OFFSET), # FL: Forward(+X), Left(+Y FRC? Wait.)
	Vector2(MODULE_OFFSET, -MODULE_OFFSET), # FR: Forward(+X), Right(-Y FRC?)
	Vector2(-MODULE_OFFSET, MODULE_OFFSET), # BL: Back(-X), Left(+Y FRC?)
	Vector2(-MODULE_OFFSET, -MODULE_OFFSET) # BR: Back(-X), Right(-Y FRC?)
]
# Note on Coordinate Systems:
# If the Field2D maps the field such that we are viewing it Top-Down:
# Typically FRC: +X Forward, +Y Left.
# Godot 2D: +X Right, +Y Down.
# RobotVisualizer2D rotation logic:
# if det > 0: rotation = base_rot + rot
# Visuals: +X is "Forward" relative to robot.
# So we just need to place modules relative to (0,0) in meters, then scale to pixels.

var arrangement_map: Array[int] = [0, 1, 2, 3] # visual_idx -> data_idx
const QUADRANT_NAMES = ["FL", "FR", "BL", "BR"]

const SMOOTH_SPEED = 30.0
# State tracking for smoothing
var current_angles: Array[float] = [0.0, 0.0, 0.0, 0.0]
var current_speeds: Array[float] = [0.0, 0.0, 0.0, 0.0]

func setup(nt: Node, path: String, context: Dictionary = {}):
	nt_instance = nt
	topic_path = path

	# Parse Context Options
	var arr_str = "FL/FR/BL/BR"
	if context.has("Arrangement"):
		arr_str = context["Arrangement"]
	_parse_arrangement(arr_str)
	
	var color_name = "Red"
	if context.has("Color"):
		color_name = context["Color"]
	_set_color(color_name)

func _parse_arrangement(arr_str: String):
	var tokens = arr_str.split("/")
	if tokens.size() != 4:
		arrangement_map = [0, 1, 2, 3]
		return
	
	# Mapping visual_idx (FL, FR, BL, BR) to data index based on tokens
	for i in range(4):
		var key = QUADRANT_NAMES[i]
		var data_idx = tokens.find(key)
		if data_idx == -1: data_idx = i
		if arrangement_map.size() <= i: arrangement_map.resize(i + 1)
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

func _process(delta: float) -> void:
	if not nt_instance or topic_path == "":
		return
	
	var parent_viz = get_parent()
	if not parent_viz or not parent_viz.get("field_2d"):
		# Ensure we are in a valid hierarchy
		return

	# Parse Struct Array
	var raw = nt_instance.get_value(topic_path, PackedByteArray())
	if typeof(raw) == TYPE_PACKED_BYTE_ARRAY and raw.size() > 0:
		var data = StructParser.parse_packet(raw, "struct:SwerveModuleState[]")
		if typeof(data) == TYPE_ARRAY and data.size() >= 4:
			_process_smoothing(data, delta)
			queue_redraw()

func _process_smoothing(target_states: Array, delta: float):
	for viz_idx in range(4):
		var data_idx = arrangement_map[viz_idx]
		if data_idx >= target_states.size(): continue
		
		var state = target_states[data_idx]
		var target_angle = state.get("angle", 0.0) # Radians
		var target_speed = state.get("speed", 0.0)
		
		# Interpolate
		current_angles[viz_idx] = lerp_angle(current_angles[viz_idx], target_angle, SMOOTH_SPEED * delta)
		current_speeds[viz_idx] = lerp(current_speeds[viz_idx], target_speed, SMOOTH_SPEED * delta)

func _draw():
	var parent_viz = get_parent()
	if not parent_viz or not parent_viz.get("field_2d"):
		return
		
	var field_2d = parent_viz.field_2d
	var m_to_px = field_2d.get_m_to_px_scale()
	
	# Coordinate Mapping:
	# Parent is RobotVisualizer2D. Use generic FRC robot frame: +X Forward, +Y Left.
	# We need to flip Y for Godot drawing if the parent's scale doesn't handle it?
	# RobotVisualizer2D draws directly in local space where +X is "Forward".
	
	for i in range(4):
		var angle = current_angles[i]
		var speed = current_speeds[i]
		
		# Revert for negative speed
		var effective_angle = angle
		if speed < 0:
			effective_angle += PI
			speed = abs(speed)
			
		# Module Position in Meters (Relative to Robot Center)
		# Assuming standard FRC: +X Forward, +Y Left
		var pos_m = MODULE_POSITIONS_METERS[i]
		
		# Convert to Pixels (Robot Local)
		# NOTE: RobotVisualizer draws normally. +Y in Godot is "Down" or "Right" depending on parent rotation.
		# If Field2D Y is inverted relative to FRC Y?
		# Let's assume standard Godot Vector2 logic for now and adjust if flipped.
		# If FRC Y is Left, and Godot Y is Down...
		# We might need to invert Y component of position?
		# Let's look at RobotVisualizer2D rect: `Rect2(-size_px / 2.0, size_px)`. 
		# It relies on the transform to orient correctly.
		# So we should draw in "FRC Local Frame" but transformed to Godot?
		# Actually, if we stick to (X, Y) = (Forward, Left), and RobotVisualizer2D is rotated correctly...
		# Wait, if Godot +Y is Down (Screen), and FRC +Y is Left.
		# A rotation of 0 (Forward, +X) means +X matches +X.
		# +Y (Left) needs to match -Y (Up in Godot? No, Up is -Y).
		# So FRC (x, y) -> Godot (x, -y).
		var pos_px = Vector2(pos_m.x, -pos_m.y) * m_to_px
		
		# Draw module point
		draw_circle(pos_px, 2.0, arrow_color)
		
		# Draw Arrow
		# Angle 0 is Forward (+X).
		# In Godot, Angle 0 is +X (Right).
		# So they match!
		# Positive rotation FRC is CCW (Left).
		# Positive rotation Godot is CW (Down).
		# So we need to negate angle.
		var draw_angle = - effective_angle
		
		var arrow_len = speed * 0.5 * m_to_px # Scale: 1m/s = 0.5m length on field
		if arrow_len < 5.0 and speed > 0.1: arrow_len = 5.0 # Min visibility
		
		var tip = pos_px + Vector2(arrow_len, 0).rotated(draw_angle)
		
		draw_line(pos_px, tip, arrow_color, 2.0)
		
		# Arrowhead
		var head_size = 8.0
		var head_angle = PI / 6.0 # 30 degrees
		
		var p1 = tip + Vector2(head_size, 0).rotated(draw_angle + PI - head_angle)
		var p2 = tip + Vector2(head_size, 0).rotated(draw_angle + PI + head_angle)
		
		var points = PackedVector2Array([tip, p1, p2])
		draw_colored_polygon(points, arrow_color)
