class_name HeldInventory
extends RefCounted

# Una sola cosa en las manos: objeto suelto, maletin (con todo el botin), trampa o arma.

enum Kind { NONE, ITEM, SUITCASE, TRAP, COUNTER, WEAPON }

var kind: int = Kind.NONE
var held_id: int = -1
var held_weapon_id: StringName = &""
var held_weapon_ammo: int = 0


func is_holding() -> bool:
	return kind != Kind.NONE and (held_id >= 0 or not held_weapon_id.is_empty())


func is_holding_trap() -> bool:
	return kind == Kind.TRAP and held_id >= 0


func is_holding_weapon() -> bool:
	return kind == Kind.WEAPON and not held_weapon_id.is_empty()


func is_holding_carried() -> bool:
	return kind == Kind.ITEM or kind == Kind.SUITCASE


func is_holding_suitcase() -> bool:
	return kind == Kind.SUITCASE


func get_trap_id() -> int:
	return held_id if is_holding_trap() else -1


func get_weapon_id() -> StringName:
	return held_weapon_id if is_holding_weapon() else &""


func clear() -> void:
	kind = Kind.NONE
	held_id = -1
	held_weapon_id = &""
	held_weapon_ammo = 0


func set_item(item_id: int) -> void:
	clear()
	kind = Kind.ITEM
	held_id = item_id


func set_suitcase() -> void:
	clear()
	kind = Kind.SUITCASE
	held_id = ItemDB.ItemId.SUITCASE


func set_trap(trap_id: int) -> void:
	clear()
	kind = Kind.TRAP
	held_id = trap_id


func set_weapon(weapon_id: StringName, ammo: int = -1) -> void:
	clear()
	kind = Kind.WEAPON
	held_weapon_id = weapon_id
	var weapon: WeaponData = WeaponDB.get_weapon(weapon_id)
	if weapon != null and not weapon.uses_ammo:
		held_weapon_ammo = 1
	elif ammo >= 0:
		held_weapon_ammo = ammo
	elif weapon != null:
		held_weapon_ammo = maxi(1, weapon.pickup_ammo)
	else:
		held_weapon_ammo = 1


func get_weapon_ammo() -> int:
	if not is_holding_weapon():
		return 0
	var weapon: WeaponData = WeaponDB.get_weapon(held_weapon_id)
	if weapon != null and not weapon.uses_ammo:
		return 1
	return held_weapon_ammo


func consume_weapon_ammo() -> bool:
	if not is_holding_weapon():
		return false
	var weapon: WeaponData = WeaponDB.get_weapon(held_weapon_id)
	if weapon == null:
		return false
	if not weapon.uses_ammo:
		return true
	if held_weapon_ammo <= 0:
		return false
	held_weapon_ammo -= 1
	return true


func has_weapon_ammo() -> bool:
	if not is_holding_weapon():
		return false
	var weapon: WeaponData = WeaponDB.get_weapon(held_weapon_id)
	if weapon == null:
		return false
	if not weapon.uses_ammo:
		return true
	return held_weapon_ammo > 0


func release_trap() -> void:
	if kind == Kind.TRAP:
		clear()


func sync_carried_from_inventory(spy_id: int) -> bool:
	var before_kind: int = kind
	var before_id: int = held_id
	var before_weapon: StringName = held_weapon_id
	if is_holding_weapon():
		return false
	var inv: Array = GameState.get_items(spy_id)
	if inv.has(ItemDB.ItemId.SUITCASE):
		set_suitcase()
	elif inv.size() == 1:
		set_item(int(inv[0]))
	else:
		clear()
	return kind != before_kind or held_id != before_id or held_weapon_id != before_weapon


func get_available_traps(spy_id: int) -> Array[int]:
	var out: Array[int] = []
	for trap_id: int in ItemDB.get_all_traps():
		if GameState.get_trap_count(spy_id, trap_id) > 0:
			out.append(trap_id)
	return out


func cycle_trap(spy_id: int) -> bool:
	return _cycle_trap(spy_id)


func get_display_color() -> Color:
	if not is_holding():
		return Color.TRANSPARENT
	if kind == Kind.WEAPON:
		var weapon: WeaponData = WeaponDB.get_weapon(held_weapon_id)
		return weapon.hold_color if weapon != null else Color.WHITE
	if kind == Kind.TRAP:
		return ItemDB.TRAP_COLORS.get(held_id, Color.WHITE)
	if kind == Kind.SUITCASE:
		return ItemDB.ITEM_COLORS.get(ItemDB.ItemId.SUITCASE, Color.WHITE)
	if kind == Kind.ITEM:
		return ItemDB.ITEM_COLORS.get(held_id, Color.WHITE)
	return Color.WHITE


func get_display_name() -> String:
	if not is_holding():
		return ""
	if kind == Kind.WEAPON:
		return WeaponDB.get_weapon_name(held_weapon_id)
	if kind == Kind.TRAP:
		return ItemDB.get_trap_hold_label(held_id)
	if kind == Kind.SUITCASE:
		return ItemDB.get_item_name(ItemDB.ItemId.SUITCASE)
	if kind == Kind.ITEM:
		return ItemDB.get_item_name(held_id)
	return "?"


func _cycle_trap(_spy_id: int) -> bool:
	var available: Array[int] = get_available_traps(_spy_id)
	if available.is_empty():
		clear()
		return false
	if not is_holding_trap() or not available.has(held_id):
		set_trap(available[0])
		return true
	var idx: int = available.find(held_id)
	var next_idx: int = idx + 1
	if next_idx >= available.size():
		clear()
		return true
	set_trap(available[next_idx])
	return true
