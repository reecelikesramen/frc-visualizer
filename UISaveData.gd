extends Resource
class_name UISaveData

@export var monitored_topics: Array[Dictionary] = [] 
@export var expanded_paths: Array[String] = [] 

# New Persistence Fields
@export var camera_position: Vector3 = Vector3(0, 5, 10)
@export var camera_rotation: Vector3 = Vector3(-0.5, 0, 0) # Pitch, Yaw, Roll (Euler)
@export var search_filter: String = ""
@export var split_offset: int = 0 # Main HSplit
@export var v_split_offset: int = 0 # Topic Dock VSplit
