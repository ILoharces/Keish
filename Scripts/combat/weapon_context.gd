class_name WeaponContext
extends RefCounted

var attacker: SpyBase = null
var weapon_data: WeaponData = null
var screen_pos: Vector2 = Vector2.ZERO
var aim_result: AimResult = null
var target_spy: SpyBase = null


func _init(
	p_attacker: SpyBase,
	p_weapon_data: WeaponData,
	p_screen_pos: Vector2,
	p_aim_result: AimResult
) -> void:
	attacker = p_attacker
	weapon_data = p_weapon_data
	screen_pos = p_screen_pos
	aim_result = p_aim_result
	target_spy = p_aim_result.target_spy if p_aim_result != null else null
