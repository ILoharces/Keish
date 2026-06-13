---
name: kage-game-systems
description: >-
  Crea y edita armas (WeaponData), combate PvP, apuntado, mirillas, espías
  (visual/hitbox/animación), input y modos de control en Kage (Godot 4). Usar
  cuando el usuario pida armas, controles, combate, AimController,
  InputBindings, mirilla, P1/P2, espías, hitbox, animación de caminar, o
  cambios en resources/weapons.
---

# Sistemas de juego — Kage

Proyecto Godot 4.6 (`config/name="Kage"`). GDScript con tipos explícitos, `@onready`, señales `.connect()`, `randf_range()`.

Antes de cambiar código, lee [reference.md](reference.md) si necesitas rutas, señales o tablas completas.

## Principios

- **Armas**: datos en `.tres` (`WeaponData`); lógica genérica en `WeaponExecutor`. No duplicar pipeline en `Player`.
- **Controles**: bindings **fijos** en código; el jugador solo elige **modo** (teclado+ratón / mando), no remapeo de teclas.
- **InputMap**: `InputBindings.apply_action()` registra **un solo slot** por jugador según modo; nunca teclado+mando a la vez para el mismo jugador.
- **Apuntado**: `AimController` por espía; P1 ratón o stick der.; P2 stick der. Mirilla fija: cuerpo blanco/negro, detalles rojos; sin validación de color.
- **Espías**: placeholder visual (rect + cabeza); hitbox y animación de caminar documentados abajo.
- **Vistas**: `PlayerViewport` y `AiViewport` comparten `world_2d` (`MainScreens`); cámaras independientes centradas en la habitación de cada espía.

## Nueva arma

1. Duplicar `resources/weapons/placeholder_pistol.tres` → `mi_arma.tres`.
2. Ajustar en inspector: `weapon_id` (único), `aim_profile`, `delivery`, `damage`, `cooldown`, `uses_ammo`, `requires_same_room`, etc.
3. Spawn: pool en `MansionBuilder._spawn_placeholder_weapons()` o mapa.
4. Probar: pickup → manos → mirilla → disparo con clic izq. / RT.

Solo tocar código si añades `delivery` nuevo o `WeaponEffect` custom (`custom_effect`).

## Editar controles / modos

| Archivo | Qué hacer |
|---------|-----------|
| `InputBindings` | Teclas/mando por defecto en `_build_default_bindings()`; filtro por modo en `apply_action()` |
| `GameSettings` | Persistir `p1_control_mode` / `p2_control_mode` en `user://game_settings.cfg` |
| `ControlsSettingsPanel` | UI de modos (sin remapeo) |
| `Main` | `uses_mouse` en `AimController`; ocultar cursor SO en partida P1 teclado+ratón |

Reglas de negocio: no dos jugadores en teclado; P2 teclado deshabilitado hasta teclas de apuntado; 2 mandos si ambos en modo mando.

**No** reintroducir `set_binding`, `input_bindings.cfg` ni tabla editable de teclas sin acuerdo explícito.

## Apuntado y mirilla

### Dirección vs. validación de disparo (dos caminos)

| Uso | API | Notas |
|-----|-----|-------|
| Rotación del espía, proyectiles | `AimResolver.resolve_aim_direction()` | Pantalla → mundo con **cámara del atacante**; origen = boca de cañón |
| Hitscan, sala objetivo, `aim_profile` | `AimResolver.resolve()` + `validate_for_weapon()` | Detecta vista bajo el cursor (propia / rival) |

**Regla de diseño**: el personaje apunta hacia **donde está la mirilla en pantalla** respecto al arma, no hacia la posición de mundo de la habitación bajo el cursor en la vista rival.

### Posición de la mirilla

- Límite: `GameViewsPanel.get_aim_views_global_rect()` (unión de `PlayerView` + `AiView`), **no** toda la columna HUD.
- Clamp: `GameViewsPanel.clamp_to_aim_views()` — usar en `AimController`, `AimCursor`, disparo y `resolve_aim_direction`.
- Si el ratón sale de las ventanas, la mirilla se queda en el borde; apuntado y disparo deben usar esa posición clampada.

### Modos de `AimController` (mando)

- **Cursor virtual**: stick mueve `screen_pos` libremente (clamp a vistas).
- **Órbita**: mirilla a distancia fija del arma (`ORBIT_SCREEN_RADIUS` = 128 px); pivote = `SpyBase.get_muzzle_world_position()` en pantalla, **no** el centro del cuerpo.
- Toggle: `aim_mode_toggle` / `p2_aim_mode_toggle` (R3); persistido en `GameSettings`.

### Ratón P1

- `AimController.update()` sigue el ratón con clamp a `get_aim_views_global_rect()`.
- Claves de `AimController`: P1 → `ItemDB.SpyId.PLAYER1`, P2/vista negra → `ItemDB.SpyId.PLAYER2` (aunque el nodo sea `Player2`).

### Snap al equipar

- `Main._snap_aim_to_room_center()` vía `weapon_changed` y `held_changed` (tipo `WEAPON`).
- Re-seleccionar misma arma: `GameState.equip_weapon_in_hands()` y `SpyCombat.set_equipped_weapon()` deben emitir `weapon_changed` aunque el id no cambie.

## Input de combate (SubViewport)

Los espías (`Player`, `Player2`) están dentro de `PlayerViewport/Mansion`. **`_unhandled_input` no recibe clics de ratón** ahí.

- **Movimiento**: ya usa polling (`Input.get_vector` en `_physics_process`) — correcto.
- **Disparo**: `Input.is_action_just_pressed(_get_fire_action())` en `Player._process`; P2 sobreescribe `_get_fire_action()` → `"p2_fire_weapon"`.
- No mover disparo de vuelta a `_unhandled_input` sin resolver enrutado de input al SubViewport.

## Espías: visual, hitbox y animación

### Diseño visual acordado

- **Estilo**: cuerpo rectangular + cabeza circular (`ItemDB.SPY_COLORS`: P1 blanco, P2 negro; contorno `ItemDB.COLOR_OUTLINE`).
- **Escala**: crece/encoge según profundidad en la habitación oblicua (`Room.get_depth_at_local` → lerp de constantes en `SpyVisual`).
- **No** sustituir por monigotes, sombreros, corbatas u otros estilos sin pedido explícito del usuario.

### Hitbox dinámica

| Pieza | Rol |
|-------|-----|
| `SpyVisual.compute_metrics()` | Fuente única de dimensiones (cuerpo, cabeza, hitbox) según profundidad |
| `SpyBase.update_body_collider()` | Actualiza `RectangleShape2D` cada frame (`SpyMovement`) |
| `SpyBase.contains_hit_point(world_pos)` | Hitscan (`AimResolver._find_spy_at_world_pos`) y orbital strike |
| `SpyBase.HITBOX_SHRINK` (0.9) | Mismo factor en collider físico y detección de disparo |

La hitbox cubre **cuerpo + cabeza** y se centra en la silueta. **No** usar radio fijo desde `global_position` (p. ej. 48 px).

### Animación de caminar (wiggle)

- `SpyBase.walk_phase` avanza en `SpyMovement._update_walk_phase()` solo si `velocity.length_squared() > 64`.
- Efecto **solo visual**: ligera rotación izq./der. + pequeño rebote; pivote en los pies `(0, body_h * 0.45)`.
- Constantes en `SpyVisual`: `WALK_TILT` (~0.055 rad), `WALK_BOB`, `SpyBase.WALK_WIGGLE_SPEED`.
- **`SpyVisual._get_walk_transform()`**: devuelve `Transform2D.IDENTITY` en reposo. Al caminar: rotación alrededor del pivote de los pies (`translated(pivot+bob).rotated(tilt).translated(-pivot)`).
- **Regla crítica**: nunca aplicar offset de pivote al dibujo cuando el espía está quieto; desincroniza cañón visual vs. lógico.

### Boca de cañón y agarre (sincronía dibujo ↔ combate)

- Origen de proyectiles: `SpyBase.get_muzzle_world_position()` → `SpyVisual.get_muzzle_local_offset()`.
- La punta del cañón se calcula con la **misma geometría del rect del cañón** (`PISTOL_BARREL_*`) vía `_muzzle_weapon_local()` + `_weapon_point_local()`.
- Si hay wiggle activo, aplicar `_get_walk_transform()` también a cañón y agarre (misma matriz que el dibujo del arma: `walk_xf * Transform2D(angle, grip)`).
- **Anti-patrones**: `grip + aim_direction * barrel_len` sin offset en espacio del arma; dibujar con `walk_xf` pero calcular muzzle sin él.

## Checklist antes de cerrar

- [ ] ¿`weapon_id` único y cargado por `WeaponDB`?
- [ ] ¿Acciones `fire_weapon` / `p2_*` / `aim_*` solo en el slot del modo activo?
- [ ] ¿Mirilla visible con arma que usa cursor (`aim_profile` ≠ NONE/DIRECTIONAL)?
- [ ] ¿Apuntado usa mirilla clampada y pivote en boca de cañón?
- [ ] ¿Disparo usa polling, no `_unhandled_input` en espías?
- [ ] ¿Hitbox escala con profundidad y `contains_hit_point` alineado con collider?
- [ ] ¿Proyectiles salen de la punta visual del cañón (reposo y caminando)?
- [ ] ¿Documentado en `docs/ARCHITECTURE.md` si cambia flujo global?

## Recursos

- Detalle: [reference.md](reference.md)
- Arquitectura general: `docs/ARCHITECTURE.md`
