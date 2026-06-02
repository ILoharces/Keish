# Kage — arquitectura

Proyecto Godot 4.6, duelo 1v1 estilo Spy vs Spy. Mapas editables en JSON (`user://maps/`).

## Flujo de partida

1. `Scenes/main.tscn` — orquestador (`Scripts/core/main.gd`).
2. Menú → `PlayMenu` / `MapEditor` → `LevelLayout` vía `MapStorage`.
3. `GameState.reset_match()` → `Mansion.begin_with_layout(layout)`.
4. HUD, Trapulator y cámaras se enlazan en `Main._bind_ui()`.

## Autoloads

| Nombre | Rol |
|--------|-----|
| `ItemDB` | Enums y datos de items, trampas, muebles, espías |
| `WeaponDB` | Registro de armas (`resources/weapons/*.tres`) |
| `GameState` | Inventario de objetos (maletín/items), trampas en stock, armas solo en manos, tiempo, victoria |
| `GameSettings` | Opciones persistentes (`use_ai_default`, modos de control por jugador) |
| `InputBindings` | Mapa fijo de acciones; aplica solo el slot del modo elegido (teclado+ratón o mando) |
| `DisplayConfig` | Tamaño habitación, panel stats, zoom |
| `DebugFlags` | Toggles F1–F8 |

## Carpetas

- `Scripts/core/` — `GridDirection`, `main.gd`, `MainLayout`, `MainScreens`, `MatchConfig`
- `Scripts/combat/` — `WeaponData`, `WeaponExecutor`, `AimController`, `AimResolver`
- `Scripts/actors/` — `SpyBase` + `SpyMovement/Combat/Interaction/Visual`, `Player`, `AiSpy`
- `Scripts/world/` — `Mansion`, `MansionBuilder`, `MansionAiPaths`, `Room`, `RoomGeometry`, mapas
- `Scripts/ui/` — `Hud`, `SpyHudPanel`, editor (`MapEditorGrid*` helpers), menús

## Grupos de nodos

- `"spy"`, `"player"`, `"ai_spy"`
- `"room"`, `"furniture"`, `"door"`
- `"ground_pickup"`, `"dropped_item"`, `"dropped_weapon"`
- `"hud_root"`, `"minimap"`, `"map_overlay_root"`

## Checklist: cambiar algo

### Nueva trampa

1. `ItemDB` — enum `TrapId`, colores, nombres, `TRAP_TO_COUNTER`
2. `GameState` — lógica de consumo (si aplica)
3. `spy_base.gd` / `SpyCombat` — efecto en `apply_trap_effect`
4. `hud.gd` / Trapulator — UI
5. `furniture.gd` — colocación en mueble

### Nuevo item

1. `ItemDB` — enum `ItemId`, `ITEM_COUNT`
2. `GameState` — reglas maletín / inventario
3. `hud.gd` — slots de inventario

### Nuevo mueble

1. `ItemDB` — `FurnitureKind`
2. `furniture_placement.gd` — posiciones
3. `furniture.gd` — interacción

### Tiempo de partida / balance

- `resources/match_config.tres` (`MatchConfig`)
- `GameState.reset_match()` lee el resource

### Nuevo mapa

- Editor in-game o JSON en `user://maps/` (ver `levels/README.md`)
- `LevelLayout` + `Mansion.begin_with_layout`

### Direcciones de rejilla

- Usar `GridDirection.delta()` y `GridDirection.opposite()` — no duplicar `_dir_delta`.

### Nueva arma (combate PvP)

1. Crear `resources/weapons/mi_arma.tres` (`WeaponData`): `aim_profile`, `delivery`, daño, cooldown, etc.
2. (Opcional) Script `WeaponEffect` custom en `custom_effect` si la lógica no cabe en el delivery genérico.
3. Añadir al spawn en `MansionBuilder` o datos de mapa.
4. Probar: pickup suelo → arma en manos (no en caja de inventario) → apuntar → `fire_weapon` → daño / eliminación.

Las armas no comparten el inventario de objetos ni el stock de trampas: una sola en manos; al equipar trampa u otra arma, la anterior cae al suelo; al coger arma se sueltan maletín/objetos en manos.

No suele hacer falta tocar `Player`, `AimResolver` ni `WeaponExecutor` salvo un nuevo valor de `delivery`.

## Input y modos de control

Los controles **no se reasignan** en v1. En **Ajustes > Controles** cada jugador elige un modo; `InputBindings.apply_action()` registra en el `InputMap` solo el slot activo (teclado o mando), evitando solapes entre jugadores.

| Modo | Jugador | Movimiento / acciones | Apuntado (combate) |
|------|---------|----------------------|-------------------|
| Teclado y ratón | P1 | WASD, E/Q/R/Tab/M/Esc, clic disparo | Ratón |
| Mando | P1 o P2 | Stick izq., A/Y/X/LB/Start/Select, RT disparo | Stick der. (cursor virtual) |

Combinaciones válidas (2 jugadores locales):

- P1 teclado+ratón + P2 mando (1 mando)
- P1 mando + P2 mando (2 mandos)

Reglas:

- No se permiten dos jugadores en modo teclado a la vez.
- P2 «Teclado» está deshabilitado hasta definir teclas de apuntado.
- Con ambos en mando hace falta hardware: 2 mandos conectados (`PlayMenu` avisa al jugar).
- **Contra IA**: `InputBindings.set_ai_adaptive_controls(true)` al iniciar partida; P1 cambia entre teclado+ratón y mando según el último dispositivo usado (sin guardar en disco). El modo de J1 en Ajustes solo fija el valor inicial.

Persistencia: `user://game_settings.cfg` sección `controls` (`p1_control_mode`, `p2_control_mode`). Los bindings fijos viven en código (`InputBindings._build_default_bindings()`).

## Señales globales útiles

- `GameState.map_overlay_close_requested` — cerrar minimapa sin acoplar UI a `Main`
- `Mansion.player_room_changed` — habitación actual del jugador
