class_name GridDirection
extends RefCounted

# Utilidad compartida para direcciones de rejilla N/S/E/W en mapas y mansion.


static func delta(dir_str: String) -> Vector2i:
	match dir_str:
		"N":
			return Vector2i(0, -1)
		"S":
			return Vector2i(0, 1)
		"W":
			return Vector2i(-1, 0)
		"E":
			return Vector2i(1, 0)
	return Vector2i.ZERO


static func opposite(dir_str: String) -> String:
	match dir_str:
		"N":
			return "S"
		"S":
			return "N"
		"W":
			return "E"
		"E":
			return "W"
	return ""
