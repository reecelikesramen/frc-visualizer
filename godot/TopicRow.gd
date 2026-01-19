extends VBoxContainer

var topic_path: String = ""
var topic_type: String = ""
var nt_instance = null

@onready var icon_rect: TextureRect = $TopBar/Icon
@onready var name_label: Label = $TopBar/NameLabel
@onready var value_label: Label = $TopBar/ValueLabel
@onready var path_label: Label = $TopBar/PathLabel
@onready var close_button: Button = $TopBar/CloseButton
@onready var children_container: VBoxContainer = $MarginContainer/ChildrenContainer
@onready var highlight_rect = $HighlightRect

	# Create Options Container dynamically
	# Removed: UI moved to Context Menu
var parent_row = null
var row_data = {}
var is_drag_highlighted = false

# Visualizer State
var current_viz_type = ""
var viz_options = {} # { "Model": "path", "Offset": Vector3 }

func setup(path: String, type: String, nt: Node):
	topic_path = path
	topic_type = type
	nt_instance = nt
	
	# Extract name from path (last element)
	var parts = path.split("/", false)
	var topic_name = parts[parts.size() - 1] if parts.size() > 0 else path
	
	if name_label:
		name_label.text = topic_name
	
	if path_label:
		path_label.text = path
	
	tooltip_text = path
	
	row_data = {
		"path": topic_path,
		"type": "nt_topic",
		"nt_type": topic_type,
		"nt_ref": nt_instance
	}

	# Options UI moved to Context Menu

# --- Drag & Drop ---

func _get_drag_data(at_position):
	var preview = Label.new()
	preview.text = topic_path
	set_drag_preview(preview)
	
	row_data["source_node"] = self
	row_data["viz_options"] = viz_options # Include options in drag data
	return row_data

func _can_drop_data(at_position, data):
	if typeof(data) == TYPE_DICTIONARY and data.get("type") == "nt_topic":
		var source_node = data.get("source_node")
		if source_node == self: return false
		
		# STRICT VALIDATION: Parent must be visualized to accept children
		var dock = get_dock()
		if dock and dock.active_visualizers.has(topic_path):
			var parent_viz_info = dock.active_visualizers[topic_path]
			var parent_viz_type = parent_viz_info["type"]
			var current_mode = dock.current_mode if "current_mode" in dock else "3D"
			var child_nt_type = data.get("nt_type", "")
			
			var modifiers = VisualizerRegistry.get_compatible_modifiers(child_nt_type, parent_viz_type, current_mode)
			if modifiers.is_empty():
				return false
		else:
			return false # No viz on parent -> no children

		_set_drag_highlight(true)
		return true
	return false

func _drop_data(at_position, data):
	_set_drag_highlight(false)
	
	if not _can_drop_data(at_position, data): return

	var source_node = data.get("source_node")
	
	if is_instance_valid(source_node):
		# Existing Node Move
		print("Nesting ", source_node.topic_path, " under ", topic_path)
		if source_node.get_parent():
			source_node.get_parent().remove_child(source_node)
		children_container.add_child(source_node)
		source_node.parent_row = self
		get_tree().call_group("dock_updates", "_notify_change")
		return

	# New Topic Drop (from Tree)
	var path = data.get("path")
	var type = data.get("nt_type")
	var nt_ref = data.get("nt_ref")
	
	if path and type:
		for child in children_container.get_children():
			if "topic_path" in child and child.topic_path == path:
				return
		
		var new_row = load("res://TopicRow.tscn").instantiate()
		children_container.add_child(new_row)
		new_row.setup(path, type, nt_ref)
		new_row.parent_row = self
		
		var dock = get_dock()
		if dock:
			new_row.visualization_requested.connect(dock._on_visualization_requested)
			new_row.tree_exiting.connect(dock._on_row_exiting.bind(new_row))
			new_row.tree_exiting.connect(dock._notify_change)
		
		get_tree().call_group("dock_updates", "_notify_change")

func _notification(what):
	if what == NOTIFICATION_MOUSE_EXIT:
		_set_drag_highlight(false)
	elif what == NOTIFICATION_DRAG_END:
		_set_drag_highlight(false)

func _process(_delta):
	if nt_instance and topic_path != "":
		var val = _fetch_value()
		value_label.text = val
		
		if val == "...":
			_set_params(true)
		else:
			_set_params(false)

func _fetch_value() -> String:
	if topic_type.begins_with("struct:"):
		var raw = nt_instance.get_value(topic_path, PackedByteArray())
		if typeof(raw) == TYPE_PACKED_BYTE_ARRAY:
			if raw.size() > 0:
				_set_params(false)
				var parsed = StructParser.parse_packet(raw, topic_type)
				return StructParser.format_value(parsed, false)
			else:
				_set_params(true)
				return "..."
		return "struct..."
		
	if topic_type == "double" or topic_type == "float":
		return "%.2f" % nt_instance.get_number(topic_path, 0.0)
	elif topic_type == "int":
		return str(int(nt_instance.get_number(topic_path, 0.0)))
	elif topic_type == "boolean":
		return str(nt_instance.get_boolean(topic_path, false))
	elif topic_type == "string":
		return nt_instance.get_string(topic_path, "")
	elif topic_type == "double[]":
		return StructParser.format_value(nt_instance.get_number_array(topic_path, PackedFloat64Array()), false)
	elif topic_type == "string[]":
		return StructParser.format_value(nt_instance.get_string_array(topic_path, PackedStringArray()), false)
	elif topic_type == "boolean[]":
		var default_arr: Array[bool] = []
		return StructParser.format_value(nt_instance.get_boolean_array(topic_path, default_arr), false)
	return "..."

func _set_params(missing: bool):
	if missing:
		modulate.a = 0.5
	else:
		modulate.a = 1.0

func _ready():
	icon_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	icon_rect.gui_input.connect(_on_icon_gui_input)

func _on_icon_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_context_menu()

func get_dock():
	var p = get_parent()
	while p:
		if p.name == "TopicDock" or p.get_script() == load("res://TopicDock.gd"):
			return p
		p = p.get_parent()
	return null

func _show_context_menu():
	var popup = PopupMenu.new()
	
	var dock = get_dock()
	var current_mode = dock.current_mode if dock and "current_mode" in dock else "3D"
	var current_viz = ""
	
	if dock and dock.active_visualizers.has(topic_path):
		current_viz = dock.active_visualizers[topic_path]["type"]
		# Update internal state if drift occurred
		if current_viz != current_viz_type:
			restore_viz_state(current_viz, viz_options)
	
	current_viz_type = current_viz # Sync
	
	var default_checked = (current_viz == "")
	popup.add_radio_check_item("Visualize as Text (Default)", 0)
	popup.set_item_checked(popup.get_item_index(0), default_checked)
	
	var id_map = {}
	var current_id = 100
	
	var has_visualized_parent = false
	var parent_viz_type = ""
	
	if parent_row:
		if dock and dock.active_visualizers.has(parent_row.topic_path):
			has_visualized_parent = true
			parent_viz_type = dock.active_visualizers[parent_row.topic_path]["type"]

	# 1. Top Level Visualizers
	if not has_visualized_parent:
		var compatible_viz = VisualizerRegistry.get_compatible_visualizers(topic_type, current_mode)
		if compatible_viz.size() > 0:
			popup.add_separator("Visualizers")
			for viz in compatible_viz:
				popup.add_radio_check_item(viz, current_id)
				popup.set_item_checked(popup.get_item_index(current_id), viz == current_viz)
				id_map[current_id] = viz
				current_id += 1
			
	# 2. Modifiers
	if has_visualized_parent:
		var modifiers = VisualizerRegistry.get_compatible_modifiers(topic_type, parent_viz_type, current_mode)
		if modifiers.size() > 0:
			popup.add_separator("Add to Parent")
			for mod in modifiers:
				popup.add_radio_check_item(mod, current_id)
				popup.set_item_checked(popup.get_item_index(current_id), mod == current_viz)
				id_map[current_id] = mod
				current_id += 1
	
	for id in id_map:
		var idx = popup.get_item_index(id)
		popup.set_item_metadata(idx, id_map[id])

	# 3. Model Configuration (if applicable)
	if current_viz != "" and current_viz != "none":
		var rules = VisualizerRegistry.get_rules(current_mode)
		var options_def = rules.get(current_viz, {}).get("options", {})
		
		# Check if it supports custom model
		if options_def.has("Model") and options_def["Model"].has("Custom"):
			popup.add_separator()
			popup.add_item("Configure Model...", 200)

	popup.id_pressed.connect(_on_context_menu_item_selected.bind(popup))
	add_child(popup)
	popup.position = get_global_mouse_position()
	popup.show()

func _on_context_menu_item_selected(id, popup: PopupMenu):
	if id == 200:
		_open_model_config()
		return
		
	var index = popup.get_item_index(id)
	var viz_name = popup.get_item_metadata(index)
	
	if id == 0:
		visualization_requested.emit(topic_path, topic_type, "none")
		current_viz_type = ""
		return

	if viz_name:
		visualization_requested.emit(topic_path, topic_type, viz_name)
		current_viz_type = viz_name
	else:
		print("Unknown visualizer ID selected: ", id)

func _on_close_button_pressed():
	queue_free()

func _set_drag_highlight(enabled: bool):
	if is_drag_highlighted == enabled: return
	is_drag_highlighted = enabled
	if highlight_rect:
		highlight_rect.visible = enabled
	else:
		modulate = Color(1.2, 1.2, 1.2) if enabled else Color(1, 1, 1)

signal visualization_requested(path: String, type: String, viz_type: String)
signal options_changed(path: String, options: Dictionary) # To notify dock to update live visualizer

# --- Options UI Logic ---

# --- Options UI Logic ---

func restore_viz_state(viz_type: String, options: Dictionary):
	current_viz_type = viz_type
	viz_options = options.duplicate()
	# No UI updates needed, handled via context menu now

func _open_model_config():
	# Instantiate dialog
	var dialog_script = load("res://ModelConfigDialog.gd")
	if not dialog_script:
		print("ModelConfigDialog.gd not found")
		return
		
	var dialog = dialog_script.new()
	add_child(dialog)
	dialog.setup(viz_options)
	dialog.settings_changed.connect(_on_dialog_settings_changed)
	dialog.popup_centered()
	# Dialog will auto-hide on close/confirm, and we let it stay alive or free it?
	# AcceptDialogs queue_free on close usually if configured? No.
	dialog.visibility_changed.connect(func(): if not dialog.visible: dialog.queue_free())

func _on_dialog_settings_changed(new_options: Dictionary):
	# Merge changes
	var old_model = viz_options.get("Model", "")
	var new_model = new_options.get("Model", "")
	
	# Handle File Persistence if model changed
	if new_model != "" and new_model != old_model:
		# Copy logic with hashing
		if not new_model.begins_with("res://") and not new_model.begins_with("user://"):
			new_model = _import_model_file(new_model)
			
	viz_options["Model"] = new_model
	viz_options["Offset"] = new_options.get("Offset", Vector3.ZERO)
	viz_options["Rotation"] = new_options.get("Rotation", Vector3.ZERO)
	
	_notify_options_changed()

func _import_model_file(path: String) -> String:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		print("Failed to open model file: ", path)
		return path
		
	var content_hash = f.get_md5(path) # Godot built-in MD5 check
	var ext = path.get_extension()
	var filename = content_hash + "." + ext
	
	var dest_dir = "user://models"
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("models"):
		dir.make_dir("models")
		
	var dest_path = dest_dir + "/" + filename
	
	# If exists, we assume it's the same file (hash collision unlikely or acceptable)
	if FileAccess.file_exists(dest_path):
		return dest_path
		
	# Copy
	var dir_abs = DirAccess.open(path.get_base_dir())
	if dir_abs:
		var err = dir_abs.copy(path, dest_path)
		if err == OK:
			return dest_path
	
	print("Failed to copy model.")
	return path

func _notify_options_changed():
	options_changed.emit(topic_path, viz_options)
	# Also update drag data
	row_data["viz_options"] = viz_options
	get_tree().call_group("dock_updates", "_notify_change") # Trigger Save
