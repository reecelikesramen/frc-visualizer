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
# The Rules Definition
const RULES_3D = {
	"Robot": {
		"sources": ["Pose2d", "Pose3d", "Pose2d[]", "Pose3d[]", "Transform2d", "Transform3d", "Transform2d[]", "Transform3d[]", "number[]"],
		"options": {
			"Model": ["2026 KitBot", "2025 KitBot", "2025", "2024 KitBot", "Crab Bot", "Duck Bot", "KitBot", "Custom"],
			"Offset": "Vector3",
			"Rotation": "Vector3"
		}
	},
	"Ghost": {
		"sources": ["Pose2d", "Pose3d", "Pose2d[]", "Pose3d[]", "Transform2d", "Transform3d", "Transform2d[]", "Transform3d[]", "number[]"],
		"options": {
			"Model": ["2026 KitBot", "2025 KitBot", "2025", "2024 KitBot", "Crab Bot", "Duck Bot", "KitBot", "Custom"],
			"Color": ["Green", "Red", "Blue", "Orange", "Cyan", "Yellow", "Magenta"],
			"Offset": "Vector3",
			"Rotation": "Vector3"
		}
	},
	"Component": {
		"sources": ["Pose3d", "Pose3d[]", "Transform3d", "Transform3d[]", "number[]"],
		"options": {
			"Model": ["Custom"],
			"Offset": "Vector3",
			"Rotation": "Vector3"
		},
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

const RULES_2D = {
	"Robot": {
		"sources": ["Pose2d", "Pose3d", "Pose2d[]", "Pose3d[]", "Transform2d", "Transform3d", "Transform2d[]", "Transform3d[]", "number[]"],
		"options": {
			"Bumpers": ["Alliance Color", "Green", "Red", "Blue", "Orange", "Cyan", "Yellow", "Magenta"]
		}
	},
	"Ghost": {
		"sources": ["Pose2d", "Pose3d", "Pose2d[]", "Pose3d[]", "Transform2d", "Transform3d", "Transform2d[]", "Transform3d[]", "number[]"],
		"options": {
			"Color": ["Green", "Red", "Blue", "Orange", "Cyan", "Yellow", "Magenta"]
		}
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
	"Arrow": {
		"sources": ["Pose2d", "Pose3d", "Pose2d[]", "Pose3d[]", "Transform2d", "Transform3d", "Transform2d[]", "Transform3d[]", "DifferentialSample[]", "SwerveSample[]", "Trajectory", "number[]"],
		"options": {
			"Position": ["Center", "Back", "Front"]
		}
	},
	"Game Piece": {
		"sources": ["Pose3d", "Pose3d[]", "Transform3d", "Transform3d[]", "Translation3d", "Translation3d[]", "number[]"],
		"options": {
			"Variant": ["Fuel", "None"]
		}
	}
}

static func get_rules(mode: String = "3D") -> Dictionary:
	return RULES_2D if mode == "2D" else RULES_3D
	
# Backwards compatibility accessor for 3D rules if accessed directly via property (it's const though)
# We replaced the const RULES, so direct access will break. We must fix callsites.
# Since we are updating callsites, we don't need to emulate the const.
const RULES = {} # Deprecated, empty to force error/refactor? Or alias to 3D?
# GDScript const cannot be dynamic.
# Let's alias RULES to RULES_3D for compatibility if I miss any spots, assuming 3D is default.
# But I removed RULES so I should re-add it or alias it if possible.
# GDScript doesn't support aliasing consts like `const RULES = RULES_3D` easily if RULES_3D is defined above in same block?
# Actually it does.

static func get_abstract_type(nt_type: String) -> String:
	if TYPE_MAPPING.has(nt_type):
		return TYPE_MAPPING[nt_type]
	# Fallback/Pass-through
	return nt_type

static func is_compatible(nt_type: String, visualizer_name: String, mode: String = "3D") -> bool:
	var rules = get_rules(mode)
	if not rules.has(visualizer_name): return false
	var abstract = get_abstract_type(nt_type)
	var sources = rules[visualizer_name]["sources"]
	return abstract in sources

static func get_compatible_visualizers(nt_type: String, mode: String = "3D") -> Array[String]:
	var list: Array[String] = []
	var abstract = get_abstract_type(nt_type)
	var rules = get_rules(mode)
	
	for viz in rules:
		# Check if this visualizer supports this source
		if abstract in rules[viz]["sources"]:
			# Check context constraints
			if not rules[viz].has("context"):
				list.append(viz)
			elif rules[viz]["context"].is_empty():
				list.append(viz)
				
	return list

# To get child visualizers (modifiers)
static func get_compatible_modifiers(nt_type: String, parent_viz_type: String, mode: String = "3D") -> Array[String]:
	var list: Array[String] = []
	var abstract = get_abstract_type(nt_type)
	var rules = get_rules(mode)
	
	for viz in rules:
		if rules[viz].has("context") and parent_viz_type in rules[viz]["context"]:
			if abstract in rules[viz]["sources"]:
				list.append(viz)
	return list
