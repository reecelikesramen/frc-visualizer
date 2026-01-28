extends AcceptDialog

signal component_saved(name: String, config: Dictionary)

var name_edit: LineEdit
var model_path_edit: LineEdit
var file_dialog: FileDialog
var pos_spinboxes = []
var rot_spinboxes = []

func _init():
	title = "Edit Component"
	min_size = Vector2(400, 280)

func _ready():
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# Name
	var name_hbox = HBoxContainer.new()
	vbox.add_child(name_hbox)
	
	var name_label = Label.new()
	name_label.text = "Name:"
	name_hbox.add_child(name_label)
	
	name_edit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.placeholder_text = "Arm, Elevator, etc."
	name_hbox.add_child(name_edit)
	
	vbox.add_child(HSeparator.new())
	
	# Model File
	var file_hbox = HBoxContainer.new()
	vbox.add_child(file_hbox)
	
	var file_label = Label.new()
	file_label.text = "Model:"
	file_hbox.add_child(file_label)
	
	model_path_edit = LineEdit.new()
	model_path_edit.editable = false
	model_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	file_hbox.add_child(model_path_edit)
	
	var select_btn = Button.new()
	select_btn.text = "Select..."
	select_btn.pressed.connect(_open_file_dialog)
	file_hbox.add_child(select_btn)
	
	# Offset
	var pos_label = Label.new()
	pos_label.text = "Offset (meters):"
	vbox.add_child(pos_label)
	
	var pos_hbox = HBoxContainer.new()
	vbox.add_child(pos_hbox)
	for i in range(3):
		var sb = SpinBox.new()
		sb.step = 0.01
		sb.min_value = -100.0
		sb.max_value = 100.0
		sb.custom_minimum_size.x = 80
		sb.prefix = ["X", "Y", "Z"][i]
		pos_hbox.add_child(sb)
		pos_spinboxes.append(sb)
	
	# Rotation
	var rot_label = Label.new()
	rot_label.text = "Rotation (degrees):"
	vbox.add_child(rot_label)
	
	var rot_hbox = HBoxContainer.new()
	vbox.add_child(rot_hbox)
	for i in range(3):
		var sb = SpinBox.new()
		sb.step = 0.1
		sb.min_value = -360.0
		sb.max_value = 360.0
		sb.custom_minimum_size.x = 80
		sb.prefix = ["R", "P", "Y"][i]
		rot_hbox.add_child(sb)
		rot_spinboxes.append(sb)
	
	# File Dialog
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.gltf, *.glb ; GLTF Files", "*.obj ; OBJ Files"]
	file_dialog.use_native_dialog = true
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)
	
	confirmed.connect(_on_confirmed)

func setup(comp_name: String, config: Dictionary):
	name_edit.text = comp_name
	model_path_edit.text = config.get("model", "")
	
	var offset = RobotModelLibrary.parse_vector3(config.get("offset", [0, 0, 0]))
	pos_spinboxes[0].value = offset.x
	pos_spinboxes[1].value = offset.y
	pos_spinboxes[2].value = offset.z
	
	var rot = RobotModelLibrary.parse_vector3(config.get("rotation", [0, 0, 0]))
	rot_spinboxes[0].value = rot.x
	rot_spinboxes[1].value = rot.y
	rot_spinboxes[2].value = rot.z

func _open_file_dialog():
	file_dialog.popup_centered_ratio(0.6)

func _on_file_selected(path: String):
	var final_path = _import_model_file(path)
	model_path_edit.text = final_path

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

func _on_confirmed():
	var n = name_edit.text.strip_edges()
	if n == "":
		n = "Component"
	
	var config = RobotModelLibrary.make_component_config(
		model_path_edit.text,
		Vector3(pos_spinboxes[0].value, pos_spinboxes[1].value, pos_spinboxes[2].value),
		Vector3(rot_spinboxes[0].value, rot_spinboxes[1].value, rot_spinboxes[2].value)
	)
	component_saved.emit(n, config)
	hide()
