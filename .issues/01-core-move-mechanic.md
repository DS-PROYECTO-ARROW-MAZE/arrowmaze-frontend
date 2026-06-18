# 01 · Core Move Mechanic (Tracer Bullet spine)

- **Phase:** 1 — BLOCKING
- **Stories:** A1 (valid move / arrow exits), A3 (tap any order)
- **Blocked by:** —
- **Unblocks:** 02, 03, 04, 05, 06, 07, 08
- **Traceability:** PRD §11 (A1–A3) · tests §7.2

## Why this is the tracer bullet

It is the thinnest end-to-end path that proves the architecture: a tap on a
rendered cell travels `View → ViewModel → UseCase → Tablero(domain)` and back as
an immutable `*ViewState`, and the arrow visibly disappears. Every other slice
hangs off the entities and ports established here.

## User Story

> *As a player, when I tap an arrow whose path to the edge is clear, I want it to
> leave the board so I make progress — and I want to be able to tap any arrow at
> any time, in any order, with no position/reachability constraint.*

## Deep Modules touched (vertical slice)

| Layer | Module / file |
|---|---|
| `domain/entities` | `Celda` (sealed) + `Flecha`, `CeldaVacia`, `CeldaPared`; `FabricaCeldasEstandar` (Factory Method) |
| `domain/value_objects` | `Posicion`, `Vector3`/`Direccion` (dimension-agnostic; 2D = 4 dirs) |
| `domain` (DM-F1) | `Tablero` **port** (`celdaEn`, `raycast`), `GrafoTablero` + `Nodo` incremental impl, `DetectorColisiones.detectar` → `raycast` |
| `application/use_cases` (DM-F2) | `MoverFlechaUseCase.ejecutar(Posicion) → ResultadoMovimiento` (valid-exit path only here), `ResultadoMovimiento`, `EventoJuego`/`TipoEvento` (`MovimientoRealizado`, `FlechaEliminada`) |
| `presentation/viewmodels` (DM-F8) | `JuegoViewModel` + immutable `JuegoViewState` (`TableroUI`, `CeldaUI`) via `copyWith`; binds via `notifyListeners()` |
| `presentation/views/game` | minimal `GameView` rendering a grid; `onTap(Posicion)` → ViewModel |
| `infrastructure` + `di` | in-memory/hardcoded board source so the slice runs; DI wires `Tablero` + use case into the VM |

## Acceptance Criteria (from PRD §3 A1/A3, §7.2)

1. Clear ray to edge → arrow's cell becomes `CeldaVacia`; move is **valid**; `movimientos += 1`.
2. `ResultadoMovimiento` carries events including `FlechaEliminada` and `MovimientoRealizado`.
3. `CeldaVacia` is **transparent**: a ray flies over it without interacting.
4. Edge case: arrow already adjacent to the edge with a clear ray → exits in one tap.
5. Tap-any-order: arbitrary tap sequences resolve with **no** reachability/position error.
6. Removal is **incremental** — the removed arrow unlinks its `Nodo`; no full graph rebuild.

## Strict TDD instructions (red → green → refactor)

Tests target the **deep-module interfaces** (`Tablero`, `MoverFlechaUseCase`), never internals.

### 🔴 RED — write failing tests first (`flutter_test` + `mocktail`)
- `domain/tablero_raycast_test.dart`
  - `should_return_clear_to_edge_when_path_has_only_vacias` (AC3).
  - `should_report_arrow_adjacent_to_edge_as_clear` (AC4).
- `domain/grafo_tablero_test.dart`
  - `should_unlink_node_without_full_rebuild_when_arrow_removed` (AC6 — assert neighbours of the removed node are re-wired, board instance identity of untouched nodes preserved).
- `application/mover_flecha_valida_test.dart` (fake `Tablero` via mocktail)
  - `should_empty_cell_and_increment_movimientos_when_ray_clear` (AC1).
  - `should_emit_FlechaEliminada_and_MovimientoRealizado_when_move_valid` (AC2).
  - `should_resolve_without_reachability_error_when_tapping_any_arrow` (AC5).
- `presentation/juego_viewmodel_test.dart`
  - `should_expose_new_JuegoViewState_with_emptied_cell_when_move_valid` (binding works; state is a new immutable instance via `copyWith`).

All must fail (classes don't exist / throw `UnimplementedError`). Use **AAA** layout.

### 🟢 GREEN — minimum to pass
- `FabricaCeldasEstandar.crear(json)` → correct `Celda`. Implement `GrafoTablero.raycast` greedy walk to edge. Implement `MoverFlechaUseCase` valid branch (+1, empty cell, events). Wire `JuegoViewModel.tocar(Posicion)` to call the use case and `notifyListeners()`.
- **No invalid-move logic yet** (that is ticket 02) — keep the surface honest.

### ♻️ REFACTOR
- Extract `DetectorColisiones` so collision lives behind `raycast` (OCP seam for the future 3D `Tablero`).
- Confirm `domain/` imports **zero** Flutter (will be re-checked by ticket 12 guard).
- Keep `≥ 90%` line coverage on the domain + application files added here.

## Definition of Done
- All RED tests green; coverage gate met on touched domain/application files.
- Tapping a clear-ray arrow in `GameView` visibly empties the cell on device.
- `domain/` and `application/` contain no `package:flutter` import.
