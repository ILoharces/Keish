class_name WeaponData
extends Resource

enum AimProfile {
	NONE,
	LOCAL_VIEW,
	REMOTE_VIEW,
	ANY_VIEW,
	DIRECTIONAL,
}

enum Delivery {
	HITSCAN,
	PROJECTILE,
	DELAYED_STRIKE,
	MELEE_ARC,
	AREA,
}

@export var weapon_id: StringName = &""
@export var display_name: String = ""
@export var hold_color: Color = Color("#9e9e9e")
@export var aim_profile: AimProfile = AimProfile.LOCAL_VIEW
@export var delivery: Delivery = Delivery.HITSCAN
@export var damage: float = 25.0
@export var stun_duration: float = 0.0
@export var cooldown: float = 0.4
@export var uses_ammo: bool = true
@export var pickup_ammo: int = 12
@export var auto_fire: bool = false
@export var orbital_strike: bool = false
@export var telegraph_time: float = 0.0
@export var max_range: float = 0.0
@export var requires_same_room: bool = false
@export var blocks_when_same_room: bool = false
@export var projectile_speed: float = 400.0
@export var knockback_force: float = 0.0
@export var aoe_radius: float = 0.0
@export var vfx_muzzle: PackedScene = null
@export var vfx_impact: PackedScene = null
@export var vfx_beam: PackedScene = null
@export var custom_effect: Script = null
