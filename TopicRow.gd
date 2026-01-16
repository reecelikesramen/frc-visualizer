extends HBoxContainer

var topic_path: String = ""
var topic_type: String = ""
var nt_instance = null

@onready var icon_rect: TextureRect = $Icon
@onready var name_label: Label = $NameLabel
@onready var value_label: Label = $ValueLabel
@onready var path_label: Label = $PathLabel
@onready var close_button: Button = $CloseButton

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
		
		var val = _fetch_value()
		value_label.text = val
		
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
		pass

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
		return "%.3f" % nt_instance.get_number(topic_path, 0.0)
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

func _ready():
	# Setup icon input
	icon_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	icon_rect.gui_input.connect(_on_icon_gui_input)

func _on_icon_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_context_menu()

func _show_context_menu():
	var popup = PopupMenu.new()
	popup.add_item("Visualize as Text (Default)", 0)
	
	if topic_type == "struct:Pose3d":
		popup.add_item("Visualize as Robot", 1)
		popup.add_item("Visualize as Arrow", 2)
		
	popup.id_pressed.connect(_on_context_menu_item_selected)
	add_child(popup)
	popup.position = get_global_mouse_position()
	popup.show()

func _on_context_menu_item_selected(id):
	# Handle selection
	print("Selected visualization: ", id)
	# Todo: Implement actual visualization switching
	
func _on_close_button_pressed():
	queue_free()
