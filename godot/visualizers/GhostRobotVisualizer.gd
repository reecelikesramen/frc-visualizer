extends "res://visualizers/RobotVisualizer.gd"

var ghost_material: ShaderMaterial
var current_color_name: String = "Green" # Default

const COLORS = {
	"Green": Color(0.0, 1.0, 0.0, 0.35),
	"Red": Color(1.0, 0.0, 0.0, 0.35),
	"Blue": Color(0.0, 0.0, 1.0, 0.35),
	"Orange": Color(1.0, 0.65, 0.0, 0.35),
	"Cyan": Color(0.0, 1.0, 1.0, 0.35),
	"Yellow": Color(1.0, 1.0, 0.0, 0.35),
	"Magenta": Color(1.0, 0.0, 1.0, 0.35)
}

func setup(nt: Node, path: String, context: Dictionary = {}):
	super.setup(nt, path, context)
	
	# Initialize material
	var shader = load("res://visualizers/ghost.gdshader")
	if shader:
		ghost_material = ShaderMaterial.new()
		ghost_material.shader = shader
		_update_color()
	else:
		push_error("GhostRobotVisualizer: Failed to load ghost.gdshader")

func _process(delta):
	super._process(delta)
	# Continuously ensure all children (components) have the ghost effect
	# This covers dynamic loading of component models
	_apply_ghost_effect(self)

func _apply_ghost_effect(node: Node):
	if not ghost_material:
		return
		
	if node is MeshInstance3D:
		if node.material_override != ghost_material:
			node.material_override = ghost_material
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	for child in node.get_children():
		_apply_ghost_effect(child)

# Option Handlers matching the registry options
func set_color(color_name: String):
	if COLORS.has(color_name):
		current_color_name = color_name
		_update_color()

func _update_color():
	if ghost_material:
		var col = COLORS.get(current_color_name, COLORS["Green"])
		# If not in presets, try parsing it as a HEX string or Color string
		if not COLORS.has(current_color_name):
			if current_color_name.begins_with("#"):
				col = Color(current_color_name)
				col.a = 0.35 # Force transparency consistency
			else:
				# Try parsing generic string if Godot supports it, or fallback
				# Godot's Color constructor handles some names and hex
				col = Color(current_color_name)
				col.a = 0.35
		
		ghost_material.set_shader_parameter("albedo", col)

# Override to handle options generically if passed via name reflection
# Or TopicDock calls set_color directly because we mapped it?
# TopicDock calls `_apply_options` which checks `node.has_method("set_Color")`?
# TopicDock checks keys like "Model", "Offset". For "Color", we need `set_Color` or lowercased?
# TopicDock: 
# 	if options.has("Rotation") and node.has_method("set_model_rotation"): ...
#   # Add other option handlers here (Color, etc) -> This implies I need to edit TopicDock to support "Color"

# So I will add `set_Color` just in case, or rely on TopicDock edit.
# The registry key is "Color", so TopicDock will look for that key.
# I'll implement `set_model_color` or just rely on the `set_color` I made and update TopicDock to call it.
