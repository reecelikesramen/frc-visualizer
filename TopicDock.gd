extends Panel

var topic_row_scene = preload("res://TopicRow.tscn")
@onready var container = $ScrollContainer/VBoxContainer

# Reference to NT, needed for restoration when dragging isn't happening
# We will inject this from Main or finding it.
var nt_instance_ref = null

var active_visualizers = {} # path -> { "node": Node, "type": String }

func _ready():
	# Try to find NT instance if not set
	# It's usually a child of NTTreeView, which is a sibling of the parent's parent...
	# Let's rely on set_nt_instance being called or finding by group/path if possible.
	# For now, we wait for the first drop or main to set it.
	# Add to group for updates
	add_to_group("dock_updates")
	pass

func set_nt_instance(nt_node):
	nt_instance_ref = nt_node

func _can_drop_data(at_position, data):
	if typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "nt_topic":
		return true
	return false

func _drop_data(at_position, data):
	if _can_drop_data(at_position, data):
		var path = data["path"]
		var type = data["nt_type"]
		var nt_ref = data.get("nt_ref")
		
		# Check if it's a move (reorder/unnest) or a new add
		var source_node = data.get("source_node")
		if is_instance_valid(source_node) and source_node.get("topic_path") == path:
			# It's an existing node from our dock.
			# If we drop here (onto the main list area), we might mean "move to root".
			# But TopicRow handles drops ON rows (nesting).
			# So dropping here means "Root".
			if source_node.get_parent():
				source_node.get_parent().remove_child(source_node)
			
			container.add_child(source_node)
			source_node.parent_row = null # No longer nested
			_notify_change()
			return

		# Cache the ref if we get it
		if nt_ref and nt_instance_ref == null:
			nt_instance_ref = nt_ref
			
		add_topic(path, type, nt_ref)
		_notify_change()

func add_topic(path: String, type: String, nt_ref: Node):
	# Check for duplicates
	for child in container.get_children():
		if "topic_path" in child and child.topic_path == path:
			return # Already exists
			
	var row = topic_row_scene.instantiate()
	container.add_child(row)
	row.setup(path, type, nt_ref)
	row.visualization_requested.connect(_on_visualization_requested)
	# Connect tree_exiting with binding to handle removal
	row.tree_exiting.connect(_on_row_exiting.bind(row))
	row.tree_exiting.connect(_notify_change) # Listen for removal/change
	
	# If we have existing children in the list data? 
	# The flatten/restore logic needs to handle this.
	# For simple add, we just add to root.


func _on_visualization_requested(path: String, type: String, viz_type: String):
	print("TopicDock: Viz requested for ", path, " as ", viz_type)
	if active_visualizers.has(path):
		var current = active_visualizers[path]["type"]
		remove_visualizer(path)
		# If clicking the same type, we treat it as toggle OFF
		if current == viz_type:
			_notify_change()
			return

	add_visualizer(path, viz_type)
	_notify_change()

func add_visualizer(path: String, viz_type: String):
	if not nt_instance_ref:
		push_warning("TopicDock: Cannot add visualizer, NT instance not set")
		return

	# Find or Create 'RobotParent'
	var main = OwnerUtils.get_main(self)
	var parent = main.get_node_or_null("RobotParent")
	if not parent:
		parent = Node3D.new()
		parent.name = "RobotParent"
		main.add_child(parent)

	var viz_node = null
	if viz_type == "robot":
		viz_node = Node3D.new()
		viz_node.set_script(load("res://visualizers/RobotVisualizer.gd"))
		# Add default debug mesh since we don't have a specific robot asset selector yet
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = BoxMesh.new()
		mesh_inst.mesh.size = Vector3(0.5, 0.5, 0.5)
		viz_node.add_child(mesh_inst)
		var context = {
			"topic_type": "struct:Pose3d", # Or generic
			"viz_type": viz_type,
			"parent_viz_type": "root",
			"parent_node": null
		}
		
		# CHECK FOR PARENTING
		# We need to find the TopicRow for this path and see if it has a parent row
		var row_node = _find_row_by_path(path, container)
		if row_node and row_node.get("parent_row"):
			var parent_row = row_node.parent_row
			var p_path = parent_row.topic_path
			if active_visualizers.has(p_path):
				var p_viz_info = active_visualizers[p_path]
				var p_node = p_viz_info["node"]
				if is_instance_valid(p_node):
					parent = p_node
					context["parent_viz_type"] = p_viz_info["type"]
					context["parent_node"] = p_node
					print("TopicDock: Parenting ", path, " viz to ", p_path, " viz")

		if viz_node.has_method("setup"):
			# Check setup signature count? Or just try passing context.
			# GDScript doesn't crash on extra args if using call? No, it does.
			# But we can assume we updated visualizers or they use varargs. 
			# User request implies visualizer SHOULD get this.
			# Let's try passing 3 args.
			viz_node.setup(nt_instance_ref, path, context)
			
	elif viz_type == "game_pieces":
		# Context for game pieces
		var context = {"viz_type": viz_type}
		viz_node = MultiMeshInstance3D.new()
		viz_node.set_script(load("res://visualizers/GamePieceVisualizer.gd"))
		if viz_node.has_method("setup"):
			viz_node.setup(nt_instance_ref, path, context)
	
	elif viz_type == "arrow":
		var context = {"viz_type": viz_type}
		# Simple arrow visualization (using a thin box for now)
		viz_node = Node3D.new()
		viz_node.set_script(load("res://visualizers/RobotVisualizer.gd"))
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = BoxMesh.new()
		mesh_inst.mesh.size = Vector3(0.1, 0.1, 1.0) # Long thin box
		viz_node.add_child(mesh_inst)
		if viz_node.has_method("setup"):
			viz_node.setup(nt_instance_ref, path, context)

	elif viz_type == "swerve_states":
		var context = {"viz_type": viz_type}
		viz_node = Node3D.new()
		viz_node.set_script(load("res://visualizers/SwerveStateVisualizer.gd"))
		if viz_node.has_method("setup"):
			viz_node.setup(nt_instance_ref, path, context)

	if viz_node:
		parent.add_child(viz_node)
		active_visualizers[path] = {"node": viz_node, "type": viz_type}

func remove_visualizer(path: String):
	if active_visualizers.has(path):
		var info = active_visualizers[path]
		if is_instance_valid(info.node):
			info.node.queue_free()
		active_visualizers.erase(path)

func _on_row_exiting(row_node: Node):
	# If the row is being deleted (X button or parent deletion), remove viz.
	# If it's just moving (drag/drop), is_queued_for_deletion should be false.
	if row_node.is_queued_for_deletion():
		# Use recursive helper to ensure children are also cleaned up, 
		# as is_queued_for_deletion checks might not propagate instantly to children signals
		_remove_all_viz_in_branch(row_node)
		_notify_change()

func _remove_all_viz_in_branch(node: Node):
	if "topic_path" in node:
		remove_visualizer(node.topic_path)
	
	for child in node.get_children():
		_remove_all_viz_in_branch(child)

func get_topics() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	# Recursive helper
	_gather_topics_recursive(container, list)
	return list

func _gather_topics_recursive(parent_container, list: Array):
	for child in parent_container.get_children():
		if "topic_path" in child and child.topic_path != "":
			var data = {
				"path": child.topic_path,
				"type": child.topic_type,
				"children": []
			}
			if active_visualizers.has(child.topic_path):
				data["viz"] = active_visualizers[child.topic_path]["type"]
			
			# Recurse into ChildrenContainer
			if child.has_node("ChildrenContainer"):
				_gather_topics_recursive(child.get_node("ChildrenContainer"), data["children"])
				
			list.append(data)

func _find_row_by_path(path: String, parent_node: Node) -> Node:
	for child in parent_node.get_children():
		if "topic_path" in child and child.topic_path == path:
			return child
		# Recurse
		if child.has_node("ChildrenContainer"):
			var found = _find_row_by_path(path, child.get_node("ChildrenContainer"))
			if found: return found
	return null

func restore_topics(list: Array[Dictionary], nt_node):
	nt_instance_ref = nt_node
	# Clear existing topics? Or just add missing?
	# Implementation choice: Clear UI first or just append. 
	# TopicDock usually clears on reload if not persistent.
	# But here we are just appending.
	
	_restore_topics_recursive(list, container, nt_node)

func _restore_topics_recursive(list: Array, parent_node: Node, nt_node: Node):
	for item in list:
		# Add row to parent_node
		# Note: add_topic adds to `container` by default interactively. 
		# We need manual instantiation here to respect hierarchy.
		var row = topic_row_scene.instantiate()
		parent_node.add_child(row)
		row.setup(item["path"], item["type"], nt_node)
		row.visualization_requested.connect(_on_visualization_requested)
		row.tree_exiting.connect(_on_row_exiting.bind(row))
		row.tree_exiting.connect(_notify_change)
		
		# If parent_node is a ChildrenContainer, set parent_row?
		# The row script sets parent_row explicitly on drop, but here we just rely on tree structure.
		# But `_find_row_by_path` relies on `parent_row` property?
		# No, `_find_row_by_path` traverses nodes.
		# BUT `add_visualizer` checks `row.parent_row`. We MUST set it.
		
		if parent_node.name == "ChildrenContainer":
			row.parent_row = parent_node.get_parent() # TopicRow
		
		if item.has("viz"):
			add_visualizer(item["path"], item["viz"])
			
		if item.has("children"):
			_restore_topics_recursive(item["children"], row.get_node("ChildrenContainer"), nt_node)

func _notify_change():
	# Signal up to main/persistence manager to save
	if OwnerUtils.get_main(self).has_method("save_ui_state"):
		OwnerUtils.get_main(self).save_ui_state()
		
class OwnerUtils:
	static func get_main(node: Node) -> Node:
		var root = node.get_tree().root
		var main_scene = root.get_child(root.get_child_count() - 1) # Generally the last loaded scene
		return main_scene
