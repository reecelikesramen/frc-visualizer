extends Tree

func _get_drag_data(at_position):
	var item = get_item_at_position(at_position)
	if not item:
		return null
		
	# Traverse up to build full path
	var path_stack = []
	var curr = item
	while curr != null:
		var txt = curr.get_text(0)
		if txt != "/":
			path_stack.push_front(txt)
		curr = curr.get_parent()
		
	var full_path = "/" + "/".join(path_stack)
	
	# Get type from metadata (set in NTTreeView)
	var type = item.get_metadata(1)
	if type == null:
		# Fallback if metadata not set (e.g. root) or extract from tooltip?
		# Or maybe we just didn't set it yet.
		type = ""
	
	# Create preview
	var preview = Label.new()
	preview.text = full_path
	set_drag_preview(preview)
	
	# Attempt to find NT reference in the scene root (NTTreeView)
	var nt_ref = null
	if owner and "nt" in owner:
		nt_ref = owner.nt
	
	return {
		"type": "nt_topic",
		"path": full_path,
		"nt_type": type,
		"nt_ref": nt_ref
	}
