# Referencia: armas, combate, controles (Kage)

## Archivos clave

| Área | Archivos |
|------|----------|
| Datos arma | `Scripts/combat/weapon_data.gd`, `resources/weapons/*.tres` |
| Ejecución | `Scripts/combat/weapon_executor.gd`, `weapon_effect.gd`, `weapon_context.gd` |
| Registro | `Scripts/autoload/weapon_db.gd` |
| Inventario arma | `GameState.weapons_by_spy`, `equip_weapon_in_hands()`, `DroppedWeapon` |
| Manos | `HeldInventory.Kind.WEAPON`, `SpyCombat.set_equipped_weapon()` |
| Apuntado | `aim_controller.gd`, `aim_resolver.gd`, `aim_cursor.gd`, `aim_cursor_dot.gd` |
| Vistas | `Scripts/ui/game_views_panel.gd` (`clamp_to_aim_views`, cámaras, viewports) |
| Orquestación | `Scripts/core/main.gd` (`setup_combat_aim`, `_snap_aim_to_room_center`) |
| Input | `Scripts/autoload/input_bindings.gd`, `game_settings.gd` |
| UI controles | `Scripts/ui/controls_settings_panel.gd` |
| Actores | `spy_base.gd`, `spy_visual.gd`, `spy_movement.gd`, `player1.gd`, `player2.gd` |
| P2 aim id | P2 usa `get_aim_controller_spy_id()` → `ItemDB.SpyId.PLAYER2` (aunque el nodo sea `Player2`) |

## Espías (`SpyBase` + componentes)

| Archivo | Rol |
|---------|-----|
| `spy_base.gd` | `CharacterBody2D`; collider, `contains_hit_point`, `get_muzzle_world_position`, `walk_phase` |
| `spy_visual.gd` | Dibujo, `compute_metrics()`, wiggle, geometría de pistola |
| `spy_movement.gd` | Movimiento, `update_body_collider()`, `_update_walk_phase()` |
| `spy_combat.gd` | Daño, disparo vía `WeaponExecutor` |
| `room.gd` | `get_depth_at_local()` → profundidad 0..1 en suelo oblicuo |

### `SpyVisual.compute_metrics()` → Dictionary

Claves habituales: `depth`, `body_h`, `body_w`, `head_r`, `foot_y`, `body_top_y`, `head_top_y`, `hitbox_size`, `hitbox_center`, `hit_radius`.

Dimensiones base × `SpyBase.COLLIDER_SCALE` (1.95), con lerp near/far según `depth`.

### Hitbox y daño

```
SpyMovement.physics_process
  → update_body_collider()     # RectangleShape2D según metrics
  → move_and_slide()

AimResolver._find_spy_at_world_pos
  → spy.contains_hit_point(world_pos)   # NO HIT_RADIUS fijo

OrbitalStrikeEffect._find_victim_at_strike
  → spy.contains_hit_point(world_pos)

WeaponProjectile
  → colisión con CharacterBody2D (mismo collider)
```

### Animación de caminar

| Constante / var | Valor / rol |
|-----------------|-------------|
| `SpyBase.walk_phase` | Fase acumulada (rad implícito vía sin/cos) |
| `SpyBase.WALK_WIGGLE_SPEED` | 13.0 |
| `SpyMovement.WALK_PHASE_DECAY` | 10.0 (vuelta suave a reposo) |
| Umbral movimiento | `velocity.length_squared() > 64` |
| `SpyVisual.WALK_TILT` | ~0.055 rad balanceo |
| `SpyVisual.WALK_BOB` | 0.04 × body_h rebote vertical |
| Pivote wiggle | `(0, body_h * 0.45)` — pies |

### Pistola: geometría compartida (dibujo + combate)

| Constante | Uso |
|-----------|-----|
| `PISTOL_GRIP_X/Y` | Posición del agarre en espacio del espía |
| `PISTOL_BARREL_X/Y` | Origen del rect del cañón (espacio del arma) |
| `PISTOL_BARREL_W/H_RATIO` | Tamaño del cañón |
| `_muzzle_weapon_local()` | Punta del cañón en espacio del arma |
| `_weapon_point_local(point, apply_walk)` | Aplica `Transform2D(angle, grip)` + opcional `_get_walk_transform()` |

API pública:

- `get_grip_local_offset()` → `_weapon_point_local(Vector2.ZERO, true)`
- `get_muzzle_local_offset()` → `_weapon_point_local(_muzzle_weapon_local(), true)`
- `SpyBase.get_muzzle_world_position()` → `global_position + get_muzzle_local_offset()`

### Dibujo del espía con wiggle

```
draw():
  walk_xf = _get_walk_transform(body_h)   # IDENTITY si quieto
  draw_set_transform_matrix(walk_xf)
  # cuerpo, cabeza, objeto en mano en coords. originales del espía
  # arma: draw_set_transform_matrix(walk_xf * Transform2D(angle, grip))
  draw_set_transform_matrix(IDENTITY)
```

## WeaponData (campos habituales)

| Campo | Uso |
|-------|-----|
| `weapon_id` | ID único (`StringName`) |
| `aim_profile` | `LOCAL_VIEW`, `REMOTE_VIEW`, `ANY_VIEW`, `DIRECTIONAL`, `NONE` |
| `delivery` | `HITSCAN`, `PROJECTILE`, otros en enum |
| `damage`, `cooldown`, `stun_duration` | Combate |
| `uses_ammo` | Consume de `GameState.weapons_by_spy` |
| `requires_same_room` | Valida en `AimResolver.validate_for_weapon` |
| `custom_effect` | Script que extiende `WeaponEffect` |

### `aim_profile` en PvP split-screen

| Perfil | Cuándo usar |
|--------|-------------|
| `ANY_VIEW` | Arma apunta/dispara con mirilla en vista propia o rival (placeholder pistola) |
| `LOCAL_VIEW` | Solo válido si el cursor está en la vista propia |
| `REMOTE_VIEW` | Solo válido si el cursor está en la vista del oponente |
| `DIRECTIONAL` / `NONE` | Sin mirilla de cursor |

## Acciones de input (partida)

Prefijo P2: `p2_`. Sin prefijo: P1.

- Movimiento: `move_*` / `p2_move_*` (polling en `SpyMovement`)
- Combate: `fire_weapon` (clic izq.), `p2_fire_weapon` (O), `aim_*`, `p2_aim_*` (solo InputMap en modo mando)
- Trampas: `interact`, `place_trap`, `next_trap`, `trapulator`, etc.

Menús: `ui_*` fijos en `InputBindings._apply_fixed_menu_bindings()`.

## Modos de control (`InputBindings.PlayerControlMode`)

| Valor | P1 | P2 (v1) |
|-------|----|---------|
| `KEYBOARD_MOUSE` (0) | WASD + ratón | — |
| `KEYBOARD` (1) | — | Deshabilitado en UI |
| `GAMEPAD` (2) | Stick L mover, R apuntar, RT disparo, R3 modo apuntado | Igual en su mando |

Asignación de device:

- Solo P2 en mando → `pads[0]`
- Solo P1 en mando → `pads[0]`
- Ambos → P1 `pads[0]`, P2 `pads[1]`

## Flujo de disparo

```
Player._process → Input.is_action_just_pressed(_get_fire_action())
  → _try_fire_weapon → clamp_to_aim_views(AimController.screen_pos)
  → WeaponExecutor.try_fire → clamp_reticle_pos + AimResolver.resolve + validate
  → PROJECTILE: resolve_aim_direction (desde boca de cañón)
       → WeaponProjectile.spawn(..., attacker.get_muzzle_world_position())
  → HITSCAN: aim_result.target_spy (via contains_hit_point)
```

## Apuntado (API)

| Función | Rol |
|---------|-----|
| `AimController.get_screen_pos()` | Posición de mirilla en coords. de ventana raíz |
| `AimResolver.clamp_reticle_pos()` | Clamp a unión de vistas |
| `AimResolver.resolve_aim_direction()` | `Vector2` mundo: boca de cañón → mirilla |
| `AimResolver.resolve()` | `AimResult` (vista, sala, `world_pos`, `target_spy`) |
| `AimResolver.world_to_screen()` | Mundo → pantalla con cámara del atacante |
| `SpyBase.get_muzzle_world_position()` | Origen de disparo y pivote de órbita |
| `SpyBase.get_grip_world_position()` | Agarre del arma (apuntado, dead zone mirilla) |
| `SpyBase.contains_hit_point(world_pos)` | ¿Cursor/disparo impacta silueta del espía? |

### Constantes de órbita (`aim_controller.gd`)

- `ORBIT_SCREEN_RADIUS`: 128 px
- `VIRTUAL_CURSOR_SPEED`: 900 px/s
- `STICK_DEADZONE`: 0.35

## Mirilla (UI)

- Colores fijos en `aim_cursor.gd`: P1 blanco `#f5f5f5`, P2 negro `#1a1a1a`, detalle rojo `#c03030`
- Visible si `held.is_holding_weapon()` y `aim_profile` permite cursor
- Dibuja en `clamp_to_aim_views(controller.screen_pos)`
- Posición inicial al equipar: centro habitación → `world_to_screen` → clamp

## Vistas (`GameViewsPanel`)

- `get_player_view_global_rect()` / `get_ai_view_global_rect()`: rect de cada `SubViewportContainer`
- `get_aim_views_global_rect()`: bounding box de ambas (límite de mirilla)
- `clamp_to_aim_views(screen_pos)`: posición efectiva de mirilla/disparo
- `get_game_column_global_rect()`: columna completa (HUD); **no** usar para mirilla
- `spies_share_room()`: vista superior en negro; cámara compartida en `AiView`

## Señales útiles

- `SpyBase.weapon_changed(weapon_id)`
- `SpyBase.held_changed(kind, held_id)`
- `GameState.weapons_changed(spy_id)`
- `InputBindings.control_modes_changed` / `GameSettings.control_modes_changed`
- `AimController.aim_changed(screen_pos)`

## Anti-patrones

- Registrar teclado y mando a la vez para el mismo jugador en `InputMap`
- Usar `spy_id` del nodo para clave de `AimController` en P2 (usar `ItemDB.SpyId.PLAYER2`)
- Cambiar color de mirilla según `validate_for_weapon` (decisión de diseño actual)
- Añadir remapeo en `ControlsSettingsPanel` sin rediseñar asignación de mandos
- Calcular `aim_direction` con `resolve().world_pos - global_position` (usa vista bajo cursor, no mirilla en pantalla)
- Clamp de mirilla a `get_game_column_global_rect()` en lugar de `get_aim_views_global_rect()`
- Órbita pivoteada en `spy.global_position` en lugar de `get_muzzle_world_position()`
- `_unhandled_input` en `Player`/`Player2` para `fire_weapon` (SubViewport no recibe ratón)
- Radio fijo de impacto desde `spy.global_position` (usar `contains_hit_point`)
- Hitbox estática ignorando profundidad en habitación
- `Transform2D(0, pivot)` en idle al dibujar espía (desplaza visual sin mover cañón lógico)
- Calcular muzzle como `grip + aim_direction * barrel_len` sin coords. del rect del cañón
- Dibujo del arma con `walk_xf` pero `get_muzzle_local_offset()` sin la misma transformación
