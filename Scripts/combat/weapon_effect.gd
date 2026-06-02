class_name WeaponEffect
extends RefCounted

func can_fire(_ctx: WeaponContext) -> bool:
	return true


func on_telegraph_start(_ctx: WeaponContext) -> void:
	pass


func execute(_ctx: WeaponContext) -> void:
	pass


func on_hit(_target: SpyBase, _ctx: WeaponContext) -> void:
	pass
