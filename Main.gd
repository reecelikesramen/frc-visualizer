extends Node3D

@onready var nt_tree_view = $HSplitContainer/NTTreeView
@onready var topic_dock = $HSplitContainer/VSplitContainer/TopicDock
@onready var h_split = $HSplitContainer
@onready var v_split = $HSplitContainer/VSplitContainer
@onready var camera = $Camera3D

const SAVE_PATH = "user://ui_state.tres"
var auto_save_timer = 0.0

func _ready():
	# Wire up dependencies
	var nt = nt_tree_view.nt
	topic_dock.set_nt_instance(nt)
	
	load_ui_state()
	
	# Handle clean exit request for auto-save
	get_tree().auto_accept_quit = false

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
	var data = UISaveData.new()
	data.monitored_topics = topic_dock.get_topics()
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
			# Restore Dock
			var nt = nt_tree_view.nt
			topic_dock.restore_topics(data.monitored_topics, nt)
			
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
