# 03 · Collectible Pass-through (bonus time)

- **Phase:** 2 — PARALLELIZABLE
- **Stories:** A4 (collectible pass-through)
- **Blocked by:** 01
- **Unblocks:** —
- **Traceability:** PRD §11 (A4) · tests §7.2

## User Story

> *As a player, when a valid move's ray crosses a collectible, I want bonus time.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain/entities` | `Coleccionable` — the 4th `Celda` kind from `FabricaCeldasEstandar` (no decorators, no Composite) |
| `domain` (DM-F1) | `Tablero.raycast` treats `Coleccionable` as **transparent** (does not block the ray) |
| `application` (DM-F2) | `MoverFlechaUseCase` emits `ColeccionableRecogido` on a valid ray crossing a collectible; adds seconds to the level timer |
| `presentation` (DM-F8) | `JuegoViewState` reflects collected bonus + updated timer in the HUD |

## Acceptance Criteria (PRD §3 A4, §7.2)

1. `Coleccionable` on the path of an otherwise-clear ray → ray is **not** blocked.
2. When the arrow exits, a `ColeccionableRecogido` event adds seconds to the timer.
3. Victory **never** depends on the collectible (board can empty regardless).

## Strict TDD instructions (red → green → refactor)

### 🔴 RED
- `domain/raycast_collectible_test.dart`:
  - `should_not_block_ray_when_path_crosses_collectible` (AC1).
- `application/mover_flecha_collectible_test.dart` (fake `Tablero` + fake timer/clock):
  - `should_emit_ColeccionableRecogido_and_add_seconds_when_ray_crosses_collectible` (AC2).
  - `should_reach_victory_without_collecting_when_board_empties` (AC3 — negative/property guard).

### 🟢 GREEN
- Add `Coleccionable` to `FabricaCeldasEstandar`; mark it transparent in `raycast`; emit the event and apply the timer delta in the valid branch.

### ♻️ REFACTOR
- Keep "transparency" a property of the cell kind queried by `raycast`, not an `if (type == ...)` in the use case (OCP — adding cell kinds shouldn't touch callers).

## Definition of Done
- Collectible never blocks; bonus seconds applied via event; victory independent of collectibles.
