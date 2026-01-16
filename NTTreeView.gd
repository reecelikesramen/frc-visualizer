extends Control

var nt = NT4.new()
var tree: Tree
var search_bar: LineEdit

var topic_map = {} # Path String -> TreeItem
var update_timer = 0.0
var saved_expansion_set = {} # Path -> bool

var tuning_root_item: TreeItem = null
var tuning_map = {} # RelPath -> TreeItem

var server_ip = "127.0.0.1" 

func _ready():
	add_child(nt)
	nt.start_client(server_ip)
	nt.subscribe_to_all()
	
	if OS.get_name() == "macOS":
		get_window().content_scale_factor = 1.5
	
	# --- Dynamic UI Setup (Search Bar) ---
	var panel = $Panel
	var old_tree = $Panel/Tree
	
	var vbox = VBoxContainer.new()
	vbox.layout_mode = 1 # Anchors
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	panel.add_child(vbox)
	
	search_bar = LineEdit.new()
	search_bar.placeholder_text = "Search..."
	search_bar.text_changed.connect(_on_search_text_changed)
	vbox.add_child(search_bar)
	
	# Reparent Tree
	old_tree.get_parent().remove_child(old_tree)
	vbox.add_child(old_tree)
	old_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree = old_tree
	
	# Setup Tree
	tree.columns = 3 # FIX: Changed to 3 to support metadata(2)
	tree.set_column_title(0, "Path")
	tree.set_column_title(1, "Value")
	tree.set_column_titles_visible(true)
	tree.hide_root = true 
	
	# Enable interaction
	tree.allow_rmb_select = true
	tree.item_mouse_selected.connect(_on_item_mouse_selected)
	tree.item_edited.connect(_on_item_edited)
	
	# Create Roots
	var root = tree.create_item()
	root.set_text(0, "/")
	topic_map["/"] = root
	
	tuning_root_item = tree.create_item(root)
	tuning_root_item.set_text(0, "Tuning")
	tuning_root_item.set_selectable(0, false)
	tuning_map[""] = tuning_root_item # Root of tuning

func set_paths_to_expand(paths: Array[String]):
	for p in paths:
		saved_expansion_set[p] = true

func get_expanded_paths() -> Array[String]:
	var paths: Array[String] = []
	for path in topic_map:
		var item = topic_map[path]
		if item and not item.collapsed:
			paths.append(path)
	return paths

func get_filter_text() -> String:
	if search_bar: return search_bar.text
	return ""

func set_filter_text(txt: String):
	if search_bar:
		search_bar.text = txt
		_on_search_text_changed(txt) # Force update

func _on_search_text_changed(new_text):
	_apply_filter(new_text)

func _apply_filter(filter_text: String):
	var root = topic_map["/"]
	_recursive_filter(root, filter_text.to_lower())

func _recursive_filter(item: TreeItem, filter: String) -> bool:
	var visible = false
	var child = item.get_first_child()
	while child:
		var child_visible = _recursive_filter(child, filter)
		if child_visible:
			visible = true
		child = child.get_next()
		
	if not visible:
		# If empty filter, show everything
		if filter.is_empty():
			visible = true
		elif filter in item.get_text(0).to_lower():
			visible = true
			
	item.visible = visible
	return visible

func _process(delta):
	update_timer += delta
	if update_timer > 0.033: 
		update_timer = 0.0
		_refresh_tree()

func _refresh_tree():
	var info_array = nt.get_topic_info()
	
	for topic in info_array:
		var topic_name = String(topic["name"])
		var topic_type = String(topic["type"])
		
		# 1. Normal Tree
		var item = _get_or_create_item(topic_name)
		
		# Ensure metadata[0] is always set to full path
		if item.get_metadata(0) == null:
			item.set_metadata(0, topic_name)
			
		_update_item_value(item, topic_name, topic_type, false, "")
		
		# 2. Tuning Mirror
		if topic_name.begins_with("/AdvantageKit/NetworkInputs/Tuning/"):
			var rel_path = topic_name.replace("/AdvantageKit/NetworkInputs/Tuning/", "")
			var tuning_item = _get_or_create_tuning_item(rel_path)
			
			tuning_item.set_metadata(0, topic_name) 
			_update_item_value(tuning_item, topic_name, topic_type, true, "")

func _update_item_value(item: TreeItem, topic_name: String, topic_type: String, editable: bool, struct_subpath: String):
	var raw_val = null
	var val_str = "..."
		
	# Skip update if editing
	if tree.get_edited() == item:
		return

	if topic_type.begins_with("struct:"):
		var bytes = nt.get_value(topic_name, PackedByteArray())
		if typeof(bytes) == TYPE_PACKED_BYTE_ARRAY:
			var parsed = StructParser.parse_packet(bytes, topic_type)
			val_str = StructParser.format_value(parsed, true) 
			raw_val = parsed # FIX: Use PARSED value for dictionary recursion
		else:
			val_str = "struct..."
	elif topic_type == "double" or topic_type == "float":
		raw_val = nt.get_number(topic_name, 0.0)
		val_str = "%.3f" % raw_val
	elif topic_type == "boolean":
		raw_val = nt.get_boolean(topic_name, false)
		val_str = str(raw_val)
	elif topic_type == "int":
		raw_val = nt.get_number(topic_name, 0)
		val_str = str(int(raw_val))
	elif topic_type == "string":
		raw_val = nt.get_string(topic_name, "")
		val_str = raw_val
	elif topic_type.ends_with("[]"):
		if topic_type == "double[]":
			raw_val = nt.get_number_array(topic_name, PackedFloat64Array())
		elif topic_type == "boolean[]":
			raw_val = nt.get_boolean_array(topic_name, [])
		elif topic_type == "string[]":
			raw_val = nt.get_string_array(topic_name, PackedStringArray())
			
		val_str = StructParser.format_value(raw_val, true)
	else:
		val_str = _fetch_value_string(topic_name, topic_type)
		
	item.set_text(1, val_str)
	item.set_metadata(1, topic_type)
	item.set_editable(1, editable)
	
	# Verify complex children
	if raw_val != null and (struct_subpath == ""): 
		var complex_data = StructParser.to_dictionary(raw_val)
		if typeof(complex_data) == TYPE_DICTIONARY or typeof(complex_data) == TYPE_ARRAY:
			_update_complex_item(item, complex_data, editable, topic_name)

func _update_complex_item(item: TreeItem, data: Variant, editable: bool, root_topic: String, path_prefix: String = ""):
	var dict_form = StructParser.to_dictionary(data)
	
	if typeof(dict_form) == TYPE_ARRAY:
		var arr = dict_form
		var current = item.get_first_child()
		for i in range(arr.size()):
			if current == null:
				current = item.create_child()
				current.set_text(0, str(i))
				current.collapsed = true 
			else:
				current.set_text(0, str(i))
				
			var elem_val = arr[i]
			current.set_text(1, StructParser.format_value(elem_val, true))
			current.set_editable(1, editable)
			
			current.set_metadata(0, root_topic)
			current.set_metadata(1, "array_elem")
			current.set_metadata(2, str(i)) 
			
			if typeof(elem_val) == TYPE_DICTIONARY or typeof(elem_val) == TYPE_ARRAY:
				_update_complex_item(current, elem_val, editable, root_topic, path_prefix + "/" + str(i))
				
			current = current.get_next()
		
		while current:
			var next = current.get_next()
			item.remove_child(current)
			current = next
				
	elif typeof(dict_form) == TYPE_DICTIONARY:
		var keys = dict_form.keys()
		if dict_form.has("_type"): keys.erase("_type")
		keys.sort()
		
		var existing_children = {}
		var c = item.get_first_child()
		while c:
			existing_children[c.get_text(0)] = c
			c = c.get_next()
			
		for k in keys:
			var val = dict_form[k]
			var child = existing_children.get(k)
			if not child:
				child = item.create_child()
				child.set_text(0, k)
				child.collapsed = true
			
			var subpath = k if path_prefix == "" else path_prefix + "/" + k
			
			child.set_text(1, StructParser.format_value(val, true))
			child.set_editable(1, editable)
			
			child.set_metadata(0, root_topic) 
			child.set_metadata(1, "struct_field") 
			child.set_metadata(2, subpath) # Metadata index 2 is now safe
			
			if typeof(val) == TYPE_DICTIONARY or typeof(val) == TYPE_ARRAY:
				_update_complex_item(child, val, editable, root_topic, subpath)
				
			existing_children.erase(k)
		
		for k in existing_children:
			item.remove_child(existing_children[k])

func _on_item_edited():
	var item = tree.get_edited()
	if not item: return
	
	var text = item.get_text(1)
	var type = item.get_metadata(1)
	var real_path = item.get_metadata(0)
	
	if type == "struct_field":
		var subpath = item.get_metadata(2)
		var raw = nt.get_value(real_path, PackedByteArray())
		if typeof(raw) != TYPE_PACKED_BYTE_ARRAY: return
		
		var topic_list = nt.get_topic_info()
		var schema_type = ""
		for t in topic_list:
			if str(t["name"]) == real_path:
				schema_type = str(t["type"])
				break
				
		if schema_type != "":
			var new_bytes = StructParser.update_struct(raw, schema_type, subpath, text)
			if new_bytes.size() > 0:
				nt.set_raw(real_path, new_bytes)
		
	elif real_path:
		if type == "double" or type == "float":
			if text.is_valid_float():
				nt.set_number(real_path, text.to_float())
			else:
				print("Invalid float input for ", real_path)
		elif type == "boolean":
			nt.set_boolean(real_path, text == "true")
		elif type == "string":
			nt.set_string(real_path, text)

func _get_or_create_item(full_path: String) -> TreeItem:
	if topic_map.has(full_path): return topic_map[full_path]
	var parts = full_path.split("/", false)
	var current = topic_map["/"]
	var acc = ""
	for part in parts:
		acc += "/" + part
		if topic_map.has(acc):
			current = topic_map[acc]
		else:
			var n = tree.create_item(current)
			n.set_text(0, part)
			n.collapsed = !saved_expansion_set.has(acc)
			n.set_metadata(0, acc)
			topic_map[acc] = n
			current = n
	return current
	
func _get_or_create_tuning_item(rel_path: String) -> TreeItem:
	if tuning_map.has(rel_path): return tuning_map[rel_path]
	var parts = rel_path.split("/", false)
	var current = tuning_root_item
	var acc = ""
	for part in parts:
		acc += "/" + part if acc != "" else part
		if tuning_map.has(acc):
			current = tuning_map[acc]
		else:
			var n = tree.create_item(current)
			n.set_text(0, part)
			n.collapsed = true
			tuning_map[acc] = n
			current = n
	return current

func _fetch_value_string(topic: String, type: String) -> String:
	return "..."

func _on_item_mouse_selected(pos, btn):
	if btn == MOUSE_BUTTON_RIGHT:
		var item = tree.get_selected()
		if item:
			var popup = PopupMenu.new()
			popup.add_item("Copy Key", 0)
			popup.add_item("Copy Value (JSON)", 1)
			popup.add_item("Copy Path", 2)
			popup.id_pressed.connect(func(id):
				var txt = ""
				if id==0: 
					txt = item.get_text(0)
				if id==1: 
					var path = item.get_metadata(0)
					if path:
						var type = item.get_metadata(1)
						if type == "struct_field" or type == "array_elem":
							txt = item.get_text(1)
						else:
							var val = nt.get_value(path, PackedByteArray())
							if type and type.begins_with("struct:"):
								var parsed = StructParser.parse_packet(val, type)
								var dict = StructParser.to_dictionary(parsed)
								txt = JSON.stringify(dict, "  ")
							else:
								txt = item.get_text(1)
				if id==2: 
					txt = item.get_metadata(0) if item.get_metadata(0) else item.get_text(0)
				DisplayServer.clipboard_set(txt)
			)
			add_child(popup)
			popup.position = get_global_mouse_position()
			popup.popup()
