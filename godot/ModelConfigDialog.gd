extends AcceptDialog

signal settings_changed(options: Dictionary)

var current_options = {}

var path_line_edit: LineEdit
var file_dialog: FileDialog
var pos_spinboxes = []
var rot_spinboxes = []

func _init():
	title = "Model Configuration"
	min_size = Vector2(400, 300)

func _ready():
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# --- Model File ---
	var hbox_file = HBoxContainer.new()
	vbox.add_child(hbox_file)
	
	var label = Label.new()
	label.text = "Model File:"
	hbox_file.add_child(label)
	
	path_line_edit = LineEdit.new()
	path_line_edit.editable = false
	path_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_file.add_child(path_line_edit)
	
	var btn = Button.new()
	btn.text = "Select..."
	btn.pressed.connect(_open_file_dialog)
	hbox_file.add_child(btn)
	
	# --- Position Offset ---
	vbox.add_child(HSeparator.new())
	var lbl_pos = Label.new()
	lbl_pos.text = "Position Offset (meters):"
	vbox.add_child(lbl_pos)
	
	var hbox_pos = HBoxContainer.new()
	vbox.add_child(hbox_pos)
	
	for i in range(3):
		var sb = SpinBox.new()
		sb.step = 0.01
		sb.min_value = -100.0
		sb.max_value = 100.0
		sb.custom_minimum_size.x = 80
		sb.prefix = ["X", "Y", "Z"][i]
		sb.value_changed.connect(_on_val_changed)
		hbox_pos.add_child(sb)
		pos_spinboxes.append(sb)

	# --- Rotation Offset ---
	vbox.add_child(HSeparator.new())
	var lbl_rot = Label.new()
	lbl_rot.text = "Rotation Offset (degrees):"
	vbox.add_child(lbl_rot)
	
	var hbox_rot = HBoxContainer.new()
	vbox.add_child(hbox_rot)
	
	for i in range(3):
		var sb = SpinBox.new()
		sb.step = 0.1
		sb.min_value = -360.0
		sb.max_value = 360.0
		sb.custom_minimum_size.x = 80
		sb.prefix = ["R", "P", "Y"][i] # Roll Pitch Yaw
		sb.value_changed.connect(_on_val_changed)
		hbox_rot.add_child(sb)
		rot_spinboxes.append(sb)

	# Setup File Dialog
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.gltf, *.glb ; GLTF Files", "*.obj ; OBJ Files", "*.tscn, *.scn; Godot Scenes"]
	file_dialog.use_native_dialog = true
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)

	# Connect buttons
	confirmed.connect(hide)
	
func setup(options: Dictionary):
	current_options = options.duplicate()
	
	# Path
	path_line_edit.text = current_options.get("Model", "")
	
	# Position
	var pos = current_options.get("Offset", Vector3.ZERO)
	pos_spinboxes[0].value = pos.x
	pos_spinboxes[1].value = pos.y
	pos_spinboxes[2].value = pos.z
	
	# Rotation
	var rot = current_options.get("Rotation", Vector3.ZERO)
	rot_spinboxes[0].value = rot.x
	rot_spinboxes[1].value = rot.y
	rot_spinboxes[2].value = rot.z

func _open_file_dialog():
	file_dialog.popup_centered_ratio(0.6)

func _on_file_selected(path: String):
	# Handle file uniqueness logic HERE or in parent? 
	# Let's do it here to keep UI contained, passing back the "final" path key.
	# Actually, the copy logic was in TopicRow. Let's move it here or utility.
	# For now, let's just use the path and let the caller handle persistence/copying?
	# Better: This dialog just returns the path selected. The caller (TopicRow) handles the copying logic 
	# because it knows about user:// scope etc.
	# OR we do it here.
	path_line_edit.text = path
	current_options["Model"] = path # Caller will process this path
	_emit_change()

func _on_val_changed(_val):
	# Update dictionary
	current_options["Offset"] = Vector3(
		pos_spinboxes[0].value,
		pos_spinboxes[1].value,
		pos_spinboxes[2].value
	)
	current_options["Rotation"] = Vector3(
		rot_spinboxes[0].value,
		rot_spinboxes[1].value,
		rot_spinboxes[2].value
	)
	_emit_change()

func _emit_change():
	settings_changed.emit(current_options)
