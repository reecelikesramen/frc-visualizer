extends Control

# Field dimensions (meters)
@export var field_length_m: float = 16.540988
@export var field_width_m: float = 8.0689958

# Reference points on the image (pixels)
# Corner 00 is FRC (0,0) in meters -> Top Right
@export var corner_00_px: Vector2 = Vector2(3378, 95)
# Corner Max is FRC (length, width) in meters -> Bottom Left
@export var corner_max_px: Vector2 = Vector2(524, 1489)
@export var field_image: Texture2D:
	set(value):
		field_image = value
		field_texture = value
		_update_transform()
		queue_redraw()

var field_texture: Texture2D = null
var _draw_offset: Vector2 = Vector2.ZERO
var _draw_scale: float = 1.0

# Reference Field Config (for field_with_fuel.png 3902x1584)
const REF_SIZE = Vector2(3902, 1584)
const REF_C00 = Vector2(3378, 95)
const REF_CMAX = Vector2(524, 1489)

func _ready():
	item_rect_changed.connect(_update_transform)
	if field_image:
		field_texture = field_image
	_update_transform()

func _update_transform():
	var rect_size = get_rect().size
	if field_texture:
		var tex_size = field_texture.get_size()
		
		# Dynamic Calibration
		# If texture size differs from reference, scale the calibration points
		var cal_scale_x = tex_size.x / REF_SIZE.x
		var cal_scale_y = tex_size.y / REF_SIZE.y
		
		# Update exported vars to match current texture
		# Note: updating exported vars at runtime is fine, they are used by field_to_pixel
		corner_00_px = REF_C00 * Vector2(cal_scale_x, cal_scale_y)
		corner_max_px = REF_CMAX * Vector2(cal_scale_x, cal_scale_y)
		
		var scale_x = rect_size.x / tex_size.x
		var scale_y = rect_size.y / tex_size.y
		_draw_scale = min(scale_x, scale_y) # Fit to screen
		# ...
		
		var scaled_tex_size = tex_size * _draw_scale
		_draw_offset = (rect_size - scaled_tex_size) / 2.0
	else:
		_draw_scale = 1.0
		_draw_offset = Vector2.ZERO
	queue_redraw()

var background_with_fuel = preload("res://fields/rebuilt/assets/field_with_fuel.png")
var background_without_fuel = preload("res://fields/rebuilt/assets/field_without_fuel.png")

func set_game_pieces_visible(are_game_pieces_visible: bool):
	# If game pieces are visible (rendered by visualizer), use clean field
	if are_game_pieces_visible:
		field_image = background_without_fuel
	else:
		field_image = background_with_fuel
	queue_redraw()

func setup(image_path: String):
	if FileAccess.file_exists(image_path):
		var image = Image.load_from_file(image_path)
		field_texture = ImageTexture.create_from_image(image)
		_update_transform()
	else:
		print("Field2D: Image not found at ", image_path)

func field_to_pixel(field_m: Vector2) -> Vector2:
	# 1. Normalize position relative to the field dimensions [0, 1]
	var normalized = Vector2(
		field_m.x / field_length_m,
		field_m.y / field_width_m
	)
	
	# 2. Map to pixel space within the image image pixels
	var local_px = corner_00_px + (corner_max_px - corner_00_px) * normalized
	
	# 3. Scale and offset based on how the image is drawn in the control
	return (local_px * _draw_scale) + _draw_offset

func pixel_to_field(pixel: Vector2) -> Vector2:
	# Inverse of field_to_pixel
	var local_px = (pixel - _draw_offset) / _draw_scale
	
	# Component-wise inverse mapping from local_px to normalized [0, 1]
	var t_x = (local_px.x - corner_00_px.x) / (corner_max_px.x - corner_00_px.x)
	var t_y = (local_px.y - corner_00_px.y) / (corner_max_px.y - corner_00_px.y)
	
	return Vector2(t_x * field_length_m, t_y * field_width_m)

func get_m_to_px_scale() -> float:
	# Returns pixels per meter
	var image_dist_px = corner_00_px.distance_to(corner_max_px)
	var diag_m = Vector2(field_length_m, field_width_m).length()
	return (image_dist_px / diag_m) * _draw_scale

func _draw():
	var rect_size = get_rect().size
	
	if field_texture:
		var scaled_tex_size = field_texture.get_size() * _draw_scale
		draw_texture_rect(field_texture, Rect2(_draw_offset, scaled_tex_size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, rect_size), Color(0.05, 0.05, 0.05, 1.0))
		draw_string(ThemeDB.get_fallback_font(), Vector2(20, 40), "2D Field View (No Image)", HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	
	# Always draw the grid (or at least the corners) for debug
	_draw_grid()

func _draw_grid():
	var color = Color(0.2, 0.2, 0.2, 0.5)
	if not field_texture: color = Color(0.5, 0.5, 0.5, 0.8)
	
	# Draw lines every meter
	for x in range(int(field_length_m) + 1):
		var p1 = field_to_pixel(Vector2(x, 0))
		var p2 = field_to_pixel(Vector2(x, field_width_m))
		draw_line(p1, p2, color, 1.0)
	
	for y in range(int(field_width_m) + 1):
		var p1 = field_to_pixel(Vector2(0, y))
		var p2 = field_to_pixel(Vector2(field_length_m, y))
		draw_line(p1, p2, color, 1.0)
	
	# Draw origin (Red side right corner usually)
	var p00 = field_to_pixel(Vector2.ZERO)
	var pMM = field_to_pixel(Vector2(field_length_m, field_width_m))
	
	draw_circle(p00, 8.0, Color.GREEN)
	draw_string(ThemeDB.get_fallback_font(), p00 + Vector2(10, 0), "Origin (0,0)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.GREEN)
	
	# Draw field bounds
	var size_shifted = pMM - p00
	draw_rect(Rect2(p00, size_shifted).abs(), Color.YELLOW, false, 2.0)
	
	# Debug print mapping for center
	var _center_px = field_to_pixel(Vector2(field_length_m / 2.0, field_width_m / 2.0))
	# print("Field2D Debug: Center M (", field_length_m/2.0, ", ", field_width_m/2.0, ") -> Px ", _center_px)
