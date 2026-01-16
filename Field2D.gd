extends Control

var field_texture: Texture2D = null
var field_rect: Rect2 = Rect2(0, 0, 100, 100) # Default setup

func _ready():
	# Placeholder: Load field image
	# In the future, this should be configurable
	# For now, we'll try to load a default if available, or just use a placeholder color
	pass

func setup(image_path: String):
	if FileAccess.file_exists(image_path):
		var image = Image.load_from_file(image_path)
		field_texture = ImageTexture.create_from_image(image)
		queue_redraw()
	else:
		print("Field2D: Image not found at ", image_path)

func _draw():
	var rect_size = get_rect().size
	
	if field_texture:
		# Draw texture scaled to fit or keep aspect ratio?
		# For now, just stretch to fill or naive fit
		draw_texture_rect(field_texture, Rect2(Vector2.ZERO, rect_size), false)
	else:
		# Draw placeholder background
		draw_rect(Rect2(Vector2.ZERO, rect_size), Color(0.1, 0.1, 0.1, 1.0))
		draw_string(ThemeDB.get_fallback_font(), Vector2(20, 40), "2D Field View (No Image)", HORIZONTAL_ALIGNMENT_LEFT, -1, 24)

	# Placeholder for 2D primitives
	# draw_circle(size / 2, 20, Color.RED)
