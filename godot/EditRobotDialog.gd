extends AcceptDialog

signal robot_saved(robot_name: String)

var robot_name_edit: LineEdit
var chassis_path_edit: LineEdit
var chassis_file_dialog: FileDialog
var chassis_pos_spinboxes = []
var chassis_rot_spinboxes = []

var component_list: ItemList
var add_component_btn: Button
var edit_component_btn: Button
var remove_component_btn: Button

var editing_robot_name: String = "" # Empty = new robot
var current_config: Dictionary = {}

func _init():
	title = "Edit Custom Robot Model"
	min_size = Vector2(500, 450)

func _ready():
	var main_vbox = VBoxContainer.new()
	add_child(main_vbox)
	
	# --- Robot Name ---
	var name_hbox = HBoxContainer.new()
	main_vbox.add_child(name_hbox)
	
	var name_label = Label.new()
	name_label.text = "Robot Name:"
	name_hbox.add_child(name_label)
	
	robot_name_edit = LineEdit.new()
	robot_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	robot_name_edit.placeholder_text = "My Custom Robot"
	name_hbox.add_child(robot_name_edit)
	
	main_vbox.add_child(HSeparator.new())
	
	# --- Chassis Model ---
	var chassis_label = Label.new()
	chassis_label.text = "Chassis Model"
	main_vbox.add_child(chassis_label)
	
	var chassis_file_hbox = HBoxContainer.new()
	main_vbox.add_child(chassis_file_hbox)
	
	var file_label = Label.new()
	file_label.text = "File:"
	chassis_file_hbox.add_child(file_label)
	
	chassis_path_edit = LineEdit.new()
	chassis_path_edit.editable = false
	chassis_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chassis_file_hbox.add_child(chassis_path_edit)
	
	var select_btn = Button.new()
	select_btn.text = "Select..."
	select_btn.pressed.connect(_open_chassis_file_dialog)
	chassis_file_hbox.add_child(select_btn)
	
	# Chassis Offset
	var pos_label = Label.new()
	pos_label.text = "Offset (meters):"
	main_vbox.add_child(pos_label)
	
	var pos_hbox = HBoxContainer.new()
	main_vbox.add_child(pos_hbox)
	for i in range(3):
		var sb = SpinBox.new()
		sb.step = 0.01
		sb.min_value = -100.0
		sb.max_value = 100.0
		sb.custom_minimum_size.x = 80
		sb.prefix = ["X", "Y", "Z"][i]
		pos_hbox.add_child(sb)
		chassis_pos_spinboxes.append(sb)
	
	# Chassis Rotation
	var rot_label = Label.new()
	rot_label.text = "Rotation (degrees):"
	main_vbox.add_child(rot_label)
	
	var rot_hbox = HBoxContainer.new()
	main_vbox.add_child(rot_hbox)
	for i in range(3):
		var sb = SpinBox.new()
		sb.step = 0.1
		sb.min_value = -360.0
		sb.max_value = 360.0
		sb.custom_minimum_size.x = 80
		sb.prefix = ["R", "P", "Y"][i]
		rot_hbox.add_child(sb)
		chassis_rot_spinboxes.append(sb)
	
	main_vbox.add_child(HSeparator.new())
	
	# --- Components ---
	var comp_label = Label.new()
	comp_label.text = "Components"
	main_vbox.add_child(comp_label)
	
	component_list = ItemList.new()
	component_list.custom_minimum_size.y = 100
	component_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(component_list)
	
	var comp_btn_hbox = HBoxContainer.new()
	main_vbox.add_child(comp_btn_hbox)
	
	add_component_btn = Button.new()
	add_component_btn.text = "Add..."
	add_component_btn.pressed.connect(_add_component)
	comp_btn_hbox.add_child(add_component_btn)
	
	edit_component_btn = Button.new()
	edit_component_btn.text = "Edit..."
	edit_component_btn.pressed.connect(_edit_component)
	comp_btn_hbox.add_child(edit_component_btn)
	
	remove_component_btn = Button.new()
	remove_component_btn.text = "Remove"
	remove_component_btn.pressed.connect(_remove_component)
	comp_btn_hbox.add_child(remove_component_btn)
	
	# File Dialog
	chassis_file_dialog = FileDialog.new()
	chassis_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	chassis_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	chassis_file_dialog.filters = ["*.gltf, *.glb ; GLTF Files", "*.obj ; OBJ Files"]
	chassis_file_dialog.use_native_dialog = true
	chassis_file_dialog.file_selected.connect(_on_chassis_file_selected)
	add_child(chassis_file_dialog)
	
	# Connect confirm
	confirmed.connect(_on_confirmed)

func setup(robot_name: String = ""):
	editing_robot_name = robot_name
	if robot_name != "":
		current_config = RobotModelLibrary.get_custom_robot(robot_name).duplicate(true)
		robot_name_edit.text = robot_name
	else:
		current_config = RobotModelLibrary.make_robot_config("", Vector3.ZERO, Vector3.ZERO)
		robot_name_edit.text = ""
	
	_load_config_to_ui()

func _load_config_to_ui():
	chassis_path_edit.text = current_config.get("chassis_model", "")
	
	var offset = RobotModelLibrary.parse_vector3(current_config.get("chassis_offset", [0, 0, 0]))
	chassis_pos_spinboxes[0].value = offset.x
	chassis_pos_spinboxes[1].value = offset.y
	chassis_pos_spinboxes[2].value = offset.z
	
	var rot = RobotModelLibrary.parse_vector3(current_config.get("chassis_rotation", [0, 0, 0]))
	chassis_rot_spinboxes[0].value = rot.x
	chassis_rot_spinboxes[1].value = rot.y
	chassis_rot_spinboxes[2].value = rot.z
	
	_refresh_component_list()

func _refresh_component_list():
	component_list.clear()
	var components = current_config.get("components", {})
	for comp_name in components.keys():
		component_list.add_item(comp_name)

func _open_chassis_file_dialog():
	chassis_file_dialog.popup_centered_ratio(0.6)

func _on_chassis_file_selected(path: String):
	# Copy to user:// if needed
	var final_path = _import_model_file(path)
	chassis_path_edit.text = final_path
	current_config["chassis_model"] = final_path

func _import_model_file(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return path
		
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return path
	
	var content_hash = f.get_md5(path)
	f.close()
	var ext = path.get_extension()
	var filename = content_hash + "." + ext
	
	var dest_dir = "user://models"
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("models"):
		dir.make_dir("models")
	
	var dest_path = dest_dir + "/" + filename
	if FileAccess.file_exists(dest_path):
		return dest_path
	
	var dir_abs = DirAccess.open(path.get_base_dir())
	if dir_abs:
		var err = dir_abs.copy(path, dest_path)
		if err == OK:
			return dest_path
	
	return path

func _add_component():
	_open_component_dialog("")

func _edit_component():
	var sel = component_list.get_selected_items()
	if sel.size() == 0:
		return
	var comp_name = component_list.get_item_text(sel[0])
	_open_component_dialog(comp_name)

func _remove_component():
	var sel = component_list.get_selected_items()
	if sel.size() == 0:
		return
	var comp_name = component_list.get_item_text(sel[0])
	if current_config.has("components") and current_config["components"].has(comp_name):
		current_config["components"].erase(comp_name)
		_refresh_component_list()

func _open_component_dialog(comp_name: String):
	var dialog = load("res://EditComponentDialog.gd").new()
	add_child(dialog)
	
	var comp_config = {}
	if comp_name != "" and current_config.get("components", {}).has(comp_name):
		comp_config = current_config["components"][comp_name].duplicate(true)
	
	dialog.setup(comp_name, comp_config)
	dialog.component_saved.connect(_on_component_saved.bind(comp_name))
	dialog.popup_centered()
	dialog.visibility_changed.connect(func(): if not dialog.visible: dialog.queue_free())

func _on_component_saved(new_name: String, config: Dictionary, old_name: String):
	if not current_config.has("components"):
		current_config["components"] = {}
	
	# If renamed, remove old
	if old_name != "" and old_name != new_name:
		current_config["components"].erase(old_name)
	
	current_config["components"][new_name] = config
	_refresh_component_list()

func _on_confirmed():
	# Gather UI to config
	current_config["chassis_model"] = chassis_path_edit.text
	current_config["chassis_offset"] = [
		chassis_pos_spinboxes[0].value,
		chassis_pos_spinboxes[1].value,
		chassis_pos_spinboxes[2].value
	]
	current_config["chassis_rotation"] = [
		chassis_rot_spinboxes[0].value,
		chassis_rot_spinboxes[1].value,
		chassis_rot_spinboxes[2].value
	]
	
	var new_name = robot_name_edit.text.strip_edges()
	if new_name == "":
		new_name = "Unnamed Robot"
	
	# Handle rename
	if editing_robot_name != "" and editing_robot_name != new_name:
		RobotModelLibrary.rename_custom_robot(editing_robot_name, new_name)
	else:
		RobotModelLibrary.add_custom_robot(new_name, current_config)
	
	robot_saved.emit(new_name)
	hide()
