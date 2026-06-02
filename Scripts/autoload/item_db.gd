extends Node

# Base de datos estática del juego: items, trampas, contramedidas y muebles.
# Se accede como singleton (autoload ItemDB).

enum ItemId { SUITCASE, KEY, MONEY, PASSPORT, MICROFILM }
enum TrapId { BOMB, SPRING, WATER_BUCKET, GUN_STRING, TIMED_BOMB }
enum CounterId { WIRE_CUTTERS, WRENCH, UMBRELLA, TONGS, GAS_MASK }
enum FurnitureKind { PAINTING, BOOKSHELF, ARMCHAIR, DRAWERS, PLANT, LAMP, CLOCK, TABLE, WEAPON_BOX }
enum SpyId { PLAYER, AI }

const ITEM_COUNT: int = 5
const TRAP_COUNT: int = 5

# Reservado (la inspeccion de muebles es instantanea al pulsar interactuar).
const SEARCH_DURATION: float = 0.0
# Cuanto dura la bomba temporizada antes de explotar tras colocarse.
const TIMED_BOMB_FUSE: float = 5.0

# Cada trampa se neutraliza con una contramedida concreta segun la guia clasica.
const TRAP_TO_COUNTER: Dictionary = {
	TrapId.BOMB: CounterId.WIRE_CUTTERS,
	TrapId.SPRING: CounterId.WRENCH,
	TrapId.WATER_BUCKET: CounterId.UMBRELLA,
	TrapId.GUN_STRING: CounterId.TONGS,
	TrapId.TIMED_BOMB: CounterId.GAS_MASK,
}

# Colores placeholder para todos los elementos visuales
const ITEM_COLORS: Dictionary = {
	ItemId.SUITCASE: Color("#00bcd4"),
	ItemId.KEY: Color("#ffeb3b"),
	ItemId.MONEY: Color("#43a047"),
	ItemId.PASSPORT: Color("#1565c0"),
	ItemId.MICROFILM: Color("#c62828"),
}

const ITEM_NAMES: Dictionary = {
	ItemId.SUITCASE: "Maletin",
	ItemId.KEY: "Llave",
	ItemId.MONEY: "Dinero",
	ItemId.PASSPORT: "Pasaporte",
	ItemId.MICROFILM: "Microfilm",
}

const TRAP_COLORS: Dictionary = {
	TrapId.BOMB: Color("#ff1744"),
	TrapId.SPRING: Color("#eeeeee"),
	TrapId.WATER_BUCKET: Color("#4fc3f7"),
	TrapId.GUN_STRING: Color("#9e9e9e"),
	TrapId.TIMED_BOMB: Color("#ff9100"),
}

const TRAP_NAMES: Dictionary = {
	TrapId.BOMB: "Bomba",
	TrapId.SPRING: "Resorte",
	TrapId.WATER_BUCKET: "Cubo agua",
	TrapId.GUN_STRING: "Pistola-cuerda",
	TrapId.TIMED_BOMB: "Bomba temporizada",
}

# Etiquetas cortas para el placeholder en mano del jugador.
const TRAP_HOLD_LABELS: Dictionary = {
	TrapId.BOMB: "Bomba",
	TrapId.SPRING: "Resorte",
	TrapId.WATER_BUCKET: "Cubo",
	TrapId.GUN_STRING: "P.cuerda",
	TrapId.TIMED_BOMB: "T-Bomba",
}

const COUNTER_NAMES: Dictionary = {
	CounterId.WIRE_CUTTERS: "Cortacables",
	CounterId.WRENCH: "Llave inglesa",
	CounterId.UMBRELLA: "Paraguas",
	CounterId.TONGS: "Pinzas",
	CounterId.GAS_MASK: "Mascara gas",
}

const FURNITURE_NAMES: Dictionary = {
	FurnitureKind.PAINTING: "Cuadro",
	FurnitureKind.BOOKSHELF: "Estanteria",
	FurnitureKind.ARMCHAIR: "Sillon",
	FurnitureKind.DRAWERS: "Cajonera",
	FurnitureKind.PLANT: "Planta",
	FurnitureKind.LAMP: "Lampara",
	FurnitureKind.CLOCK: "Reloj",
	FurnitureKind.TABLE: "Mesa",
	FurnitureKind.WEAPON_BOX: "Caja armas",
}

const FURNITURE_COLORS: Dictionary = {
	FurnitureKind.PAINTING: Color("#d4a017"),
	FurnitureKind.BOOKSHELF: Color("#5d4037"),
	FurnitureKind.ARMCHAIR: Color("#7b1f1f"),
	FurnitureKind.DRAWERS: Color("#a1887f"),
	FurnitureKind.PLANT: Color("#388e3c"),
	FurnitureKind.LAMP: Color("#fdd835"),
	FurnitureKind.CLOCK: Color("#fbc02d"),
	FurnitureKind.TABLE: Color("#8d6e63"),
	FurnitureKind.WEAPON_BOX: Color("#455a64"),
}

const SPY_COLORS: Dictionary = {
	SpyId.PLAYER: Color("#f5f5f5"),
	SpyId.AI: Color("#1a1a1a"),
}

const COLOR_FLOOR: Color = Color("#9a92ae")
const COLOR_FLOOR_EXIT: Color = Color("#6a9a72")
const COLOR_WALL: Color = Color("#d4cce8")
const COLOR_DOOR: Color = Color("#c03030")
const COLOR_DOOR_EXIT: Color = Color("#2e8b4a")
const COLOR_DOOR_GAP: Color = Color("#0a0a0a")
const COLOR_OUTLINE: Color = Color("#1a1a1a")


func get_item_name(item_id: int) -> String:
	return String(ITEM_NAMES.get(item_id, "?"))


func get_furniture_name(kind: int) -> String:
	return String(FURNITURE_NAMES.get(kind, "Mueble"))


func get_all_items() -> Array[int]:
	var arr: Array[int] = [
		ItemId.SUITCASE,
		ItemId.KEY,
		ItemId.MONEY,
		ItemId.PASSPORT,
		ItemId.MICROFILM,
	]
	return arr


func get_all_traps() -> Array[int]:
	var arr: Array[int] = [
		TrapId.BOMB,
		TrapId.SPRING,
		TrapId.WATER_BUCKET,
		TrapId.GUN_STRING,
		TrapId.TIMED_BOMB,
	]
	return arr


func get_all_counters() -> Array[int]:
	var arr: Array[int] = [
		CounterId.WIRE_CUTTERS,
		CounterId.WRENCH,
		CounterId.UMBRELLA,
		CounterId.TONGS,
		CounterId.GAS_MASK,
	]
	return arr


func get_counter_for_trap(trap_id: int) -> int:
	return int(TRAP_TO_COUNTER.get(trap_id, -1))


func get_trap_hold_label(trap_id: int) -> String:
	return String(TRAP_HOLD_LABELS.get(trap_id, TRAP_NAMES.get(trap_id, "?")))


func get_all_furniture_kinds() -> Array[int]:
	var arr: Array[int] = get_decor_furniture_kinds()
	arr.append(FurnitureKind.WEAPON_BOX)
	return arr


func get_decor_furniture_kinds() -> Array[int]:
	var arr: Array[int] = [
		FurnitureKind.PAINTING,
		FurnitureKind.BOOKSHELF,
		FurnitureKind.ARMCHAIR,
		FurnitureKind.DRAWERS,
		FurnitureKind.PLANT,
		FurnitureKind.LAMP,
		FurnitureKind.CLOCK,
		FurnitureKind.TABLE,
	]
	return arr
