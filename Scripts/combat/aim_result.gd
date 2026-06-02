class_name AimResult
extends RefCounted

enum TargetView { NONE, OWN, OPPONENT }

var is_valid: bool = false
var target_view: int = TargetView.NONE
var viewport: SubViewport = null
var camera: Camera2D = null
var world_pos: Vector2 = Vector2.ZERO
var target_room: Room = null
var target_spy: SpyBase = null
var is_remote_shot: bool = false
