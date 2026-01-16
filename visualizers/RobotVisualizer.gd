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
	# Pass 'target_pose' as the default to avoid snapping to 0,0,0 on frame loss
	var new_pose = nt_instance.get_pose3d(topic_path, target_pose)
	target_pose = new_pose
