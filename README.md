# Kage

Duelo 1v1 de espías en una mansión, inspirado en **Spy vs Spy**. Recoge objetos secretos, usa trampas y armas, y escapa antes de que se acabe el tiempo — o agota el reloj de tu rival.

> **Versión muy temprana (alpha cruda).** Hay errores, sistemas incompletos y comportamientos inesperados. El **respawn** en particular todavía no funciona bien (reapariciones fallidas, teletransportes raros, penalización de tiempo confusa). Úsalo como prototipo jugable, no como producto terminado.

## Requisitos

- [Godot 4.6](https://godotengine.org/) (el proyecto declara la feature `4.6`)
- Windows / Linux / macOS según exportes desde el editor

## Cómo ejecutar

1. Clona el repositorio.
2. Abre la carpeta del proyecto en Godot (**Import** → selecciona `project.godot`).
3. Pulsa **F5** (escena principal: `Scenes/main.tscn`).

La primera vez verás un **tutorial** en pantalla. Puedes saltarlo; no volverá a mostrarse (se guarda en `user://game_settings.cfg`).

## Objetivo de la partida

- Dos espías: **blanco** (jugador 1) vs **negro** (IA o segundo jugador local).
- Reúne **5 objetos**: primero el **maletín**, luego llave, dinero, pasaporte y microfilm.
- **Escapa** por la puerta de salida con todo el botín.
- Cada espía tiene unos **5 minutos** de reloj personal. Ganas escapando o si el rival se queda sin tiempo.
- Matar al rival **no** termina la partida: suelta su botín y le penaliza el tiempo; luego reaparece (con los problemas del respawn mencionados arriba).

## Controles (resumen)

| Acción | Jugador 1 (teclado + ratón) | Jugador 2 (PvP local) |
|--------|----------------------------|------------------------|
| Mover | WASD | Flechas |
| Apuntar (combate) | Ratón en las ventanas de vista | Mando: stick derecho (recomendado) |
| Disparar | Clic izquierdo | **O** / RT (mando) |
| Interactuar | E | I |
| Trampas / ciclar | Q / R | P / U |
| Trapulator | Tab | Home |
| Mapa | M | (ver bindings P2 en Ajustes) |
| Pausa | Esc | (acción P2 en Ajustes) |

Modos de control (teclado+ratón vs mando) en **Ajustes > Controles**. No hay remapeo de teclas en esta versión.

Con **IA**, el jugador 1 puede alternar entre ratón y mando según el último dispositivo usado.

## Armas

Las armas se recogen en el mapa y se equipan **en las manos** (no van al inventario de objetos).

### Mirilla y ventanas de vista

El apuntado de combate usa la **mirilla** dentro de la unión de las dos ventanas (vista del espía blanco y vista del negro). Fuera de esa zona, la mirilla se queda en el borde.

### Pistola y metralleta

Apuntas hacia donde quieres disparar (en tu vista o en la del rival, según el arma) y disparas con clic / RT. Los proyectiles salen de la boca del cañón del espía.

### Cañón orbital (láser)

Arma especial que ataca **la habitación del rival** desde su propia ventana de vista:

1. Equipa el **cañón orbital**.
2. Pulsa **disparar** una vez para **armar** el láser (modo de puntería orbital).
3. Mueve la mirilla a la **ventana del rival** y colócala sobre la habitación donde quieres golpear.
4. Pulsa **disparar** de nuevo: breve aviso y un rayo orbital; si el rival está en esa habitación y el impacto le alcanza, es letal.

Solo tiene **un disparo** por recarga en el mapa. Es la forma principal de atacar sin estar en la misma sala que el enemigo.

## Trampas y HUD

- **Trampas**: Q/R para ciclar y colocar; **Tab** abre el trapulator.
- **Mapa**: **M** durante la partida.
- El **HUD** muestra inventario, tiempo, munición y estado de cada espía.

## Editor de mapas

Desde el menú principal: **Crear mapa**. Los mapas guardados van a `user://maps/` (JSON). Ver también [`levels/README.md`](levels/README.md).

## Estructura del proyecto

| Ruta | Contenido |
|------|-----------|
| `Scenes/` | Escenas (principal, UI, mundo) |
| `Scripts/` | Lógica GDScript |
| `resources/weapons/` | Datos de armas (`.tres`) |
| `docs/ARCHITECTURE.md` | Arquitectura y checklist para contribuir |

Autoloads principales: `GameState`, `GameSettings`, `InputBindings`, `WeaponDB`, `ItemDB`.

## Problemas conocidos

- Respawn inestable (ver aviso arriba).
- P2 con solo teclado: apuntado de combate muy limitado.
- Algunos tipos de disparo de `WeaponData` no están implementados.
- Victoria oficial solo por **escape** o **timeout** (muertes sueltan botín pero no cierran la partida solas).
