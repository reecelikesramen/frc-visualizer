extends Node3D

var nt = NT4.new()

# Store where we WANT to be
var target_pose: Transform3D = Transform3D()

# Tuning knob: Higher = Snappier (but jittery), Lower = Smoother (but laggy)
# 10.0 to 15.0 is usually the "AdvantageScope feel" sweet spot.
const SMOOTH_SPEED = 30.0 

func _ready():
	add_child(nt)
	nt.start_client("127.0.0.1")
	
	# Initialize target to current spot so we don't snap from (0,0,0)
	target_pose = global_transform

func _process(delta: float) -> void:
	# 1. Get the latest data from NT
	# TIP: Pass 'target_pose' as the default. 
	# If NT loses connection for a frame, we stay where we are instead of snapping to 0,0,0.
	var new_pose = nt.get_pose3d("/AdvantageKit/RealOutputs/FieldSimulation/RobotPose", target_pose)
	
	# 2. Update the target
	target_pose = new_pose

	# 3. Smoothly Interpolate the visual object towards the target
	# transform.interpolate_with handles both Position (Lerp) and Rotation (Slerp) automatically.
	transform = transform.interpolate_with(target_pose, SMOOTH_SPEED * delta)
