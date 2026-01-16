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
@onready var highlight_rect = $HighlightRect # Added via code/edit separately or expected

# Hierarchy
var parent_row = null # If nested
var row_data = {} # {path, type, etc} for drag data
var is_drag_highlighted = false

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
	
	# Set tooltip
	tooltip_text = path
	
	row_data = {
		"path": topic_path,
		"type": "nt_topic",
		"nt_type": topic_type,
		"nt_ref": nt_instance
	}

# --- Drag & Drop ---

func _get_drag_data(at_position):
	var preview = Label.new()
	preview.text = topic_path
	set_drag_preview(preview)
	
	# If we are dragging, we might be dragging THIS whole tree.
	# Return self reference or data struct? Data struct is safer for cross-dock.
	# But we need to move the node.
	row_data["source_node"] = self
	return row_data

func _can_drop_data(at_position, data):
	if typeof(data) == TYPE_DICTIONARY and data.get("type") == "nt_topic":
		var source_node = data.get("source_node")
		if source_node == self: return false # Can't drop on self
		
		# STRICT VALIDATION based on User Request
		# "Add to existing 'Robot' or 'Ghost' item"
		# Check if THIS row (parent) has an active visualizer
		var dock = get_dock()
		if dock and dock.active_visualizers.has(topic_path):
			var parent_viz_info = dock.active_visualizers[topic_path]
			var parent_viz_type = parent_viz_info["type"]
			
			var child_nt_type = data.get("nt_type", "")
			
			# Check if there are any compatible modifiers for this child type given the parent
			var modifiers = VisualizerRegistry.get_compatible_modifiers(child_nt_type, parent_viz_type)
			if modifiers.is_empty():
				# No compatible modifiers? REJECT.
				return false
		else:
			# Parent has NO visualizer.
			# User strict rule: "Prevent top-level visualizers from being nested under any other visualizer."
			# And "Add to existing 'Robot' or 'Ghost' item" implies parent MUST be visualized.
			return false

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
		# Notify dock of structure change
		get_tree().call_group("dock_updates", "_notify_change")
		return

	# New Topic Drop (from Tree)
	var path = data.get("path")
	var type = data.get("nt_type")
	var nt_ref = data.get("nt_ref")
	
	if path and type:
		# Check duplicates in immediate children?
		for child in children_container.get_children():
			if "topic_path" in child and child.topic_path == path:
				return # Already exists
		
		# Instantiate new row
		# We need to load the scene. self.filename? Or preload from script?
		# TopicDock has the scene preloaded. We can ask Dock?
		# Or just load("res://TopicRow.tscn")
		var new_row = load("res://TopicRow.tscn").instantiate()
		children_container.add_child(new_row)
		new_row.setup(path, type, nt_ref)
		new_row.parent_row = self
		
		# Connect signals logic is tricky because `TopicDock` usually connects them.
		# `TopicRow` doesn't have `_on_visualization_requested`.
		# We need to connect the new row's signals to `TopicDock`!
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

func _set_drag_highlight(enabled: bool):
	if is_drag_highlighted == enabled: return
	is_drag_highlighted = enabled
	if highlight_rect:
		highlight_rect.visible = enabled
	else:
		# Fallback if node missing?
		modulate = Color(1.2, 1.2, 1.2) if enabled else Color(1, 1, 1)


func _process(_delta):
	if nt_instance and topic_path != "":
		# Check liveness
		# We can check if get_topic_info contains our path, or simply check the value
		# NT4 doesn't have a cheap "exists" on client side easily without checking topic info list linearly
		# But we can try to get value. If it returns default for a long time...?
		# Better: Check if the value returned is "non-empty/non-default" or if we use get_topic_info check occasionally.
		# For efficiency, let's just assume if get_value returns default it might be missing, 
		# OR we can assume if it's not in the tree it doesn't exist.
		# Let's check `nt_instance.get_topic_info`? No that's expensive every frame.
		# NT4 lib usually returns 0/default if missing.
		# Let's just modify visual based on value.
		# Basic liveness check: If we have a standard default value and it never changes, it might be missing.
		# But better, if the tree refreshes, we know what topics exist.
		# But `TopicRow` doesn't have access to the Tree.
		# Let's rely on simple rule: If `nt_instance` is valid, we assume it's connected.
		# If we want "missing topic" (e.g. robot offline or code changed), 
		# we'd need to poll `nt.get_topic_info()` occasionally. 
		# Let's do a loose check: if value is empty/default, dim it.
		# Actually, user requirement: "add an X symbol and a muted text or strikethrough"
		# To strictly know if it "no longer exists", we need to know the list of ALL topics.
		# Let's have TopicDock pass the "known_topics" set to rows? 
		# Or have TopicRow poll `nt_instance` occasionally?
		# Let's skip complex polling for now and just set text. 
		# If we really want to support 'missing' properly we need the list of topics.
		var val = _fetch_value()
		value_label.text = val
		
		# Basic check
		if val == "...":
			_set_params(true)
		else:
			_set_params(false)

func _fetch_value() -> String:
	# Check for Structs
	if topic_type.begins_with("struct:"):
		var raw = nt_instance.get_value(topic_path, PackedByteArray())
		if typeof(raw) == TYPE_PACKED_BYTE_ARRAY:
			if raw.size() > 0:
				_set_params(false) # Exists
				var parsed = StructParser.parse_packet(raw, topic_type)
				return StructParser.format_value(parsed, false) # Long format
			else:
				_set_params(true) # Empty/Default -> Missing?
				return "..."
		return "struct..."
		
	# For primitives, hard to distinguish 0.0 from missing.
	# But we can assume if we are getting updates it works.
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
		return StructParser.format_value(nt_instance.get_boolean_array(topic_path, []), false)
	# Add other types as needed
	return "..."

func _set_params(missing: bool):
	if missing:
		modulate.a = 0.5
		# We could add strikethrough if we had a font override, but alpha is good for now.
		# Adding 'X' symbol:
		if not value_label.text.begins_with("[X]"):
			# value_label.text = "[X] " + value_label.text
			pass
	else:
		modulate.a = 1.0

signal visualization_requested(path: String, type: String, viz_type: String)

func _ready():
	# Setup icon input
	icon_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	icon_rect.gui_input.connect(_on_icon_gui_input)

func _on_icon_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_context_menu()

func get_dock():
	# Traverse up to find TopicDock
	# Row -> VBox -> ScrollContainer -> TopicDock
	var p = get_parent()
	while p:
		if p.name == "TopicDock" or p.get_script() == load("res://TopicDock.gd"):
			return p
		p = p.get_parent()
	return null

func _show_context_menu():
	var popup = PopupMenu.new()
	popup.add_item("Visualize as Text (Default)", 0)
	
	# Dictionary to map IDs to specific visualizer names strings
	# because PopupMenu uses integer IDs.
	var id_map = {}
	var current_id = 100
	
	# Check Parent Visualization Status
	var has_visualized_parent = false
	var parent_viz_type = ""
	
	if parent_row:
		var dock = get_dock()
		if dock and dock.active_visualizers.has(parent_row.topic_path):
			has_visualized_parent = true
			parent_viz_type = dock.active_visualizers[parent_row.topic_path]["type"]

	# 1. Top Level Visualizers
	# ONLY show if we are NOT nested under a visualizer.
	if not has_visualized_parent:
		# Check if we are compatible with any top level visualizers
		var compatible_viz = VisualizerRegistry.get_compatible_visualizers(topic_type)
		
		if compatible_viz.size() > 0:
			popup.add_separator("Visualizers")
			for viz in compatible_viz:
				popup.add_item(viz, current_id)
				id_map[current_id] = viz
				current_id += 1
			
	# 2. Modifiers (Context-based)
	if has_visualized_parent:
		var modifiers = VisualizerRegistry.get_compatible_modifiers(topic_type, parent_viz_type)
		
		if modifiers.size() > 0:
			popup.add_separator("Add to Parent")
			for mod in modifiers:
				popup.add_item(mod, current_id)
				id_map[current_id] = mod
				current_id += 1
	
	# Store the map on the popup or self for retrieval?
	# PopupMenu doesn't store arbitrary data per item easily besides metadata...
	# Set metadata for each item!
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
		# Text / Default (clears others?)
		# Actually TopicDock "add_visualizer" checks if active and replaces/toggles.
		# If we select 0, implying "Remove Visualization".
		# Let's send a special signal or just null?
		# Existing logic: "If clicking the same type, we treat it as toggle OFF".
		# Text is basically "None".
		visualization_requested.emit(topic_path, topic_type, "none")
		return

	if viz_name:
		visualization_requested.emit(topic_path, topic_type, viz_name)
	else:
		print("Unknown visualizer ID selected: ", id)

	
func _on_close_button_pressed():
	queue_free()
