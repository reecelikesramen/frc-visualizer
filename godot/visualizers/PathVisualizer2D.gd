extends Node2D

var nt_instance = null
var topic_path: String = ""
var field_2d = null

var path_points: Array[Vector2] = []
var line_color = Color.CYAN
var line_width = 2.0

func setup(nt: Node, path: String, context: Dictionary = {}):
	nt_instance = nt
	topic_path = path
	
	# Find Field2D parent
	var p = get_parent()
	while p and not p.has_method("field_to_pixel"):
		p = p.get_parent()
	field_2d = p
	
	if context.has("options"):
		var opts = context["options"]
		if opts.has("Color"):
			line_color = Color(opts["Color"].to_lower())

func _process(_delta):
	if not nt_instance or topic_path == "" or not field_2d:
		return
		
	# Trajectory can be Pose2d[] or Pose3d[] or number[]
	var poses = nt_instance.get_pose2d_array(topic_path, [])
	if poses.is_empty():
		var poses3d = nt_instance.get_pose3d_array(topic_path, [])
		if not poses3d.is_empty():
			for p in poses3d:
				var raw_x = p.origin.x
				var raw_y = p.origin.z
				# Origin shift if center-based (detect negative or small values)
				if raw_x < 0 or raw_y < 0 or abs(raw_x) < 8.0:
					raw_x += 16.540988 / 2.0
					raw_y += 8.0689958 / 2.0
				
				poses.append(Transform2D(p.get_rotation().z, Vector2(raw_x, raw_y)))
	
	if not poses.is_empty():
		path_points.clear()
		for pose in poses:
			path_points.append(field_2d.field_to_pixel(pose.get_origin()))
		queue_redraw()

func _draw():
	if path_points.size() < 2:
		return
		
	draw_polyline(path_points, line_color, line_width, true)
