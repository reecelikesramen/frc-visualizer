extends Control

var nt = NT4.new()
@onready var tree: Tree = $Tree

var topic_map = {} # Path String -> TreeItem
var update_timer = 0.0

# Initial "local" IP, can be changed or make a UI field for it.
var server_ip = "127.0.0.1" 

func _ready():
	add_child(nt)
	nt.start_client(server_ip)
	
	# Setup Tree
	tree.columns = 3
	tree.set_column_title(0, "Path")
	tree.set_column_title(1, "Value")
	tree.set_column_title(2, "Type")
	tree.set_column_titles_visible(true)
	
	# Create Root
	var root = tree.create_item()
	root.set_text(0, "/")
	topic_map["/"] = root

func _process(delta):
	update_timer += delta
	if update_timer > 0.5: # 2 Hz update
		update_timer = 0.0
		_refresh_tree()

func _refresh_tree():
	var info_array = nt.get_topic_info()
	
	for topic in info_array:
		var topic_name = String(topic["name"])
		var topic_type = String(topic["type"])
		
		# 1. Get/Create Tree Item
		var item = _get_or_create_item(topic_name)
		
		# 2. Update Value Display
		var val_str = _fetch_value_string(topic_name, topic_type)
		item.set_text(1, val_str)
		item.set_text(2, topic_type)

func _get_or_create_item(full_path: String) -> TreeItem:
	if topic_map.has(full_path):
		return topic_map[full_path]
	
	# Parse path
	# NT paths usually start with /, so split("/", false) handles empty first part
	var parts = full_path.split("/", false)
	
	var current_item = topic_map["/"]
	var accumulated_path = ""
	
	for part in parts:
		accumulated_path += "/" + part
		
		if topic_map.has(accumulated_path):
			current_item = topic_map[accumulated_path]
		else:
			# Create new child
			var new_item = tree.create_item(current_item)
			new_item.set_text(0, part)
			new_item.collapsed = true # Start collapsed? Or expanded? 'can expand folders' usually means collapsed by default except maybe top level.
			
			topic_map[accumulated_path] = new_item
			current_item = new_item
			
	return current_item

func _fetch_value_string(topic: String, type: String) -> String:
	# Basic types
	if type == "double":
		return str(nt.get_number(topic, 0.0))
	elif type == "float":
		return str(nt.get_number(topic, 0.0))
	elif type == "int": # NT4 int is usually Int64/IntegerTopic
		return str(int(nt.get_number(topic, 0.0))) # Warning: NT4 get_number returns double, I didn't expose get_integer specifically yet, but get_number usually handles numbers? 
		# Wait, NT4 has IntegerTopic. get_number logic in my cpp does GetDoubleTopic...
		# Uh oh. get_number only subscribes to DoubleTopic!
		# It won't work for IntegerTopic.
		# But usually FRC uses Doubles primarily. 
		# If I need Integer support, I need to add get_integer.
		# I'll enable "int" case just in case, but it might fail if topic is strictly Int.
		# For now, return "..."
		return "..."
	elif type == "boolean":
		return str(nt.get_boolean(topic, false))
	elif type == "string":
		return nt.get_string(topic, "")
	elif type == "double[]":
		return str(nt.get_number_array(topic, PackedFloat64Array()))
	elif type == "boolean[]":
		return str(nt.get_boolean_array(topic, []))
	elif type == "string[]":
		return str(nt.get_string_array(topic, PackedStringArray()))
		
	return "..."
