extends Node3D

var nt_instance = null
var topic_path: String = ""

# Store where we WANT to be
var target_pose: Transform3D = Transform3D()

# Tuning knob: Higher = Snappier (but jittery), Lower = Smoother (but laggy)
const SMOOTH_SPEED = 30.0

func setup(nt: Node, path: String, context: Dictionary = {}):
	nt_instance = nt
	topic_path = path

func _ready():
	# Initialize target to current spot
	target_pose = global_transform

func _process(delta: float) -> void:
	if not nt_instance or topic_path == "":
		return

	# 1. Get the latest data from NT
	valid_nt_update()
	
	# 3. Smoothly Interpolate
	transform = transform.interpolate_with(target_pose, SMOOTH_SPEED * delta)

func valid_nt_update():
	# Check for Pose2d vs Pose3d based on data size
	var val = nt_instance.get_value(topic_path, null)
	
	if val is PackedByteArray and val.size() == 24:
		# Pose2d (24 bytes) -> Convert to 3D
		# get_pose2d returns Godot 2D: x=FRC_X, y=-FRC_Y, rot=-FRC_Theta
		var p2d = nt_instance.get_pose2d(topic_path, Transform2D())
		
		# Map to Godot 3D:
		# X = -FRC_Y = p2d.origin.y
		# Z = -FRC_X = -p2d.origin.x
		# Yaw = FRC_Theta = -p2d.rotation
		var x = p2d.origin.y
		var z = - p2d.origin.x
		var yaw = - p2d.get_rotation()
		
		target_pose = Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0.0, z))
	else:
		# Default to Pose3d
		target_pose = nt_instance.get_pose3d(topic_path, target_pose)
