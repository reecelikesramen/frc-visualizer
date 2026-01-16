class_name VisualizerRegistry

# Logic for mapping NT types to "Abstract Types" used in the rules
# NT Types: "struct:Pose3d", "double[]", "struct:SwerveModuleState[]", etc.
# Abstract Types: "Pose3d", "Pose3d[]", "number[]", "SwerveModuleState[]", etc.

const TYPE_MAPPING = {
	"struct:Pose3d": "Pose3d",
	"struct:Pose2d": "Pose2d",
	"struct:Pose3d[]": "Pose3d[]",
	"struct:Pose2d[]": "Pose2d[]",
	"struct:Transform3d": "Transform3d",
	"struct:Transform2d": "Transform2d",
	"struct:Transform3d[]": "Transform3d[]",
	"struct:Transform2d[]": "Transform2d[]",
	"struct:Translation3d": "Translation3d",
	"struct:Translation2d": "Translation2d",
	"struct:Translation3d[]": "Translation3d[]",
	"struct:Translation2d[]": "Translation2d[]",
	"struct:SwerveModuleState[]": "SwerveModuleState[]",
	"struct:Mechanism2d": "Mechanism2d",
	"struct:Rotation2d": "Rotation2d",
	"struct:Rotation3d": "Rotation3d",
	"rotation2d": "Rotation2d",
	"rotation3d": "Rotation3d",
	"struct:SwerveSample[]": "SwerveSample[]",
	"struct:DifferentialSample[]": "DifferentialSample[]",
	"struct:Trajectory": "Trajectory",
	"double[]": "number[]",
	"float[]": "number[]",
	"int[]": "number[]",
	"double": "number",
	"float": "number",
	"int": "number"
}

# The Rules Definition
const RULES = {
	"Robot": {
		"sources": ["Pose2d", "Pose3d", "Pose2d[]", "Pose3d[]", "Transform2d", "Transform3d", "Transform2d[]", "Transform3d[]", "number[]"],
		"options": {
			"Model": ["2026 KitBot", "2025 KitBot", "2025", "2024 KitBot", "Crab Bot", "Duck Bot", "KitBot"]
		}
	},
	"Ghost": {
		"sources": ["Pose2d", "Pose3d", "Pose2d[]", "Pose3d[]", "Transform2d", "Transform3d", "Transform2d[]", "Transform3d[]", "number[]"],
		"options": {
			"Model": ["2026 KitBot", "2025 KitBot", "2025", "2024 KitBot", "Crab Bot", "Duck Bot", "KitBot"],
			"Color": ["Green", "Red", "Blue", "Orange", "Cyan", "Yellow", "Magenta"]
		}
	},
	"Component": {
		"sources": ["Pose3d", "Pose3d[]", "Transform3d", "Transform3d[]", "number[]"],
		"options": {},
		"context": ["Robot", "Ghost"]
	},
	"Mechanism": {
		"sources": ["Mechanism2d"],
		"options": {
			"Plane": ["XZ Plane", "YZ Plane"]
		},
		"context": ["Robot", "Ghost"]
	},
	"Vision Target": {
		"sources": ["Pose2d", "Pose3d", "Pose2d[]", "Pose3d[]", "Transform2d", "Transform3d", "Transform2d[]", "Transform3d[]", "Translation2d", "Translation3d", "Translation2d[]", "Translation3d[]", "number[]"],
		"options": {
			"Color": ["Green", "Red", "Blue", "Orange", "Cyan", "Yellow", "Magenta"],
			"Thickness": ["Normal", "Bold"]
		},
		"context": ["Robot", "Ghost"]
	},
	"Swerve States": {
		"sources": ["SwerveModuleState[]", "number[]"],
		"options": {
			"Color": ["Red", "Blue", "Green", "Orange", "Cyan", "Yellow", "Magenta"],
			"Arrangement": ["FL/FR/BL/BR", "FR/FL/BR/BL", "FL/FR/BR/BL", "FL/BL/BR/FR", "FR/BR/BL/FL", "FR/FL/BL/BR"]
		},
		"context": ["Robot", "Ghost"]
	},
	"Rotation Override": {
		"sources": ["Rotation2d", "Rotation3d", "number"],
		"options": {},
		"context": ["Robot", "Ghost"]
	},
	"Game Piece": {
		"sources": ["Pose3d", "Pose3d[]", "Transform3d", "Transform3d[]", "Translation3d", "Translation3d[]", "number[]"],
		"options": {
			"Variant": ["Fuel"]
		}
	},
	"Trajectory": {
		"sources": ["Pose2d[]", "Pose3d[]", "Transform2d[]", "Transform3d[]", "Translation2d[]", "Translation3d[]", "SwerveSample[]", "DifferentialSample[]", "Trajectory", "number[]"],
		"options": {
			"Color": ["Green", "Red", "Blue", "Orange", "Cyan", "Yellow", "Magenta"],
			"Thickness": ["Normal", "Bold"]
		}
	},
	"Heatmap": {
		"sources": ["Pose2d", "Pose3d", "Pose2d[]", "Pose3d[]", "Transform2d", "Transform3d", "Transform2d[]", "Transform3d[]", "Translation2d", "Translation3d", "Translation2d[]", "Translation3d[]", "number[]"],
		"options": {
			"Time Range": ["Enabled", "Auto", "Teleop", "Teleop (No Endgame)", "Full Log", "Visible Range"]
		}
	},
	"AprilTag": {
		"sources": ["Pose3d", "Pose3d[]", "Transform3d", "Transform3d[]", "Trajectory", "number[]"],
		"options": {
			"Variant": ["36h11", "16h5"]
		}
	},
	"AprilTag IDs": {
		"sources": ["number[]"],
		"options": {},
		"context": ["AprilTag"]
	},
	"Axes": {
		"sources": ["Pose3d", "Pose3d[]", "Transform3d", "Transform3d[]", "Trajectory", "number[]"],
		"options": {}
	},
	"Cone": {
		"sources": ["Pose2d", "Pose3d", "Pose2d[]", "Pose3d[]", "Transform2d", "Transform3d", "Transform2d[]", "Transform3d[]", "Trajectory", "number[]"],
		"options": {
			"Color": ["Green", "Red", "Blue", "Orange", "Cyan", "Yellow", "Magenta"],
			"Position": ["Center", "Back", "Front"]
		}
	},
	"Camera Override": {
		"sources": ["Pose3d", "Transform3d", "number[]"],
		"options": {}
	}
}

static func get_abstract_type(nt_type: String) -> String:
	if TYPE_MAPPING.has(nt_type):
		return TYPE_MAPPING[nt_type]
	# Fallback/Pass-through
	return nt_type

static func is_compatible(nt_type: String, visualizer_name: String) -> bool:
	if not RULES.has(visualizer_name): return false
	var abstract = get_abstract_type(nt_type)
	var sources = RULES[visualizer_name]["sources"]
	return abstract in sources

static func get_compatible_visualizers(nt_type: String) -> Array[String]:
	var list: Array[String] = []
	var abstract = get_abstract_type(nt_type)
	for viz in RULES:
		# Check if this visualizer supports this source
		if abstract in RULES[viz]["sources"]:
			# Check context constraints?
			# If a visualizer requires a context (e.g. "Add to existing..."), 
			# it generally shouldn't be a TOP LEVEL option for a "new" visualizer,
			# unless we are handling context in the UI. 
			# For now, let's include everything, and UI can filter if it's "Add to..."
			# Wait, user said "Add to existing 'Robot' or 'Ghost' item."
			# This implies these are secondary modifiers.
			# But "Robot" itself is top level.
			# If we are dragging a topic to the empty dock, we only show Top Level visualizers.
			# If we are right clicking a topic, we might show all?
			# Let's distinguish Top Level vs Child.
			if not RULES[viz].has("context"):
				list.append(viz)
			elif RULES[viz]["context"].is_empty(): # Should not happen based on manual dict
				list.append(viz)
				
	return list

# To get child visualizers (modifiers)
static func get_compatible_modifiers(nt_type: String, parent_viz_type: String) -> Array[String]:
	var list: Array[String] = []
	var abstract = get_abstract_type(nt_type)
	for viz in RULES:
		if RULES[viz].has("context") and parent_viz_type in RULES[viz]["context"]:
			if abstract in RULES[viz]["sources"]:
				list.append(viz)
	return list
