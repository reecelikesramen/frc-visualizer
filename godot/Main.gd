extends Node3D

@onready var nt_tree_view = $HSplitContainer/NTTreeView
@onready var topic_dock = $HSplitContainer/RightSide/VSplitContainer/TopicDock
@onready var h_split = $HSplitContainer
@onready var v_split = $HSplitContainer/RightSide/VSplitContainer
@onready var camera = $Camera3D
@onready var tab_bar = $HSplitContainer/RightSide/TabBar
@onready var field_2d = $HSplitContainer/RightSide/VSplitContainer/ViewContainer/Field2D
@onready var field_3d = $Field
@onready var robot_parent = $RobotParent
@onready var spacer_3d = $HSplitContainer/RightSide/VSplitContainer/ViewContainer/Spacer

const SAVE_PATH = "user://ui_state.tres"
var auto_save_timer = 0.0
var current_tab_idx = 0

# Cache for monitored topics per tab: tab_idx (int) -> Array[Dictionary]
var monitored_topics_cache = {}

var menu_bar: MenuBar
var file_menu: PopupMenu
var connect_dialog: AcceptDialog
var team_num_edit: LineEdit
var file_dialog: FileDialog

func _ready():
	# Wired up dependencies
	var nt = nt_tree_view.nt
	topic_dock.set_nt_instance(nt)
	
	_setup_menus()

	
	# Connect TabBar
	tab_bar.tab_changed.connect(_on_tab_changed)
	
	load_ui_state()
	
	# Apply initial tab state
	_update_view_visibility()
	
	# Handle clean exit request for auto-save
	get_tree().auto_accept_quit = false

	# --- Add Timeline ---
	var right_side = $HSplitContainer/RightSide
	var TimelineScript = preload("res://Timeline.gd")
	var timeline = TimelineScript.new()
	timeline.name = "Timeline"
	timeline.custom_minimum_size.y = 60 # Initial height
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_side.add_child(timeline)
	# Move to index 1 (Below TabBar, Above VSplitContainer)
	right_side.move_child(timeline, 1)

func _on_tab_changed(tab_idx: int):
	# Save current topics to cache before switching
	monitored_topics_cache[current_tab_idx] = topic_dock.get_topics()
	
	current_tab_idx = tab_idx
	_update_view_visibility()
	
	# Update TopicDock mode
	if current_tab_idx == 0:
		topic_dock.current_mode = "3D"
	else:
		topic_dock.current_mode = "2D"
	
	# Restore topics for new tab
	_clear_topic_dock()
	
	var topics_generic = monitored_topics_cache.get(current_tab_idx, [])
	var topics_typed: Array[Dictionary] = []
	topics_typed.assign(topics_generic)
	
	topic_dock.restore_topics(topics_typed, nt_tree_view.nt)

func _clear_topic_dock():
	topic_dock.clear_topics()

func _update_view_visibility():
	if current_tab_idx == 0: # 3D Field
		field_3d.visible = true
		robot_parent.visible = true
		camera.process_mode = Node.PROCESS_MODE_INHERIT
		camera.current = true # Enable rendering
		field_2d.visible = false
		spacer_3d.visible = true
	else: # 2D Field
		field_3d.visible = false
		robot_parent.visible = false
		camera.process_mode = Node.PROCESS_MODE_DISABLED
		camera.current = false # Disable rendering
		field_2d.visible = true
		# ...
		pass

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_ui_state()
		get_tree().quit()

func _process(delta):
	auto_save_timer += delta
	if auto_save_timer > 5.0:
		save_ui_state()
		auto_save_timer = 0.0

func _unhandled_input(event):
	# Click off UI to defocus (restore camera control context)
	if event is InputEventMouseButton:
		if event.pressed:
			var focus_owner = get_viewport().gui_get_focus_owner()
			if focus_owner:
				# If we clicked on the background/3D area, release focus
				focus_owner.release_focus()

func save_ui_state():
	# Update current tab cache before saving
	monitored_topics_cache[current_tab_idx] = topic_dock.get_topics()

	var data = UISaveData.new()
	data.monitored_topics_by_tab = monitored_topics_cache
	data.active_tab = current_tab_idx
	data.expanded_paths = nt_tree_view.get_expanded_paths()
	
	# Camera
	data.camera_position = camera.position
	data.camera_rotation = camera.rotation
	
	# Search & UI
	data.search_filter = nt_tree_view.get_filter_text()
	data.split_offset = h_split.split_offset
	data.v_split_offset = v_split.split_offset
	
	var err = ResourceSaver.save(data, SAVE_PATH)
	if err != OK:
		print("Failed to save UI state: ", err)

func load_ui_state():
	if ResourceLoader.exists(SAVE_PATH):
		var data = ResourceLoader.load(SAVE_PATH)
		if data is UISaveData:
			# Restore active tab
			current_tab_idx = data.active_tab
			if current_tab_idx >= tab_bar.tab_count:
				current_tab_idx = 0
			tab_bar.current_tab = current_tab_idx
			
			# Restore Topics Cache
			monitored_topics_cache = data.monitored_topics_by_tab
			
			# Restore Dock for current tab
			# Restore Dock for current tab
			var topics_generic = monitored_topics_cache.get(current_tab_idx, [])
			var topics_typed: Array[Dictionary] = []
			topics_typed.assign(topics_generic)
			
			topic_dock.restore_topics(topics_typed, nt_tree_view.nt)
			
			# Restore Tree Expansion
			nt_tree_view.set_paths_to_expand(data.expanded_paths)
			
			# Restore Camera
			camera.position = data.camera_position
			camera.rotation = data.camera_rotation
			
			# Restore Search & UI
			nt_tree_view.set_filter_text(data.search_filter)
			h_split.split_offset = data.split_offset
			v_split.split_offset = data.v_split_offset
	else:
		print("No saved UI state found.")

func _setup_menus():
	menu_bar = MenuBar.new()
	menu_bar.name = "MenuBar"
	menu_bar.prefer_global_menu = true
	add_child(menu_bar)

	file_menu = PopupMenu.new()
	file_menu.name = "File"
	menu_bar.add_child(file_menu)
	
	file_menu.add_item("Connect to Simulator", 1)
	file_menu.add_item("Connect to Robot...", 2)
	file_menu.add_item("Load Log File...", 3)
	file_menu.id_pressed.connect(_on_file_menu_item)
	
	# Dialogs
	connect_dialog = AcceptDialog.new()
	connect_dialog.title = "Connect to Robot"
	
	var vbox = VBoxContainer.new()
	connect_dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "Enter Team Number:"
	vbox.add_child(label)
	
	team_num_edit = LineEdit.new()
	team_num_edit.placeholder_text = "e.g. 3538"
	team_num_edit.custom_minimum_size.x = 200
	vbox.add_child(team_num_edit)
	
	connect_dialog.confirmed.connect(_on_connect_confirmed)
	add_child(connect_dialog)
	
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.wpilog ; WPILog Files", "*.datalog ; DataLog Files"]
	file_dialog.file_selected.connect(_on_log_file_selected)
	file_dialog.title = "Open Log File"
	file_dialog.min_size = Vector2(600, 400)
	add_child(file_dialog)

func _on_file_menu_item(id):
	if id == 1:
		# Connect Simulator
		nt_tree_view.clear_tree()
		nt_tree_view.nt.start_client("127.0.0.1")
	elif id == 2:
		# Connect Robot
		connect_dialog.popup_centered()
		team_num_edit.grab_focus()
	elif id == 3:
		# Load Log
		file_dialog.popup_centered_ratio(0.6)

func _on_connect_confirmed():
	var txt = team_num_edit.text
	if txt.is_valid_int():
		var team = int(txt)
		var ip = "10.%d.%d.2" % [team / 100, team % 100]
		print("Connecting to Robot IP: ", ip)
		nt_tree_view.clear_tree()
		nt_tree_view.nt.start_client(ip)
	else:
		print("Invalid Team Number")

func _on_log_file_selected(path):
	nt_tree_view.clear_tree()
	nt_tree_view.nt.load_log_file(path)
