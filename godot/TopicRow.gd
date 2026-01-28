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
		if current_viz != current_viz_type:
			restore_viz_state(current_viz, viz_options)
	
	current_viz_type = current_viz
	
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

	# --- Model Submenu (if applicable) ---
	if current_viz != "" and current_viz != "none":
		var rules = VisualizerRegistry.get_rules(current_mode)
		var options_def = rules.get(current_viz, {}).get("options", {})
		
		if options_def.has("Model"):
			var model_submenu = PopupMenu.new()
			model_submenu.name = "ModelSubmenu"
			popup.add_child(model_submenu)
			
			var model_id = 1000
			var current_model = viz_options.get("Model", "")
			
			# Special handling for Component visualizer - show parent robot's components
			if current_viz == "Component" and has_visualized_parent and (parent_viz_type == "Robot" or parent_viz_type == "Ghost"):
				var parent_model = ""
				if parent_row and "viz_options" in parent_row:
					parent_model = parent_row.viz_options.get("Model", "")
				
				if parent_model != "":
					var component_names = RobotModelLibrary.get_component_names(parent_model)
					if component_names.size() > 0:
						model_submenu.add_separator("Robot Components")
						for comp_name in component_names:
							model_submenu.add_radio_check_item(comp_name, model_id)
							model_submenu.set_item_checked(model_submenu.get_item_index(model_id), current_model == comp_name)
							model_submenu.set_item_metadata(model_submenu.get_item_index(model_id), {"type": "robot_component", "name": comp_name, "robot": parent_model})
							model_id += 1
				
				# Also allow adding a new component to the parent robot
				model_submenu.add_separator()
				model_submenu.add_item("Add Component to Robot...", model_id)
				model_submenu.set_item_metadata(model_submenu.get_item_index(model_id), {"type": "add_component_to_robot", "robot": parent_model})
				model_id += 1
			else:
				# Standard Robot/Ghost model selection
				var preinstalled_models = options_def["Model"]
				
				# Pre-installed models
				for model_name in preinstalled_models:
					if model_name == "Custom":
						continue
					model_submenu.add_radio_check_item(model_name, model_id)
					model_submenu.set_item_checked(model_submenu.get_item_index(model_id), current_model == model_name)
					model_submenu.set_item_metadata(model_submenu.get_item_index(model_id), {"type": "preinstalled", "name": model_name})
					model_id += 1
				
				# Custom Robots from Library
				var custom_robots = RobotModelLibrary.get_custom_robot_names()
				if custom_robots.size() > 0:
					model_submenu.add_separator("Custom Robots")
					
					# 1. Selection Items (Radio Buttons)
					for robot_name in custom_robots:
						model_submenu.add_radio_check_item(robot_name, model_id)
						model_submenu.set_item_checked(model_submenu.get_item_index(model_id), current_model == robot_name)
						model_submenu.set_item_metadata(model_submenu.get_item_index(model_id), {"type": "custom", "name": robot_name, "action": "select"})
						model_id += 1
					
					model_submenu.add_separator()
					
					# 2. Management Submenu
					var manage_submenu = PopupMenu.new()
					manage_submenu.name = "ManageRobotsSubmenu"
					model_submenu.add_child(manage_submenu)
					
					for robot_name in custom_robots:
						var robot_opts_menu = PopupMenu.new()
						robot_opts_menu.name = "RobotOpts_" + robot_name.replace(" ", "_")
						manage_submenu.add_child(robot_opts_menu)
						
						var r_id = 100
						robot_opts_menu.add_item("Edit...", r_id)
						robot_opts_menu.set_item_metadata(0, {"type": "custom", "name": robot_name, "action": "edit"})
						
						robot_opts_menu.add_item("Delete", r_id + 1)
						robot_opts_menu.set_item_metadata(1, {"type": "custom", "name": robot_name, "action": "delete"})
						
						robot_opts_menu.id_pressed.connect(_on_robot_action_selected.bind(robot_opts_menu))
						
						manage_submenu.add_submenu_node_item(robot_name, robot_opts_menu)
					
					model_submenu.add_submenu_node_item("Edit/Delete Robots...", manage_submenu)
				
				# Add Custom Robot option
				model_submenu.add_separator()
				model_submenu.add_item("Add Custom Robot Model...", model_id)
				model_submenu.set_item_metadata(model_submenu.get_item_index(model_id), {"type": "add_custom"})
			
			model_submenu.id_pressed.connect(_on_model_submenu_selected)
			popup.add_submenu_node_item("Model", model_submenu)
		
		# --- Color Submenu (if applicable) ---
		if options_def.has("Color"):
			var color_submenu = PopupMenu.new()
			color_submenu.name = "ColorSubmenu"
			popup.add_child(color_submenu)
			
			var color_id = 2000
			var color_options = options_def["Color"]
			var current_color = viz_options.get("Color", "")
			
			for color_name in color_options:
				color_submenu.add_radio_check_item(color_name, color_id)
				color_submenu.set_item_checked(color_submenu.get_item_index(color_id), current_color == color_name)
				color_submenu.set_item_metadata(color_submenu.get_item_index(color_id), color_name)
				color_id += 1
			
			# Custom Color...
			color_submenu.add_separator()
			color_submenu.add_item("Custom...", color_id)
			color_submenu.set_item_metadata(color_submenu.get_item_index(color_id), "Custom")
			color_id += 1
			
			color_submenu.id_pressed.connect(_on_color_submenu_selected)
			popup.add_submenu_node_item("Color", color_submenu)
	
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

	popup.id_pressed.connect(_on_context_menu_item_selected.bind(popup))
	add_child(popup)
	popup.position = get_global_mouse_position()
	popup.show()

func _on_context_menu_item_selected(id, popup: PopupMenu):
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

func _on_model_submenu_selected(id):
	# Find the submenu in the open popups
	var submenu = get_tree().get_nodes_in_group("model_submenus")
	# Fallback: find it by looking for the popup's child
	# We stored metadata on each item
	for popup in get_children():
		if popup is PopupMenu:
			for child in popup.get_children():
				if child is PopupMenu and child.name == "ModelSubmenu":
					var idx = child.get_item_index(id)
					if idx >= 0:
						var meta = child.get_item_metadata(idx)
						_handle_model_selection(meta)
						return

func _handle_model_selection(meta: Dictionary):
	if meta.get("type") == "add_custom":
		_open_edit_robot_dialog("")
	elif meta.get("type") == "preinstalled":
		match meta.get("name", ""):
			"2026 KitBot":
				viz_options["Rotation"] = Vector3(0, 0, 180)
			"Duck Bot":
				viz_options["Rotation"] = Vector3(180, -90, 0)
			"Crab Bot":
				viz_options["Rotation"] = Vector3(-90, 180, 90)
		viz_options["Offset"] = Vector3(0, 0, 0)
		viz_options["Model"] = meta.get("name", "")
		_notify_options_changed()
	elif meta.get("type") == "custom":
		var robot_name = meta.get("name", "")
		var robot_config = RobotModelLibrary.get_custom_robot(robot_name)
		if not robot_config.is_empty():
			viz_options["Model"] = robot_name
			viz_options["Offset"] = RobotModelLibrary.parse_vector3(robot_config.get("chassis_offset", [0, 0, 0]))
			viz_options["Rotation"] = RobotModelLibrary.parse_vector3(robot_config.get("chassis_rotation", [0, 0, 0]))
			_notify_options_changed()
			_apply_custom_robot_model(robot_name, robot_config)
	elif meta.get("type") == "robot_component":
		# Component visualizer selecting a component from parent robot
		var comp_name = meta.get("name", "")
		var robot_name = meta.get("robot", "")
		var comp_config = RobotModelLibrary.get_component(robot_name, comp_name)
		if not comp_config.is_empty():
			viz_options["Model"] = comp_name
			viz_options["Offset"] = RobotModelLibrary.parse_vector3(comp_config.get("offset", [0, 0, 0]))
			viz_options["Rotation"] = RobotModelLibrary.parse_vector3(comp_config.get("rotation", [0, 0, 0]))
			_notify_options_changed()
			_apply_component_model(comp_config)
	elif meta.get("type") == "add_component_to_robot":
		var robot_name = meta.get("robot", "")
		_open_add_component_dialog(robot_name)

func _apply_component_model(comp_config: Dictionary):
	var dock = get_dock()
	if not dock or not dock.active_visualizers.has(topic_path):
		return
	var viz_node = dock.active_visualizers[topic_path]["node"]
	if not is_instance_valid(viz_node):
		return
	
	var model_path = comp_config.get("model", "")
	if model_path != "" and viz_node.has_method("set_custom_model"):
		viz_node.set_custom_model(model_path)
	if viz_node.has_method("set_model_offset"):
		viz_node.set_model_offset(RobotModelLibrary.parse_vector3(comp_config.get("offset", [0, 0, 0])))
	if viz_node.has_method("set_model_rotation"):
		viz_node.set_model_rotation(RobotModelLibrary.parse_vector3(comp_config.get("rotation", [0, 0, 0])))

func _open_add_component_dialog(robot_name: String):
	var dialog = load("res://EditComponentDialog.gd").new()
	add_child(dialog)
	dialog.setup("", {})
	dialog.component_saved.connect(_on_new_component_saved.bind(robot_name))
	dialog.popup_centered()
	dialog.visibility_changed.connect(func(): if not dialog.visible: dialog.queue_free())

func _on_new_component_saved(comp_name: String, config: Dictionary, robot_name: String):
	RobotModelLibrary.add_component(robot_name, comp_name, config)
	# Select the new component
	viz_options["Model"] = comp_name
	viz_options["Offset"] = RobotModelLibrary.parse_vector3(config.get("offset", [0, 0, 0]))
	viz_options["Rotation"] = RobotModelLibrary.parse_vector3(config.get("rotation", [0, 0, 0]))
	_notify_options_changed()
	_apply_component_model(config)

func _apply_custom_robot_model(robot_name: String, robot_config: Dictionary):
	var dock = get_dock()
	if not dock or not dock.active_visualizers.has(topic_path):
		return
	var viz_node = dock.active_visualizers[topic_path]["node"]
	if not is_instance_valid(viz_node):
		return
	
	# Apply chassis model
	var chassis_model = robot_config.get("chassis_model", "")
	if chassis_model != "" and viz_node.has_method("set_custom_model"):
		viz_node.set_custom_model(chassis_model)
	
	# Apply offsets
	if viz_node.has_method("set_model_offset"):
		viz_node.set_model_offset(RobotModelLibrary.parse_vector3(robot_config.get("chassis_offset", [0, 0, 0])))
	if viz_node.has_method("set_model_rotation"):
		viz_node.set_model_rotation(RobotModelLibrary.parse_vector3(robot_config.get("chassis_rotation", [0, 0, 0])))

func _on_color_submenu_selected(id):
	for popup in get_children():
		if popup is PopupMenu:
			for child in popup.get_children():
				if child is PopupMenu and child.name == "ColorSubmenu":
					var idx = child.get_item_index(id)
					if idx >= 0:
						var color_name = child.get_item_metadata(idx)
						if color_name == "Custom":
							_open_custom_color_picker()
						else:
							viz_options["Color"] = color_name
							_notify_options_changed()
						return

func _open_custom_color_picker():
	var picker_popup = PopupPanel.new()
	picker_popup.min_size = Vector2(300, 400)
	var picker = ColorPicker.new()
	picker.deferred_mode = true # Update on release? No, let's do live.
	picker_popup.add_child(picker)
	add_child(picker_popup)
	
	var current_col_str = viz_options.get("Color", "")
	if current_col_str.begins_with("#"):
		picker.color = Color(current_col_str)
	elif current_col_str != "":
		# Try to use existing named color as base
		# (Requires visualizer registry or manual map, skipping for simplicity)
		pass
		
	picker.color_changed.connect(func(col):
		viz_options["Color"] = "#" + col.to_html(false)
		_notify_options_changed()
	)
	
	picker_popup.popup_centered()
	picker_popup.popup_hide.connect(func(): picker_popup.queue_free())

func _on_robot_action_selected(id, popup: PopupMenu):
	var idx = popup.get_item_index(id)
	var meta = popup.get_item_metadata(idx)
	var action = meta.get("action")
	var robot_name = meta.get("name")
	
	if action == "select":
		_handle_model_selection({"type": "custom", "name": robot_name})
	elif action == "edit":
		_open_edit_robot_dialog(robot_name)
	elif action == "delete":
		_confirm_delete_robot(robot_name)

func _confirm_delete_robot(robot_name: String):
	var confirm = ConfirmationDialog.new()
	confirm.title = "Delete Robot"
	confirm.dialog_text = "Are you sure you want to delete '" + robot_name + "'?"
	add_child(confirm)
	confirm.confirmed.connect(func():
		RobotModelLibrary.delete_custom_robot(robot_name)
		# If currently selected, maybe define what happens? 
		# For now, it stays until changed or reload.
		confirm.queue_free()
	)
	confirm.canceled.connect(func(): confirm.queue_free())
	confirm.popup_centered()

func _open_edit_robot_dialog(robot_name: String):
	var dialog = load("res://EditRobotDialog.gd").new()
	add_child(dialog)
	dialog.setup(robot_name)
	dialog.robot_saved.connect(_on_robot_saved)
	dialog.popup_centered()
	dialog.visibility_changed.connect(func(): if not dialog.visible: dialog.queue_free())

func _on_robot_saved(robot_name: String):
	# After saving a new robot, select it
	var robot_config = RobotModelLibrary.get_custom_robot(robot_name)
	viz_options["Model"] = robot_name
	if not robot_config.is_empty():
		viz_options["Offset"] = RobotModelLibrary.parse_vector3(robot_config.get("chassis_offset", [0, 0, 0]))
		viz_options["Rotation"] = RobotModelLibrary.parse_vector3(robot_config.get("chassis_rotation", [0, 0, 0]))
		_apply_custom_robot_model(robot_name, robot_config)
	_notify_options_changed()

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
