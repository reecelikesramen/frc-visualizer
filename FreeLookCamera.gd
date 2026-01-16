extends Camera3D

@export var move_speed = 5.0
@export var mouse_sensitivity = 0.003
@export var boost_multiplier = 2.0

var velocity = Vector3.ZERO
var look_rotation = Vector2.ZERO

func _ready():
	# Initialize rotation from current transform
	var rot = rotation
	look_rotation.x = rot.y
	look_rotation.y = rot.x

func _input(event):
	if get_viewport().gui_get_focus_owner() != null:
		return # Block camera movement if UI is focused

	if event is InputEventMouseMotion:
		# Right Click: Pan POV (Rotation)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			look_rotation.x -= event.relative.x * mouse_sensitivity
			look_rotation.y -= event.relative.y * mouse_sensitivity
			look_rotation.y = clamp(look_rotation.y, -PI/2, PI/2)
			
			rotation.x = look_rotation.y
			rotation.y = look_rotation.x
			
		# Middle Click: Pan (Truck/Pedestal) logic could go here
		# But request said "pan w.r.t to center point" which is orbiting?
		# "hold middle click to pan w.r.t to center point" -> Orbit? Or Pan?
		# Usually Pan means move camera plane.
		# Let's implement simple Plane Pan for Middle Click.
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			var pan_speed = move_speed * 0.01
			translate_object_local(Vector3(-event.relative.x * pan_speed, event.relative.y * pan_speed, 0))

func _process(delta):
	# Movement
	if get_viewport().gui_get_focus_owner() != null:
		return

	var input_dir = Vector3.ZERO
	
	# Only move if right click is held? Standard editor usually allows movement anytime or only when focused.
	# Let's allow anytime, but maybe check if UI is capturing input?
	# For simplicity, always enabled unless typing.
	
	if Input.is_key_pressed(KEY_W): input_dir.z -= 1
	if Input.is_key_pressed(KEY_S): input_dir.z += 1
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_key_pressed(KEY_D): input_dir.x += 1
	if Input.is_key_pressed(KEY_Q): input_dir.y -= 1
	if Input.is_key_pressed(KEY_E): input_dir.y += 1
	
	var speed = move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= boost_multiplier
		
	# Apply local movement
	# basis.z is forward vector (backwards actually in Godot/OpenGL)
	# translate_object_local handles local axis
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
		translate_object_local(input_dir * speed * delta)

	# Scroll Zoom
	# Handled via input event strictly usually, or mapped actions.
	# Input polling for scroll is tricky, `_input` event with MouseButton Wheel is better.

func _unhandled_input(event):
	if event is InputEventMouseButton:
		# Prevent scroll zoom if mouse is over a UI element
		if get_viewport().gui_get_hovered_control() != null:
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			translate_object_local(Vector3(0, 0, -1)) # Forward
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			translate_object_local(Vector3(0, 0, 1)) # Back
