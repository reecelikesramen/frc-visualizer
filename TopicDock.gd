extends Panel

var topic_row_scene = preload("res://TopicRow.tscn")
@onready var container = $ScrollContainer/VBoxContainer

# Reference to NT, needed for restoration when dragging isn't happening
# We will inject this from Main or finding it.
var nt_instance_ref = null

func _ready():
	# Try to find NT instance if not set
	# It's usually a child of NTTreeView, which is a sibling of the parent's parent...
	# Let's rely on set_nt_instance being called or finding by group/path if possible.
	# For now, we wait for the first drop or main to set it.
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
		
		# Cache the ref if we get it
		if nt_ref and nt_instance_ref == null:
			nt_instance_ref = nt_ref
			
		add_topic(path, type, nt_ref)
		_notify_change()

func add_topic(path: String, type: String, nt_ref: Node):
	# Check for duplicates
	for child in container.get_children():
		if child.has_method("get") and child.topic_path == path:
			return # Already exists
			
	var row = topic_row_scene.instantiate()
	container.add_child(row)
	row.setup(path, type, nt_ref)
	row.tree_exiting.connect(_notify_change) # Listen for removal

func get_topics() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for child in container.get_children():
		if child.has_method("get") and child.topic_path != "":
			list.append({
				"path": child.topic_path,
				"type": child.topic_type
			})
	return list

func restore_topics(list: Array[Dictionary], nt_node):
	nt_instance_ref = nt_node
	# Clear existing? Or append? appending is safer.
	
	for item in list:
		add_topic(item["path"], item["type"], nt_node)

func _notify_change():
	# Signal up to main/persistence manager to save
	if OwnerUtils.get_main(self).has_method("save_ui_state"):
		OwnerUtils.get_main(self).save_ui_state()
		
class OwnerUtils:
	static func get_main(node: Node) -> Node:
		var root = node.get_tree().root
		var main_scene = root.get_child(root.get_child_count() - 1) # Generally the last loaded scene
		return main_scene
